module GeGIcal;

import std.getopt;
import std.stdio;

int main(string[] args)
{

    bool generateIndicies;

    auto helpInformation = getopts(&args,
        "generate-indicies", &generateIndicies);

    if (helpInformation.helpWanted) {
        defaultGetOptPrinter("An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS ...",
        helpInformation.options);
    }


    return 0;
}


// Todo debug levels
// fix many bugs introduced in thinking this through


//TODO: add return value when that makes sense
void indexGridScans()
{
    string inputRootPath = "D:\\2016_APSdata/WaveFormMode";
    string outputDataPath = "D:\\WaveformScans";

    size_t[] gridSizes = [11, 21, 41];
    GridScan[] grids;

    foreach (i, size_t steps; gridSizes) { // CHECK ME SYNTAX
        string gridFolderName = format!"%2dby%2dGrid"(N, N);
        string inputMetadataFolderName;
        float stepSize;

        switch (steps) {
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
        auto inputPath = buildPath(inputRootPath, gridFolderName);
        auto inputMetaPath = buildPath(inputPath, inputMetadataFolderName); //
        auto outputPath = buildPath(outputDataPath, gridFolderName);

        grids ~= new GridScan(inputPath, inputMetaPath, outputPath, [steps, steps]);

        grids[i].generateIndex();


    }
}