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