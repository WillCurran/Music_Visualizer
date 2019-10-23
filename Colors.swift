import MetalKit

// color buckets along spectrum
let colors: [float3] = [float3(1, 0.0, 0.0),
                        float3(1, 0.7, 0.0),
                        float3(0.47, 0.0, 1.0),
                        float3(0.0, 0.3, 1.0),
                        float3(0.0, 1.0, 1.0),
                        float3(0.0, 1.0, 0.24),
                        float3(0.44, 1.0, 0.0),
                        float3(1.0, 1.0, 0.0),
                        float3(1, 0.0, 0.0)]

func getBucketedLERP(scalar: Float) -> float3 {
    var i = Int(7*scalar)
    var r: Float = remainderf(7*scalar, 1.0)
    if(r < 0) {
        r = 1 + r
    }
    if(i > 6) {
        i = 7
    } else if(i < 0) {
        i = 0
        r = 0
    }
    return r*colors[i+1] + (1-r)*colors[i]
}
