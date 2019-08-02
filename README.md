# EASY-analyses
Analyses related to EASY study at MSKCC

## MATLAB code
The initial implementations were done in MATLAB due to rapid prototyping
demands. The functions are briefly described below.

Next to core MATLAB, the code requires the neuroelf toolbox (available at
https://github.com/neuroelf/neuroelf-matlab).

### easy_annotate.m
This function will read in the annotation images, which must reside in a
single folder and be named like this:

```[STUDYTOKEN]_ISIC[NUMBER]_[ANNOTATOR]_[FEATURE].jpg```

e.g.

```EASYstudy1_ISIC0016092_BestAnnotator_Dots.jpg```

The ```ISIC[NUMBER]``` part is used to detect which image the annotation
is related to, and the ```[ANNOTATOR]``` part is used to detect the
number of annotators per image, and finally the ```[FEATURE]``` part is
used to group the data into features.

The first argument to the function is the folder in which easy_annotate
searches for the images. If the argument is not given, it defaults to
the folder in which the ```easy_annotate.m``` file resides.

Next to the annotation (mask) images, the original ISIC images are
required as well, and also a studyfile (CSV) which defaults to
```'Annotations/study1.csv'```. These files must be available in
the expected paths.

The study file contains information about the ISIC images included in
that particular study. The information is given as one row per image,
and the following fields, separated by comma, are present in the file:

```[mongodb_ObjectId],ISIC_[NUMBER],[FEATURE_PLAIN],1```

The ObjectId (e.g. ```58b0a360d831137d0a388356```) allows a unique
addressing (and download) of the image from the ISIC archive.

The ISIC image number is contained in the ```ISIC_[NUMBER]``` string,
allowing to store downloaded files with the correct filename. Please
note that in this format, an underscore separates the string
```'ISIC'``` from the actual number!

The feature name is given in plain English, and may contain spaces,
colons, slashes, etc., as in ```Structureless : Milky red areas```.

The trailing ```1``` is for future extensions.

The file used for the first EASY1 study is included in this repository!

In addition to the folder name (first argument), a second, optional,
1x1 struct argument can be provided that allows the user to override
some of the default behavior:

The ```.colors``` field is used for the main feature (which is given
in the study1.csv file for each image!). It must be at least 2 rows
of 1x3 RGB codes (0 to 255 values).

The ```.colorscale``` field allows to scale the colors in a non-linear
way. The default is the expression ```log(1 + (0:24)) ./ log(25)```.

The ```.fullconf``` field (either true or false, default true), tells
the function whether to consider any value in the mask > 0 as 100 per
cent confidence.

The ```.maxraters``` field allows to override the number of maximum
raters per image (default: detected from all available annotation
mask images).

The ```.mcolors``` field is another set of Cx3 colors (with at least
two additional colors necessasry). These colors will be used to color
the features besides the main features.

The ```.ofolder``` field allows to set a separate folder into which all
output images will be written. The default is to use the same as the
input folder (first argument).

The function will write out montage images that contain (top row, left
to right; bottom row, left to right):
- the original ISIC image
- the original ISIC image with the main (canonical) feature heatmap
- the original ISIC image with all features (mixed color heatmap)
- a heatmap color legend, with all levels of overlap, and further features

### easy_dice.m
This function computes both the Dice and (smoothed-image)
cross-correlation coefficients for a pair of images. In addition, it
can return resampled images, which will speed up the computation for
subsequent calls with the same images.

The syntax is:

```[d, smcc, sim1, sim2] = easy_dice(im1, im2, sk, sim1, sim2)```

whereas
- im1 and im2 are the original (mask) images
- sk is the smoothing kernel
- sim1 and sim2 are the resampled images (output from the function); for the first call, simply provide two empty arrays!
- d and smcc are the Dice and smoothed-image-cross-correlation values

### easy_overlap_stats.m
This function uses easy_dice to compute confusion matrices, both using
the Dice and SMCC measures, for pairs of images in the annotation
dataset.

## Python code
For now, the repository only contains a test-download function that
demonstrates how to access the files from the ISIC archive in principle.

### download_ISIC_file.test.py
This can be executed in a terminal/console. You will be asked to enter
a (valid) ISIC username (email) and password (which will not be shown
in the console). It will then download the very first ISIC image and
store it in a local file with the correct number.

The code can be used to write additional functions (or classes) that
access the ISIC archive programmatically.

### EASY pilot study downloads.ipynb
This notebook can be used to download the ISIC and annotation images
from one study. The notebook comes preconfigured with the
```ISIC Annotation Study - All Features``` study, ID
```5a32cde91165975cf58a469c```.