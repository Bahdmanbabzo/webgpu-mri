import Engine from './engine/engine.js';
import { RenderPipelineBuilder } from './engine/renderPipeline.js';
import Helpers from './utils/helpers.js';
import raytracerShaderCode from './shaders/raytracer.wgsl?raw'; 

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;

  // Set up canvas dimensions to match window dimensions
  // const devicePixelRatio = window.devicePixelRatio || 1;
  // canvas.width = window.innerWidth * devicePixelRatio;
  // canvas.height = window.innerHeight * devicePixelRatio ;
  // canvas.style.width = `${window.innerWidth}px`;
  // canvas.style.height = `${window.innerHeight}px`;

  // Load a NIfTI file
  const {header, voxelData} = await Helpers.loadNiftiFile('/sub-001/anat/sub-001_T1w.nii.gz'); 
  Helpers.processNiftiData(header);
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

  const maxIntensity = voxelData.reduce((max, v) => Math.max(max, v), 0);
  const invMax = 1.0 / maxIntensity; 
  console.log('this is the max intensity', maxIntensity);
  const fov = 45.0; // Field of view in degrees

  const params = new Float32Array([invMax, fov]);
  const paramBuffer = device.createBuffer({
    size: params.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });
  device.queue.writeBuffer(paramBuffer, 0, params);

  const shaderModule = device.createShaderModule({
    code: raytracerShaderCode
  })

  const bufferLayout = {
    arrayStride: 2 * 4, 
    attributes: [
      {
        shaderLocation:0, 
        offset: 0, 
        format: 'float32x2'
      }
    ]
  }; 

  // Fullscreen quad
  const vertexData = new Float32Array([
      // x,    y
      -1.0, -1.0, 
      1.0, -1.0, 
      -1.0,  1.0, 
      -1.0,  1.0, 
      1.0, -1.0, 
      1.0,  1.0 
    ]);
  const vertexBuffer = device.createBuffer({
    size: vertexData.byteLength, 
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST
  }); 
  device.queue.writeBuffer(vertexBuffer, 0, vertexData); 
  const pipelineBuilder = new RenderPipelineBuilder(device);
  const renderPipeline = pipelineBuilder
    .setShaderModule(shaderModule)
    .setVertexBuffers([bufferLayout])
    .setTargetFormats([engine.canvasFormat])
    .setPrimitive("triangle-list")
    .build()

  const bindGroupLayouts = renderPipeline.getBindGroupLayout(0); 
  const bindGroup = device.createBindGroup({
    layout: bindGroupLayouts, 
    entries: [
      { binding: 0, resource: volumeTexture.createView()}, 
      { binding: 1, resource: paramBuffer }
    ]
  })
  const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
  await engine.submitCommand(commandBuffer);
}

webgpu(); 
