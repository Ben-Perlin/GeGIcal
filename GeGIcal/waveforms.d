module waveforms;

import std.algorithm;
import std.file;
import std.stdio;
import std.mmfile;
import std.container.dlist;
import std.conv;

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
    const string outputDir;

    const size_t rawLength;
    size_t errorCount;

    size_t outOfRangeCount; // has either slowE, waveform, or both out of range
    size_t outOfRangeSlowEnergyCount;
    size_t outOfRangeWaveformCount; // if not an error

    size_t usableEventCount() const @property
    {
        return rawLength - errorCount - outOfRangeCount;
    }

    /// rate of errors detected in this session
    double errorRate() const @property
    {
        return cast(double) errorCount / cast(double) rawLength;
    }

    double outOfRangeRate() const @property
    {
        return cast(double) outOfRangeCount / cast(double) rawLength;
    } 
    

    this(string sourceWaveformFile, string outputDir, WaveEventFilterSettings settings = defaultSettings)
    {
        // scoped mmap sourcefile to memory
        auto source = SourceFile(sourceWaveformFile);
        rawLength = source.length();

        this.outputDir = outputDir;
        this.settings = settings;

        //string outputBinFile = "intermediateData.bin";

        auto events = DList!WaveEvent();
         
        //// todo open output for deshittified data
        //// take note of what was removed
        //// collect pre & post summary stats
 
        foreach(i, const ref diskEntry; source.entries)
        {
            // load current entry from the DMA VMEM to RAM (hopefully cache)
            events ~= new WaveEvent(diskEntry, i, (0!=i) ? events.back : null);
        }
        

        

        //todo save intermediate data

    }

    /// settings for out of range filter (defaults to very permissive values with pretty-printable range);
    static struct WaveEventFilterSettings
    {
        float maxSlowEnergyValueDC = 10000;
        float maxSlowEnergyValueAC = 10000;
        float maxSlowEnergySumDC = 10000;
        float maxSlowEnergySumAC = 10000;
        float maxWaveformABSvalue = 1000;
    }

    static WaveEventFilterSettings defaultSettings; //  default

    // thread local
    const WaveEventFilterSettings settings;

    /// A container for a WaveEvent stored in RAM
    /// disk will be filled with WaveEventRecords
    class WaveEvent
    {
        WaveEventRecord data;

        alias data this;

        this(const ref DiskEntry diskEntry, size_t i, WaveEvent previous)
        {
            data = WaveEventRecord(diskEntry, i);

            if (i==0)
            {
                // check ADC error
                if (waveformValues[0] == -2048)
                {
                    errorADCinit = true;
                    //hasError = true;
                    //this.outer.errorCount++;
                }
            }
            else if (previous.errorGlitch)
            {
               // check if this is also a glitch
               if (eventData == previous.eventData)
               {
                   errorGlitch = true;
                   //hasError = true;
                   //this.outer.errorCount++;
               }
            }
            else if (uselessTag == RepeatedNonsenseEventTag)           
            {
                // assert(!previous.errorGlitch)
                
            }

            checkRangesSlowEnergy();
        }


    package:
        void setError()
        {
            if (!hasError)
            {
                hasError = true;
                this.outer.errorCount++;
            }
        }

        void checkGlitchError(WaveEvent previous)
        {
                  // scanning for this allows ma
            if (eventData.equal(previous.eventData))
            {
            previous.setGlitchError();
                setGlitchError();
            }
        }

        /// involked on a glitch error
        void setGlitchError()
        {
            data.errorGlitch = true;
            setError();
        }

        void markOutOfRange()
        {
            if (!outOfRange)
            {
                outOfRange = true;
                this.outer.outOfRangeCount++;
            }
        }

        void checkRangesSlowEnergy()
        {
            if ( (data.slowEnergyDC[].maxElement >= settings.maxSlowEnergyValueDC
                 || data.slowEnergySumDC >= settings.maxSlowEnergySumDC)
             ||  ( data.slowEnergyAC[].maxElement >= settings.maxSlowEnergyValueAC
                 || data.slowEnergySumAC >= settings.maxSlowEnergySumAC) )
            {
                this.outOfRangeSlowEnergy = true;
                this.outer.outOfRangeSlowEnergyCount++;
                markOutOfRange();
            }
        }   

        void checkRangesWaveform()
        {
            import std.math;

            if ((data.waveformValues[].map!(a => abs(a)).maxElement >= settings.maxWaveformABSvalue))
            {
                // todo independent flag for waveform range
                this.outOfRangeWaveform = true;
                this.outer.outOfRangeWaveformCount++;
                markOutOfRange();
            }
        }

        /+

        // this will be used for printing analysis
        void submitForAnalysis()
        in
        {
            assert(!data.hasError);
            assert(!data.outOfRangeSlowEnergy);
        }
        do
        {
            //todo

            //todo slowEnergy Histograms

            // sums -> rbtree

            // waveform for depth? 50% cfd diff ?
            
            
        }
        +/

        // todo tostring for printing




    }

    // struct errorcount
    // struct will allow easier DMA storage and use later
    // thus may be const, so it recieves owner pointer to use as "this" in creation only
    // might consider align with page size
    /// waveform values out of +- 1000
    static struct WaveEventRecord
    {
        align(1):
    
        size_t eventNumber; // in file

        // todo bitfield

        // todo move these fields to waveEvent ???
        bool hasError;
        bool errorADCinit;
        bool errorGlitch;
        
        bool outOfRange;
        bool outOfRangeSlowEnergy; // and not an error
        bool outOfRangeWaveform;


        bool likelyNoise;

        ubyte uselessTime;
        short uselessTag;

        // storing makes easier to sort
        float slowEnergySumDC;
        float slowEnergySumAC;

        union
        {
            struct
            {
            align(1):
                union 
                {
                    struct
                    {
                    align (1):
                        bool[16] CFDflagsDC;
                        bool[16] CFDflagsAC;
                    }

                package:
                    bool[32] CFDflags;
                }

                // may want
                union
                {
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
        
                package:
                    float[32] slowEnergy;
                }

                union
                {
                    struct
                    {
                    align(1):
                        short[20][16] waveformDC;
                        short[20][16] waveformAC;
                    }
        
                package:
                    short[20][32] waveforms;
                    short[640] waveformValues;
                }
            }

            void[CFDflags.sizeof + slowEnergy.sizeof + waveformValues.sizeof] eventData;
        }

    package:
        /// this will handle preprocessing
        this(const ref DiskEntry diskEntry, size_t index)
        {
            eventNumber = index;

            uselessTime = diskEntry.time;
            uselessTag = diskEntry.eventTag;

            // set up the CFD
            static foreach(i_byte; 0 ..4)
            {
                static foreach(i_bit; 0..8)
                {
                    this.CFDflags[i_byte*8 + i_bit] = (0 != (diskEntry.CFDflags[i_byte] & (128u>>i_bit)));
                }    
            }

            // reduce size of slowE type
            foreach (size_t i, float slowE; diskEntry.slowEnergy[])
            {
                slowEnergy[i] = slowE;
            }

            waveformValues[] = diskEntry.waveformValues[];

            slowEnergySumDC = slowEnergyAC[].sum();
            slowEnergySumAC = slowEnergyDC[].sum();
        }
    }


package:
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
        ubyte[4] CFDflags;

        short eventTag;

        double[32] slowEnergy;
        union{
            short[640] waveformValues;
            short[20][32] waveforms;
        }
        double delay;// always 0 in this data set
    }

    /// container 
    struct SourceFile
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
