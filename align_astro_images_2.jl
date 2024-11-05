using FileIO, ImageView, Glob, Images
using Plots
using Base.Threads
using Images, ImageTransformations, FFTW
using PNGFiles
using CubicSplines

# Function to compute the cross-correlation between two images and find the shift
function find_offset(image1, image2)
    # Convert images to grayscale if needed
    img1 = Float64.(Gray.(image1-imfilter(image1, Kernel.gaussian(5))))
    img2 = Float64.(Gray.(image2-imfilter(image2, Kernel.gaussian(5))))

    # Perform cross-correlation using FFT
    f1 = fft(img1)
    f2 = fft(img2)
    cross_correlation = ifft(f1 .* conj(f2))
    # Find the location of the maximum value in the cross-correlation
    max_idx = argmax(abs.(cross_correlation))
    shiftsi = (max_idx[1] - size(image1, 1) ÷ 2) % size(image1, 1) - size(image1, 1) ÷ 2
    shiftsj = (max_idx[2] - size(image1, 2) ÷ 2) % size(image1, 2) - size(image1, 2) ÷ 2
    return (shiftsi, shiftsj)
end

find_offset(images[17], images[16])


# Function to align and stack multiple images
function stack_images(image_list)
    nimages = length(image_list)
    iref = nimages ÷ 2
    reference_image = image_list[iref]
    aligned_images = [reference_image]  # Store aligned images

    offsetsi = []
    offsetsj = []
    for i in 1:nimages
        if i == iref
            continue
        end
        print(".")
        offset = find_offset(reference_image, image_list[i])
        aligned_image = circshift(image_list[i], offset)
        push!(aligned_images, aligned_image)
        push!(offsetsi, offset[1])
        push!(offsetsj, offset[2])
    end
    mi = maximum(abs.(offsetsi))
    mj = maximum(abs.(offsetsj))
    # Stack images by averaging
    reds = sum(float.(map(i -> red.(i), aligned_images))) ./ length(aligned_images)
    greens = sum(float.(map(i -> green.(i), aligned_images))) ./ length(aligned_images)
    blues = sum(float.(map(i -> blue.(i), aligned_images))) ./ length(aligned_images)
    return (red=reds, green=greens, blue=blues, mi = mi, mj = mj, offsets=(offsetsi, offsetsj))
end

function radial_background(mat)
    rs = []
    vs = []
    for i ∈ 1:20:size(mat, 1)
        for j ∈ 1:20:size(mat, 2)
            r = sqrt.((i .- size(mat, 1) ÷ 2) .^ 2 .+ (j .- size(mat, 2) ÷ 2) .^ 2)
            push!(rs, r)
            push!(vs, mat[i, j])
        end
    end
    ncells = 10
    mrs = maximum(rs)
    bins = collect(range(0, stop=maximum(rs), length=ncells))
    bin_means = []
    bin_stds = []
    for i ∈ 1:length(bins)-1
        idxs = findall(x -> x > bins[i] && x < bins[i+1], rs)
        push!(bin_means, mean([vs[i] for i in idxs]))
        push!(bin_stds, std([vs[i] for i in idxs]))
    end
    #scatter!(0.5 * (bins[1:end-1] .+ bins[2:end]), log10.(bin_means), c=:blue, label="Mean", markersize=5, markerstrokewidth=0)
    bin_means[1:2] .= bin_means[3]

    slopeend = (log10(bin_means[end]) - log10(bin_means[end-1])) / (bins[end] - bins[end-1])
    cs = CubicSpline(0.5 * (bins[1:end-1] .+ bins[2:end]), log10.(bin_means), extrapl=[0,], extrapr=[slopeend,])
    rs_spline = range(0, stop=mrs, length=100)

    back_mat = 0.0 * mat
    ci = size(mat, 1) ÷ 2
    cj = size(mat, 2) ÷ 2
    for i = 1:size(mat, 1)
        for j = 1:size(mat, 2)
            r = sqrt((i - ci)^2 + (j - cj)^2)
            back_mat[i,j] = 10^cs(r)
        end
    end


    return back_mat
end

function remove_vertical_gradient_byline(mat)
    for i = 1:size(mat, 1)
#        mat[i,:] .-= minimum(mat[i,:])
        mat[i,:] .-= percentile(mat[i,:], 10)
    end
    return mat
end

function remove_vertical_gradient(mat)
    nbins = 10
    bins = collect(1:round(Int, size(mat, 1) / nbins):size(mat, 1))
    bin_means = 0.0 * bins[1:end-1] 
    for i ∈ 1:length(bins)-1
        idxs = bins[i]:bins[i+1]
        bin_means[i] = percentile(vec(mat[idxs,:]),1)
    end
    slopeend = (bin_means[end-1] - bin_means[end-2]) / (bins[end-1] - bins[end-2])
    slopebegin = (bin_means[2] - bin_means[1]) / (bins[2] - bins[1])
    cs = CubicSpline(0.5 * (bins[1:end-1] .+ bins[2:end]), bin_means, 
         extrapl=[slopebegin,], extrapr=[slopeend,])
    for i = 1:size(mat, 1)
        mat[i,:] .-= cs(i)
    end
    return mat
end

path = "/Users/shaviv/Desktop/series-1"
path = "/Users/shaviv/Desktop/series-4"

files = glob("*.JPG", "$path")

images = [load(file) for file in files[1:end]];

stacked = stack_images(images);

stacked.offsets

rngi = 250:4000-200
rngj = 200:6000-200


#histogram(stacked.red[:], bins=100, label="Red", alpha=0.5, c=:red)
#histogram!(stacked.green[:], bins=100, label="Green", alpha=0.5, c=:green)
#histogram!(stacked.blue[:], bins=100, label="Blue", alpha=0.5, c=:blue)

Gray.(10.0 * stacked.red[rngi, rngj])

fac = 10.0
map(p -> RGB(fac*p[1], fac*p[2], fac*p[3]), zip(stacked.red, stacked.green, stacked.blue))

@time back_red = radial_background(stacked.red[rngi, rngj]);

@time back_green = radial_background(stacked.green[rngi, rngj]);

@time back_blue = radial_background(stacked.blue[rngi, rngj]);



red_corr =  (stacked.red[rngi,rngj] - back_red)[1:end,500:end-1000];
green_corr = (stacked.green[rngi,rngj] - back_green)[1:end,500:end-1000];
blue_corr = (stacked.blue[rngi,rngj] - back_blue)[1:end,500:end-1000];

#red_corr = remove_vertical_gradient_byline(red_corr);
#green_corr = remove_vertical_gradient_byline(green_corr);
#blue_corr = remove_vertical_gradient_byline(blue_corr);

red_corr = remove_vertical_gradient(red_corr);
green_corr = remove_vertical_gradient(green_corr);
blue_corr = remove_vertical_gradient(blue_corr);

fun2(x) = x < 0.0 ? 0.0 : tanh(40*x^1.0)
colimg = map(p -> RGB(fun2(p[1]), fun2(p[2]), fun2(p[3])), zip(red_corr, green_corr, blue_corr))

hsvimg = HSV.(colimg)
channels = channelview(float.(hsvimg));
sat_img = channels[2,:,:];

mean_red =  10.0^mean(log10.(red_corr .+ 0.05))-0.05
mean_green = 10.0^mean(log10.(green_corr .+ 0.05))-0.05
mean_blue = 10.0^mean(log10.(blue_corr .+ 0.05))-0.05

function colorize(r,g,b,s;
    factor = 5.0,
    offset = 0.0004,
    γ = 0.5)
#    fun(x) = x < offset ? 0.0 : tanh(factor*(x-offset)^γ)
    fun(x) = x < offset ? 0.0 : 0.5*tanh(factor*(x-offset)^γ) + 0.5*tanh(factor*(x-offset)^γ /2 )
    if s < 0.1
        R, G, B = N0f16.([fun(r), fun(g), fun(b)])
    else 
        mv = fun(mean([r,g,b])*1.5 - 0.5*maximum([r,g,b]))
        R, G, B = N0f16.([mv , mv, mv])
    end
    return RGB(R,G,B)
end 

@time colimg = Gray.(map((r,g,b,s) -> colorize(r,g,b,s;     
        factor = 25.0, offset = 0.002, γ = 0.75), 
        red_corr, green_corr, blue_corr, sat_img))

imginvert = 1.0 .- colimg

save("comet-TA-3.png", colimg)

using ImageFiltering

filtered_image = imfilter(colimg, Kernel.gaussian(5))
save("comet-TA_blur.png", filtered_image)
