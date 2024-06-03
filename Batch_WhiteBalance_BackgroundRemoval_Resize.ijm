#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ Integer (label="Pyramid Level to analyze", style="slider", min=1, max=6, value= 2, stepSize=1, persist=true) level
#@ Integer (label="ResizeHeight", style="slider", min=1, max=5000, value= 2000, stepSize=1, persist=true) targetHeight

run("Bio-Formats Macro Extensions");

//Preparing Stage
setBatchMode(false);
setOption("BlackBackground", true);
print("\\Clear");
close("*");
if (roiManager("count")>0) {

roiManager("Deselect");
roiManager("Delete");
}
setOption("ExpandableArrays", 1);
File.makeDirectory(output + "\\OriginalSize\\");
File.makeDirectory(output + "\\Resize\\");
var resizeFolder=newArray(0);
var resizeWidth=newArray(0);
var B;
B=0;
//Processing the folder 
processFolder(input);
//test
Array.print(resizeFolder);
Array.print(resizeWidth);
//making resized Versions uniform
Array.getStatistics(resizeWidth, min, max, mean, stdDev);
for (a = 0; a < B; a++) {
	open(resizeFolder[a]);
	Stack.getDimensions(width, height, channels, slices, frames);
	getPixelSize(unit, pixelWidth, pixelHeight);
	run("Select All");
	run("Copy");
	newImage("New", "RGB", max, targetHeight, 1);
	run("Paste");
	run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width="+pixelWidth+" pixel_height="+pixelHeight+" voxel_depth=1.0000000");
	saveAs("TIFF", resizeFolder[a]);
	close("*");
}

//run("Clear Results");
print("I'm DONE with this folder - time for coffee!");


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	A=list.length;
	print("0 of "  + A + " files processed");
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], ".czi"))
			processFile(input, output, list[i]);
	}
}

// function to do the actual processing
function processFile(input, output, file) {

// Bio-Formats Importer opens files in specified pyramid stage and gets metadata
run("Bio-Formats Importer", "open=[" + input + "\\" + list[i] + "] color_mode=Default view=Hyperstack stack_order=XYCZT series_"+ level);
title=getTitle();
Stack.getDimensions(width, height, channels, slices, frames);
getPixelSize(unit, pixelWidth, pixelHeight);
path=getInfo("image.directory");
folder_list=split(path, "\\");
a=lengthOf(folder_list)-1;
folder=folder_list[a];
targetWidth=round(width*(targetHeight/height));

//Correct for wrong scaling in Pyramid formats
pixelWidth2=(pixelWidth*pow(2, level-1));
pixelHeight2=(pixelHeight*pow(2, level-1));
run("Properties...", "channels="+channels+" slices="+slices+" frames="+frames+" pixel_width="+pixelWidth2+" pixel_height="+pixelHeight2+" voxel_depth=3.0000000");

waitForUser("Alignment Adjustment", "Aling the Image by using Image>Transform");

//Preparing&Getting statistics
run("Duplicate...", "title=Mask_Aorta duplicate");
run("RGB Color");
run("8-bit");
getStatistics(area, mean, min, max, std, histogram);
run("Duplicate...", "title=Mask_Aorta_backfill duplicate");

//Compensate missing tiles
if (min==0) {
setThreshold(0, 1);
//
run("Convert to Mask");
run("Create Selection");
selectWindow("Mask_Aorta (RGB)");
run("Restore Selection");
run("Fill", "slice");
run("Select None");
}

//Compensate White Tiles
selectWindow("Mask_Aorta (RGB)");
run("Duplicate...", "title=Mask_Aorta_frontfill duplicate");
setThreshold(255, 255);
run("Convert to Mask");
run("Create Selection");
run("Make Inverse");
roiManager("add");
roiManager("select", 0);
roiManager("rename", "TotalImageArea");

//Tissue Detection
selectWindow("Mask_Aorta (RGB)");
run("Restore Selection");
setAutoThreshold("Huang");
run("Convert to Mask");
run("Remove Outliers...", "radius=3 threshold=50 which=Bright");
run("Remove Outliers...", "radius=3 threshold=50 which=Dark");
run("Create Selection");
roiManager("Add");
roiManager("Select", 1);
roiManager("Rename", "Aorta_Area");

//Background Creation
roiManager("Select", newArray(0,1));
roiManager("XOR");
roiManager("Add");
roiManager("Select", 2);
roiManager("Rename", "Background");
close("Mask*");

//RGB White balance Correction
run("Split Channels");
MeanColor=newArray(3);

maxi = 0;

for (u=1; u<4; u++) {
selectWindow("C"+u+"-"+title);
roiManager("select", 2);
getStatistics(area, mean);
MeanColor[u-1] = mean;
if (mean>=maxi) maxi = mean;
}

for (u=1; u<4; u++) {
selectWindow("C"+u+"-"+title);
run("Select None");
run("Multiply...", "value="+maxi/MeanColor[u-1]);
}

run("Merge Channels...", "c1=[C1-" + title + "] c2=[C2-"+title+"] c3=[C3-"+title+"] create");
run("RGB Color");

roiManager("Select", 0);
run("Make Inverse");
run("Fill", "slice");
//Saving result
saveAs("TIFF", output + "\\OriginalSize\\" + folder +"_Original_"+ title + ".tif");
rename("Original");

run("Duplicate...", "title=Resize");
run("Size...", "width=" + targetWidth + " height="+targetHeight+" depth=1 constrain average interpolation=Bilinear");
saveAs("TIFF", output + "\\Resize\\" + folder +"_Original_"+ title + ".tif");

resizeFolder[B]=output + "\\Resize\\" + folder +"_Original_"+ title + ".tif";
resizeWidth[B]=getWidth();

close("Resize");

selectImage("Original");

roiManager("Select", 2);
run("Fill", "slice");
roiManager("deselect");

run("Select None");
saveAs("TIFF", output + "\\OriginalSize\\" + folder +"_Filled_"+ title + ".tif");
rename("Original_Filled");
run("Duplicate...", "title=Resize");
run("Size...", "width=" + targetWidth + " height="+targetHeight+" depth=1 constrain average interpolation=Bilinear");
saveAs("TIFF", output + "\\Resize\\" + folder +"_Filled_"+ title + ".tif");
close("Resize");

//Clean up
close("*");
roiManager("Deselect");
roiManager("Delete");

print("\\Clear");
print((i+1)  + " of "  + A + " files processed");
B++;}

