module waveforms;


// require little endian for compilation
version(BigEndian) {
    static assert(0);
}

class WaveEvent
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
             * Useful in energy resolution
             * DC = front side, vertical strips, predicts x position  */
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

    
    // TODO: Link forward and back??
    // could do list of annotation object




package:
    import std.algorithm;

    struct slowEnergyBank {
    align 1:
        const double[16] values;

    //// treat as double
    //    alias values this;
    //    //

        double sum() const @property {
            return values[].sum;
        }

        double maxValue() const @property{
            return values[].maxValue;
        }

        size_t maxIndex() const @property {
            return values[].maxIndex;
        }

        // HOW TO DEAL WITH EQUAL? should be rare
        // maybe return a tuple
        size_t secondMaxIndex() const @property {
            return 0; //TODO
        }
    
        // nMaxValue
        
    // nMaxIndex

    // bool predict comptom

        // chances are a compton will be offset in both dirrections, but .p..


        

    }


    this(ubyte[] buffer)
    in {
        assert(buffer.length == chunkSize);
    } do {
        rawData = buffer;
    }

    static const size_t chunkSize = time.sizeof + eventTag.sizeof + cfdFlags.sizeof 
        + slowEnergyDC.sizeof + slowEnergyAC.sizeof
        + waveformDC.sizeof + waveformAC.sizeof
        + delay.sizeof;

    invariant{
        import std.algorithm.searching : all, minElement;
        import std.math.traits;

        assert(slowEnergyDC[].minElement >= 0, "Negative slow energy found on DC side");
        assert(slowEnergyAC[].minElement >= 0, "Negative slow energy found on AC side");
        assert(slowEnergyDC[].all!isFinite, "infinite slow energy found on DC side"); // or NaN?
        assert(slowEnergyAC[].all!isFinite, "infinite slow energy found on AC side");

        // TEMPORARY: Find bad data to identify patterns

        // todo assert no NANs
        //assert()

        // UNTIL Proven otherwise
        assert(delay == 0.0, "Apparently delay isn't always 0");

        
    }
}

/**
 * 
 * events are ordered as read from the file
 */
class WaveFormSession{
    const(WaveEvent)[] events;
    // change to dl-linked list
    

    // TODO look for non-monotonic(excluding roll-over) eventtags
    // TODO look for long repeats ...

    // look for -2048 for 8 or so strips of waveform at the start

    // this(const(WaveEvent)[] events) {
    //    import std.conv;
    //    this.events = events;
    //}

    static WaveEventSeq readWaveFile(string filename) {
        import std.file;
        import std.stdio;

        // check first if file exists std.file and handle error seperately 
        if (!exists(filename)){
            throw new Exception("Waveform File: \"" ~ filename ~ "\" does not exist\n");
        }

        try {

            auto f = File(filename, "r");

            const(WaveEvent)[] events;

            foreach (ubyte[] buffer; f.byChunk(WaveEvent.chunkSize)) {
                // drop partially captured events (if recording crashed)
                if (buffer.length != WaveEvent.chunkSize) {
                    stderr.writefln("Trailing bytes in file \"%s\" found and dropped", filename); // can add details later
                    break;
                }

                events ~= new const WaveEvent(buffer);
            }

            return new WaveEventSeq(events);

        } catch (StdioException e) {
            stderr.writefln!"Failed to read waveform file: %s"(filename);

            //rethrow so this crashes now
            throw e;
        }

        assert(0);
    }


    // save to file
    void save(string filename) {
        import std.stdio;

        //TODO check file exists?
        //if (exists(filename)) {/*warn ...*/}

        // open file for writing
        File file = File(filename, "w");

        foreach(event; events){
            file.rawWrite(event.rawData);
        }
    }

}




