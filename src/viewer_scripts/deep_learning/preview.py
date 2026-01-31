import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np

# Load NIfTI image
nii_path = 'public/sub-002_T1w.nii.gz'
img = nib.load(nii_path)
data = img.get_fdata()

print('Sample Slices from NIfTI Image')

def show_sample_slices(data, num_samples=9):
    """
    Display `num_samples` evenly spaced slices from a 3D volume.
    """
    num_slices = data.shape[2]
    print(data.shape)
    indices = np.linspace(0, num_slices - 1, num_samples, dtype=int)
    print(len(indices))
    print(indices)

    plt.figure(figsize=(5, 5))
    for i, idx in enumerate(indices):
        plt.subplot(3, 3, i + 1)
        plt.imshow(data[:, :, idx], cmap='gray')
        plt.axis('off')

    plt.tight_layout()
    plt.show()

def plot_intensity_histogram(data, bins=100):
    """
    Plots a histogram of pixel intensities for the given 3D image data.
    """
    plt.figure(figsize=(6,4))
    plt.hist(data.flatten(), bins=bins, color='blue', alpha=0.7)
    plt.xlabel('Intensity')
    plt.ylabel('Pixel Count')
    plt.title('Pixel Intensity Histogram')
    plt.tight_layout()
    plt.show()
def plot_skull_brain_masks(im, brain_thresh=45):
    """
    Create and plot skull and brain masks from a 2D image slice using intensity thresholds.
    Skull mask: pixels >= skull_thresh
    Brain mask: pixels >= brain_thresh and < skull_thresh
    """
    mask_brain = im <= brain_thresh

    fig, axes = plt.subplots(1, 2, figsize=(12, 4))
    axes[0].imshow(mask_brain, cmap='gray')
    axes[0].set_title('Brain Mask')
    axes[0].axis('off')
    axes[1].imshow(im, cmap='gray')
    axes[1].set_title('Original Image')
    plt.tight_layout()
    plt.show()

# Call the function
# show_sample_slices(data)
# plot_intensity_histogram(data)
plot_skull_brain_masks(data[120, :, :], 200)