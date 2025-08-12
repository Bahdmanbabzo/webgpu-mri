
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib


# Load with nibabel
im = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
print('Data type:', im.dtype)
print('Min. value:', im.min())
print('Max value:', im.max())

# Plot the grayscale image
plt.imshow(im, cmap='gray', vmin=0, vmax=255)
plt.colorbar()