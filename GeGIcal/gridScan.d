module gridScan;

import waveforms;

import std.array;
import std.algorithm;
import std.exception;
import std.file;
import std.format;
import std.math;
import std.stdio;
import std.string;
import std.path;


/// class representing a raster scan 
class GridScan {
    const string outputFolder;
    // todo
    //const string metadataFile;
    const string indexFile;
    const size_t gridDim;
    const double stepSize;
    ScanPoint[] points;
    ScanPoint[const float[2]] pointsByRelOffset;

    // todo check axis1,2 indexing
    ScanPoint[][] pointGrid;

    float[] axis1RelCenterOffsets;
    float[] axis2RelCenterOffsets;


    /***
     * Create GridScan recreate index on fast data structure
     * this will make it easy to index and view particular points
     *
     * Implicit assumptions Grid is centered and 
     *
     * the indexing function will also place symlinks to the original file in the subfolders
     */
    this (string inputFolder, string inputMetadataRootFolder, string outputFolder, size_t gridDim, double stepSize)
    in
    {
        assert(exists(inputFolder) && isDir(inputFolder));
        assert(exists(inputMetadataRootFolder) && isDir(inputMetadataRootFolder));

        assert(gridDim%2); // assuming gridDim is odd will alert to errors
    }
    do
    {
        import std.range: lockstep;

        mkdirRecurse(outputFolder);


        this.gridDim = gridDim;
        this.stepSize = stepSize;
        this.outputFolder = outputFolder;

        auto inputWaveformFiles = dirEntries(inputFolder, "WaveFormDataOut*.bin", SpanMode.shallow, false).array; 

        auto unfilteredMetadataFolders = dirEntries(inputMetadataRootFolder, "*run_number*", SpanMode.shallow, false);


        // REMOVING DUPLICATE FOLDER WITH HARDCODING IS good enough
        auto inputMetadataFolders = (gridDim == 11) ? 
            unfilteredMetadataFolders.filter!(a=>!a.name.endsWith("19-Dec-2016_run_number_000031")).array
            : unfilteredMetadataFolders.array;


        enforce(inputWaveformFiles.length == gridDim^^2);
        enforce(inputMetadataFolders.length == gridDim^^2);

        // sort by date modified
        inputWaveformFiles.schwartzSort!(d => d.name, SwapStrategy.stable);
        inputMetadataFolders.schwartzSort!(d => d.name, SwapStrategy.stable);

        // setsize griddim 2
        points.reserve(gridDim * gridDim);        
        
        // create points from metadata (files in each folder), and pair with waveform
        foreach (i, metadataFolder, waveformFile; lockstep(inputMetadataFolders, inputWaveformFiles)) 
        {
            auto metadataFile = buildPath(metadataFolder, "info.txt");
           

            // ScanPoint is a nested class so it can access it's "outer" property
            auto point = new ScanPoint(metadataFile, waveformFile, outputFolder);
            points ~= point;
            pointsByRelOffset[point.offsetRelCenter] = point;

           
        }

        //todo
        //metadataFile = buildPath(outputFolder, "GridMetadata.json");
        indexFile = buildPath(outputFolder, "GridIndex.csv");
        // index metadata
        auto fIndex = File(indexFile, "w");
        
        fIndex.writeln(CSVHeader);
        
        //TODO add sort options??

        // for now default
        foreach (point; points)
        {
            fIndex.writeln(point.CSVLine);
        }


        // map all offsets used
        {
            float[] axis1RelCenterAllOffsets = points.map!(a => a.axis1RelCenter).array.dup;
            float[] axis2RelCenterAllOffsets = points.map!(a => a.axis2RelCenter).array.dup;
            //
            axis1RelCenterAllOffsets.sort();
            axis2RelCenterAllOffsets.sort();
            //
            //// implicit assertion each shows up gridDim times
            //
            axis1RelCenterOffsets = axis1RelCenterAllOffsets.uniq.array;
            axis2RelCenterOffsets = axis2RelCenterAllOffsets.uniq.array;
            //
            assert(axis1RelCenterOffsets.length == gridDim);
            assert(axis2RelCenterOffsets.length == gridDim);
        }


        // todo check every point is represented (so can make bitmaps)

        writefln!("Successfully indexed %dby%d grid")(gridDim, gridDim);


        // count errors and printCSV

        // todo printCSVs
    }

    
/+
    /// loader in progress
    this (string indexFilename, size_t gridDim, double stepSize) 
    in 
    {
        assert(exists(indexFilename) && isFile(indexFilename));
    }
    do
    {
        import std.string;

        //outputRoot folder is folder that holds indexFile 
        this.outputFolder = dirName(indexFilename);
        this.gridDim = gridDim;
        this.stepSize = stepSize;
        this.indexFile = indexFilename;
        
        auto f = File(indexFilename, "r");
        
        foreach (ulong i, string line; f.lines()) 
        {
            if (i==0)
            {
                enforce(line.cmp(CSVHeader) == 0);
            }

            auto point = new ScanPoint(line);

            //assert(dirName(point.outputSubFolder) == dirName(f));

            if (!exists(point.outputSubFolder))
            {
                mkdir(point.outputSubFolder);
            }

            points ~= point;
            pointsByRelOffset[point.offsetRelCenter] = point;

        }

        assert(points.length == gridDim^^2);
    }
+/

    

    /// after indexing, do preprocessing, and make it parallel
    void preprocessAll() 
    {
        import std.parallelism;

        writefln!"Preprocessing started for %dx%d grid"(gridDim, gridDim);

        

        foreach(i,  point; parallel(points))
        {
            writefln!"    Preprocessing Started on point (%0.2f, %0.2f)"(point.axis1RelCenter, point.axis2RelCenter);
            point.preprocess();
            writefln!"    Preprocessing Finished on point (%0.2f, %0.2f):\t%9d entries  %9d errors   %9d range"(point.axis1RelCenter, point.axis2RelCenter,
                point.waveform.rawLength, point.waveform.errorCount, point.waveform.outOfRangeCount);

        }
        
        writefln!"Preprocessing successful for %dx%d grid"(gridDim, gridDim);

        string summaryDir = buildNormalizedPath(outputFolder, "summaries");

        if (!exists(summaryDir))
        {
            mkdir(summaryDir);
        }

        //void compileSpatialSummary(string filename)
        //{
        //
        //}

        // todo template for 

        //  compile error rate in data
        foreach (float offset1; axis1RelCenterOffsets)
        {
            foreach(float offset2; axis2RelCenterOffsets)
            {
                auto point = pointsByRelOffset[cast(const float[2])[offset1, offset2]];

                // todo 

            }



        }



        
    }
    


    /**
     * A point at which a scan was conducted for this grid
     */
    class ScanPoint
    {
        const float axis1ABS, axis2ABS;
        
        union {
            const float[2] offsetRelCenter;
            
            struct
            {
                const float axis1RelCenter, axis2RelCenter;
            }
        }

        const double startTime, initialColTime, colTimeThisRun;
        const bool  colTimeIsImag, dataCollectionFailed;
    
        const string metadataFile;
        const string waveformFile;
        const string outputSubFolder;

        WaveformSession waveform;

    package:

        /**********************************************************************
         * construct that does the actual setup
         *********************************************************************/
        this(in float axis1ABS,       in float axis2ABS,
             in float axis1RelCenter, in float axis2RelCenter,
             in double startTime,     in double initialColTime, in double colTimeThisRun,
             in bool  colTimeIsImag,  in bool dataCollectionFailed,
             in string metadataFile,  in string waveformFile, in string outputSubFolder)
        in 
        {
            assert(!isNaN(axis1ABS));
            assert(!isNaN(axis2ABS));
            assert(!isNaN(axis1RelCenter));
            assert(!isNaN(axis2RelCenter));
            assert(!isNaN(startTime) && startTime >= 0.0);
            assert(!isNaN(initialColTime) && initialColTime >= 0.0);
            assert(!isNaN(colTimeThisRun) && colTimeThisRun >= 0.0);

            // DEBUG disable if breaks things
            assert(initialColTime == colTimeThisRun);

            // DEBUG don't expect to handle unless these show up
            assert(!colTimeIsImag);
            assert(!dataCollectionFailed);

            assert(exists(metadataFile) && isFile(metadataFile));
            assert(exists(waveformFile) && isFile(waveformFile));
            assert(exists(outputSubFolder) && isDir(outputSubFolder));
        }
        do
        {
            this.axis1ABS = axis1ABS;
            this.axis2ABS = axis2ABS;
            this.axis1RelCenter = axis1RelCenter;
            this.axis2RelCenter = axis2RelCenter;
            this.startTime = startTime;
            this.initialColTime = initialColTime;
            this.colTimeThisRun = colTimeThisRun;

            this.colTimeIsImag = colTimeIsImag;
            this.dataCollectionFailed = dataCollectionFailed;

            this.metadataFile = metadataFile;
            this.waveformFile = waveformFile;
            this.outputSubFolder = outputSubFolder;
        }

        /**********************************************************************
         * Construct a ScanPoint From a line of an already created index file
         * 
         * Used in loading previously indexed grids (and the preprocessed data)
         *********************************************************************/
        this(string line)
        {
            float axis1ABS, axis2ABS;
            float axis1RelCenter, axis2RelCenter;
            double startTime, initialColTime, colTimeThisRun;
            bool  colTimeIsImag, dataCollectionFailed;
            string metadataFile, waveformFile, outputSubFolder;
     
            size_t items = line.formattedRead("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"\n"
                ,&axis1RelCenter, &axis2RelCenter, &axis1ABS, &axis2ABS,
                 &startTime, &initialColTime, &colTimeThisRun, 
                 &colTimeIsImag, &dataCollectionFailed,
                 &metadataFile, &waveformFile, &outputSubFolder);

            assert(items == 12, format!"ERROR: failed to parse entire line <%s>"(line));

            this(axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS,
                startTime, initialColTime, colTimeThisRun, 
                colTimeIsImag, dataCollectionFailed,
                metadataFile, waveformFile, outputSubFolder);
        }


        /**********************************************************************
         * Parse metadata to create a new ScanPoint
         *********************************************************************/
        this(string metadataFile, string waveformFile, string outputRootFolder)
        in
        {
            assert(exists(metadataFile) && isFile(metadataFile));
            assert(exists(waveformFile) && isFile(waveformFile));
            assert(exists(outputRootFolder) && isDir(outputRootFolder));
        }
        do 
        {
            auto metadata = File(metadataFile, "r");

            float axis1ABS,axis2ABS;
            float axis1RelCenter, axis2RelCenter;
            double startTime, initialColTime, colTimeThisRun;
            bool  colTimeIsImag, dataCollectionFailed;

            try 
            {
                // assume spelling errors are in all files until a failure proves otherwise
                auto itemsRead = metadata.readf!(
                      "current location of Axis 1: %f\n"
                    ~ "current location of Axis 2: %f\n"
                    ~ "current location of Axis 1 from detector center: %f\n"
                    ~ "current location of Axis 2 from detector center: %f\n"
                    ~ "start time : %f\n"
                    ~ "inital collection time : %f\n"
                    ~ "collection time this run : %f\n"
                    ~ "collection time is imag : %b\n"
                    ~ "data colllection failed : %b")          // Assume all files have this typo
                    (axis1ABS, axis2ABS, axis1RelCenter, axis2RelCenter,
                     startTime, initialColTime, colTimeThisRun,
                     colTimeIsImag, dataCollectionFailed);
            
                enforce(itemsRead == 9);
                // todo catch this or better label that it would not be
            }
            catch (StdioException e) 
            {
                stderr.writefln!("ERROR reading metadata File \"%s\"")(metadataFile);
                throw e;
            }

            outputSubFolder = buildPath(outputRootFolder, 
                format!"point_axis1rel_%+0.2f_axis2rel_%+0.2f"(axis1RelCenter, axis2RelCenter));
        
            mkdirRecurse(outputSubFolder);

            this(axis1ABS, axis2ABS, axis1RelCenter, axis2RelCenter,
                startTime, initialColTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed,
                metadataFile, waveformFile, outputSubFolder);
        }


        /// load and preprocess the waveform file for this point
        void preprocess() 
        {
            waveform = new WaveformSession(waveformFile, outputSubFolder);
        }


    package:

        /// does not include header
        string CSVLine() const @property 
        {
            return format!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"")
                (axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS,
                startTime, initialColTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed,
                 metadataFile, waveformFile, outputSubFolder);
        }
    }

package:

    enum string CSVHeader="axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS, startTime, initialColTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed, metadataFile, waveformFile, outputSubFolder";

}
