import Engine from './engine/engine.js';
import { RenderPipelineBuilder } from './engine/renderPipeline.js';
import Helpers from './utils/helpers.js';
import raytracerShaderCode from './shaders/raytracer.wgsl?raw'; 
import preprocessShaderCode from './shaders/preprocess.wgsl?raw';
import { mat4 } from 'wgpu-matrix';
import { GUI } from 'dat.gui'; 
import Stats from './utils/stats.js';

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const device = engine.device;
  const stats = new Stats();

  // Load a NIfTI file
  const {header, voxelData} = await Helpers.loadNiftiFile('/sub-001/anat/sub-001_T1w.nii.gz'); 
  Helpers.processNiftiData(header);
  const [_, width, height, depth] = header.dims; 
  // Cast back to float32 to allow texture to use trilinear sampling
  const voxelDataArray = new Float32Array(voxelData);
  const adjustedData = Helpers.pad(voxelDataArray, width, height, depth);

  const volumeTexture = device.createTexture({
    size: [width, height, depth], 
    format: 'r32float', 
    usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST, 
    dimension: '3d'
  }); 

  device.queue.writeTexture(
    { texture: volumeTexture },
    adjustedData.paddedData, 
    { offset: 0, bytesPerRow: adjustedData.alignedBytesPerRow , rowsPerImage: height }, 
    [width, height, depth]
  ); 

  // --- COMPUTE SHADER PREPROCESSING ---
  const processedTexture = device.createTexture({
    size: [width, height, depth],
    format: 'rgba16float',
    usage: GPUTextureUsage.STORAGE_BINDING | GPUTextureUsage.TEXTURE_BINDING,
    dimension: '3d'
  });

  const preprocessModule = device.createShaderModule({
    code: preprocessShaderCode
  });

  const computePipeline = device.createComputePipeline({
    layout: 'auto',
    compute: {
      module: preprocessModule,
      entryPoint: 'main',
    },
  });

  const computeParamsBuffer = device.createBuffer({
    size: 4 * 4, // vec4f
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  device.queue.writeBuffer(computeParamsBuffer, 0, new Float32Array([width, height, depth, 0]));

  const computeBindGroup = device.createBindGroup({
    layout: computePipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: volumeTexture.createView() },
      { binding: 1, resource: processedTexture.createView() },
      { binding: 2, resource: { buffer: computeParamsBuffer } },
    ],
  });

  const commandEncoder = device.createCommandEncoder();
  const passEncoder = commandEncoder.beginComputePass();
  passEncoder.setPipeline(computePipeline);
  passEncoder.setBindGroup(0, computeBindGroup);
  passEncoder.dispatchWorkgroups(Math.ceil(width / 8), Math.ceil(height / 8), Math.ceil(depth / 4));
  passEncoder.end();
  device.queue.submit([commandEncoder.finish()]);
  // ------------------------------------

  const sampler = device.createSampler({
    magFilter: 'linear',
    minFilter: 'linear',
    mipmapFilter: 'linear',
    addressModeU: 'clamp-to-edge',
    addressModeV: 'clamp-to-edge',
    addressModeW: 'clamp-to-edge'
  }); 

  let camera = {
    fov: 20 * Math.PI / 180.0, 
    eye: [0.0, 0.0, -2.0],
    target: [0.0, 0.0, 0.0],
    up: [0.0, 1.0, 0.0],
    aspect: canvas.width / canvas.height, 
    near: 0.1, 
    far: 1000.0
  }
  let alphaValues = {
    csf: 0.1,
    gray: 0.3,
    white: 0.5, 
    convexEdges: 0.8,
    concaveEdges: 0.8
  };
  let volumeState = {
    rotation: [0.0, 0.0, 0.0], 
  }
  const gui = new GUI();
  gui.add(camera, 'fov', 10 * Math.PI / 180.0, 90 * Math.PI / 180.0).name('FOV (radians)');

  const eyeFolder = gui.addFolder('Camera Eye');
  eyeFolder.add(camera.eye, '0', -5.0, 5.0).name('Eye X');
  eyeFolder.add(camera.eye, '1', -5.0, 5.0).name('Eye Y');
  eyeFolder.add(camera.eye, '2', -5.0, 5.0).name('Eye Z');
  eyeFolder.open();

  const alphaValuesFolder = gui.addFolder('Tissue Alpha Values');
  alphaValuesFolder.add(alphaValues, 'csf', 0.01, 1.0).name('CSF');
  alphaValuesFolder.add(alphaValues, 'gray', 0.0, 1.0).name('Gray Matter');
  alphaValuesFolder.add(alphaValues, 'white', 0.0, 1.0).name('White Matter');
  alphaValuesFolder.add(alphaValues, 'convexEdges', 0.0, 1.0).name('Convex Edges');
  alphaValuesFolder.add(alphaValues, 'concaveEdges', 0.0, 1.0).name('Concave Edges');
  alphaValuesFolder.open();

  const volumeStateFolder = gui.addFolder('Volume Rotation');
  volumeStateFolder.add(volumeState.rotation, '0', 0.0, 2.0 * Math.PI).name('Rotation X');
  volumeStateFolder.add(volumeState.rotation, '1', 0.0, 2.0 * Math.PI).name('Rotation Y');
  volumeStateFolder.add(volumeState.rotation, '2', 0.0, 2.0 * Math.PI).name('Rotation Z');
  volumeStateFolder.open();

  const paramsBuffer = device.createBuffer({
    size: 16 * 4,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });

  const alphaData = new Float32Array([
    alphaValues.csf, 
    alphaValues.gray, 
    alphaValues.white,
    alphaValues.convexEdges,
    alphaValues.concaveEdges
  ]); 
  const alphaBuffer = device.createBuffer({
    size: alphaData.byteLength,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
  });
  device.queue.writeBuffer(alphaBuffer, 0, alphaData);

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
      { binding: 0, resource: processedTexture.createView()}, 
      { binding: 1, resource: sampler },
      { binding: 2, resource: {buffer:paramsBuffer } }, 
      { binding: 3, resource: {buffer:alphaBuffer } },
    ]
  });

  function updateAndRender() {
    const modelMat = mat4.identity();
    mat4.rotateX(modelMat, -Math.PI / 2.0, modelMat);
    mat4.rotateY(modelMat, volumeState.rotation[1], modelMat);
    mat4.rotateZ(modelMat, volumeState.rotation[2], modelMat);
    mat4.rotateX(modelMat, volumeState.rotation[0], modelMat);
    const projectionMat = mat4.perspective(camera.fov, camera.aspect, camera.near, camera.far);
    const viewMat = mat4.lookAt(camera.eye, camera.target, camera.up);
    const modelViewProjMat = mat4.multiply(mat4.multiply(projectionMat, viewMat), modelMat);
    const invMVP = mat4.invert(modelViewProjMat);

    alphaData[0] = alphaValues.csf;
    alphaData[1] = alphaValues.gray;
    alphaData[2] = alphaValues.white;
    alphaData[3] = alphaValues.convexEdges;
    alphaData[4] = alphaValues.concaveEdges;
    device.queue.writeBuffer(alphaBuffer, 0, alphaData);

    device.queue.writeBuffer(paramsBuffer, 0, invMVP);
    const commandBuffer = engine.encodeRenderPass(6, renderPipeline, vertexBuffer, bindGroup);
    engine.submitCommand(commandBuffer);

    stats.update();
    requestAnimationFrame(updateAndRender);
  };
  updateAndRender();
}

webgpu(); 
