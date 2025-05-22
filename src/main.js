import Engine from './engine/engine.js';

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const device = await Engine.getGPUDevice();
  console.log("this is the device", device);
  const engine  = await Engine.initialize(canvas);
  const commandBuffer = engine.encodeRenderPass();
  await engine.submitCommand(commandBuffer);
}

webgpu(); 
