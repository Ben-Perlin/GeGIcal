module gridScan;

import std.array;
import std.exception;
import std.file;
import std.format;
import std.stdio;
import std.path;


class GridScan {
    const string outputFolder;
    const size_t gridDim; //perhaps rename to gridDim?
    const string indexFile;
    const double stepSize;
    ScanPoint[] points;



    /***
     * recreate index on fast data structure
     * this will make it easy to index and view particular points
     *
     * the indexing function will also place symlinks to the original file in the subfolders
     */
    static GridScan index(string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridDim, double stepSize)
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
    this (string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridSize, double stepSize)
    {
        import std.range: lockstep;

        this.gridSize = gridSize;
        this.stepSize = stepSize;

        auto inputWaveformFiles = dirEntries(inputFolder, "WaveFormDataOut*.bin", SpanMode.shallow, false).array;
        auto inputMetadataFolders = dirEntries(inputMetadataRootFolder, "*run_number*", spanMode.shallow, false).array;

        enforce(inputWaveformFiles.len == expectedN);
        enforce(inputMetadataFolders.len == expectedN);

        // sort by date modified
        inputWaveformFiles.sort!(a,b => a.lastModificationTime < b.lastModificationTime)(SwapStrategy.stable);
        inputMetadataFolders.sort!(a,b => a.lastModificationTime < b.lastModificationTime)(SwapStrategy.stable);

        
        // create points from metadata (files in each folder), and pair with waveform
        foreach (i, metadataFolder, wavefile; lockstep(inputMetadataFolders, inputWaveformFiles)) 
        {
            auto inputMetadataFile = buildNormalizedPath(metadataFolder,"info.dat");
           
            // ScanPoint is a nested class so it can access it's "outer" property
            points ~= ScanPoint.loadFromFiles(inputMetadataFile, wavefile, outputRootFolder);
        }
    }


    ///
    this (string indexFilename, size_t gridSize) 
    in 
    {
        assert(exists(indexFilename) && isFile(indexFilename));
    }
    do
    {
        //TODO !!!!!!!!
        //outputRoot folder is folder that holds indexFile 
        auto outputRootFolder = dirName(indexFilename);
        this.gridSize=gridSize;
        
        auto indexFile = File(indexFilename, "r");
        
        string header = indexFile.readline();
        if (header != ScanPoint.CSVheader) 
        {
            assert(0);
        }

        foreach (string line; indexFilename.readLines) 
        {
            auto point = ScanPoint.loadFromCSVline(line);

            assert(dirname(point.outputSubFolder) == dirName(indexFilename));

            if (!exists(point.outputSubFolder))
            {
                // TODO create this subfolder in its appropriate place
                mkdir(point.outputSubFolder);
            }

            points ~= point;
        }

        enforce(points.length == expectedN);
    }


    /// after indexing, do preprocessing, and make it parallel
    void preprocessAll() 
    {
        import std.parallelism; 

        //TODO check
        foreach(i,  point; parallel(points))
        {
            point.preprocess();
        }
    }



/**
 * Todo document me
 */
class ScanPoint
{
    const float axis1ABS,axis2ABS;
    const float axis1RelCenter, axis2RelCenter;
    const double startTime, initialColTime, colTimeThisRun;
    const bool  colTimeIsImag, dataCollectionFailed;
    
    const string inputMetadataFilename;
    const string inputWaveformFilename;
    string outputSubfolder;

package:


    /// 
    this(in float axis1ABS,       in float axis2ABS,
         in float axis1RelCenter, in float axis2RelCenter,
         in double startTime,     in double initialColTime, in double colTimeThisRun,
         in bool  colTimeIsImag,  in bool dataCollectionFailed,
         in string inputMetadataFilename,
         in string inputWaveformFilename)
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

        // I think I am forgetting something
    
        this.inputMetadataFilename = inputMetadataFilename;
        this.inputWaveformFilename = inputWaveformFilename;
        this.outputRootFolder = outputRootFolder;
    
        // TODO create output subfolder

        // try registering ...



        string name = format!"point_axis1rel_%+0.2f_axis2rel_%+0.2f"(axis1RelCenter, axis2RelCenter);

        this.outputSubFolder = buildNormalizedPath(outer.outputRootFolder, name);
    
        assert(!exists(outputSubfolder));

        //try
        //mkdir(outputSubFolder);
        // create the directory
        //todo
    
    }



    static ScanPoint loadFromCSVline(string line)
    {
        float axis1ABS,axis2ABS;
        float axis1RelCenter, axis2RelCenter;
        double startTime, initialColTime, colTimeThisRun;
        bool  colTimeIsImag, dataCollectionFailed;
        string metadataFilename, waveformFilename, outputSubFolder;
     
        line.formatedRead!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"\n")
            (&Axis1RelCenter, &Axis2RelCenter, &Axis1ABS, &Axis2ABS,
             &startTime, &collectionTimeThisRun, &colTimeIsImag, &dataColectionFailed,
             &metadataFilename, &waveformFilename, &outputSubFolder);

        return new ScanPoint(Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS,
            startTime, collectionTimeThisRun, colTimeIsImag, dataColectionFailed,
            metadataFilename, waveformFilename, outputSubFolder);
    }

    static ScanPoint createFromFiles(string metadataFilename, string waveformFilename, string outputRootFolder)
    in
    {
        // redundant
        //assert(exists(metadataFilename) && isFile(metadataFilename));
        //assert(exists(waveformFilenmane) &&isFile(waveformFilename));
    }
    do 
    {
        auto metadataFile = File(metadataFilename, "r");

        float axis1ABS,axis2ABS;
        float axis1RelCenter, axis2RelCenter;
        double startTime, initialColTime, colTimeThisRun;
        bool  colTimeIsImag, dataCollectionFailed;

        try 
        {
            // assume spelling errors are in all files until a failure proves otherwise
            metadataFile.readf!("current location of Axis 1: %f\n"
                              ~ "current location of Axis 2: %f\n"
                              ~ "current location of Axis 1 from detector center: %f\n"
                              ~ "current location of Axis 2 from detector center: %f\n"
                              ~ "start time : %f\n"
                              ~ "inital collection time : %f\n"
                              ~ "collection time this run : %b\n"
                              ~ "collection time is imag : %b\n"
                              ~ "data colllection failed : %b")          // Assume all files have this error
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
    
        return new ScanPoint(axis1ABS, axis2ABS, axis1RelCenter, axis2RelCenter,
        startTime, initialColTime, colTimeIsImag dataCollectionFailed, metadataFilename);
    }

package:
    enum string CSVHeader="Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS, startTime, collectionTimeThisRun, colTimeIsImag, dataCollectionFailed, inputMetadataFile, inputWaveform, outputSubFolder";

    ///
    string writeCSVline(File output) 
    {
        output.writefln!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"")
            (Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS,
            startTime, collectionTimeThisRun, colTimeIsImag, dataColectionFailed,
             inputMetadataFile, inputWaveformFile, outputSubFolder);
    }
}
