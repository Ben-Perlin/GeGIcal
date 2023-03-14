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

    this(string sourceWaveformFile, string outputDir)
    {
        this.source = new SourceFile(sourceWaveformFile);
        this.outputDir = outputDir;
    }




    
    void preprocess()
    {
        // todo open output for deshittified data
        // take note of what was removed
        // collect pre & post summary stats

        foreach(i, entry; SourceFile.entries)
        {
            if (i==0 && entry.waveforms[0][0] == -2048)
            {
                //BAD ADC found

            }


            

        }

    }

    //class WaveEntry
    //{
    //    // want mixed percision for slowEnergy & waveform 
    //
    //    this(Entry entry)
    //    {
    //    ;
    //    }
    //
    //    // link to next  ...    
    //}
    //

    /// keep the mmap open to facilitate debugging
    class SourceFile
    {
        const string filename;
        const Entry[] entries;

        this(string filename) 
        in
        {
            assert(exists(filename) && isFile(filename));
        } 
        do        
        {
            this.filename = filename;
            diskFile = new MmFile(filename, MmFile.Mode.read, 0, null, 0);
            entries = cast(const Entry[]) diskFile[];
        }
    
        static struct Entry
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

            
            double delay;// always 0 in this data set
        }

        package:
            import std.mmfile;
            MmFile diskFile;

    }

}
