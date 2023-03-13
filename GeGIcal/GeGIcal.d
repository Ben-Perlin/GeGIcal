//An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS
module GeGIcal;

import gridScan;

import std.file;
import std.format;
import std.path;
import std.stdio;


int main(string[] args)
{

    string inputRootPath = `D:\APSdata\WaveFormMode`;
    string outputRootPath = `D:\APScal\WaveformMode`;

    if (!exists(outputRootPath))
    {
        mkdir(outputRootPath);
    }
    else
    {
        assert(isDir(outputRootPath));
    }

    GridScan[] grids = indexGrids(inputRootPath, outputRootPath);

    // todo implement load index top level

    import std.algorithm : each;

    grids.each!"a.preprocessAll()";


    return 0;
}

GridScan[] indexGrids(string inputRootPath, string outputRootPath)
{

    GridScan[] grids;

    foreach (i, size_t gridDim; [11, 21, 41])
    {
        string gridFolderName = format!"%2dby%2dGrid"(gridDim, gridDim);
        auto inputPath      = buildPath(inputRootPath, gridFolderName);

        string inputMetadataFolderName;
        float stepSize;

        switch (gridDim) 
        {
            case 11:
                inputMetadataFolderName = "WFM_10mm_1mmsteps";
                stepSize = 1.0;
                break;

            case 21:
                inputMetadataFolderName = "WFM_10mm_pt50steps";
                stepSize = 0.5;
                break;

            case 41:
                inputMetadataFolderName = "WFM_10mm_pt25Step"; // assertions caught this inconsistancy!
                stepSize = 0.25;
                break;

            default:
                assert(0);
        }

        // build paths
        auto metadataRootFolder  = buildPath(inputPath, inputMetadataFolderName);
        auto outputFolder = buildPath(outputRootPath, gridFolderName);

        // This is as much a script as a program, so just clean before reindexing a grid for now
        if (exists(outputFolder))
        {
            rmdirRecurse(outputRootPath);
        }


        grids ~= new GridScan(inputPath, metadataRootFolder, outputFolder, gridDim, stepSize);
        writeln("Successfully indexed grid");

    }

    return grids;
}