export default class Engine {
    constructor (device, canvasContext, canvasFormat) {
        this.device = device; 
        this.canvasContext = canvasContext;
        this.canvasFormat = canvasFormat;
    }

    static async initialize(canvas) {
        const device = await Engine.getGPUDevice();
        const canvasContext = canvas.getContext("webgpu");
        const canvasFormat = navigator.gpu.getPreferredCanvasFormat();

        canvasContext.configure({
            device: device,
            format: canvasFormat,
        });
        return new Engine(device, canvasContext, canvasFormat);
    }

    static async getGPUDevice() {
        if (!navigator.gpu) {
            throw new Error("WebGPU is not supported in this browser.");
        }

        const adapter = await navigator.gpu.requestAdapter();
        if (!adapter) {
            throw new Error("No GPU adapter found.");
        }

        const device = await adapter.requestDevice();
        return device;
    }

    encodeRenderPass(pipeline, bindGroup, vertexBuffer) {
        const commandEncoder = this.device.createCommandEncoder();
        const renderPassDescriptor = {
            colorAttachments: [{
                view: this.canvasContext.getCurrentTexture().createView(),
                loadValue: [0.0, 0.0, 0.0, 1.0],
                storeOp: 'store',
            }],
        };

        const renderPass = commandEncoder.beginRenderPass(renderPassDescriptor);
        renderPass.setPipeline(pipeline);
        renderPass.setBindGroup(0, bindGroup);
        renderPass.setVertexBuffer(0, vertexBuffer);
        renderPass.draw(3, 1, 0, 0);
        renderPass.end();

        return commandEncoder.finish();
    }

    async submitCommand(commandBuffer) {
        this.device.queue.submit([commandBuffer]);
    }
}