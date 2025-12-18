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

        const device = await adapter.requestDevice({
            requiredFeatures: ["float32-filterable"]
        });
        return device;
    }

    encodeRenderPass(drawCount, pipeLine, vertexBuffer, bindGroup = null) {
        const commandEncoder = this.device.createCommandEncoder();
        const renderPassDescriptor = {
            colorAttachments: [{
                view: this.canvasContext.getCurrentTexture().createView(),
                clearValue: [1.0, 0.0, 0.0, 1.0],
                loadOp: 'clear',
                storeOp: 'store',
            }],
        };

        const renderPass = commandEncoder.beginRenderPass(renderPassDescriptor);
        bindGroup ? renderPass.setBindGroup(0, bindGroup) : null;
        renderPass.setPipeline(pipeLine);
        renderPass.setVertexBuffer(0, vertexBuffer);
        renderPass.draw(drawCount, 1, 0, 0);
        renderPass.end(); 

        return commandEncoder.finish();
    }

    async submitCommand(commandBuffer) {
        this.device.queue.submit([commandBuffer]);
    }
}