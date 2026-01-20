import nibabel as nib
import numpy as np
import imageio
import scipy.ndimage as ndi
import os

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
        norm_edges = ((edges - edges.min()) / (edges.ptp()) * 255).astype(np.uint8)
        # Save as PNG
        imageio.imwrite(os.path.join(output_folder, f'slice_{i:03d}_edges.png'), norm_edges)

# Example usage:
# generate_edge_map('public/sub-002_T1w.nii.gz', 'output/sobel_edges')