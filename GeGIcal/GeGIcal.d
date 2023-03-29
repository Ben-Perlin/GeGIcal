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


    if (exists(outputRootPath))
    {
        rmdirRecurse(outputRootPath);
    }

    mkdir(outputRootPath);

    assert(isDir(outputRootPath));

    GridScan grid11 = new GridScan(buildNormalizedPath(inputRootPath, "11by11Grid"),
                        buildNormalizedPath(inputRootPath, "11by11Grid/WFM_10mm_1mmsteps"),
                        buildNormalizedPath(outputRootPath, "11by11Grid"),
                        11, 1.0 /* mm */);

    GridScan grid21 = new GridScan(buildNormalizedPath(inputRootPath, "21by21Grid"),
                        buildNormalizedPath(inputRootPath, "21by21Grid/WFM_10mm_pt50steps"),
                        buildNormalizedPath(outputRootPath, "21by21Grid"),
                        21, 0.5 /* mm */);

    GridScan grid41 = new GridScan(buildNormalizedPath(inputRootPath, "41by41Grid"),
                        buildNormalizedPath(inputRootPath, "41by41Grid/WFM_10mm_pt25Step"),
                        buildNormalizedPath(outputRootPath, "41by41Grid"),
                        41, 0.25 /* mm */);
    

    grid11.preprocessAll();
    grid21.preprocessAll();
    grid41.preprocessAll();
    return 0;
}
