import Engine from './engine/engine.js';
import { RenderPipelineBuilder } from './engine/renderPipeline.js';
import Helpers from './utils/helpers.js';
import triangleShaderCode from './shaders/triangle.wgsl?raw'; 

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;

  // Load a NIfTI file
  const {header, voxelData} = await Helpers.loadNiftiFile('/sub-01/anat/sub-01_T1w.nii.gz'); 
  const [numDims, width, height, depth] = header.dims; 
  const adjustedData = Helpers.pad(voxelData, width, height, depth);

  const volumeTexture = device.createTexture({
    size: [width, height, depth], 
    format: 'r16uint', 
    usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST, 
    dimension: '3d'
  }); 

  device.queue.writeTexture(
    { texture: volumeTexture },
    adjustedData.paddedData, 
    { offset: 0, bytesPerRow:adjustedData.alignedBytesPerRow, rowsPerImage: height }, 
    [width, height, depth]
  ); 

  console.log("This is the volume texture", volumeTexture);
  
  const shaderModule = device.createShaderModule({
    code: triangleShaderCode
  })

  const pipelineBuilder = new RenderPipelineBuilder(device);
  const renderPipeline = pipelineBuilder
    .setPipelineLayout(device.createPipelineLayout({ bindGroupLayouts: [] }))
    .setShaderModule(shaderModule)
    .setVertexBuffers([bufferLayout])
    .setTargetFormats([engine.canvasFormat])
    .setPrimitive("triangle-list")
    .build()
  const commandBuffer = engine.encodeRenderPass(3, renderPipeline, vertexBuffer);
  await engine.submitCommand(commandBuffer);
}

webgpu(); 
