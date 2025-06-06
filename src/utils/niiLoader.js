import * as nifti from 'nifti-reader-js';

export async function loadNiftiFile(filePath) {

    let voxelData; 

    const response = await fetch(filePath); 
    if (!response.ok) {
        throw new Error(`Failed to fetch NIfTI file: ${response.statusText}`);
    }

    let arrayBuffer = await response.arrayBuffer();

    if (nifti.isCompressed(arrayBuffer)) {
        const decompressed = nifti.decompress(arrayBuffer);
        console.log('Decompressed NIfTI data');
        arrayBuffer = decompressed;
    }

    if (nifti.isNIFTI(arrayBuffer)) {
    const header = nifti.readHeader(arrayBuffer);
    const image = nifti.readImage(header, arrayBuffer);
    
    // Make typed array depending on dataType
    switch(header.datatypeCode) {
        case 2: 
            voxelData = new Uint8Array(image);
            break;
        case 4:
            voxelData = new Int16Array(image);
            break;
        case 8:
            voxelData = new Int32Array(image);
            break;
        case 16:
            voxelData = new Float32Array(image);
            break;
    }
    console.log('NIfTI Header:', header);
    console.log('Image dimensions:', header.dims);
    console.log('Data type:', header.datatypeCode);
    console.log('Image data:', image);
    console.log('Voxel data:', voxelData);

    return {
        header: header,
        image: image,
        voxelData: voxelData
    }
  }
}

export function processNiftiData(header) {
    const dims = header.dims; 
    const pixelDims = header.pixDims; 

    const voxelSpacing = { 
        x: pixelDims[1],
        y: pixelDims[2],
        z: pixelDims[3]
    }; 

    const physicalSize = { 
        x: dims[1] * voxelSpacing.x,
        y: dims[2] * voxelSpacing.y,
        z: dims[3] * voxelSpacing.z
    }

    return {
        voxelSpacing: voxelSpacing,
        physicalSize: physicalSize,
        isIsotropic: voxelSpacing.x === voxelSpacing.y && voxelSpacing.y === voxelSpacing.z,
    }
}