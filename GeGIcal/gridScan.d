module gridScan;

import std.array;
import std.exception;
import std.file;
import std.format;
import std.stdio;
import std.path;


class GridScan {
    const string outputFolder;
    const string indexFile;
    const size_t gridDim;
    const double stepSize;
    ScanPoint[] points;


    //TODO enum option for sorting
    //


    /***
     * recreate index on fast data structure
     * this will make it easy to index and view particular points
     *
     * the indexing function will also place symlinks to the original file in the subfolders
     */
    static GridScan createAndIndex(string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridDim, double stepSize)
    in
    {
        assert(exists(inputFolder) && isDir(inputFolder));
        assert(exists(inputMetadataRootFolder) && isDir(inputMetadataRootFolder));
        assert(!exists(outputRootFolder));

        assert(gridDim > 1);
        assert(stepSize > 0.0);
    }
    do    
    {
        // todo safe
        mkdir(outputRootFolder);



        auto grid = new GridScan(inputFolder, inputMetadataRootFolder, outputRootFolder, gridDim, stepSize);
    
        
        // keep out here to have sort options
        // sort

        // csv line
        // then let points generate turns in line


        // generate CSV
        // sort and ...



    
        return grid;
    }
    //out (result)
    //{
    //    assert(result !is null);
    //    assert(results.points.length == result.gridDim^^2);
    //    assert(exists(outputRootFolder) && isDir(outputRootFolder));
    //}
    //

package:

    ///
    this (string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridDim, double stepSize)
    {
        import std.algorithm : sorting;
        import std.range: lockstep;

        this.gridDim = gridDim;
        this.stepSize = stepSize;

        auto inputWaveformFiles = dirEntries(inputFolder, "WaveFormDataOut*.bin", SpanMode.shallow, false).array;
        auto inputMetadataFolders = dirEntries(inputMetadataRootFolder, "*run_number*", SpanMode.shallow, false).array;

        assert(inputWaveformFiles.length == gridDim^^2);
        assert(inputMetadataFolders.length == gridDim^^2);

        // sort by date modified
        inputWaveformFiles.sort!(a,b => a.timeLastModified < b.timeLastModified)(SwapStrategy.stable);
        inputMetadataFolders.sort!(a,b => a.timeLastModified < b.timeLastModified)(SwapStrategy.stable);

        
        // create points from metadata (files in each folder), and pair with waveform
        foreach (i, metadataFolder, wavefile; lockstep(inputMetadataFolders, inputWaveformFiles)) 
        {
            auto inputMetadataFile = buildNormalizedPath(metadataFolder,"info.dat");
           
            // ScanPoint is a nested class so it can access it's "outer" property
            points ~= ScanPoint.createFromFiles(inputMetadataFile, wavefile, outputRootFolder);
        }
    }


    ///
    this (string indexFilename, size_t gridDim) 
    in 
    {
        assert(exists(indexFilename) && isFile(indexFilename));
    }
    do
    {
        //TODO !!!!!!!!
        //outputRoot folder is folder that holds indexFile 
        auto outputRootFolder = dirName(indexFilename);
        this.gridDim=gridDim;
        this.indexFile = indexFilename;
        
        auto f = File(indexFilename, "r");
        
        string header = indexFile.readln();
        if (header != ScanPoint.CSVheader) 
        {
            assert(0);
        }

        foreach (string line; f.byLine) 
        {
            auto point = ScanPoint.loadFromCSVline(line);

            assert(dirName(point.outputSubFolder) == dirName(f));

            if (!exists(point.outputSubFolder))
            {
                mkdir(point.outputSubFolder);
            }

            points ~= point;
        }

        assert(points.length == gridDim^^2);
    }


    ///// after indexing, do preprocessing, and make it parallel
    //void preprocessAll() 
    //{
    //    import std.parallelism; 
    //
    //    //TODO check
    //    foreach(i,  point; parallel(points))
    //    {
    //        point.preprocess();
    //    }
    //}



/**
 * Todo document me
 */
class ScanPoint
{
    const float axis1ABS,axis2ABS;
    const float axis1RelCenter, axis2RelCenter;
    const double startTime, initialColTime, colTimeThisRun;
    const bool  colTimeIsImag, dataCollectionFailed;
    
    const string metadataFile;
    const string waveformFile;
    string outputSubfolder;

package:


    /// 
    this(in float axis1ABS,       in float axis2ABS,
         in float axis1RelCenter, in float axis2RelCenter,
         in double startTime,     in double initialColTime, in double colTimeThisRun,
         in bool  colTimeIsImag,  in bool dataCollectionFailed,
         in string metadataFile,
         in string waveformFile,
         in string outputSubFolder)
    in 
    {
        import std.math.traits;

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
        assert(exists(outputSubfolder) && isDir(outputSubFolder));
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

    /// Construct a ScanPoint From a line of an already created index file
    this(string line)
    {
        float axis1ABS,axis2ABS;
        float axis1RelCenter, axis2RelCenter;
        double startTime, initialColTime, colTimeThisRun;
        bool  colTimeIsImag, dataCollectionFailed;
        string metadataFile, waveformFile, outputSubFolder;
     
        auto success = line.formatedRead!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"\n")
            (&axis1RelCenter, &axis2RelCenter, &axis1ABS, &axis2ABS,
             &startTime, &colTimeThisRun, &colTimeIsImag, &dataCollectionFailed,
             &metadataFile, &waveformFile, &outputSubFolder);

        assert(success == 10, format!"ERROR: failed to parse entire line <%s>"(line));

        return new ScanPoint(axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS,
            startTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed,
            metadataFilename, waveformFilename, outputSubFolder);
    }

    /// Parse metadata to create a new ScanPoint
    this(string metadataFile, string waveformFile, string outputRootFolder)
    in
    {
        assert(exists(metadataFile) && isFile(metadataFile));
        assert(exists(waveformFile) && isFile(waveformFile));
        assert(exists(outputRootFolder) && isDir(outputRootFolder));
    }
    do 
    {
        auto metadata = File(metadataFilename, "r");

        float axis1ABS,axis2ABS;
        float axis1RelCenter, axis2RelCenter;
        double startTime, initialColTime, colTimeThisRun;
        bool  colTimeIsImag, dataCollectionFailed;

        try 
        {
            // assume spelling errors are in all files until a failure proves otherwise
            metadata.readf!("current location of Axis 1: %f\n"
                          ~ "current location of Axis 2: %f\n"
                          ~ "current location of Axis 1 from detector center: %f\n"
                          ~ "current location of Axis 2 from detector center: %f\n"
                          ~ "start time : %f\n"
                          ~ "inital collection time : %f\n"
                          ~ "collection time this run : %f\n"
                          ~ "collection time is imag : %b\n"
                          ~ "data colllection failed : %b")          // Assume all files have this typo
                           (&axis1ABS, &axis2ABS,
                            &axis1RelCenter, &axis2RelCenter,
                            &startTime,
                            &initialColTime, &colTimeThisRun,
                            &colTimeIsImag, &dataCollectionFailed);
        }
        catch (StdioException e) 
        {
            stderr.writefln!("ERROR reading metadataFile %s")(metadataFilename);
            throw e;
        }
    
        auto outputSubfolder = buildNormalizedPath(outputRootFolder, 
            format!"point_axis1rel_%+0.2f_axis2rel_%+0.2f"(axis1RelCenter, axis2RelCenter));
        
        assert(!exists(outputSubFolder));
        mkdir(outputSubFolder);

        // could register with grid here if wanted

        this(axis1ABS, axis2ABS, axis1RelCenter, axis2RelCenter,
            startTime, initialColTime, colTimeIsImag, dataCollectionFailed,
            metadataFile, waveformFile, outputSubFolder);
    }

package:
    enum string CSVHeader="axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS, startTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed, metadataFile, waveformFile, outputSubFolder";

    ///
    string writeCSVline(File output) 
    {
        output.writefln!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"")
            (axis1RelCenter, axis2RelCenter, axis1ABS, axis2ABS,
            startTime, colTimeThisRun, colTimeIsImag, dataCollectionFailed,
             metadataFile, waveformFile, outputSubFolder);
    }
}
