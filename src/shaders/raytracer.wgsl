struct VertexOutput {
    @builtin(position) position: vec4f, 
    @location(0) uv: vec2f
}

struct Params {
    invMVPMat: mat4x4<f32>, 
}

struct TissueAlphas {
    csf: f32,
    gray: f32,
    white: f32,
    convexEdges: f32,
    concaveEdges: f32
}

@group(0) @binding(0) var volumeTexture: texture_3d<u32>; 
@group(0) @binding(1) var<uniform> params: Params; 
@group(0) @binding(2) var<uniform> tissueAlphas: TissueAlphas;

@vertex
fn vs_main(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5;
    return output;
}

fn sampleVolume(coord: vec3u) -> f32 {
    let rawValue = textureLoad(volumeTexture, coord, 0).r; 
    return f32(rawValue);
}

fn mapToColor(intensity: f32, gradientMagnitude: f32, curvature: f32) -> vec4f {
    var color: vec4f;

    let rawIntensity = intensity; // Assume max ~1709

    // Accurately draws around the boundary of the volum
    // Anything that is not brain tissue
    if (rawIntensity >= 0.0 && rawIntensity < 90) {
        color = vec4f(0.0, 0.0, 0.0, 0.0); 
    } 
    else if (gradientMagnitude >= 50.0) {
        if (curvature > 0.0) {
            // High positive curvature (convex regions)
            color = vec4f(1.0, 1.0, 0.0, tissueAlphas.convexEdges); // Yellow for convex
        } else {
            // High negative curvature (concave regions)
            color = vec4f(0.0, 1.0, 1.0, tissueAlphas.concaveEdges); // Cyan for concave
        }
    }
    else if (rawIntensity >= 90 && rawIntensity < 200) {
        // Probably csf range 
        // Third ventricle was clearly visible at slide 0.65
        color = vec4f(0.0, 0.0, 1.0, tissueAlphas.csf); 
    } else if (rawIntensity >=200 && rawIntensity < 300) { // Probably gray matter range
        color = vec4f(0.0, 1.0, 0.0, tissueAlphas.gray);
    } else if (rawIntensity >= 300 && rawIntensity < 400) { // Probably white matter range
        color = vec4f(1.0, 0.5, 0.8, tissueAlphas.white); 
    } else if (rawIntensity >= 400 && rawIntensity < 600) { // Probably white matter range
        color = vec4f(1.0, 0.0, 1.0, 0.2); 
    } else if (rawIntensity >= 600 && rawIntensity < 800) { // Probably white matter range
        color = vec4f(0.0, 1.0, 1.0, 0.25); 
    } else if (rawIntensity >= 800 && rawIntensity < 1200) { // Probably white matter range
        color = vec4f(1.0, 1.0, 1.0, 0.3); 
    }

    // Default fallback
    else {
        color = vec4f(1.0, 1.0, 1.0, 0.0); // Soft white
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
    let pvec: vec3f = cross(rayDir, edge2);
    let det: f32 = dot(edge1, pvec); 
    let T: vec3f = rayOrigin - v0; 
    let barycentricBeta: f32 = (dot(T, pvec)) / det;
    if (barycentricBeta < 0.0 || barycentricBeta > 1.0) {
        return -1.0; 
    }
    let qvec: vec3f = cross(T, edge1);
    let barycentricGamma: f32 = dot(rayDir, qvec) / det;
    if (barycentricGamma < 0.0 || barycentricBeta + barycentricGamma > 1.0) {
        return -1.0; 
    }
    let t: f32 = dot(edge2, qvec) / det;
    if (t > 0.0) {
        return t; 
    } else {
        return -1.0; 
    }

}
fn rayBoxIntersection(boxMin: vec3f, boxMax: vec3f, rayOrigin: vec3f, rayDir: vec3f) -> vec2f {
    let invDir: vec3f = 1.0 / rayDir; 
    let t1: vec3f = (boxMin - rayOrigin) * invDir; 
    let t2: vec3f = (boxMax - rayOrigin) * invDir;  
    let tmin: vec3f = min(t1, t2); 
    let tmax: vec3f = max(t1, t2);
    let tnear: f32 = max(max(tmin.x, tmin.y), tmin.z); 
    let tfar: f32 = min(min(tmax.x, tmax.y), tmax.z); 

    if (tnear > tfar || tfar < 0.0) {
        return vec2f(1.0, 0.0);
    }; 

    return vec2f(tnear, tfar); 
}
@fragment
fn fs_main(input: VertexOutput) -> @location(0) vec4f {
    // First convert clip space to ndc then to world space
    // Imagine how a projector works but in the reverse direction since we're going from 2D(pixels on the screen) to 3D
    let ndcNear: vec4f = vec4f(input.uv.x * 2.0 - 1.0, input.uv.y * 2.0 - 1.0, 0.0, 1.0);
    let ndcFar: vec4f = vec4f(input.uv.x * 2.0 - 1.0, input.uv.y * 2.0 - 1.0, 1.0, 1.0);
    let worldNear: vec4f = params.invMVPMat * ndcNear;
    let worldFar: vec4f = params.invMVPMat * ndcFar;
    // Perform perspective divide
    // This gives us the ray origin and direction in world space while reflecting camera perspective correctly
    let rayOrigin: vec3f = worldNear.xyz / worldNear.w;
    let rayDir: vec3f = normalize((worldFar.xyz / worldFar.w) - rayOrigin);
    let boxMin: vec3f = vec3f(-0.5); 
    let boxMax: vec3f = vec3f(0.5); 
    let intersection: vec2f = rayBoxIntersection(boxMin, boxMax, rayOrigin, rayDir);
    let tnear: f32 = intersection.x; 
    let tfar: f32 = intersection.y; 
    if(tnear >= tfar) {
        return vec4f(0.0, 0.0, 0.0, 1.0); 
    };

    let dims: vec3u = textureDimensions(volumeTexture);
    var accumulatedColor: vec4f = vec4f(0.0, 0.0, 0.0, 0.0);
    let numSteps: u32 = 256u;
    let stepSize: f32 = (tfar - tnear) / f32(numSteps);
    var t: f32 = tnear + stepSize * 0.5;

    for(var i: u32 = 0u; i < u32(numSteps); i = i + 1u) {
        if (t >= tfar) {
            break; 
        }
        let samplePos: vec3f = rayOrigin + t * rayDir; 
        let texCoord: vec3f = samplePos + vec3f(0.5); 
        let coords: vec3u = vec3u(
            u32(clamp(texCoord.x * f32(dims.x), 0.0, f32(dims.x - 1u))),
            u32(clamp(texCoord.y * f32(dims.y), 0.0, f32(dims.y - 1u))),
            u32(clamp(texCoord.z * f32(dims.z), 0.0, f32(dims.z - 1u)))
        );
        let intensity: f32 = sampleVolume(coords); 
        let firstDerivative: vec3f = computeFirstDerivative(coords, dims);
        let gradientMagnitude: f32 = length(firstDerivative);
        let curvature: f32 = computeSecondDerivative(coords, dims, firstDerivative);
        let colorSample: vec4f = mapToColor(intensity, gradientMagnitude, curvature);

        if (colorSample.a > 0.0) {
            let transmittance: f32 = 1.0 - colorSample.a; 
            let totalTransmittance: f32 = pow(transmittance, stepSize * 2.0); 
            let correctedOpacity: f32 = 1.0 - totalTransmittance;
            let colorToAdd: vec3f = colorSample.rgb * correctedOpacity * (1.0 - accumulatedColor.a);
            accumulatedColor.r += colorToAdd.r;
            accumulatedColor.g += colorToAdd.g;
            accumulatedColor.b += colorToAdd.b;
            accumulatedColor.a += correctedOpacity * (1.0 - accumulatedColor.a);
        };
        if (accumulatedColor.a >= 0.95) {
            break; 
        };
        t = t + stepSize;
    }
    return accumulatedColor;
}