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

fn sampleVolume(coord: vec3u) -> f32 {
    let rawValue = textureLoad(volumeTexture, coord, 0).r; 
    let normalised = f32(rawValue) * params.invMax; 
    return normalised;
}

fn computeGradient(coord: vec3u) -> vec3f {
    // f(x) = x^2
    let dx = sampleVolume(coord + vec3u(1u, 0u, 0u)) - sampleVolume(coord - vec3u(1u, 0u, 0u));
    let dy = sampleVolume(coord + vec3u(0u, 1u, 0u)) - sampleVolume(coord - vec3u(0u, 1u, 0u));
    let dz = sampleVolume(coord + vec3u(0u, 0u, 1u)) - sampleVolume(coord - vec3u(0u, 0u, 1u));
    let stepSize: f32 = 2.0; // f(x) = x^2
    let scale: f32 = 1.0 / stepSize; // Stepsize replica for vector use. 
    return vec3f(dx, dy, dz) * scale; 
}
@fragment 
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let dims = textureDimensions(volumeTexture);
    let coords = vec3u(
        u32(clamp(input.uv.x * f32(dims.x), 0.0, f32(dims.x - 1u))), // Max = 255, not 256
        u32(clamp(input.uv.y * f32(dims.y), 0.0, f32(dims.y - 1u))), 
        u32(f32(dims.z) * 0.4)
    );

    let gradient = computeGradient(coords);
    let gradientMagnitude = length(gradient);
    return vec4f(gradientMagnitude, gradientMagnitude, gradientMagnitude, 1.0);
}