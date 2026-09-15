//----------------------------------------------------------------------------------------------------------------------
//This macro is designed to create a radial gradient of Shh fluorescence intensity radiating from the ZPA of a limb bud
//----Starting material: 
//---------Maximum intensity projection of limb bud
//---------Hand drawn ROI around ZPA
//----Returns:
//---------ROIs of the limb bud and point coordinate max within ZPA
//---------median filtered image
//---------text document of ZPA peak coordinates
//---------Results.csv table of radial fluorescence of SHH emanating from ZPA peak within limb bud. 
//---------------------------------------------------------------------------------------------------------------------------

//STEP ONE: FIND PEAK OF ZPA SHH GRADIENT------------------------------------
// =====================================================
// Find Ch2 image -> Median Filter -> Create Cell Mask ROI
// Then reopen MedianFilter + ZPA.roi
// Find maximum intensity within ROI
// Save coordinates and point ROI
// =====================================================



// -----------------------------------------------------
// Choose directory and select max projected image
// -----------------------------------------------------
dir = getDirectory("Choose a directory"); // Ensure 'dir' is defined
list = getFileList(dir);
Ch2File = "";

for (i=0; i<list.length; i++) {
    name = list[i];
    // Check for extension and "Ch2" while preserving case sensitivity for "Ch2"
    if (endsWith(toLowerCase(name), ".tif") || endsWith(toLowerCase(name), ".tiff")) {
        if (indexOf(name, "Ch2") != -1) {
            Ch2File = list[i]; // Fixed variable name
            break;
        }
    }
}

if (Ch2File == "")
    exit("No image containing 'Ch2' found.");

open(dir + Ch2File);
origTitle = getTitle();

// -----------------------------------------------------
// Duplicate FULL image
// -----------------------------------------------------
run("Select None");
run("Duplicate...", "title=MedianFilter");

selectWindow(origTitle);
close();

// -----------------------------------------------------
// Median filter
// -----------------------------------------------------
selectWindow("MedianFilter");
run("Median...", "radius=4");

// Save filtered image
saveAs("Tiff", dir + "MedianFilter.tif");

// -----------------------------------------------------
// Create mask using Huang threshold
// -----------------------------------------------------
run("Threshold...");
waitForUser("Adjust threshold manually, then click Apply (or close window to continue)");
//Change particle size if needed to ensure your limb bud is selected
run("Analyze Particles...", "size=80000-Infinity add");
if (roiManager("count") == 0) exit("No particles found matching the size criteria.");

roiManager("Select", 0);
roiManager("Rename", "LimbBudMask");
roiManager("Save", dir + "LimbBudMask.roi");

// Close everything
run("Close All");

// -----------------------------------------------------
// Reopen MedianFilter image
// -----------------------------------------------------
open(dir + "MedianFilter.tif");

// -----------------------------------------------------
// Open ZPA ROI
// -----------------------------------------------------
roiManager("Reset");
roiPath = dir + "ZPA.roi";

if (!File.exists(roiPath)) exit("ZPA.roi not found in directory.");
roiManager("Open", roiPath);

// Select first ROI
roiManager("Select", 0);

// -----------------------------------------------------
// Find maximum inside ROI
// -----------------------------------------------------
getSelectionBounds(x0, y0, w, h);

maxVal = -1;
maxX = -1;
maxY = -1;

for (y=y0; y<y0+h; y++) {
    for (x=x0; x<x0+w; x++) {
        if (selectionContains(x,y)) {
            v = getPixel(x,y);
            if (v > maxVal) {
                maxVal = v;
                maxX = x;
                maxY = y;
            }
        }
    }
}

// Print results
print("\\Clear");
print("Maximum Intensity = " + maxVal);
print("X = " + maxX);
print("Y = " + maxY);

// Save log window
if (isOpen("Log")) {
    selectWindow("Log");
    saveAs("Text", dir + "coordinates.txt");
}

// -----------------------------------------------------
// Create point ROI
// -----------------------------------------------------
selectWindow("MedianFilter.tif");
makePoint(maxX, maxY);
roiManager("Add");

idx = roiManager("count") - 1;
roiManager("Select", idx);
roiManager("Rename", "PeakValueCoordinate");
roiManager("Save", dir + "PeakValueCoordinate.roi");

// Close everything prior to profiling
run("Close All");


//STEP TWO: RADIAL PROFILE IN BOUNDARY RESTRICTED AREA------------------------------------
// =====================================================
// ReOpen LimbBudImage & Run Radial Profile
// =====================================================
open(dir + Ch2File);

// CRITICAL FIX: Reset the ROI manager so indices 0 and 1 are exactly what we expect
roiManager("Reset");

if (File.exists(dir + "PeakValueCoordinate.roi"))
    roiManager("Open", dir + "PeakValueCoordinate.roi"); // Will be Index 0

if (File.exists(dir + "LimbBudMask.roi"))
    roiManager("Open", dir + "LimbBudMask.roi");         // Will be Index 1

roiManager("Show All");

if (roiManager("count") < 2) {
    exit("Error: Failed to load required ROIs.\nROI 0: Center Point\nROI 1: Tissue Mask");
}

// 1. Get spatial calibration details
getVoxelSize(pixelWidth, pixelHeight, depth, unit);
if (unit == "pixels" || unit == "pixel") {
    exit("Error: Your image is uncalibrated. Please set a scale in microns first (Analyze > Set Scale).");
}

// 2. Extract Center Point Coordinates
roiManager("Select", 0);
getSelectionCoordinates(xCenterArray, yCenterArray);
cx = xCenterArray[0];
cy = yCenterArray[0];

// 3. Activate the Tissue Mask
roiManager("Select", 1);

// 4. Setup profile parameters
radiusMaxMicrons = 300;
stepSizeMicrons = 1.0; 

run("Clear Results");
row = 0;

print("Starting boundary-restricted radial profile calculation...");

// 5. Sweep outward ring by ring
for (r = 0; r <= radiusMaxMicrons; r += stepSizeMicrons) {
    
    sumIntensity = 0;
    pixelCount = 0;
    radiusInPixels = r / pixelWidth;
    
    // Dynamic angular resolution calculation
    angularStep = 0.5 / (radiusInPixels + 1); 
    
    for (angle = 0; angle < 2 * PI; angle += angularStep) {
        px = round(cx + radiusInPixels * cos(angle));
        py = round(cy + radiusInPixels * sin(angle));
        
        if (px >= 0 && px < getWidth() && py >= 0 && py < getHeight()) {
            // Evaluates against the active LimbBudMask selection
            if (selectionContains(px, py)) {
                sumIntensity += getPixel(px, py);
                pixelCount++;
            }
        }
    }
    
    // 6. Record to Results Table
    if (pixelCount > 0) {
        avgIntensity = sumIntensity / pixelCount;
        setResult("Distance (" + unit + ")", row, r);
        setResult("Mean Intensity", row, avgIntensity);
        setResult("Tissue Pixels Counted", row, pixelCount);
        row++;
    }
}

updateResults();
print("--- Radial Profile Generation Complete! ---");

saveAs("Results", dir + "Results.csv");

// Clean cleanup
run("Close All");
if (isOpen("ROI Manager")) {
    selectWindow("ROI Manager");
    run("Close");
}
if (isOpen("Log")) {
    selectWindow("Log");
    run("Close");
}