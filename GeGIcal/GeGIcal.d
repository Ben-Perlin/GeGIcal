
///An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS
module GeGIcal;
import gridScan;

import std.file;
import std.format;
import std.path;
import std.stdio;

int main(string[] args)
{

    string inputRootPath = "D:\\APSdata/WaveFormMode";
    string outputDataPath = "E:\\APScal/WaveformMode";

    if (!exists(outputDataPath))
    {
        mkdir(outputDataPath);
    }
    else
    {
        assert(isDir(outputDataPath));
    }

    GridScan[] grids;

    foreach (i, size_t gridSize; [11, 21, 41]) 
    {
        string gridFolderName = format!"%2dby%2dGrid"(gridSize, gridSize);
        string inputMetadataFolderName;
        float stepSize;

        switch (gridSize) 
        {
            case 11:
                inputMetadataFolderName = "WFM_10mm_1mmsteps";
                stepSize = 1.0;
            case 21:
                inputMetadataFolderName = "WFM_10mm_pt50steps";
                stepSize = 0.5;
            case: 41
                inputMetadataFolderName = "WFM_10mm_pt25steps";
                stepSize = 0.25;
        }

        // build paths
        auto inputPath      = buildNormalizedPath(inputRootPath, gridFolderName);
        auto inputMetaPath  = buildNormalizedPath(inputPath, inputMetadataFolderName);
        auto outputRootPath = buildNormalizedPath(outputDataPath, gridFolderName);

        // This is as much a script as a program, so just clean before reindexing a grid for now
        if (exists(ouptutRootPath))
        {
            rmdirRecurse(outputRootPath);
        }

        grids ~= GridScan.indexAndPreprocess(inputPath, inputMetaPath, outputRootPath, gridSize, stepSize);
    }

    writeln("debugger point");

    return 0;
}