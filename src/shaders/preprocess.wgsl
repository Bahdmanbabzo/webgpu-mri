@group(0) @binding(0) var inputVolume: texture_3d<f32>;
@group(0) @binding(1) var outputVolume: texture_storage_3d<rgba16float, write>;
@group(0) @binding(2) var<uniform> params: Params;
@group(0) @binding(3) var<storage, read_write> globalStats: GlobalStats;

struct Params {
    volumeDimensions: vec4f,
}

struct GlobalStats {
    maxGradient: atomic<u32>,
}

var<workgroup> whiteBoard: array<u32, 256>;

fn sampleVolume(pos: vec3i) -> f32 {
    let dims: vec3i = vec3i(params.volumeDimensions.xyz);
    let clampedPos: vec3i = clamp(pos, vec3i(0), vec3i(dims) - vec3i(1));
    return textureLoad(inputVolume, clampedPos, 0).r;
}

@compute @workgroup_size(8, 8, 4)
fn main(@builtin(global_invocation_id) global_id: vec3u, @builtin(local_invocation_index) local_index: u32) {
    let dims: vec3i = vec3i(params.volumeDimensions.xyz);
    let id: vec3i = vec3i(global_id);

    var gradientMagnitude: f32 = 0.0;
    var intensity: f32 = 0.0;
    var curvature: f32 = 0.0;
    
    let inside: bool = all(id < dims);

    if (inside) {
        intensity = sampleVolume(id);
        
        // Sample neighboring voxels for gradient and curvature calculations
        let val_x_p: f32 = sampleVolume(id + vec3i(1, 0, 0));
        let val_x_m: f32 = sampleVolume(id - vec3i(1, 0, 0));
        let val_y_p: f32 = sampleVolume(id + vec3i(0, 1, 0));
        let val_y_m: f32 = sampleVolume(id - vec3i(0, 1, 0));
        let val_z_p: f32 = sampleVolume(id + vec3i(0, 0, 1));
        let val_z_m: f32 = sampleVolume(id - vec3i(0, 0, 1));

        // --- GRADIENT CALCULATION ---
        var gradient: vec3f;
        {
            // Recall central difference: f'(x) = (f(x+h) - f(x-h)) / 2
            let dx: f32 = (val_x_p - val_x_m) * 0.5;
            let dy: f32 = (val_y_p - val_y_m) * 0.5;
            let dz: f32 = (val_z_p - val_z_m) * 0.5;
            
            gradient = vec3f(dx, dy, dz);
            gradientMagnitude = length(gradient);
        }

        // --- CURVATURE CALCULATION ---
        {
            //  Only compute curvature if there is a gradient to curve along
            if (gradientMagnitude > 1e-5) {
                let g_hat: vec3f = gradient / gradientMagnitude;

                // Axial Second Derivatives 
                // Recall f(x) = f(x+h) - 2f(x) + f(x-h)
                let dxx: f32 = val_x_p - 2.0 * intensity + val_x_m;
                let dyy: f32 = val_y_p - 2.0 * intensity + val_y_m;
                let dzz: f32 = val_z_p - 2.0 * intensity + val_z_m;

                // Mixed Partials
                // Recall f(x,y) = (f(x+h,y+h) - f(x+h,y-h) - f(x-h,y+h) + f(x-h,y-h)) / 4
                let f_xy: f32 = (
                    sampleVolume(id + vec3i(1, 1, 0)) - 
                    sampleVolume(id + vec3i(1, -1, 0)) - 
                    sampleVolume(id - vec3i(1, 1, 0)) + 
                    sampleVolume(id - vec3i(1, -1, 0))
                ) * 0.25;

                let f_xz: f32 = (
                    sampleVolume(id + vec3i(1, 0, 1)) - 
                    sampleVolume(id + vec3i(1, 0, -1)) - 
                    sampleVolume(id - vec3i(1, 0, 1)) + 
                    sampleVolume(id - vec3i(1, 0, -1))
                ) * 0.25;

                let f_yz: f32 = (
                    sampleVolume(id + vec3i(0, 1, 1)) - 
                    sampleVolume(id + vec3i(0, 1, -1)) - 
                    sampleVolume(id - vec3i(0, 1, 1)) + 
                    sampleVolume(id - vec3i(0, 1, -1))
                ) * 0.25;

                let hessian: mat3x3<f32> = mat3x3<f32>(
                    vec3f(dxx, f_xy, f_xz),
                    vec3f(f_xy, dyy, f_yz),
                    vec3f(f_xz, f_yz, dzz)
                );

                curvature = dot(g_hat, hessian * g_hat);
            }
        }
    }

    // Update local max using parallel reduction
    whiteBoard[local_index] = bitcast<u32>(gradientMagnitude);
    
    workgroupBarrier();

    // Parallel reduction loop
    for (var i: u32 = 128u; i > 0u; i >>= 1u) {
        if (local_index < i) {
            let otherThread: u32 = whiteBoard[local_index + i];
            if (otherThread > whiteBoard[local_index]) {
                whiteBoard[local_index] = otherThread;
            }
        }
        workgroupBarrier();
    }

    if (local_index == 0u) {
        atomicMax(&globalStats.maxGradient, whiteBoard[0]);
    }

    if (inside) {
        textureStore(outputVolume, id, vec4f(intensity, gradientMagnitude, curvature, 1.0));
    }
}
