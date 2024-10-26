# read all the packages and functions for the stacking and background subtraction.
include("src/astro_image_stacking.jl")

# Where are the images stored?
path = "input/sample_series/"

# Find all the images in the folder
files = glob("*.JPG", "$path")

# Now read in the image data
images = [load(file) for file in files[1:end]];

# Stack the images
@time stacked = stack_images(images);

# You can see the different fields that stacked has
keys(stacked)
# It includes the 3 color channels, the maximum shift in i and j, and the offsets
stacked.offsets

#size of Images doesn't change but it includes less data at the edges
size(stacked.red)   

# We can define smaller ranges to work with
rngi = 250:4000-200
rngj = 200:6000-200

# If you want to see a histogram of the stacked images
if false 
    histogram(stacked.red[:], bins=100, label="Red", alpha=0.5, c=:red)
    histogram!(stacked.green[:], bins=100, label="Green", alpha=0.5, c=:green)
    histogram!(stacked.blue[:], bins=100, label="Blue", alpha=0.5, c=:blue)
end 

# Here is the stacked image (combined from all the images)
fac = 10.0
map(p -> RGB(fac*p[1], fac*p[2], fac*p[3]), zip(stacked.red, stacked.green, stacked.blue))

# You can see the vignetting in the image and that the lower part is brighter 
# Because of dusk. 

# Now lets try to remove the vignetting
@time back_red = radial_background(stacked.red[rngi, rngj]);
@time back_green = radial_background(stacked.green[rngi, rngj]);
@time back_blue = radial_background(stacked.blue[rngi, rngj]);

red_corr =  (stacked.red[rngi,rngj] - back_red)[1:end,500:end-1000];
green_corr = (stacked.green[rngi,rngj] - back_green)[1:end,500:end-1000];
blue_corr = (stacked.blue[rngi,rngj] - back_blue)[1:end,500:end-1000];

# This is what it looks like
map(p -> RGB(fac*p[1], fac*p[2], fac*p[3]), zip(red_corr, green_corr, blue_corr))

# Now lets try to review the vertical gradient
red_corr = remove_vertical_gradient(red_corr);
green_corr = remove_vertical_gradient(green_corr);
blue_corr = remove_vertical_gradient(blue_corr);

# We can also add some level scaling
func(x) = x < 0.0 ? 0.0 : tanh(40.0*x^1.0)
colimg = map(p -> RGB(func(p[1]), func(p[2]), func(p[3])), zip(red_corr, green_corr, blue_corr))

# We can now try to improve the picture but removing pixels with high saturation (they are noise)
hsvimg = HSV.(colimg)                     # RGB -> HSV
channels = channelview(float.(hsvimg));   # separate into channels
sat_img = channels[2,:,:];                # saturation channel hSv i.e, the second channel

@time colimg = Gray.(map((r,g,b,s) -> colorize(r,g,b,s;     
        factor = 25.0, offset = 0.002, γ = 0.75), 
        red_corr, green_corr, blue_corr, sat_img))

#The inverted image allows more easily to see the details. 
imginvert = 1.0 .- colimg

save("output/comet-Tsuchinshan–ATLAS.png", colimg)

# We can also add some blur since the details are larger than that of a pixel anyway
filtered_image = imfilter(colimg, Kernel.gaussian(3))
save("output/comet-Tsuchinshan–ATLAS-blur.png", filtered_image)

scaled_image = imresize(filtered_image, size(filtered_image) .÷ 3);
save("output/comet-Tsuchinshan–ATLAS-scaled.png", scaled_image)
