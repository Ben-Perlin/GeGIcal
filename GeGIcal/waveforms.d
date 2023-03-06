module waveforms;

import std.stdio;


// require little endian for compilation
version(BigEndian) {
    static assert(0);
}


// LETS START OVER HERE: mmap is an easier way to scan these files, and I can output all subsets as lists of u64 digits corresponding to index for position
   
/**
 * 
 * the detector is reverse-biased, the AC-coupled side collects the electrons and the DC-coupled side collects the holes, one reason for this behavior is that the electrodes are more sensitive as their respective charge carriers get closer.
 */
struct WaveEventEntry
{
    // Store event data exactly as laid out in binary file
    const union
    {
    public:
        struct{
        align (1):
            /// Time: used in deltaT
            ubyte time;

            /// Constant Fraction Discriminator: used for depth of interaction
            ubyte[4] cfdFlags;

            short eventTag;

            /**
             * slowEnergy: Energy deposited on each strip
             * Useful in energy resolution (multiplier to get energy)
             * strips 0-15 represent the DC coulpled side,
             * That is the front side with vertical strips, predicts x position  */
             double[16] slowEnergyDC;

             /**
             * slowEnergy: Energy deposited on each strip
             * Useful in energy resolution
             * AC = back side, horizontal strips, predicts y position */
             double[16] slowEnergyAC;
            
             
                /// Waveforms recorded at 12bit
                // our goal will be to take advantage of this and perform calculations on these inputs using the Nvidia Ampere Tensor cores to do 4 16bit MAc ops in the time of a single fp op
             short[20][16] waveformDC;
             short[20][16] waveformAC;
            
             double delay;
        }
    package:
        ubyte[chunkSize] rawData; // this feels too kludgy, but low priority for now
        // I don't want to use this after I switch over to objects for bank data
        // this change is not just about object oriented programming but a potential way of configuring daat for feed into cudnn
    }

    // TODO link for next if there is one
package:

    this(ubyte[] buffer)
    in {
        assert(buffer.length == chunkSize);
    } 
    do
    {
        rawData = buffer;
    }

    enum size_t chunkSize = time.sizeof + eventTag.sizeof + cfdFlags.sizeof 
        + slowEnergyDC.sizeof + slowEnergyAC.sizeof
        + waveformDC.sizeof + waveformAC.sizeof
        + delay.sizeof;
}

/**
 * 
 * events are ordered as read from the file
 */
class WaveFormSession{
    const(WaveEvent)[] events;
    

    // TODO look for non-monotonic(excluding roll-over) eventtags
    // TODO look for long repeats ...

    // look for -2048 for 8 or so strips of waveform at the start

    // this(const(WaveEvent)[] events) {
    //    import std.conv;
    //    this.events = events;
    //}



    /**
    * todo look up doc comments
    */
    static WaveEventSeq readWaveFile(string filename) 
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
            stderr.writefln!"ERROR: Failed to open file \"%s\" for writing!"(filename);
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
