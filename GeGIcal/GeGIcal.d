module GeGIcal;

import std.getopt;
import std.stdio;

int main(string[] args)
{


    auto helpInformation = getopts(&args,
        "generate-index", &generateIndicies);



    // todo, use help file
    if (helpInformation.helpWanted) 
    {
        defaultGetOptPrinter("An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS ...",
        helpInformation.options);
    }


    return 0;
}





//TODO: add return value when that makes sense
void indexGridScans()
{
    string inputRootPath = "D:\\2016_APSdata/WaveFormMode";
    string outputDataPath = "D:\\WaveformScans";

    size_t[] gridSizes = [11, 21, 41];
    GridScan[] grids;

    foreach (i, size_t steps; gridSizes) 
    {
        string gridFolderName = format!"%2dby%2dGrid"(N, N);
        string inputMetadataFolderName;
        float stepSize;

        switch (steps) 
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
        auto inputPath     = buildNormalizedPath(inputRootPath, gridFolderName);
        auto inputMetaPath = buildNormalizedPath(inputPath, inputMetadataFolderName);
        auto outputRootPath = buildPath(outputDataPath, gridFolderName);

        grids ~= new GridScan(inputPath, inputMetaPath, outputRootPath, [steps, steps]);

        grids[i].generateIndex();


    }
}