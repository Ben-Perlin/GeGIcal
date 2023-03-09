//An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS
module GeGIcal;

import gridScan;

import std.file;
import std.format;
import std.path;
import std.stdio;

int main(string[] args)
{

    string inputRootPath = "D:\\\\APSdata/WaveFormMode";
    string outputDataPath = "D:\\\\APScal/WaveformMode";

    if (!exists(outputDataPath))
    {
        mkdir(outputDataPath);
    }
    else
    {
        assert(isDir(outputDataPath));
    }

    GridScan[] grids;

    foreach (i, size_t gridDim; [11, 21, 41])
    {
        string gridFolderName = format!"%2dby%2dGrid"(gridDim, gridDim);
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
                inputMetadataFolderName = "WFM_10mm_pt25steps";
                stepSize = 0.25;
                break;

            default:
                assert(0);
        }

        // build paths
        auto inputPath      = buildPath(inputRootPath, gridFolderName);
        auto inputMetaPath  = buildPath(inputPath, inputMetadataFolderName);
        auto outputRootPath = buildPath(outputDataPath, gridFolderName);

        // This is as much a script as a program, so just clean before reindexing a grid for now
        if (exists(outputRootPath))
        {
            rmdirRecurse(outputRootPath);
        }


        grids ~= GridScan.createAndIndex(inputPath, inputMetaPath, outputRootPath, gridDim, stepSize);


    }

    writeln("Indexing successful");

    return 0;
}