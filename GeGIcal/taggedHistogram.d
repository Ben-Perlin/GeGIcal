module $modulename$;







/// data structure of histogram to use with tuples of value and keys
class TaggedHistogram(T) {
    const IndexedEntry[] entries;
        
    const(T)[] keys() const @property{
        import std.array;
        import std.algorithm : map;

        return entries.map!(ev=>ev.key).array;
    }

    const(size_t)[] indicies() const @property{
        import std.array;
        import std.algorithm : map;

        return entries.map!(ev=>ev.index).array;
    }

    import std.range;

    //auto events() const @property{
    //    return indexed(this.outer.events, indicies);
    //}		

    // todo, way to subset

    T max() const @property{
        return entries[$-1];
    }

    /// Minimum value on the histogram. currently designed to not be less than 0.0
    T min() const @property
    out(result) {
        assert(result >= 0.0);
    } do {
        return entries[0];
    }

    /// median
    T median() const @property {
        return length%2 ? entries[$/2] : (entries[$/2-1] + entries[$/2])/2.0;
    }
        
    // mean
    T mean() const @property{
        import std.algorithm : mean;
        return keys.mean;
    }

    T variance() const @property {
        import std.algorithm : sum;

        T[] squares = keys.dup;
        squares[] -= mean;
        squares[] ^^=2;
        return squares.sum /(length-1);
    }

    /// standard deviation
    T stddev() const @property{
        import std.math : sqrt;
        return sqrt(variance);
    }

    size_t length() const @property {
        return entries.length;
    }


    //  MANDATING BINS[$-1] >= entries.max
    /// specified by max value in bins
    size_t[] binCounts(const double[] bins) const 
    in {
        import std.algorithm : isStrictlyMonotonic;
        assert(bins.length > 0);
        assert(bins.isStrictlyMonotonic);
        assert(bins[0] > 0);
        assert(bins[$-1] >= max);
    }
    out(result)
    {
        assert(result != null);
        assert(result.length == bins.length);
    }
    do
    {
        size_t[] counts = new size_t[bins.length];
        size_t entryIndex = 0;

        foreach (i, binMax; bins) 
        {
            while (entryIndex < entries.length && entries[entryIndex].key < binMax) 
            {
                counts[i]++;
                entryIndex++;
            }
        }

        return counts;
    }

    // TODO index tagged bins

package:
    static struct IndexedEntry
    {
        T key;
        size_t index;

        int opCmp(const IndexedEntry rhs) const {
            import std.math : cmp;
            return cmp(key, rhs.key);
        }

        alias key this;

    package:
        this(const T key, const size_t index) 
        {
            this.key = key;
            this.index = index;
        }
    }


    this(T function(const WaveEvent event) f)
    out {
        import std.algorithm : isSorted;

        assert(entries.length == events.length);
        assert(entries.isSorted);
    } do {
        import std.algorithm.mutation : SwapStrategy;
        import std.algorithm.sorting;
        import std.conv;

        IndexedEntry[] unsortedEntries;
        foreach (i, ev; events) {
            unsortedEntries ~=  IndexedEntry(f(ev), i);
        }

        unsortedEntries.sort!("a<b", SwapStrategy.stable);
        entries = unsortedEntries;
        //TODO assert sorted on out
    }

    /// SUBSETTING



    invariant {
        assert(entries[0].key>=0.0);
        /++
        assert(entries.length == events.length);
        assert(entries.isSorted);
        +/
    }

}










class SlowEnergyHist2D {
    const TaggedHistogram!double[] histograms;

    // combine keys and ranges ...
    double min() const @property{
        import std.algorithm : map, minElement;
        return histograms.map!(a=>a.min).minElement;
    }

    double max() const @property{
        import std.algorithm : map, maxElement;
        return histograms.map!(a=>a.max).maxElement;
    }

    // todo create fixedwidth bins sufficent for all strips

        
    // todo 2D bin counts
    size_t [][] binCounts2D(const double[] bins) const in{
        import std.algorithm : isStrictlyMonotonic;
        assert(bins.length > 0);
        assert(bins.isStrictlyMonotonic);
        assert(bins[0] > 0);
        assert(bins[$-1] >= max);
    } out (result) {
        assert(result.length == 32);
    } do  {
        size_t[][] output = new size_t[][32];
            
        foreach (i, hist; histograms) {
            output[i] = hist.binCounts(bins);
        }

        return output;
    }
        
        
    // TODO write 
    void saveCSV(string filename, const double[] bins, string headerPivot="strips/bin") {
        import std.stdio;

        // calculate first to ensure valid
        size_t[][] counts = binCounts2D(bins);

        auto outFile = File(filename, "w");
            
        outFile.writefln!"%s, %(%s, %)"(headerPivot, bins);

        foreach (i, count; counts) {
            assert(i<32);
            outFile.writefln!"%d, %(%s, %)"(i, count);
        }
    }
        

    this()
    in {
        assert(events.length > 0);
    } out {
        foreach (hist; histograms) {
            assert(hist.min >= 0.0);
            assert(hist.length == events.length);
        }
    }do {
        TaggedHistogram!double[] _histograms;
        static foreach(i; 0..32) {
            _histograms ~= new TaggedHistogram!double(ev => ev.slowEnergy[i]);
        }
        histograms = _histograms;
    }
}
