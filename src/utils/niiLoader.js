import * as nifti from 'nifti-reader-js';

export default async function loadNiftiFile(filePath) {

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
    
    console.log('NIfTI Header:', header);
    console.log('Image dimensions:', header.dims);
    console.log('Data type:', header.datatypeCode);
    console.log('Image data:', image);
  }
}