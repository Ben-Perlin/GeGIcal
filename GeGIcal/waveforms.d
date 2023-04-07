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
 * Data Loader and Preprocessor for waveform data
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

    size_t usableEventCount;

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

        //auto events = DList!WaveEvent();
        
        WaveEvent current, previous;

        //// todo open output for deshittified data
        //// take note of what was removed
        //// collect pre & post summary stats
 
        foreach(i, const ref diskEntry; source.entries)
        {
            previous = current;

            // todo save/better processing hist & more

            // load current entry from the DMA VMEM to RAM (hopefully cache)
            current = new WaveEvent(diskEntry, i, (0!=i) ? previous : null);
        }
        // todo replace with more eligant
        current.reportErrorsRange();


        

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
                }
            }
            else if (previous.errorGlitch)
            {
               // check if this is also a glitch
               if (eventData == previous.eventData)
               {
                   errorGlitch = true;
               }
            }
            else if (uselessTag == RepeatedNonsenseEventTag)           
            {
                if (eventData == previous.eventData)
                {
                    previous.errorGlitch = true;
                    errorGlitch = true;
                }
                
            }


            checkRangesSlowEnergy();
            checkRangesWaveform();


            // report errors (todo instead let summary stats engine do that)

            if (0 != i)
            {
               previous.reportErrorsRange();
            }
        }


    package:


        void checkRangesSlowEnergy()
        {
            outOfRangeSlowEnergy = (
                 data.slowEnergyDC[].maxElement >= settings.maxSlowEnergyValueDC
              || data.slowEnergySumDC >= settings.maxSlowEnergySumDC
              || data.slowEnergyAC[].maxElement >= settings.maxSlowEnergyValueAC
              || data.slowEnergySumAC >= settings.maxSlowEnergySumAC);
        }   

        void checkRangesWaveform()
        {
            import std.math;

            outOfRangeWaveform = (data.waveformValues[].map!(a => abs(a)).maxElement >= settings.maxWaveformABSvalue);
        }

        void reportErrorsRange()
        {
        // todo with this.outer?
            this.outer.errorCount += hasError;
            this.outer.outOfRangeCount += outOfRange;
            this.outer.outOfRangeSlowEnergyCount += outOfRangeSlowEnergy;
            this.outer.outOfRangeWaveformCount += outOfRangeWaveform;
            this.outer.usableEventCount += !(hasError || outOfRange);
        }
    }


    // struct will allow easier DMA storage and use later
    // thus may be const, so it recieves owner pointer to use as "this" in creation only
    // might consider align with page size
    static struct WaveEventRecord
    {
        align(1):
    
        size_t eventNumber; // in file

        bool errorADCinit;
        bool errorGlitch;

        bool hasError() const @property
        {
            return errorADCinit || errorGlitch;
        }


        
        bool outOfRangeSlowEnergy; // and not an error
        bool outOfRangeWaveform;

        bool outOfRange() const @property
        {
            return outOfRangeSlowEnergy || outOfRangeWaveform;   
        }

        // not used yet
        bool likelyNoise;

        ubyte uselessTime;
        short uselessTag;

        // todo positions for loss function

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

            // hold on to these only for debugging and error detection
            uselessTime = diskEntry.time;
            uselessTag = diskEntry.eventTag;

            // set up the CFD (tested before integration)
            static foreach(i_byte; 0 ..4)
            {
                static foreach(i_bit; 0..8)
                {
                    this.CFDflags[i_byte*8 + i_bit] = (0 != (diskEntry.CFDflags[i_byte] & (128u>>i_bit)));
                }    
            }


            // process DC slowEnergy
            {
                double slowEnergyDCaccum;
                foreach (size_t i, double slowE; diskEntry.slowEnergy[0..16])
                {
                    slowEnergyDCaccum += slowE;
                    slowEnergyDC[i] = cast(float) slowE;
                }
                slowEnergySumDC = cast(float) slowEnergyDCaccum;
            }

            // processAC slowEnergy
            {
                double slowEnergyACaccum; 
                foreach (size_t i, double slowE; diskEntry.slowEnergy[16..32])
                {
                    slowEnergyACaccum += slowE;
                    slowEnergyAC[i] = cast(float) slowE;
                }
                slowEnergySumAC = cast(float) slowEnergyACaccum;
            }

            // copy waveformValues
            waveformValues[] = diskEntry.waveformValues[];
        }
    }

package:
    // note both before and after have valid tags but are not valid
    enum short RepeatedNonsenseEventTag = -21846;

    static struct DiskEntry
    {
    // Store event data exactly as laid out in binary file
    align (1):
        /// Time: used in deltaT
        ubyte time;

        /// Constant Fraction Discriminator flags for strips that triggered
        ubyte[4] CFDflags;

        // useful mostly for detecting glitches
        short eventTag;

        double[32] slowEnergy;
        union{
            short[640] waveformValues;
            short[20][32] waveforms;
        }

        double delay; // unused, always 0 in this data set
    }

    /// container for open MMAP to raw, unprocessed waveform files
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
