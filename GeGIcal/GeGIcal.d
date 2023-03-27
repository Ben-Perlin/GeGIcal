//An experiment to calibrate the PhDs. Co.'s GeGI High Purity Germanium Detector using data from APS
module GeGIcal;

import gridScan;

import std.file;
import std.format;
import std.getopt;
import std.path;
import std.stdio;
import std.parallelism;




int main(string[] args)
{

    string inputRootPath = `D:\APSdata\WaveFormMode`;
    string outputRootPath = `D:\APScal\WaveformMode`;
    
    //defaultPoolThreads(21);


    if (!exists(outputRootPath))
    {
        mkdir(outputRootPath);
    }

    assert(isDir(outputRootPath));

    GridScan grid11 = new GridScan(buildPath(inputRootPath, "11by11Grid"),
,                       buildPath(inputRootPath, "11by11Grid/WFM_10mm_1mmsteps"),
                        buildPath(outputRootDataPath, "11by11Grid"),
                        11, 1.0 /* mm */);


    GridScan grid21 = new GridScan(buildPath(inputRootPath, "21by21Grid"),
,                       buildPath(inputRootPath, "21by21Grid/WFM_10mm_pt50steps"),
                        buildPath(outputRootDataPath, "21by21Grid"),
                        21, 0.5 /* mm */);

    GridScan grid21 = new GridScan(buildPath(inputRootPath, "41by41Grid"),
,                       buildPath(inputRootPath, "41by41Grid/WFM_10mm_pt25Step"),
                        buildPath(outputRootDataPath, "21by21Grid"),
                        41, 0.25 /* mm */);
    
    // todo preprocess

    return 0;
}
