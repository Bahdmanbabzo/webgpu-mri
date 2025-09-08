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
    return f32(rawValue);
}

fn mapToColor(intensity: f32, gradient: f32, curvature: f32) -> vec4f {
    var color: vec4f;

    let rawIntensity = intensity; // Assume max ~1709

    // OUTSIDE anatomical range → grayscale
    if (rawIntensity < 150.0 || rawIntensity > 1200.0) {
        color = vec4f(intensity * 0.4, intensity * 0.4, intensity * 0.4, 0.2); // Dim gray
    }

    // CSF or ventricles (150–300) with low gradient
    else if (rawIntensity < 300.0 && gradient < 200.0) {
        color = vec4f(0.9, 0.6, 1.0, 0.7); // Soft blue
    }

    // Gray matter (300–600) with soft transitions
    else if (rawIntensity >= 300.0 && rawIntensity < 600.0 && gradient < 300.0) {
        color = vec4f(0.0, 1.0, 0.0, 1.0); // Mint green
    }

    // White matter (600–900) with moderate gradient
    else if (rawIntensity >= 600.0 && rawIntensity < 900.0 && gradient < 400.0) {
        color = vec4f(1.0, 0., 0.0, 1.0); // Pale yellow
    }

    // High gradient (400–700) → tissue boundaries (e.g., corpus callosum edges)
    else if (gradient >= 400.0 && gradient < 700.0) {
        color = vec4f(1.0, 0.5, 0.0, 1.0); // Orange
    }

    // Very high gradient (≥700) → sharp transitions or pathology
    else if (gradient >= 700.0) {
        // Use curvature to differentiate:
        if (curvature < -300.0) {
            color = vec4f(0.0, 0.0, 1.0, 1.0); // Deep blue → concave (ventricle edges, sulci)
        } else if (curvature > 300.0) {
            color = vec4f(1.0, 0.0, 0.0, 1.0); // Red → convex (lesions, gyri)
        } else {
            color = vec4f(1.0, 1.0, 0.0, 1.0); // Yellow → neutral sharp edge
        }
    }

    // Default fallback
    else {
        color = vec4f(1.0, 1.0, 1.0, 0.5); // Soft white
    }

    return color;
}
fn computeFirstDerivative(coord: vec3u, textureDims: vec3u) -> vec3f {
    var dx: f32;
    var dy: f32; 
    var dz: f32;
    // f(x) = x^2
    if (coord.x == 0u || coord.x >= textureDims.x - 1u) {
        dx = 0.0;
    } else {
        dx = sampleVolume(coord + vec3u(1u, 0u, 0u)) - sampleVolume(coord - vec3u(1u, 0u, 0u));
    };
    if (coord.y == 0u || coord.y >= textureDims.y - 1u) {
       dy = 0.0;
    } else {
        dy = sampleVolume(coord + vec3u(0u, 1u, 0u)) - sampleVolume(coord - vec3u(0u, 1u, 0u));
    };
    if (coord.z == 0u || coord.z >= textureDims.z - 1u) {
        dz = 0.0;
    } else {
        dz = sampleVolume(coord + vec3u(0u, 0u, 1u)) - sampleVolume(coord - vec3u(0u, 0u, 1u));
    };
    let stepSize: f32 = 2.0; // f(x) = x^2
    let scale: f32 = 1.0 / stepSize; // Stepsize replica for vector use.
    return vec3f(dx, dy, dz) * scale;
}


fn computeSecondDerivative(coord: vec3u, textureDims: vec3u, gradientVec: vec3f) -> f32 {
    let gradMag = length(gradientVec);
    if (gradMag < 1e-5) {
        return 0.0;
    }
    let g_hat = gradientVec / gradMag;

    var dxx: f32;
    var dyy: f32;
    var dzz: f32;
    var f_xy: f32;
    var f_xz: f32;
    var f_yz: f32;

    // Second partials (central differences)
    if (coord.x > 0u && coord.x < textureDims.x - 1u) {
        dxx = sampleVolume(coord + vec3u(1u, 0u, 0u)) - (2.0 * sampleVolume(coord)) + sampleVolume(coord - vec3u(1u, 0u, 0u));
    } else {
        dxx = 0.0;
    }
    if (coord.y > 0u && coord.y < textureDims.y - 1u) {
        dyy = sampleVolume(coord + vec3u(0u, 1u, 0u)) - (2.0 * sampleVolume(coord)) + sampleVolume(coord - vec3u(0u, 1u, 0u));
    } else {
        dyy = 0.0;
    }
    if (coord.z > 0u && coord.z < textureDims.z - 1u) {
        dzz = sampleVolume(coord + vec3u(0u, 0u, 1u)) - (2.0 * sampleVolume(coord)) + sampleVolume(coord - vec3u(0u, 0u, 1u));
    } else {
        dzz = 0.0;
    }

    // Mixed partials (central differences) - BUG FIXED
    if (coord.x > 0u && coord.x < textureDims.x - 1u && coord.y > 0u && coord.y < textureDims.y - 1u) {
       f_xy = (
            sampleVolume(vec3u(coord.x + 1u, coord.y + 1u, coord.z))
            - sampleVolume(vec3u(coord.x + 1u, coord.y - 1u, coord.z))
            - sampleVolume(vec3u(coord.x - 1u, coord.y + 1u, coord.z))
            + sampleVolume(vec3u(coord.x - 1u, coord.y - 1u, coord.z))
        ) * 0.25;
    } else {
        f_xy = 0.0;
    }
    if (coord.x > 0u && coord.x < textureDims.x - 1u && coord.z > 0u && coord.z < textureDims.z - 1u) {
        f_xz = (
            sampleVolume(vec3u(coord.x + 1u, coord.y, coord.z + 1u))
            - sampleVolume(vec3u(coord.x + 1u, coord.y, coord.z - 1u))
            - sampleVolume(vec3u(coord.x - 1u, coord.y, coord.z + 1u))
            + sampleVolume(vec3u(coord.x - 1u, coord.y, coord.z - 1u))
        ) * 0.25;
    } else {
        f_xz = 0.0;
    }
    if (coord.y > 0u && coord.y < textureDims.y - 1u && coord.z > 0u && coord.z < textureDims.z - 1u) {
        f_yz = (
            sampleVolume(vec3u(coord.x, coord.y + 1u, coord.z + 1u))
            - sampleVolume(vec3u(coord.x, coord.y + 1u, coord.z - 1u))
            - sampleVolume(vec3u(coord.x, coord.y - 1u, coord.z + 1u))
            + sampleVolume(vec3u(coord.x, coord.y - 1u, coord.z - 1u))
        ) * 0.25;
    } else {
        f_yz = 0.0;
    }

    // Form Hessian matrix
    let hessian = mat3x3<f32>(
        dxx, f_xy, f_xz,
        f_xy, dyy, f_yz,
        f_xz, f_yz, dzz
    );

    // Calculate curvature using the dot product
    let curvature = dot(g_hat, hessian * g_hat);

    return curvature;
}
// ...existing code...
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let dims = textureDimensions(volumeTexture);
    let coords = vec3u(
        u32(clamp(input.uv.x * f32(dims.x), 0.0, f32(dims.x - 1u))),
        u32(clamp(input.uv.y * f32(dims.y), 0.0, f32(dims.y - 1u))),
        u32(f32(dims.z) * 0.5)
    );

    let firstDerivative = computeFirstDerivative(coords, dims);
    let gradientMagnitude = length(firstDerivative);
    let intensity = sampleVolume(coords);
    let curvature = computeSecondDerivative(coords, dims, firstDerivative);

    // --- TEMPORARY DEBUGGING ---
    // Visualize the curvature directly. You may need to adjust the multiplier.
    // Positive curvature will be bright, negative will be dark.
    let curvatureVis = curvature * 0.0007 + 0.2;
    return vec4f(curvatureVis, curvatureVis, curvatureVis, 1.0);
    // ---------------------------

    // return mapToColor(intensity, gradientMagnitude, curvature); // Comment this out for now
}