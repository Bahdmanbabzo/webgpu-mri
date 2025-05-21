import Engine from './engine/engine.js';

export default function webgpu() {
  const canvas = document.querySelector('canvas');
  const engine  = Engine.initialize(canvas);
}

webgpu(); 
