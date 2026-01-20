import nibabel as nib
import matplotlib.pyplot as plt
import numpy as np

# Load NIfTI image
nii_path = 'public/sub-002_T1w.nii.gz'
img = nib.load(nii_path)
data = img.get_fdata()

print('Sample Slices from NIfTI Image')

# Display 9 evenly spaced slices from the volume
num_slices = data.shape[2]
print(data.shape)
indices = np.linspace(0, num_slices - 1, 9, dtype=int)
print(len(indices))
print(indices)

plt.figure(figsize=(5,5))
for i, idx in enumerate(indices):
    plt.subplot(3, 3, i + 1)
    plt.imshow(data[:, :, idx], cmap='gray')
    plt.axis('off')

plt.tight_layout()
plt.show()