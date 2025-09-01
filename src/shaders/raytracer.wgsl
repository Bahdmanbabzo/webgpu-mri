struct VertexOutput {
    @builtin(position) position: vec4f, 
    @location(0) uv: vec2f
}

struct Params {
    invMax: f32 
}

@group(0) @binding(0) var volumeTexture: texture_3d<u32>; 
@group(0) @binding(1) var<uniform> params: Params; 

@vertex
fn vs_main(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5; // Convert [-1,1] to [0,1]
    return output;
}

@fragment 
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let dims = textureDimensions(volumeTexture);
    let coords = vec3u(
        u32(clamp(input.uv.x * f32(dims.x), 0.0, f32(dims.x - 1u))), // Max = 255, not 256
        u32(clamp(input.uv.y * f32(dims.y), 0.0, f32(dims.y - 1u))), 
        u32(f32(dims.z) * 0.4)
    );

    let rawValue = textureLoad(volumeTexture, coords, 0).r;
    let normalized = f32(rawValue) * params.invMax;
    
    return vec4f(normalized, normalized, normalized, 1.0);
}