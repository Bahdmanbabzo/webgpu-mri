import numpy as np
import matplotlib.pyplot as plt
import nibabel as nib

# Load MRI volume
im = nib.load('public/sub-001/anat/sub-001_T1w.nii.gz')
vol = im.get_fdata(dtype=np.float32)

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

plt.tight_layout()
plt.show()