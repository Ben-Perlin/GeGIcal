module gridScan;

import std.array;
import std.assertion;
import std.file;
import std.stdio;
import std.path;


class GridScan {
    const string outputFolder;
    const size_t[2] gridSize;
    const string indexFile;
    const ScanPoint[] points;

package:

    this (string inputFolder, string inputMetadataRootFolder, string outputFolder, size_t[2] gridSize) 
    in {
        assert(exists(inputFolder));
        assert(isDir(inputFolder));
        assert(exists(inputMetadataRootFolder));
        assert(isDir(inputMetadataRootFolder));

        if (exists(outputFolder)) {
            assert(isDir(outputFolder));
        }

        assert(gridSize[0] == gridSize[1] && gridSize[0] > 1);
    } do {
        // load index of all raw data files
        // TODO: sort by timeLastModified 

        this.gridSize = gridSize;
        size_t expectedN = gridSize[0]*gridSize(1);

        auto inputWaveformFiles = dirEntries(inputFolder, "WaveFormDataOut*.bin", SpanMode.shallow, false).array;

        auto inputMetaFolders = dirEntries(inputMetadataRootFolder, "*run_number*", spanMode.shallow, false).array;

        enforce(inputWaveformFiles.len == expectedN);
        enforce(inputMetaFolders.len == expectedN);

        // sort by date modified

        inputWaveformFiles.sort!(a,b=> a.lastModificationTime < b.lastModificationTime)(SwapStrategy.stable);

    }


    //popul te folder with files named clearly!


    this (string indexFilename, size_t gridSize) in {
        assert(exists(indexFilename));
        assert(!isDir(indexFilename));
    } do {
        this.gridSize=gridSize;
        
        auto indexFile = File(indexFilename, "r");
        
        string header = indexFile.readline();
        if (header != scanPoint.CSVheader) {
            assert(0);
        }


        scanPoint[] pointsWorkingList;
        foreach (string line; indexFile.readLines) {
            //
            //TODO


        }

        enforce(scanPoints.len == expectedN);
        // TODO FIXME - SEMANTICS
        scanPoints = pointsWorkingList; // now it is const
    }

    void preprocessAll() {
        import std.parallelism; 

        foreach(i, ref point; parallel(scanPoints))
        {
            point.preprocess();
        }
    }

}

class ScanPoint
{
   // const string metadataFilename;
    const float axis1ABS,axis2ABS;
    const float axis1RelCenter, axis2RelCenter;
    const double startTime, initialColTime, colTimeThisRun;
    const bool  colTimeIsImag, dataCollectionFailed;
    
    const string metadataInputFilename;
    string inputWaveformFilename;
    string outputFolder;
    string outputSubfolder;

    // have reference to waveform (filled when loaded)
    enum LoadMode {metadataFile};
    // todo convert to template param


package:


    /// 
    this(in float axis1ABS,       in float axis2ABS,
         in float axis1RelCenter, in float axis2RelCenter,
         in double startTime,     in double initialColTime, in double colTimeThisRun,
         in bool  colTimeIsImag,  in bool dataCollectionFailed,

         //todo
         in string inputMetadataFile,
         in string pairedWaveFile = null, // todo CHECK if this is even valid in D (may need to be "")
         in string outputRootFolder = null) // will be matched seperately some times
    in {
        import std.math.traits;

        // assert all floats are not nan
        assert(!isNaN(axis1ABS));
        assert(!isNaN(axis2ABS));
        assert(!isNaN(axis1RelCenter));
        assert(!isNaN(axis2RelCenter));
        assert(!isNaN(startTime));
        assert(!isNaN(initialColTime));
        assert(!isNaN(colTimeThisRun));

        // DEBUG disable if breaks things
        assert(initialColTime == colTimeThisRun);

        // DEBUG don't expect to handle unless these show up
        assert(!colTimeIsImag);
        assert(!dataCollectionFailed);
    }
    do {
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
    
        //todo files
        this.inputMetadataFile = inputMetadataFile;
    
    }




    // todo generateIndex()



    static ScanPoint loadFromCSVline(string line){

        // tod parser here
        //return new scanPoint();
    }

    static ScanPoint loadFromMetadataFile(string metadataFilename)
    in {
        assert(exists(metadataFilename));
        assert(!isDir(metadataFilename));
    }
    do {
        this.metadataInputFilename = metadataFilename;
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
        catch (StdioException e) {
            stderr.writefln!("ERROR reading metadataFile %s")(metadataFilename);
            throw e; // todo improve
        }
    
    //TODO FILL OUT ARGUMENTS
        return new ScanPoint(axis1ABS, axis2ABS,
        axis1RelCenter, axis2RelCenter,
        startTime, initialColTime, dataCollectionFailed,);
    }



    invariant {
        import std.math.traits;

        // assert all floats are not nan
        assert(!isNaN(axis1ABS));
        assert(!isNaN(axis2ABS));
        assert(!isNaN(axis1RelCenter));
        assert(!isNaN(axis2RelCenter));
        assert(!isNaN(startTime));
        assert(!isNaN(initialColTime));
        assert(!isNaN(colTimeThisRun));

        // DEBUG disable if breaks things
        assert(initialColTime == colTimeThisRun);

        assert(!colTimeIsImag);
        assert(!dataCollectionFailed);
    }

package:
    import std.stdio;

    static string CSVHeader="Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS, startTime, collectionTimeThisRun, colTimeIsImag, dataCollectionFailed, inputMetadataFile, inputWaveform, outputSubFolder";
    
    void preprocess() {
        // todo

    }

    // todo : consider putting filenames in quotations
    string writeCSVline(File output) {
        output.writefln!("%0.2f, %0.2f, %0.2f, %0.2f, "
                         ~"%0.7f, %0.7f, %d, %d, "
                         ~"%s, %s, %s")
            (Axis1RelCenter, Axis2RelCenter, Axis1ABS, Axis2ABS,
            startTime, collectionTimeThisRun, colTimeIsImag?1:0, dataColectionFailed,
             inputMetadataFile, inputWaveformFile, outputSubFolder);
    }
}


