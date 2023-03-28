module waveforms;

import std.algorithm;
import std.file;
import std.stdio;
import std.mmfile;
import std.container.dlist;

// require little endian for compilation
version(BigEndian) 
{
    static assert(0);
}



/**
 * 
 * events are ordered as read from the file
 */
class WaveformSession
{   
    string outputDir;

    const size_t rawLength;
    size_t errorCount;
    size_t usableEventCount() const @property
    {
        return rawLength - errorCount;
    }

    double errorRate() const @property
    {
        return cast(double) errorCount / cast(double) rawLength;
    }

    /// create a completely new one
    this(string sourceWaveformFile, string outputDir)
    {
        // scoped mmap sourcefile to memory
        auto source = new SourceFile(sourceWaveformFile);
        rawLength = source.length();
        this.outputDir = outputDir;

        this.preprocess();
    }

    // todo load/unload ...


    /*
     * This function processes entries as if they were a linked list from 2 slots as a memory aware placeholder for now
     * These objects are done this way
     *
     * maxSlowEnergy is the maximum value of slowEnergy in any event considered valid,
     * if a channel is found with more 
     *
     * It makes the histograms work more efficently
     */
    void preprocess(string outputBinFile = "intermediateData.bin", float maxSlowEnergyDC = 10000, float maxSlowEnergyAC = 10000, float maxWaveformABS = 1000)
    {

        auto events = DList!WaveEvent();
         
        //// todo open output for deshittified data
        //// take note of what was removed
        //// collect pre & post summary stats
 
        foreach(i, const ref diskEntry; source.entries)
        {
            // load current entry from the DMA VMEM to RAM (hopefully cache)
            events ~= new WaveEvent(diskEntry, i, (0!=i) ? events.front : null);
        }
        

    }

    /// A container for a WaveEvent stored in RAM
    /// disk will be filled with WaveEventRecords
    class WaveEvent
    {
        WaveEventRecord data;

        alias data this;

        this(const ref DiskEntry diskEntry, size_t i, WaveEvent previous = null)
        {
            data = new WaveEventRecord(diskEntry, i, previous);
        }

        void setADCerror()
        {
            data.errorADC = true;

            if (!data.hasError)
            {
                data.hasError = true;
                this.outer.errorCount++;
            }
        }

        void setGlitchError()
        {
            data.errorGlitch = true;

            if (!data.hasError)
            {
                data.hasError = true;
                this.outer.errorCount++;
            }
        
        }

        // this will be used for printing analysis
    }

    // struct errorcount
    // struct will allow easier DMA storage and use later
    // might consider align with page size
    /// waveform values out of +- 1000
    static struct WaveEventRecord
    {
        align(1):

        // assume time is useless for now ()
    
        const size_t eventNumber; // in file

        bool hasError;
        bool errorADCinit;
        bool errorNonsense;
        bool outOfRange;

        bool likelyNoise;
        const ubyte uselessTime;
        const ushort uselessTag;

        // storing makes easier to sort
        const uint sumSlowEnergyDC;
        const uint sumSlowEnergyAC;

        bool[32] CFDflags;

        // may want
        const union
        {
            ushort[32] slowEnergys;

            struct
            {
            align(1):

                /**
                * slowEnergy: Energy deposited on each strip
                * Useful in energy resolution (multiplier to get energy)
                * strips 0-15 represent the DC coulpled side,
                * That is the front side with vertical strips, predicts x position  */
                float[16] slowEnergyDC;


                /**
                * slowEnergy: Energy deposited on each strip
                * Useful in energy resolution
                * strips 16-31 represent the AC coupled side
                * AC = back side, horizontal strips, predicts y position */
                float[16] slowEnergyAC;
            }
        }

        union
        {
            short[20][32] waveforms;
    
            struct
            {
            align(1):
                short[20][16] waveformDC;
                short[20][16] waveformAC;
            }
        }
        // todo errors

    package:
        /// this will handle preprocessing
        this(const ref DiskEntry diskEntry, size_t i, WaveEvent previous = null)
        {
            // disabled to avoid setting up a 
            //assert(diskEntry.delay == 0); // think it is -0 somewhere (floating point is wierd)

            eventNumber = i;

            uselessTime = diskEntry.time;
            uselessTag = diskEntry.eventTag;

            // calculate CFD flags

            // CFD
            static foreach(i_byte; 0 ..4)
            {
                static foreach(i_bit; 0..8)
                {
                    this.CFDflags[i_byte*8 + i_bit] = to!bool(diskEntry.CFDflags[i_byte] & (128u>>i_bit));
                }    
            }

            slowEnergies[] = diskEntry.slowEnergie[].map!(a=>to!float(a));
            waveforms[] = diskEntry.waveforms[];

            sumSlowEnergyDC = slowEnergyAC[].sum();
            sumSlowEnergyAC = slowEnergyDC[].sum();

            // First element
            if (i == 0 && diskEntry.waveforms[0][0] == -2048)
            {
                errorADCinit = true;
                hasError = true;
            }

            // scanning for this allows ma
            if ((eventTag == - RepeatedNonsenseEventTag || previous.errorNonsense)
                && equals(CFDflags[], previous.CFDflags[])
                && equals(slowEnergys[], previous.slowEnergys[])
                && equals(waveforms[], previous.waveforms[]));
            {
                previous.errorNonsense = true;
                previous.hasError = true;
                
                errorNonsense = true;
                hasError = true;
            }
        }
    }


    // note both before and after have valid tags but are not valid
    enum short RepeatedNonsenseEventTag = -21846;

    /// fully annotated will make debugging easier
    static struct DiskEntry
    {
    // Store event data exactly as laid out in binary file
    align (1):
        /// Time: used in deltaT
        ubyte time;

        /// Constant Fraction Discriminator: used for depth of interaction
        ubyte[4] cfdFlags;

        short eventTag;

        double[32] slowEnergys;
        short[20][32] waveforms;
        double delay;// always 0 in this data set
    }

package:
    /// keep the mmap open to facilitate debugging
    class SourceFile
    {
        const string filename;
        const DiskEntry[] entries;
        size_t readIndex;

        alias entries this;

        size_t length() const @property
        {
            return entries.length;
        }

        this(string filename) 
        in
        {
            assert(exists(filename) && isFile(filename));
        } 
        do        
        {
            this.filename = filename;
            diskFile = new MmFile(filename, MmFile.Mode.read, 0, null, 0);
            entries = cast(const DiskEntry[]) diskFile[];
        }
    
        package:
            import std.mmfile;
            MmFile diskFile;
    }
}
