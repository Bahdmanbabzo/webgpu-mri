struct VertexOutput {
    @builtin(position) position: vec4f, 
    @location(0) uv: vec2f  // Changed from texCoords to uv
}

struct Params {
    width: f32, 
    height: f32, 
    depth: f32, 
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
    // Sample the volume texture
    let x = u32(clamp(floor(input.uv.x * params.width), 0.0, params.width - 1.0));
    let y = u32(clamp(floor(input.uv.y * params.height), 0.0, params.height - 1.0));
    let z = u32(params.depth * 0.4); // Middle slice
    
    let rawValue = textureLoad(volumeTexture, vec3u(x, y, z), 0).r;
    let normalized = f32(rawValue) * params.invMax;
    
    return vec4f(normalized, normalized, normalized, 1.0);
}