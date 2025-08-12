
import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib


# Load with nibabel
im = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
print('Stored dtype:', im.header.get_data_dtype())
# Perfect for visualisation
vol = im.get_fdata(dtype=np.float32)
print('Volume shape:', vol.shape, 'dtype:', vol.dtype)
print('Min. value:', vol.min())
print('Max. value:', vol.max())

# Plot the grayscale image
mid = vol.shape[2] // 2
front = vol.shape[0] // 2
plt.imshow(vol[:, :, mid], cmap='gray', vmin=vol.min(), vmax=vol.max())
plt.axis('off')
plt.title('Middle slice')
plt.show()