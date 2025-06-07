import * as nifti from 'nifti-reader-js';
export default class Helpers{

    static async loadNiftiFile(filePath) {

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
        console.log("This is the image", image);
        
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
        console.log("This is voxel buffer", voxelData.buffer);
        console.log("this is bytes", voxelData.BYTES_PER_ELEMENT); 
        console.log("This is the header", header);
        return {
            header: header,
            image: image,
            voxelData: voxelData
        }
      }
    }
    
    static processNiftiData(header) {
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
    }; 

    static alignToWebGPU(val, alignment = 256) {
        return Math.floor((val + alignment - 1) / alignment) * alignment;
    }; 

    static pad(voxelData, width, height, depth) {
        const bytesPerPixel = voxelData.BYTES_PER_ELEMENT;
        const paddedWidth = this.alignToWebGPU(width * bytesPerPixel);
        const extraSpace = paddedWidth - (width * bytesPerPixel);

        if (extraSpace === 0) {
            return {
                paddedData: voxelData.buffer,
                alignedBytesPerRow: paddedWidth,
            };
        }

        const totalPaddedSize = paddedWidth * height * depth;
        const paddedArray = new Int16Array(totalPaddedSize); 

        let sourceOffset = 0 ; 
        let paddedOffset = 0; 

        for(let z = 0; z < depth; z++) {
            for (let y = 0; y < height; y++) {
                paddedArray.set(
                    voxelData.subarray(sourceOffset, sourceOffset + (width * bytesPerPixel / 2)),
                    paddedOffset
                ); 
            }

            sourceOffset += width * bytesPerPixel / 2;
            paddedOffset += paddedWidth / bytesPerPixel;
        }

        return {
            paddedData: paddedArray.buffer, 
            alignedBytesPerRow: paddedWidth
        }
    }
   
}