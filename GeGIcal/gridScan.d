module gridScan;

import std.array;
import std.assertion;
import std.file;
import std.format;
import std.stdio;
import std.path;



// todo, perhaps think about aliasing so overlapping scans are easier to intergrate

class GridScan {
    const string outputFolder;
    const size_t gridSize;
    const string indexFile;
    const ScanPoint[] points;
    const double stepSize;

    // by 



    static GridScan indexAndPreprocess(string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridSize, double stepSize)
    in
    {
        ssert(exists(inputFolder) && isDir(inputFolder));
        assert(exists(inputMetadataRootFolder) && isDir(inputMetadataRootFolder));

        assert(!exists(outputDataPath));
    }
    do    
    {
        mkdir(outputDataPath);
        auto grid = GridScan(inputFolder, inputMetadataRootFolder, outputRootFolder, gridSize, stepSize);
    
        // generate CSV


    
        return grid;
    }
    out (result)
    {
        assert(exists(outputDataPath) && isDir(outputDataPath));
    }

package:

    this (string inputFolder, string inputMetadataRootFolder, string outputRootFolder, size_t gridSize, double stepSize) 
    in {

    }
    do
    {
        import std.range: lockstep;

        this.gridSize = gridSize;

        auto inputWaveformFiles = dirEntries(inputFolder, "WaveFormDataOut*.bin", SpanMode.shallow, false).array;

        auto inputMetadataFolders = dirEntries(inputMetadataRootFolder, "*run_number*", spanMode.shallow, false).array;

        enforce(inputWaveformFiles.len == expectedN);
        enforce(inputMetadataFolders.len == expectedN);

        // sort by date modified
        inputWaveformFiles.sort!(a,b=> a.lastModificationTime < b.lastModificationTime)(SwapStrategy.stable);
        inputMetadataFolders.sort!(a,b => a.lastModificationTime < b.lastModificationTime)(SwapStrategy.stable);

        // can now pair up !
        ScanPoint[] pointBuffer;
        // create points from metadata (files in each folder), and pair with waveform
        foreach (i, metadataFolder, wavefile; lockstep(inputMetadataFolders, inputWaveformFiles)) 
        {
            auto inputMetadataFile = buildNormalizedPath(metadataFolder,"info.dat");
            pointBuffer ~= new ScanPoint(inputMetadataFile);
            // todo create scanpoint 

        }




    }


    //popul te folder with files named clearly!


    // todo a way to quickly index 
    // property or embedded ob???


    this (string indexFilename, size_t gridSize) in {
        assert(exists(indexFilename));
        assert(!isDir(indexFilename));
    } do {
        this.gridSize=gridSize;
        
        auto indexFile = File(indexFilename, "r");
        
        string header = indexFile.readline();
        if (header != ScanPoint.CSVheader) {
            assert(0);
        }


        ScanPoint[] pointsWorkingList;
        foreach (string line; indexFile.readLines) {
            pointsWorkingList ~= loadFromCSVline(line);
        }


        enforce(pointsWorkingList.len == expectedN);
        // TODO FIXME - SEMANTICS
        points = pointsWorkingList; // now it is const
    }

    void preprocessAll() {
        import std.parallelism; 

        foreach(i, ref point; parallel(poins))
        {
            point.preprocess();
        }
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
    
    const string metadataInputFile;
    const string inputWaveformFilename;
    string outputRootFolder;
    string outputSubfolder;


package:


    /// 
    this(in float axis1ABS,       in float axis2ABS,
         in float axis1RelCenter, in float axis2RelCenter,
         in double startTime,     in double initialColTime, in double colTimeThisRun,
         in bool  colTimeIsImag,  in bool dataCollectionFailed,
         in string inputMetadataFilename,
         in string inputWaveformFilename,
         in string outputRootFolder)
    in 
    {
        import std.math.traits;

        assert(!isNaN(axis1ABS));
        assert(!isNaN(axis2ABS));
        assert(!isNaN(axis1RelCenter));
        assert(!isNaN(axis2RelCenter));
        assert(!isNaN(startTime) && startTime > =0.0)
        assert(!isNaN(initialColTime) && initialColTime >= 0.0);
        assert(!isNaN(colTimeThisRun) && colTimeThisRun >= 0.0);

        // DEBUG disable if breaks things
        assert(initialColTime == colTimeThisRun);

        // DEBUG don't expect to handle unless these show up
        assert(!colTimeIsImag);
        assert(!dataCollectionFailed);

        // redundant
        //assert(exists(inputMetadataFilename) && isFile(inputMetadataFilename));
        //assert(exists(inputWaveformFilename) && isFile(inputWaveformFilename));
        //assert(exists(outputRootFolder) && isDir(outputRootFolder));
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
    
        this.inputMetadataFilename = inputMetadataFile;
        this.inputWaveformFilename = inputWaveformFilename;
        this.outputRootFolder = outputRootFolder;
    
        // TODO create output subfolder

        string name = format!"point_axis1rel_%+0.2f_axis2rel_%+0.2f"(axis1RelCenter, axis2RelCenter);
        this.outputSubFolder = buildNormalizedPath(outputRootFolder, name);
    
        assert(!exists(outptuSubfolder));

        //try
        mkdir(outputSubFolder);
        // create the directory
        //todo
    
    }



    static ScanPoint loadFromCSVline(string line)
    {
        line.formatedRead!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, %s, %s, %s\n")
            (Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS,
            startTime, collectionTimeThisRun, colTimeIsImag, dataColectionFailed,
             inputMetadataFile, inputWaveformFile, outputSubFolder)
    }

    static ScanPoint createFromFiles(string metadataFilename, string waveformFilename, string outputRootFolder)
    in {
        // redundant
        //assert(exists(metadataFilename) && isFile(metadataFilename));
        //assert(exists(waveformFilenmane) &&isFile(waveformFilename));
    }
    do {
        auto metadataFile = File(metadataFilename, "r");

        float axis1ABS,axis2ABS;
        float axis1RelCenter, axis2RelCenter;
        double startTime, initialColTime, colTimeThisRun;
        bool  colTimeIsImag, dataCollectionFailed;

        try {
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
    string writeCSVline(File output) {
        output.writefln!("%0.2f, %0.2f, %0.2f, %0.2f, %0.7f, %0.7f, %d, %d, \"%s\", \"%s\", \"%s\"")
            (Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS,
            startTime, collectionTimeThisRun, colTimeIsImag, dataColectionFailed,
             inputMetadataFile, inputWaveformFile, outputSubFolder);
    }
}


