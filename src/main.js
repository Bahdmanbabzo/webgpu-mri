import Engine from './engine/engine.js';
import { RenderPipelineBuilder } from './engine/renderPipeline.js';
import Helpers from './utils/helpers.js';
import raytracerShaderCode from './shaders/raytracer.wgsl?raw'; 
import { vec3, mat4 } from 'wgpu-matrix'; 

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

  const fov = 45 * Math.PI / 180.0;
  const aspect = canvas.width / canvas.height;
  const near = 0.1; 
  const far = 1000.0; 
  const projectionMat = mat4.perspective(fov, aspect, near, far); 
  const eye = [0.0, 0.0, -2.0];
  const target = [0.0, 0.0, 0.0];
  const up = [0.0, 1.0, 0.0];
  const viewMat = mat4.lookAt(eye, target, up);
  const viewProjMat = mat4.multiply(projectionMat, viewMat); 
  const invViewProjMat = mat4.invert(viewProjMat);
  // const params = new Float32Array([invMax, fov]);
  const cameraBuffer = device.createBuffer({
    size: viewProjMat.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });
  device.queue.writeBuffer(cameraBuffer, 0, invViewProjMat);

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
      { binding: 1, resource: cameraBuffer }
    ]
  })
  const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
  await engine.submitCommand(commandBuffer);
}

webgpu(); 
