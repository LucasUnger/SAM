// Create the dialog for user input
Dialog.create("Configure Parameters");

// Add a message to the dialog
Dialog.addMessage("Please enter the parameters for the analysis. Note: The nuclear marker must be in Channel 1.");

// Add input fields for the user
Dialog.addNumber("Number of Channels:", 5);  // Default to 5 channels
Dialog.addChoice("Z-stack (Yes/No):", newArray("Yes", "No"), "Yes");  // Dropdown for Z-stack, default to "Yes"
Dialog.addChoice("Projection Type:", newArray("Max Intensity", "Mean Intensity"), "Max Intensity");  // Default to Max Intensity
Dialog.addCheckbox("Draw ROI?", true);  // Default to true (checked)


// Show the dialog to the user
Dialog.show();

// Retrieve the values the user entered
numChannels = Dialog.getNumber();  // Number of channels
isZStack = Dialog.getChoice();  // Z-stack ("Yes" or "No")
projectionType = Dialog.getChoice();  // Projection type
drawROI = Dialog.getCheckbox();  // Whether to draw ROI

var processed = false;
var inputFolder, outputFolder;

// Create dialog
Dialog.create("Select Folders");
Dialog.addMessage("Please first select input (TIFFs) and afterwards the output folders (CSV)");
Dialog.show();

// Get input folder
inputFolder = getDirectory("Select INPUT Directory for Processing");
if (inputFolder == "") exit("No input directory selected");

// Get output folder
savefolder = getDirectory("Select OUTPUT Directory for CSV files");
if (savefolder == "") exit("No output directory selected");

// Get list of files
filenames = getFileList(inputFolder);

X = filenames.length;
run("Set Measurements...", "area mean min integrated density area_fraction nan redirect=None decimal=3");

// Process each file
for (j = 0; j < X; j++) {
    file_to_open = inputFolder + filenames[j];
    print("Processing file " + (j + 1) + " of " + X);
    open(file_to_open);
    rename("OG");

    // Check if the image is a stack
    if (nSlices > 1) {
        if (isZStack == "Yes") {
            run("Z Project...", "projection=[" + projectionType + "]");
            // Dynamically capture the name of the new window created by Z Project
            list = getList("image.titles");
            for (k = 0; k < list.length; k++) {
                if (startsWith(list[k], "MAX_")) {  // "MAX_" is used for Max Intensity
                    projectionWindow = list[k];
                    break;
                }
            }
        } else {
            projectionWindow = "OG";  // Use the original window if no Z-projection is applied
        }
    } else {
        print("Image is not a stack. Skipping Z-projection.");
        projectionWindow = "OG";  // Use the original window if no Z-projection is applied
    }

    // Draw ROI if requested (before processing any channels)
    if (drawROI) {
        selectWindow(projectionWindow);
        roiManager("Reset");  // Clear previous ROIs from the manager
        waitForUser("Draw ROI, then click OK");
        roiManager("Add");  // Add the new ROI
        roiManager("show all");  // Show all ROIs
        roiManager("deselect");

        // Get selected ROI
        roiManager("select", 0);
        getSelectionBounds(x, y, width, height);
        // Removes all signal around ROI for all stacks
        run("Clear Outside", "stack");
    }

    // Process Channel 1 (DAPI) for segmentation
    selectWindow(projectionWindow);
    run("Duplicate...", "title=Channel_1 duplicate channels=1");
    rename("DAPI");  // Ensure Channel 1 is renamed to DAPI
    run("Command From Macro", 
        "command=[de.csbdresden.stardist.StarDist2D], " +
        "args=['input':'DAPI', 'modelChoice':'Versatile (fluorescent nuclei)', " +
        "'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', " +
        "'probThresh':'0.7500000000000001', 'nmsThresh':'0.4', " +
        "'outputType':'ROI Manager', 'nTiles':'1', 'excludeBoundary':'2', " +
        "'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', " +
        "'showProbAndDist':'false'], process=[false]");

    // Process remaining channels
    for (i = 2; i <= numChannels; i++) {
        selectWindow(projectionWindow);
        run("Duplicate...", "title=Channel_" + i + " duplicate channels=" + i);
        selectWindow("Channel_" + i);
        setAutoThreshold("Otsu dark");
        setOption("BlackBackground", true);

        // Measure without enlargement
        roiCount = roiManager("count");
        if (roiCount > 0) {
            for (l = 0; l < roiCount; l++) {
                selectWindow("Channel_" + i);
                roiManager("Select", l);
                run("Measure");
            }
        } else {
            print("No ROI selected for Channel " + i);
        }
        saveAs("Results", savefolder + filenames[j] + "_Channel_" + i + "_without_enlargement.csv");
        run("Clear Results");

        // Measure with enlargement
        if (roiCount > 0) {
            for (l = 0; l < roiCount; l++) {
                selectWindow("Channel_" + i);
                roiManager("Select", l);
                run("Enlarge...", "enlarge=1"); // Enlarges around the nuclei by 1 µm
                run("Measure");
            }
        } else {
            print("No ROI selected for Channel " + i);
        }
        saveAs("Results", savefolder + filenames[j] + "_Channel_" + i + "_with_enlargement.csv");
        run("Clear Results");

        // Close the channel window after processing
        selectWindow("Channel_" + i);
        close();
    }

    // Run Fresh Start after each image
    run("Fresh Start");
}
