module waveforms;

import std.stdio;


// require little endian for compilation
version(BigEndian) {
    static assert(0);
}


// LETS START OVER HERE: mmap is an easier way to scan these files, and I can output all subsets as lists of u64 digits corresponding to index for position

class WaveformEntry
{



    
}





/**
 * 
 * events are ordered as read from the file
 */
class WaveFormSession{
   
    static WaveformSession importUnprocessed(string sourceWaveformFilename, string outputDir)
    in 
    {
        assert(exists(sourceWaveformFileneame) && isfile(sourceWaveformFilename));
    }
    do
    {
        import std.mmfile;
        
        struct WaveformRawDiskEntry
        {
        // Store event data exactly as laid out in binary file
        align (1):
            /// Time: used in deltaT
            const ubyte time;

                /// Constant Fraction Discriminator: used for depth of interaction
            const ubyte[4] cfdFlags;

            const short eventTag;

                /**
                 * slowEnergy: Energy deposited on each strip
                 * Useful in energy resolution (multiplier to get energy)
                 * strips 0-15 represent the DC coulpled side,
                 * That is the front side with vertical strips, predicts x position  */
            const double[16] slowEnergyDC;

                 /**
                 * slowEnergy: Energy deposited on each strip
                 * Useful in energy resolution
                 * AC = back side, horizontal strips, predicts y position */
            const double[16] slowEnergyAC;
            
             
                    /// Waveforms recorded at 12bit
                    // our goal will be to take advantage of this and perform calculations on these inputs using the Nvidia Ampere Tensor cores to do 4 16bit MAc ops in the time of a single fp op
            const short[20][16] waveformDC;
            const short[20][16] waveformAC;
            
            const double delay;
        }

        auto source = MmFile(sourceWaveformFilename, Mode.read, 0, Null, 0);

        
        

    
    }


package:
    /**
     * This is the layout on the disk - will be filtered to get 
     * the detector is reverse-biased, the AC-coupled side collects the electrons and the DC-coupled side collects the holes, one reason for this behavior is that the electrodes are more sensitive as their respective charge carriers get closer.
     */


    // TODO look for non-monotonic(excluding roll-over) eventtags
    // TODO look for long repeats ...

    // look for -2048 for 8 or so strips of waveform at the start

    // this(const(WaveEvent)[] events) {
    //    import std.conv;
    //    this.events = events;
    //}


    /**
    * todo look up doc comments
    * will fork to use for
    */
    static  readWaveformFile(string filename) 
    {
        import std.file;
        import std.stdio;

        // check first if file exists std.file and handle error seperately 
        if (!exists(filename)){
            throw new Exception("Error: Waveform File: \"" ~ filename ~ "\" does not exist\n");
        }

        try 
        {
            auto f = File(filename, "r");
            const(WaveEvent)[] events;
        }
        catch (StdioException e) 
        {
            stderr.writefln!"ERROR: Failed to open file \"%s\" for reading!"(filename);
            throw e;
        }


        try 
        {
            foreach (ubyte[] buffer; f.byChunk(WaveEvent.chunkSize)) 
            {
                // drop partially captured events (if recording crashed)
                if (buffer.length != WaveEvent.chunkSize) 
                {
                    stderr.writefln("Trailing bytes in file \"%s\" found and dropped", filename); // can add details later
                    break;
                }

                events ~= new const WaveEvent(buffer);
            }

            return new WaveEventSeq(events);

        }
        catch (StdioException e)
        {
            stderr.writefln!"Failed to read waveform file: %s"(filename);
            throw e;
        }

        assert(0);
    }


    /**
     * save a waveseq to a disk
     */
    void save(string filename) {
        try
        {
            File file = File(filename, "w");    // open file for writing

        }
        catch (StdioException e)
        {
            stderr.writefln!"ERROR: Failed to open file \"%s\" for writing!"(filename);
            throw e;
        }

        foreach(event; events)
        {
            file.rawWrite(event.rawData);
        }
    }
}
