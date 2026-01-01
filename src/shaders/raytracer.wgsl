struct VertexOutput {
    @builtin(position) position: vec4f, 
    @location(0) uv: vec2f
}

struct Params {
    invMVPMat : mat4x4<f32>, 
    misc: vec4f,
}

struct TissueAlphas {
    csf: f32,
    gray: f32,
    white: f32,
    convexEdges: f32,
    concaveEdges: f32
}

@group(0) @binding(0) var volumeTexture: texture_3d<f32>; 
@group(0) @binding(1) var mySampler: sampler;
@group(0) @binding(2) var<uniform> params: Params; 
@group(0) @binding(3) var<uniform> tissueAlphas: TissueAlphas;

@vertex
fn vs_main(@location(0) position: vec2f) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4f(position, 0.0, 1.0);
    output.uv = position * 0.5 + 0.5;
    return output;
}

fn sampleVolume(uv: vec3f) -> vec4f {
    return textureSampleLevel(volumeTexture, mySampler, uv, 0.0);
}

fn calculateLighting(position: vec3f, normal: vec3f, viewDir: vec3f, color: vec4f) -> vec4f {
    let lightPos: vec3f = vec3f(0.0, 100.0, 100.0);
    let lightDir: vec3f  = normalize(lightPos - position);
    
    // 1. Ambient
    let ambientStrength: f32 = 0.3;
    let ambient: vec3f  = ambientStrength * vec3f(1.0);

    // 2. Diffuse (Lambert)
    let diff: f32 = max(dot(normal, lightDir), 0.0);
    let diffuse: vec3f = diff * vec3f(1.0);

    // 3. Specular (Phong)
    let specularStrength: f32 = 0.5;
    let reflectDir: vec3f = reflect(-lightDir, normal);
    let spec: f32 = pow(max(dot(viewDir, reflectDir), 0.0), 10.0); 
    let specular: vec3f = specularStrength * spec * vec3f(2.0);

    let lighting: vec3f = (ambient + diffuse + specular);
    return vec4f(color.rgb * lighting, color.a);
}

fn mapToColor(intensity: f32, gradientMagnitude: f32, curvature: f32) -> vec4f {
    var color: vec4f;

    let rawIntensity: f32 = intensity; // Assume max ~1709

    // Accurately draws around the boundary of the volume
    // Anything that is not brain tissue
    if (rawIntensity >= 0.0 && rawIntensity < 90) {
        color = vec4f(0.0, 0.0, 0.0, 0.0); 
    } 
    else if (gradientMagnitude >= 50.0) {
        // Transition smoothly between concave and convex edges
        let convex: vec4f = vec4f(1.0, 1.0, 0.0, tissueAlphas.convexEdges); 
        let concave: vec4f = vec4f(0.0, 1.0, 1.0, tissueAlphas.concaveEdges);
        let t: f32 = smoothstep(-100.0, 100.0, curvature);
        color = mix(concave, convex, t); 
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

// Necessary here to compute normals for lighting
fn computeGradient(uv: vec3f, step: vec3f) -> vec3f {
    let val_x_p: f32 = sampleVolume(uv + vec3f(step.x, 0.0, 0.0)).r;
    let val_x_m: f32 = sampleVolume(uv - vec3f(step.x, 0.0, 0.0)).r;
    let dx: f32 = val_x_p - val_x_m;

    let val_y_p: f32 = sampleVolume(uv + vec3f(0.0, step.y, 0.0)).r;
    let val_y_m: f32 = sampleVolume(uv - vec3f(0.0, step.y, 0.0)).r;
    let dy: f32 = val_y_p - val_y_m;

    let val_z_p: f32 = sampleVolume(uv + vec3f(0.0, 0.0, step.z)).r;
    let val_z_m: f32 = sampleVolume(uv - vec3f(0.0, 0.0, step.z)).r;
    let dz: f32 = val_z_p - val_z_m;

    return vec3f(dx, dy, dz) * 0.5; 
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
    let worldNear: vec4f = params.invMVPMat  * ndcNear;
    let worldFar: vec4f = params.invMVPMat  * ndcFar;
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

    let dims: vec3f = vec3f(textureDimensions(volumeTexture)); 
    let texelSize: vec3f = 1.0 / dims; 

    var accumulatedColor: vec4f = vec4f(0.0, 0.0, 0.0, 0.0);
    let numSteps: u32 = 512u;
    let stepSize: f32 = (tfar - tnear) / f32(numSteps);
    var t: f32 = tnear + stepSize * 0.5;

    for(var i: u32 = 0u; i < u32(numSteps); i = i + 1u) {
        if (t >= tfar) {
            break; 
        }
        let samplePos: vec3f = rayOrigin + t * rayDir; 
        let texCoord: vec3f = samplePos + vec3f(0.5); 
        
        // If the voxel's X coordinate is above the slice threshold, make it invisible.
        if (texCoord.x >= params.misc.x) {
             t = t + stepSize;
             continue;
        }

        let sampleVal: vec4f = sampleVolume(texCoord); 
        let intensity: f32 = sampleVal.r;
        let gradientMagnitude: f32 = sampleVal.g;
        let curvature: f32 = sampleVal.b;

        var colorSample: vec4f = mapToColor(intensity, gradientMagnitude, curvature);

         if (colorSample.a > 0.0) {
            let gradient: vec3f = computeGradient(texCoord, texelSize);
            let normal: vec3f = normalize(gradient);
            colorSample = calculateLighting(samplePos, normal, -rayDir, colorSample);
            
            // Opacity correction for step size independence
            let transmittance: f32 = 1.0 - colorSample.a; 
            let totalTransmittance: f32 = pow(transmittance, stepSize * 500.0); 
            let correctedOpacity: f32 = 1.0 - totalTransmittance;
            
            let colorToAdd: vec3f = colorSample.rgb * correctedOpacity * (1.0 - accumulatedColor.a);
            accumulatedColor.r += colorToAdd.r;
            accumulatedColor.g += colorToAdd.g;
            accumulatedColor.b += colorToAdd.b;
            accumulatedColor.a += correctedOpacity * (1.0 - accumulatedColor.a);
        }

        if (accumulatedColor.a >= 0.95) {
            break; 
        };
        t = t + stepSize;
    }
    return accumulatedColor;
}