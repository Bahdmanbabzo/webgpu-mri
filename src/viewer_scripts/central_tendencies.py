import numpy as np 
import matplotlib.pyplot as plt
import nibabel as nib
import scipy.ndimage as ndi

IM = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
VOL = IM.get_fdata(dtype=np.float32)

slice_idx = VOL.shape[2] // 2
im_slice = VOL[:, :, slice_idx]

def compute_local_stats(image, window_size = 3): 
    """
    Calculates local variance and standard deviation using the computational formula
    Var(X) = Mean(X^2) - (Mean(X))^2
    """
    mean_sq = ndi.uniform_filter(image**2, size=window_size)
    sq_mean = ndi.uniform_filter(image, size= window_size) ** 2
    variance = np.maximum(mean_sq - sq_mean, 0)
    std_dev = np.sqrt(variance)
    return variance, std_dev


# print('Loaded volume', VOL.shape)
# print(VOL.min(), VOL.max(), VOL.mean())
# print (IM.header)
# IM.orthoview()
# plt.show()
var, std = compute_local_stats(im_slice)
fig, axes = plt.subplots(1, 3, figsize=(10, 5))
axes[0].imshow(im_slice, cmap='gray')
axes[0].set_title('Original Slice')
axes[1].imshow(var, cmap = "hot")
axes[1].set_title('Local Variance')
axes[2].imshow(std, cmap = "viridis")
axes[2].set_title('Local Standard Deviation')
plt.tight_layout()
plt.show()
print('Local variance range:', var.min(), var.max())