import Engine from './engine/engine.js';
import { RenderPipelineBuilder } from './engine/renderPipeline.js';
import triangleShaderCode from './shaders/triangle.wgsl?raw'
import {loadNiftiFile, processNiftiData} from './utils/niiLoader.js';

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;

  // Load a NIfTI file
  const rawData = await loadNiftiFile('/sub-01/anat/sub-01_T1w.nii.gz'); 
  const headerProcessed = processNiftiData(rawData.header);
  console.log('Processed NIfTI Data:', headerProcessed);
  
  const triangleData = new Float32Array([
    0.0,  0.5, 0.0, // Vertex 1
   -0.5, -0.5, 0.0, // Vertex 2
    0.5, -0.5, 0.0  // Vertex 3
  ]);
  const vertexBuffer = device.createBuffer({
    label: "Dummy buffer", 
    size: triangleData.byteLength,
    usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
  }); 
  device.queue.writeBuffer(vertexBuffer, 0, triangleData);
  const bufferLayout = {
    arrayStride: 12, 
    attributes: [
      { format: "float32x3", offset: 0, shaderLocation: 0 },
    ]
  };
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
