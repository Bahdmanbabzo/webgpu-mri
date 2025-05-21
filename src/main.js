import Engine from './engine/engine.js';

export default async function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = await Engine.initialize(canvas);
  const commandBuffer = engine.encodeRenderPass();
  await engine.submitCommand(commandBuffer);
}

webgpu(); 
