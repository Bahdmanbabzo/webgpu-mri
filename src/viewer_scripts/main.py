import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
import scipy.ndimage as ndi

# Load MRI volume
im = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
vol = im.get_fdata(dtype=np.float32)

def detect_horizontal_edges(volume, slice_index=None):
    """
    Detect horizontal edges in a 2D slice of the volume
    
    Args:
        volume: 3D numpy array
        slice_index: which slice to use (default: middle slice)
    """
    if slice_index is None:
        slice_index = volume.shape[2] // 2
    
    # Get 2D slice
    im_slice = volume[:, :, slice_index]
    
    # Set weights to detect horizontal edges (left to right)
    weights = [[-1, 0, 1],
               [-1, 0, 1],
               [-1, 0, 1]]
    
    # Convolve slice with filter weights
    edges = ndi.convolve(im_slice, weights)
    
    # Draw the image in color
    plt.figure(figsize=(10, 8))
    plt.imshow(edges, cmap='seismic', vmin=-150, vmax=150)
    plt.title(f'Horizontal Edges (Left to Right) - Slice {slice_index}')
    plt.axis('off')
    plt.colorbar()
    plt.tight_layout()
    plt.show()
    
    return edges

# Apply mask to exclude low-intensity background
mask = vol > 100
masked_data = vol[mask]

# Compute raw histogram using numpy
counts, bin_edges = np.histogram(vol, bins=256, range=(masked_data.min(), masked_data.max()))

# Compute cumulative distribution function (CDF)
cdf = np.cumsum(counts)
cdf = cdf / cdf[-1]  # Normalize to [0, 1]

# Plot raw histogram and CDF
fig, axes = plt.subplots(2, 1, sharex=True, figsize=(10, 6))

# Histogram (raw counts)
axes[0].bar(bin_edges[:-1], counts, width=np.diff(bin_edges), align='edge', color='steelblue')
axes[0].set_ylabel('Raw Count')
axes[0].set_title('Histogram of Voxel Intensities')
axes[0].set_xticks(np.linspace(0, 1709, num=10))

# CDF
axes[1].plot(bin_edges[:-1], cdf, color='darkorange')
axes[1].set_ylabel('Cumulative Frequency')
axes[1].set_xlabel('Intensity Value')
axes[1].set_title('Cumulative Distribution Function')

# plt.tight_layout()
# plt.show()

# Call the edge detection function
print("Detecting horizontal edges...")
detect_horizontal_edges(vol)