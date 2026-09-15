//=====================================================================================================
//To measure Shh fluorescence in the golgi apparatus mask over the course of a CDH synchronous release. 
///Starting material:
//---------Requires max-intensity projected 2channel images ch1 = Shh (Shh-CB-msfGFP) ch2= Golgi (GalNAcT2-HALO)
//Creates Golgi thresholded ROI for every time frame and measures Shh fluorescence within ROI
//=====================================================================================================

//Step1: get title, Split channels, create Golgi threshold, and blur Shh fluorescence
title=getTitle();
run("Split Channels");

//GalNAcT2-HALO channel
selectWindow("C2-"+title);          
run("Gaussian Blur...", "sigma=1 stack");
//run("Threshold...");
setAutoThreshold("Otsu dark");

//Shh-CB-msfGFP channel
selectWindow("C1-"+title);
run("Grays");
run("Gaussian Blur...", "sigma=1 stack");
//run("Threshold...");

//Step2: loop through timelapse creating & restoring selection of Golgi ROI and measuring Shh fluorescence
for (n=1; n<=nSlices; n++) {
          setSlice(n);
selectWindow("C2-"+title); 
setSlice(n);
run("Create Selection");
//run("Measure");
selectWindow("C1-"+title);
run("Restore Selection");
run("Set Measurements...", "area mean min integrated limit display redirect=None decimal=0");
run("Measure");
selectWindow("C2-"+title); 
run("Select None");
selectWindow("C1-"+title);
run("Select None");
}


//Step3: Save images and Results
dir = getDirectory("Select output directory for results and images");
if (dir != "") {
    // Strip extension from original title for clean naming
    baseName = replace(title, ".tif", "");
    baseName = replace(baseName, ".tiff", "");

    // Save the Results table as a CSV
    saveAs("Results", dir + "Shh_Golgi_Results_" + baseName + ".csv");
    
    // Save the processed channel stacks
    selectWindow("C1-"+title);
    saveAs("Tiff", dir + "C1_Processed_" + title);
    
    selectWindow("C2-"+title);
    saveAs("Tiff", dir + "C2_Processed_" + title);
    
    print("Successfully completed! Results and images saved to: " + dir);
}
