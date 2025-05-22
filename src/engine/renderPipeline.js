export class RenderPipelineBuilder {
    constructor(device) {
        this.device = device;
        // Initialize with common defaults, potentially matching your project's typical setup
        this.descriptor = {
            vertex: {
                entryPoint: "vs_main",
                buffers: []
            },
            fragment: {
                entryPoint: "fs_main",
                targets: []
            },
            primitive: {
                topology: "triangle-list",
                cullMode: "none",    // Based on your previous context
                frontFace: "cw",     // Based on your previous context
            },
            multisample: {
                count: 4,            // Assuming 4x MSAA is common for you
            },
            // depthStencil will be added if setDepthStencil is called with a format
        };
    }

    setPipelineLayout(layout) {
        this.descriptor.layout = layout;
        return this;
    }

    // Use this if vertex and fragment shaders are in the same module
    setShaderModule(shaderModule, vertexEntryPoint = "vs_main", fragmentEntryPoint = "fs_main") {
        this.descriptor.vertex.module = shaderModule;
        this.descriptor.vertex.entryPoint = vertexEntryPoint;
        this.descriptor.fragment.module = shaderModule;
        this.descriptor.fragment.entryPoint = fragmentEntryPoint;
        return this;
    }

    // Optionally, allow setting vertex and fragment shaders from different modules
    setVertexShader(module, entryPoint = "vs_main") {
        this.descriptor.vertex.module = module;
        this.descriptor.vertex.entryPoint = entryPoint;
        return this;
    }

    setFragmentShader(module, entryPoint = "fs_main") {
        this.descriptor.fragment.module = module;
        this.descriptor.fragment.entryPoint = entryPoint;
        return this;
    }

    setVertexBuffers(bufferLayouts) { // Expects an array of GPUVertexBufferLayout
        this.descriptor.vertex.buffers = bufferLayouts;
        return this;
    }

    setTargetFormats(formats) { // Expects an array of GPUTextureFormat strings
        this.descriptor.fragment.targets = formats.map(format => ({ format }));
        return this;
    }

    setDepthStencil(format, depthWriteEnabled = true, depthCompare = "less") {
        if (format) {
            this.descriptor.depthStencil = {
                format,
                depthWriteEnabled,
                depthCompare,
            };
        } else {
            delete this.descriptor.depthStencil;
        }
        return this;
    }

    setPrimitive(topology = "triangle-list", cullMode = "none", frontFace = "cw") {
        this.descriptor.primitive = { topology, cullMode, frontFace };
        return this;
    }

    setMultisample(count = 4) { // Defaulting to 4 as per your MSAA setup
        this.descriptor.multisample.count = count;
        return this;
    }

    build() {
        // Basic validation
        if (!this.descriptor.layout) throw new Error("Pipeline layout must be set using .setPipelineLayout().");
        if (!this.descriptor.vertex.module) throw new Error("Vertex shader module must be set.");
        if (!this.descriptor.fragment.module) throw new Error("Fragment shader module must be set.");
        if (this.descriptor.fragment.targets.length === 0) throw new Error("At least one target format must be set using .setTargetFormats().");
        if (this.descriptor.vertex.buffers.length === 0) console.warn("No vertex buffers specified. This is valid if vertices are generated in the shader.");

        return this.device.createRenderPipeline(this.descriptor);
    }
}