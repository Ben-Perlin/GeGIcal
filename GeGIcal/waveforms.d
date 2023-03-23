module waveforms;

import std.algorithm;
import std.file;
import std.stdio;
//import std.mmfile;


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
    SourceFile source;
    string outputDir;


    size_t errorCount;

    this(string sourceWaveformFile, string outputDir)
    {
        this.source = new SourceFile(sourceWaveformFile);
        this.outputDir = outputDir;
    }

    // todo load/unload ...


    /*
     * This function processes entries as if they were a linked list from 2 slots as a memory aware placeholder for now
     * These objects are done this way
     */
    void preprocess()
    {
        // todo open output for deshittified data
        // take note of what was removed
        // collect pre & post summary stats


        //todo consider std.container
        //WaveEntry previous;
        DiskEntry last;

        // done this way to load
        foreach(i, entry; source.entries) {
            //auto entry = new WaveEntry(diskEntry, i, previous);
            
            // check ADC initialization
            if (i==0 && entry.waveforms[0][0] == -2048)
            {
                //todo ADC
            }
            
            //
            //
            //previous = entry;


            last = entry;
        }
        
        // for now, we can just take the error count and save it,
        // but todo goal is to cache to disk especially after restricting ranges

        // todo any saves necessary

        // free ram now
        //entries.destroy();
    }

package:


    // struct errorcount


    enum short RepeatedNonsenseEventTag = -21846;

    //
    //        import std.algorithm;
    //
    //        // TODO magic number
    //        if (eventTag == glitchEventTag && previous !is null && equal(source._stripData[], previous._stripData[]))
    //        {
    //            this.markError();
    //            previous.markError();
    //        }
    //
    //
    //        // todo stats, computed values (ie sums), histograms()
    //
    //
    //        // todo estimate depth from cfd flags
    //    }
    //
    //    void checkADCinitialization() 
    //    in
    //    {
    //        assert(diskIndex = 0);
    //    }
    //    do
    //    {
    //        if (waveformDC[0][0] == -2048)
    //        {
    //            markError();
    //        }
    //    }
    //
    //    void checkRepeatedNonsenseError()
    //    {
    //        if
    //
    //    }
    //

    //

    static struct DiskEntry
    {
    // Store event data exactly as laid out in binary file
    align (1):
        /// Time: used in deltaT
        ubyte time;

        /// Constant Fraction Discriminator: used for depth of interaction
        ubyte[4] cfdFlags;

        short eventTag;

        union
        {
            struct
            {
            align (1):
                union
                {
                    double[32] slowEnergy;

                    struct
                    {
                    align(1):                
                        /**
                        * slowEnergy: Energy deposited on each strip
                        * Useful in energy resolution (multiplier to get energy)
                        * strips 0-15 represent the DC coulpled side,
                        * That is the front side with vertical strips, predicts x position  */
                        double[16] slowEnergyDC;

                        /**
                            * slowEnergy: Energy deposited on each strip
                            * Useful in energy resolution
                            * strips 16-31 represent the AC coupled side
                            * AC = back side, horizontal strips, predicts y position */
                        double[16] slowEnergyAC;
                    }          
                }

                union
                {
                    short[20][32] waveforms;

                    struct
                    {
                    align(1):
                        /// Waveforms recorded at 12bit
                        short[20][16] waveformDC;
                        short[20][16] waveformAC;
                    }

                }
            }

            ubyte[32*8 + 2*20*32] _stripData;
        }

        double delay;// always 0 in this data set
    }

    /// keep the mmap open to facilitate debugging
    class SourceFile
    {
        const string filename;
        const DiskEntry[] entries;
        size_t readIndex;

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
