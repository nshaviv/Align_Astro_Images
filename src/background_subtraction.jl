

# Estimate the radially dependent background and 
# return an image of this background. This is to remove 
# Vingetting effects in the images
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

# A function to remove the background of each line separately
function remove_vertical_gradient_byline(mat)
    for i = 1:size(mat, 1)
#        mat[i,:] .-= minimum(mat[i,:])
        mat[i,:] .-= percentile(mat[i,:], 10)
    end
    return mat
end

# A function to remove a vertical gradient in the image 
# It fits a low order spline 
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

