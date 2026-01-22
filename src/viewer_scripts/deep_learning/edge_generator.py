import nibabel as nib
import numpy as np
import imageio
import scipy.ndimage as ndi
import os

def normalize_image(image, min_intensity, intensity_range, slice_index=None):
    """
    Normalizes an image to the 0-255 scale based on given intensity bounds.

    Args:
        image (numpy.ndarray): Input image to be normalized.
        min_intensity (float): Minimum intensity value for normalization.
        intensity_range (float): Range of intensity values (max - min) for normalization.
        slice_index (int, optional): Index of the slice for warning messages.

    Returns:
        numpy.ndarray: Normalized image as uint8.
    """
    if intensity_range == 0:
        if slice_index is not None:
            print(f"Warning: All the values in slice {slice_index} are the same. Returning a zeroed image.")
        else:
            print("Warning: All the values in the image are the same. Returning a zeroed image.")
        return np.zeros_like(image, dtype=np.uint8)
    normalized_image = ((image - min_intensity) / intensity_range * 255).astype(np.uint8)
    return normalized_image

def generate_edge_map(input_nii_path, output_folder):
    # Load NIfTI volume
    img = nib.load(input_nii_path)
    data = img.get_fdata()

    # Create output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)

    # Loop through each slice and save Sobel edge map as PNG
    for i in range(data.shape[2]):
        slice_img = data[:, :, i]
        # Apply Sobel filter
        sobel_x = ndi.sobel(slice_img, axis=0)
        sobel_y = ndi.sobel(slice_img, axis=1)
        edges = np.hypot(sobel_x, sobel_y)
        # Normalize to 0-255 for PNG
        norm_edges = normalize_image(edges, edges.min(), np.ptp(edges), slice_index=i)
        # Save as PNG
        imageio.imwrite(os.path.join(output_folder, f'slice_{i:03d}_edges.png'), norm_edges)

def generate_training_data(input_nii_path, output_folder):
    # Load NIfTI volume
    img = nib.load(input_nii_path)
    data = img.get_fdata()

    # Create output folder if it doesn't exist
    os.makedirs(output_folder, exist_ok=True)

    # Loop through each slice and save original as PNG, skip zeroed slices
    for i in range(data.shape[2]):
        slice_img = data[:, :, i]
        norm_slice = normalize_image(slice_img, slice_img.min(), np.ptp(slice_img), slice_index=i)
        if np.all(norm_slice == 0):
            print(f"Skipping slice {i}: all values are zero after normalization.")
            continue  # Skip saving this slice
        imageio.imwrite(os.path.join(output_folder, f'slice_{i:03d}_original.png'), norm_slice)

# Example usage:
# generate_edge_map('public/sub-002_T1w.nii.gz', 'public/train/edges')
generate_training_data('public/sub-003_T1w.nii.gz', 'public/train/predict/preds_03')