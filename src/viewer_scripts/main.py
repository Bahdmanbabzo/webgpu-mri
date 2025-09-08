import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib
import scipy.ndimage as ndi

# Load MRI volume
im = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
vol = im.get_fdata(dtype=np.float32)

def plot_directional_derivatives(volume, slice_index=None):
    """
    Plots a joint histogram (scatter plot) of intensity, gradient magnitude,
    and the second directional derivative along the gradient direction.
    """
    if slice_index is None:
        slice_index = volume.shape[2] // 2

    # Get 2D slice
    im_slice = volume[:, :, slice_index]

    # Compute first derivatives (gradient)
    gx = ndi.sobel(im_slice, axis=0, mode='constant')
    gy = ndi.sobel(im_slice, axis=1, mode='constant')
    gradient = np.stack([gx, gy], axis=-1)
    grad_mag = np.linalg.norm(gradient, axis=-1)

    # Compute normalized gradient direction (avoid division by zero)
    grad_dir = np.zeros_like(gradient)
    nonzero = grad_mag > 1e-5
    grad_dir[nonzero] = gradient[nonzero] / grad_mag[nonzero][..., None]

    # Compute Hessian matrix components
    dxx = ndi.correlate(im_slice, np.array([[1, -2, 1]]), mode='constant')
    dyy = ndi.correlate(im_slice, np.array([[1], [-2], [1]]), mode='constant')
    dxy = ndi.correlate(im_slice, np.array([[1, -1], [-1, 1]]) * 0.25, mode='constant')

    # For each pixel, compute g^T H g / |g|^2 (second directional derivative)
    D2g = np.zeros_like(im_slice)
    for y in range(im_slice.shape[0]):
        for x in range(im_slice.shape[1]):
            g = grad_dir[y, x]
            if np.linalg.norm(g) < 1e-5:
                D2g[y, x] = 0
                continue
            # Hessian at (y, x)
            H = np.array([[dxx[y, x], dxy[y, x]],
                          [dxy[y, x], dyy[y, x]]])
            D2g[y, x] = g @ H @ g

    # Flatten arrays for plotting
    intensities = im_slice.flatten()
    grad_mags = grad_mag.flatten()
    D2g_flat = D2g.flatten()

    # Mask out background
    mask = grad_mags > 1e-3
    intensities = intensities[mask]
    grad_mags = grad_mags[mask]
    D2g_flat = D2g_flat[mask]

    # Scatter plot: Intensity vs Gradient Magnitude, colored by D2g
    plt.figure(figsize=(10, 7))
    sc = plt.scatter(intensities, grad_mags, c=D2g_flat, cmap='coolwarm', s=2, alpha=0.5)
    plt.xlabel('Intensity')
    plt.ylabel('Gradient Magnitude')
    plt.title('Joint Histogram: Intensity vs Gradient Magnitude\nColor = 2nd Directional Derivative')
    plt.colorbar(sc, label='Second Directional Derivative')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.show()

# Add this at the end of your main.py to run:
print("\n" + "="*80)
print("DIRECTIONAL DERIVATIVE SCATTER PLOT")
print("="*80)
plot_directional_derivatives(vol)