SAM Instructions


Prerequisites:

o	Installed FIJI (ImageJ 2)

o	R-Language (R-Studio) installed

o	Images to analyse need to be in 8-bit and Tiff format

o	You NEED to have a nuclear staining (e.g: DAPI) in the First channel of your images 

o	Install StarDist and CSBDeep in FIJI (https://imagej.net/plugins/stardist) (more info)


Before running the Macro:

o	Make sure you have good Images to analyze (little-no oversaturation, little-no Background)

o	 All Tiff you want to analyze should be in one Folder and all CSV created by the FIJI Macro should be saved in a separate Folder

o	Determine the threshold for your channels (see How to determine threshold)

o	Check what the best Stardist segmentation settings are for your nuclear Staining (more Info in Stardist segmentation)

 Running the Analysis Pipeline:

Start by running your image analysis in Fiji:
1.	Simply drag and drop "TheMacroToRuleThemAll.ijm" into the Fiji window. While the macro runs, check if the segmentation results and DAPI nuclei ROIs look correct - if they appear unusual, there might be issues with your image preparation or file format
2.	In the first dialog window, select your input folder containing all 8-bit TIFF files
3.	In the second dialog window, choose where you want to save the CSV output files

Processing with R

After the Fiji analysis is complete:
1.	Launch "RscriptforTheMacroToRuleThemAll.R"
2.	Select the folder containing your CSV files when prompted
3.	Choose the output location for the configuration and summary files
4.	Enter your threshold values in the designated field
5.	**Important**: Save your configuration before proceeding - the script won't run without a saved configuration
6.	Click Run to start the analysis



Install StarDist and CSBDeep:
 


How to determine threshold:

Setting Up Your Analysis

Setting appropriate thresholds is a key step in achieving reliable image analysis results. While you can determine these values manually by examining representative images from your experiment, automated approaches like Otsu's method can also help establish objective cutoff values.

How This Macro Works

This analysis requires threshold determination for each channel, except for the nuclear staining in Channel 1. The macro evaluates the average signal intensity within a 1 µm region around each nucleus - if this intensity exceeds your set threshold, the cell is classified as positive.

Important Considerations

Since ROIs don't always perfectly align with cellular boundaries, consider adjusting your threshold calculations accordingly. A good practice is to set your positive signal threshold at 50-60% of typical cellular expression levels (i.e., multiply your standard threshold by 0.5-0.6). This adjustment helps account for cases where the ROI only partially overlaps with a cell while still maintaining reliable detection of positive signals.
 
Your threshold settings should align with your experimental goals - whether focusing on highly expressing populations or capturing a broader range of signal intensities.

Best Practices

- Test your thresholds on multiple representative images
- Maintain consistent settings throughout your analysis
- Document your chosen threshold values
- Adjust criteria based on your specific experimental requirements

Remember that the quality of your results depends on appropriate threshold selection and consistent application of these criteria throughout your analysis.

Example

To determine the appropriate threshold for quantifying cytoplasmic cells, I measured the background intensity in 10 different areas and obtained an average value of 32, with the highest being 41. I then calculated the background threshold by multiplying the average (32) by 1.5, resulting in a value of 48. Since the maximum measured background (41) does not exceed this threshold, I am using 48 as the treshhold in my R script for cell quantification.



Stardist segmentation


Nuclear Segmentation with StarDist

StarDist's segmentation quality is crucial as it forms the foundation for all subsequent analysis by defining your cell boundaries. The method uses star-convex shapes to detect and separate nuclei, which works particularly well for densely packed and blob-like objects.

Checking Your Segmentation

While the default settings in the macro should work well for most nuclear staining patterns, it's essential to verify the segmentation quality with your specific samples. Pay attention to:

o	Whether nuclei are properly separated
o	If the nuclear boundaries are accurately detected
o	Whether the algorithm misses dim nuclei or creates false positives

Optimizing Detection

If you notice segmentation issues, consider adjusting these key parameters:

o	Probability threshold: affects how confident the model needs to be to detect a nucleus
o	NMS threshold: controls overlap between detected objects
o	Input image normalization helps with varying staining intensities

For optimal results, ensure your nuclear staining (DAPI/Hoechst) has sufficient signal intensity and good contrast. Poor staining quality or very low exposure times can lead to suboptimal segmentation results.

Remember that accurate nuclear segmentation is critical since all subsequent measurements and analysis depend on proper cell identification.

To help with setting up StarDist parameters for your specific needs, you can use Fiji's macro recorder (Plugins > Macros > Record) while running StarDist on just your nuclear channel (make sure to close all other channels first). The recorded command can either be modified at line 79 in the existing macro or replaced with your new settings using the "Command From Macro" syntax when running StarDist.




 



Know problems:

MacOS users experience problems with StarDist segmentation. 
To fix this open FIJI

Edit › Options › TensorFlow

And change the version to TF 1.12.0 CPU, afterwards restart and it should work.
![image](https://github.com/user-attachments/assets/8aaf9e7c-151e-411d-9f32-74990917df1c)
# SAM
