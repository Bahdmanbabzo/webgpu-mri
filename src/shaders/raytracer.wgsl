struct VertexOutput {
    @builtin(position) position: vec4f, 
    @location(0) uv: vec2f
}

struct Params {
    invMax: f32, 
    fov: f32,
}

@group(0) @binding(0) var volumeTexture: texture_3d<u32>; 
@group(0) @binding(1) var<uniform> params: Params; 

@vertex
fn vs_main(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5;
    return output;
}

fn sampleVolume(coord: vec3u) -> f32 {
    let rawValue = textureLoad(volumeTexture, coord, 0).r; 
    let normalised = f32(rawValue) * params.invMax; 
    return f32(rawValue);
}

fn mapToColor(intensity: f32, gradientMagnitude: f32, curvature: f32) -> vec4f {
    var color: vec4f;

    let rawIntensity = intensity; // Assume max ~1709

    // Accurately draws around the boundary of the volum
    // Anything that is not brain tissue
    if (rawIntensity >= 0.0 && rawIntensity < 90) {
        color = vec4f(0.0, 0.0, 0.0, 1.0); 
    } 
    else if (gradientMagnitude >= 50.0) {
        if (curvature > 0.0) {
            // High positive curvature (convex regions)
            color = vec4f(1.0, 1.0, 0.0, 1.0); // Yellow for convex
        } else {
            // High negative curvature (concave regions)
            color = vec4f(0.0, 1.0, 1.0, 1.0); // Cyan for concave
        }
    }
    else if (rawIntensity >= 90 && rawIntensity < 200) {
        // Probably csf range 
        // Third ventricle was clearly visible at slide 0.65
        color = vec4f(0.0, 0.0, 1.0, 1.0); 
    } else if (rawIntensity >=200 && rawIntensity < 300) { // Probably gray matter range
        color = vec4f(0.0, 1.0, 0.0, 1.0);
    } else if (rawIntensity >= 300 && rawIntensity < 400) { // Probably white matter range
        color = vec4f(1.0, 0.5, 0.8, 1.0); 
    } else if (rawIntensity >= 400 && rawIntensity < 600) { // Probably white matter range
        color = vec4f(1.0, 0.0, 1.0, 1.0); 
    } else if (rawIntensity >= 600 && rawIntensity < 800) { // Probably white matter range
        color = vec4f(0.0, 1.0, 1.0, 1.0); 
    } else if (rawIntensity >= 800 && rawIntensity < 1200) { // Probably white matter range
        color = vec4f(1.0, 1.0, 1.0, 1.0); 
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
        return 0.0; // Avoid division by zero
    }
    let g_hat = gradientVec / gradMag;

    var dxx: f32;
    var dyy: f32;
    var dzz: f32;
    var f_xy: f32;
    var f_xz: f32;
    var f_yz: f32;

    // Second partials (central differences)
    // Recall f''(x) = 2
    // f(x + 1) -2f(x) + f(x - 1)
    // Again central differences to give more accurate descriptions
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

    // Mixed partials (central differences)
    // Recall f(x + 1, y + 1) - f( x + 1, y - 1) - f( x - 1, y + 1) + f(x - 1, y - 1)
    // More accurate to do this as opposed to just forward/backward approach
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

fn mollerTrumboreIntersection(v0: vec3f, v1: vec3f, v2: vec3f, rayOrigin: vec3f, rayDir: vec3f) -> f32 {
    let edge1: vec3f = v1 - v0; 
    let edge2: vec3f = v2 - v0; 
    let n1: vec3f = cross(rayDir, edge2);
    let det: f32 = dot(edge1, n1); 
    let T: vec3f = rayOrigin - v0; 
    let barycentricBeta: f32 = (dot(T, n1)) / det;
    if (barycentricBeta < 0.0 || barycentricBeta > 1.0) {
        return -1.0; 
    }
    let n2: vec3f = cross(T, edge1);
    let barycentricGamma: f32 = dot(rayDir, n2) / det;
    if (barycentricGamma < 0.0 || barycentricBeta + barycentricGamma > 1.0) {
        return -1.0; 
    }
    let t: f32 = dot(edge2, n2) / det;
    if (t > 0.0) {
        return t; 
    } else {
        return -1.0; 
    }

}
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    let camera: vec3f = vec3f(0.0, 0.0, 0.0); 
    let focalLength: f32 = 1.0 / tan(radians(params.fov) * 0.5);
    let aspectRatio: f32 = 1.0; 
    let ndc: vec2f = vec2f((input.uv.x * 2.0 - 1.0)* aspectRatio, (input.uv.y * 2.0 - 1.0));
    let rayDir: vec3f =normalize(vec3f(ndc.x, ndc.y, -focalLength));
    let v0 = vec3f(-0.5, -0.5, -2.0);
    let v1 = vec3f( 0.5, -0.5, -2.0);
    let v2 = vec3f( 0.0,  0.5, -2.0);
    let t = mollerTrumboreIntersection(v0, v1, v2, camera, rayDir);
    if (t > 0.0) {
        return vec4f(1.0, 0.0, 0.0, 1.0); 
    }else {
        return vec4f(0.0, 0.0, 0.0, 1.0); 
    }
    let dims: vec3u = textureDimensions(volumeTexture);
    let coords: vec3u = vec3u(
        u32(clamp(input.uv.x * f32(dims.x), 0.0, f32(dims.x - 1u))),
        u32(clamp(input.uv.y * f32(dims.y), 0.0, f32(dims.y - 1u))),
        u32(f32(dims.z) * 0.65)
    );

    let firstDerivative = computeFirstDerivative(coords, dims);
    let gradientMagnitude = length(firstDerivative);
    let intensity = sampleVolume(coords);
    let curvature = computeSecondDerivative(coords, dims, firstDerivative);

    // --- TEMPORARY DEBUGGING ---
    // Visualize the curvature directly. You may need to adjust the multiplier.
    // Positive curvature will be bright, negative will be dark.
    //let curvatureVis = curvature * 0.0007 + 0.2;
    //return vec4f(curvatureVis, curvatureVis, curvatureVis, 1.0);
    // ---------------------------
}