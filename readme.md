These are a few simple yet effective functions to stack astronomical images, and remove vingetting and a vertical gradient background.

The offset between the images is performed through convolution. This is achieved by FFTing the images, multiplying and FFTing back. If the offset is relatively large, the peak in the convolution could be the no-offset value. To remove this, we do simple high pass filtering of the images to remove the low frequencies. 

The main file to run (interactively) is align_astro_images.jl

The sample images are 5 one second snapshots of comet Tsuchinshan-ATLAS 2024 taken with a Nikon 5300 DSLR from my bedroom, during twilight. 