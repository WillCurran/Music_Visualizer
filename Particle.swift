import Metal

class Particle
{
    // Static, shared by all particles
    private static var posBuf: [float3] = []
    private static var colBuf: [float3] = []
    private static var alpBuf: [Float] = []
    private static var scaBuf: [Float] = []
    private static let defaultColor = float3(0.0, 0.9, 0.0)
//    private static var colBuffer: MTLBuffer!
//    private static var scaBuffer: MTLBuffer!
    
    init(ind: Int) {
        index = ind
        scale = Particle.scaBuf[index]
        x = Particle.posBuf[index]
        alpha = Particle.alpBuf[index]
        // Random fixed properties
        color = Particle.defaultColor
        scale = Particle.randFloat(l: 0.01, h: 0.02)
        
        // INEFFICIENT TO MAKE A NEW BUFFER EVERY TIME
        // Send color data to GPU
//        var dataSize = MemoryLayout.size(ofValue: Particle.colBuf[0]) * Particle.colBuf.count
//        Particle.colBuffer = device.makeBuffer(bytes: &Particle.colBuf, length: dataSize, options: [])
//        renderEncoder.setVertexBuffer(Particle.colBuffer, offset: 0, index: Particle.colBufID)
//        // Send scale data to GPU
//        dataSize = MemoryLayout.size(ofValue: Particle.scaBuf[0]) * Particle.colBuf.count
//        Particle.scaBuffer = device.makeBuffer(bytes: &Particle.scaBuf, length: dataSize, options: [])
//        renderEncoder.setVertexBuffer(Particle.scaBuffer, offset: 0, index: Particle.scaBufID)
        
//        // update shared color data
//        (Particle.colBuffer!.contents() + index*MemoryLayout.size(ofValue: Particle.colBuf[0])).storeBytes(of: color, as: float3.self)
//        // update shared scale data
//        (Particle.scaBuffer!.contents() + index*MemoryLayout.size(ofValue: Particle.scaBuf[0])).storeBytes(of: scale, as: Float.self)
        
        m = 1.0
        alpha = 1.0
        tEnd = 0.0
        d = 0.0
        lifespan = 0.0
        v = float3(0)
    }
    
    // inefficient(?), but not sure how to do this with UnsafeMutablePointers / Reference in Swift yet
    func sendValuesToArray() {
        Particle.posBuf[index] = x
        Particle.colBuf[index] = color
        Particle.alpBuf[index] = alpha
        Particle.scaBuf[index] = scale
    }
    
    func rebirth(t: Float, col: float3, velocity: float3, life: Float) {
//        m = 1.0;
        alpha = 1.0;
        if(col == float3(0)) {
            color = Particle.defaultColor
        } else {
            color = col
        }
        if(velocity == float3(0)) {
            v = float3(Particle.randFloat(l: -2.0, h: 2.0), Particle.randFloat(l: -2.0, h: 2.0), Particle.randFloat(l: -1.0, h: 1.0))
        } else {
            v = velocity
        }
        if(life == -1) {
            lifespan = Particle.randFloat(l: 0.4, h: 1.2)
        } else {
            lifespan = life
        }
//        if(keyToggles[(unsigned)'g']) {
//            // Gravity towards origin
//            d = randFloat(0.0f, 0.1f);
//            x << randFloat(-2.0f, -1.5f), randFloat(0.5f, 1.0f), randFloat(-0.75f, 0.75f);
//            v << randFloat(1.0f, 5.0f), randFloat(1.0f, 2.0f), randFloat(-1.0f, 1.0f);
//            lifespan = randFloat(0.4f, 4.0f);
//        } else {
        
        // Gravity downwards
        d = Particle.randFloat(l: 0.0, h: 0.1)
        let x_coord = Particle.randFloat(l: -1.0, h: 1.0)
        let y_bound = sqrtf(1 - pow(x_coord, 2.0))
        let y_coord = Particle.randFloat(l: -y_bound, h: y_bound)
        x = float3(x_coord, y_coord, Particle.randFloat(l: -0.75, h: 0.75))
        
//        }
        
        tEnd = t + lifespan;
        sendValuesToArray()
    }
    
    func step(t: Float, h: Float, g: UnsafeMutablePointer<float3>, col: float3) {
        if(t > tEnd) {
            rebirth(t: t, col: col, velocity: float3(0), life: -1)
        }
        // Update alpha based on current time
        alpha = (tEnd-t)/lifespan;
        
        // gravity force
        var fg: float3
//        if(keyToggles[(unsigned)'g']) {
//            C: Float = 9.81;
//            E: Float = 0.01f;
//            fg = - (C*m)/pow(pow(x.norm(), 2.0) + pow(E, 2.0), 1.5) * x;
//        } else {
        fg = m*g.pointee;
//        }
        
        // viscous force
        let fv = -d*v;
        // net force
        let f = fg + fv;
        // Update velocity
        v += h/m*f;
        // Update position
        x += h*v;
        
        // Apply floor collision
//        if(keyToggles[(unsigned)'f']) {
//            if(x[1] < 0.0f) {
//                x[1] = 0.0f;
//                v[1] = -v[1];
//            }
//        }
        sendValuesToArray()
    }
    
    // Static, shared by all particles
    static func initialize(n: Int) {
//        print("Initialize all particles")
        Particle.posBuf = [float3](repeating: float3(0.0), count: n)
        Particle.colBuf = [float3](repeating: float3(1.0), count: n)
        Particle.alpBuf = [Float](repeating: 1.0, count: n)
        Particle.scaBuf = [Float](repeating: 1.0, count: n)
//        print("buffers allocated")
//        // Send color buffer to GPU
//        var dataSize = MemoryLayout.size(ofValue: Particle.colBuf[0]) * Particle.colBuf.count
//        print("1")
//        Particle.colBuffer = device.makeBuffer(bytes: &Particle.colBuf, length: dataSize, options: [])
//        print("2")
//        renderEncoder.setVertexBuffer(Particle.colBuffer, offset: 0, index: Particle.colBufID)
//        print("sent colors to GPU")
//        // Send scale buffer to GPU
//        dataSize = MemoryLayout.size(ofValue: Particle.scaBuf[0]) * Particle.colBuf.count
//        Particle.scaBuffer = device.makeBuffer(bytes: &Particle.scaBuf, length: dataSize, options: [])
//        renderEncoder.setVertexBuffer(Particle.scaBuffer, offset: 0, index: Particle.scaBufID)
//        print("sent scales to GPU")
    }
    
    // send particle info to GPU
    static func draw(particles: Int, device: MTLDevice, renderEncoder: MTLRenderCommandEncoder) {
        // Send color buffer to GPU
        var dataSize = MemoryLayout.size(ofValue: Particle.colBuf[0]) * Particle.colBuf.count
        let colBuffer = device.makeBuffer(bytes: &Particle.colBuf, length: dataSize, options: [])
        renderEncoder.setVertexBuffer(colBuffer, offset: 0, index: Int(COL_BUFID))
        
        // Send scale buffer to GPU
        dataSize = MemoryLayout.size(ofValue: Particle.scaBuf[0]) * Particle.scaBuf.count
        let scaBuffer = device.makeBuffer(bytes: &Particle.scaBuf, length: dataSize, options: [])
        renderEncoder.setVertexBuffer(scaBuffer, offset: 0, index: Int(SCA_BUFID))
        
        // Send alpha buffer to GPU
        dataSize = MemoryLayout.size(ofValue: Particle.alpBuf[0]) * Particle.alpBuf.count
        let alpBuffer = device.makeBuffer(bytes: &Particle.alpBuf, length: dataSize, options: [])
        renderEncoder.setVertexBuffer(alpBuffer, offset: 0, index: Int(ALP_BUFID))
        
        // Send pos buffer to GPU
        dataSize = MemoryLayout.size(ofValue: Particle.posBuf[0]) * Particle.posBuf.count
        let posBuffer = device.makeBuffer(bytes: &Particle.posBuf, length: dataSize, options: [])
        renderEncoder.setVertexBuffer(posBuffer, offset: 0, index: Int(POS_BUFID))
        
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles, instanceCount: 1)
    }
    static func randFloat(l: Float, h: Float) -> Float {
        return Float.random(in: l...h)
    }
    
    var index: Int // index to this particle
    // Properties that are fixed
    var color: float3 // color (mapped to a location in colBuf)
    var scale: Float                     // size (mapped to a location in scaBuf)

    // Properties that changes every rebirth
    var m: Float        // mass
    var d: Float        // viscous damping
    var lifespan: Float // how long this particle lives
    var tEnd: Float    // time this particle dies

    // Properties that changes every frame
    var x: float3 // position (mapped to a location in posBuf)
    var v: float3             // velocity
    var alpha: Float                 // mapped to a location in alpBuf
}
