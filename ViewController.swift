import Metal
import MetalKit
import simd
import AVFoundation
import Accelerate
import CoreMotion

class ViewController: UIViewController {
    var device: MTLDevice!
    var renderEncoder: MTLRenderCommandEncoder!
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    var metalLayer: CAMetalLayer!
    var vertices: [AAPLVertex] = []
    var camera = Camera()

    var vertObj: MTLFunction!
    var fragObj: MTLFunction!
    var vertPart: MTLFunction!
    var fragPart: MTLFunction!
    
    var unifsBuf: MTLBuffer!
    
    var pipelineState: MTLRenderPipelineState!
    var commandQueue: MTLCommandQueue!
    var timer: CADisplayLink!
    
    var audioPlayer: AVAudioPlayer!
    var audioBuf: AVAudioPCMBuffer!
    var audioSignalArr: [Float]! // audio data
    var initTime: Double!
    var currentTime: Double!
    var songLength: Double!
    var sampleRate: Double!
    var numFrames: Int!
    
    var object: Object!
    
    // texture vars
    var texture: MTLTexture!
    lazy var samplerState: MTLSamplerState? = defaultSampler(device: self.device)
    
    // Particle vars
    var particles: UnsafeMutablePointer<Particle>!
    let n: Int = 25000
    var whichBatch: Float = 0.0 // use for keeping old particles that were batchReborn
    var grav: float3! = float3(0)
    var t: Float!
    var h: Float!
    var prevLeft = true // keep track of bass transforms
    
    // accelerometer
    var motionManager = CMMotionManager()
    var motion = CMDeviceMotion()
    var rotationByAcc = float3(0)
    var sensorTimer: Timer!
    
    var metalView: MTKView {
        return view as! MTKView
    }
    
    var width: Float {
        return Float(UIScreen.main.bounds.width)
    }
    
    var height: Float {
        return Float(UIScreen.main.bounds.height)
    }
    
    // texture sampler
    func defaultSampler(device: MTLDevice) -> MTLSamplerState {
        let sampler = MTLSamplerDescriptor()
        sampler.minFilter             = MTLSamplerMinMagFilter.nearest
        sampler.magFilter             = MTLSamplerMinMagFilter.nearest
        sampler.mipFilter             = MTLSamplerMipFilter.nearest
        sampler.maxAnisotropy         = 1
        sampler.sAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.tAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.rAddressMode          = MTLSamplerAddressMode.clampToEdge
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp           = 0
        sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
        return device.makeSamplerState(descriptor: sampler)!
    }
    
    func initParticles() {
        var parts: [Particle] = []
        Particle.initialize(n: n)
        for i in 0..<n {
            let p = Particle(ind: i)
            parts.append(p)
            p.rebirth(t: 0.0, col: float3(0), velocity: float3(0), life: -1)
        }
        particles = UnsafeMutablePointer<Particle>.allocate(capacity: n)
        particles.initialize(from: &parts, count: n)
        t = 0.0
        h = 0.01
    }
    
    func stepParticles(col: float3) {
        // This can be parallelized!
        for i in 0..<n {
            (particles + i).pointee.step(t: t, h: h, g: &grav, col: col)
        }
        t += h;
    }
    
    func batchRebirth(percent: Float, col: float3, velocity: float3, life: Float) {
        assert(percent > 0.0 && percent <= 1.0)
        if(whichBatch > (1.0 - percent)) {
            whichBatch = 0.0
        }
        let start_i = Int(Float(n)*whichBatch)
        for i in start_i..<(start_i + Int(Float(n)*percent)) {
            (particles + i).pointee.rebirth(t: t, col: col, velocity: velocity, life: life)
        }
        whichBatch += percent
    }
    
    func didSwipe() {
        object.toggle()
        if(object.active) {
            pipelineStateDescriptor.vertexFunction = vertObj
            pipelineStateDescriptor.fragmentFunction = fragObj
        } else {
            pipelineStateDescriptor.vertexFunction = vertPart
            pipelineStateDescriptor.fragmentFunction = fragPart
        }
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    }
    
    func render() {
        let now = Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        currentTime = now - initTime // time since song began playing and renders started
        // FOURIER TRANSFORM CHUNK FOR CURRENT ~1/60 sec
        // .017 sec/render is ~1635 floats to process, can we let's round up to .021 sec/cycle assumed?
        // do this before next drawable for less CPU bottleneck during 1/60th sec
        let ind = Int(currentTime * 60.075 * 1598) // 60.075 fps
        var color = float3(0)
        var scale: Float = 0.5
        var shaker = false
        if(currentTime < songLength - 1.0) {
            let ft = FFT(signal: audioSignalArr, start_i: ind, frames: numFrames)
            let bass: Float = getHeavyBass(fs: ft.realComp, frames: numFrames, f: Float(sampleRate))
            let guitar: Float = getGuitar(fs: ft.realComp, frames: numFrames, f: Float(sampleRate))
            let highs: Float = getHighs(fs: ft.realComp, frames: numFrames, f: Float(sampleRate))
            if(object.active) {
                if(bass > 400) {
                    scale += bass / 2000.0
                }
                if(highs > 200) {
                    shaker = true
                }
            } else {
                // bass-blended colors
                if(bass > 250) {
                    let bass_norm: Float = bass/1200
                    color = getBucketedLERP(scalar: bass_norm)
                    let speed_multiplier: Float = 10.0
                    let perp = cross(grav, float3(0, 0, 1))
                    var dir: float3
                    if(prevLeft) {
                        dir = normalize(0.5*grav + perp) // fling down and to the right
                    } else {
                        dir = normalize(0.5*grav - perp) // fling down and to the left
                    }
                    batchRebirth(percent: 0.015, col: color, velocity: speed_multiplier*bass_norm*dir, life: 0.3)
                    prevLeft = !prevLeft
                } else {
                    let guitar_norm = guitar/850
                    color = getBucketedLERP(scalar: guitar_norm)
                }
                if(highs > 200) {
                    let neg_g_hat = -normalize(grav) // fling particles up
                    let speed_multiplier: Float = 5.0
                    let highs_norm = highs/600
                    let col = getBucketedLERP(scalar: highs_norm)
                    batchRebirth(percent: 0.005, col: col, velocity: speed_multiplier*highs_norm*neg_g_hat, life: -1)
                }
            }
        }
        
        if(!object.active) {
            stepParticles(col: color)
        }
        
        guard let drawable = metalLayer?.nextDrawable() else { return }
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 0.0,
            green: 0.0,
            blue: 0.0,
            alpha: 1.0)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        renderEncoder = commandBuffer
            .makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(MTLCullMode.back)
        
        camera.setAspect(a: (width / height));
        camera.setInitDistance(z: 7)
        let P = MatrixStack()
        let MV = MatrixStack()
        P.pushMatrix()
        MV.pushMatrix()
        
        camera.applyProjectionMatrix(P: P)
        camera.applyViewMatrix(MV: MV)
        if(object.active) {
            print(rotationByAcc)
            MV.rotate(angle: rotationByAcc[0], axis: float3(1, 0, 0))
            MV.rotate(angle: rotationByAcc[1], axis: float3(0, 1, 0))
            if(shaker) {
                MV.translate(trans: float3(0, 1, 0)) // shaker highs translation
            }
            
            MV.scale(scale: scale) // heavy bass transform
        }
        let P_matrix = P.topMatrix()
        let MV_matrix = MV.topMatrix()
        MV.popMatrix()
        P.popMatrix()
        
        if(object.active) {
            var unifs = Uniforms(P: P_matrix, MV: MV_matrix, m: object.material)
            let dataSize = MemoryLayout.size(ofValue: unifs)
            unifsBuf = device.makeBuffer(bytes: &unifs, length: dataSize, options: [])
            renderEncoder.setVertexBuffer(unifsBuf, offset: 0, index: 1)
        } else {
            // particle shader unifs
            var unifs = ParticleUniforms(P: P_matrix, MV: MV_matrix, screenSize: float2(width, height))
            let dataSize = MemoryLayout.size(ofValue: unifs)
            unifsBuf = device.makeBuffer(bytes: &unifs, length: dataSize, options: [])
            renderEncoder.setVertexBuffer(unifsBuf, offset: 0, index: Int(UNI_BUFID))
        }
        
        // draw triangles
        if(object.active) {
            object.draw(device: device, renderEncoder: renderEncoder)
        } else {
            // send texture to GPU
            renderEncoder.setFragmentTexture(texture, index: 0)
            if let samplerState = samplerState{
                renderEncoder.setFragmentSamplerState(samplerState, index: 0)
            }
            // draw particles
            Particle.draw(particles: n, device: device, renderEncoder: renderEncoder)
        }
        renderEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    @objc func loop() {
        autoreleasepool {
            self.render()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        AppUtility.lockOrientation(.portrait) // lock orientation
        device = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()
        
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.frame = view.layer.frame
        view.layer.addSublayer(metalLayer)
        
        // load object
        object = Object(source: "sphere2", mat: Material(intensity: 1.0,
                                                     lightPos: float3(0, 0, -10),
                                                     ka: float3(0.2, 0.2, 0.2),
                                                     kd: float3(0.6, 0.6, 0.6),
                                                     ks: float3(0.3, 0.3, 0.7),
                                                     s: 1000.0))
//        object.toggle()
        // load shaders
        let defaultLibrary = device.makeDefaultLibrary()!
        vertObj = defaultLibrary.makeFunction(name: "vertexShaderPhong")!
        fragObj = defaultLibrary.makeFunction(name: "fragmentShaderPhong")!
        vertPart = defaultLibrary.makeFunction(name: "vertexShaderParticle")!
        fragPart = defaultLibrary.makeFunction(name: "fragmentShaderParticle")!
        
        // load particle info
        let tex = MetalTexture(resourceName: "alpha", ext: "jpg", mipmaped: true)
        tex.loadTexture(device: device, commandQ: commandQueue, flip: true)
        texture = tex.texture // set MTLTexture
        
        if(object.active) {
            pipelineStateDescriptor.vertexFunction = vertObj
            pipelineStateDescriptor.fragmentFunction = fragObj
        } else {
            pipelineStateDescriptor.vertexFunction = vertPart
            pipelineStateDescriptor.fragmentFunction = fragPart
        }

        pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // enable alpha blending
        let renderbufferAttachment = pipelineStateDescriptor.colorAttachments[0]
        renderbufferAttachment!.isBlendingEnabled = true
        renderbufferAttachment!.rgbBlendOperation = MTLBlendOperation.add
        renderbufferAttachment!.alphaBlendOperation = MTLBlendOperation.add
        renderbufferAttachment!.sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha
        renderbufferAttachment!.sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha
        renderbufferAttachment!.destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        renderbufferAttachment!.destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        
        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        
        timer = CADisplayLink(target: self, selector: #selector(loop))
        timer.add(to: RunLoop.main, forMode: .default)
        // Alicia by Mala
        let audioPath = URL(fileURLWithPath: Bundle.main.path(forResource: "song", ofType: "wav")!) // or mp3
        // GET AUDIO
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioPath)
        } catch {
            print(error)
        }
        audioPlayer.prepareToPlay()
        songLength = audioPlayer.duration.magnitude
        
        //INIT PARTICLES
        initParticles()
        
        startDeviceMotion()
        
        // LOAD AUDIO DATA FOR FOURIER
        let file = try? AVAudioFile(forReading: audioPath, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: false)
        print(file!.fileFormat.debugDescription)
        let format = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: file!.fileFormat.sampleRate, channels: 2, interleaved: false)
        
        audioBuf = AVAudioPCMBuffer(pcmFormat: format!, frameCapacity: 50000000)
        try? file!.read(into: audioBuf!)
        audioSignalArr = Array(UnsafeBufferPointer(start: audioBuf.floatChannelData![0], count:Int(audioBuf.frameLength)))
        sampleRate = file?.fileFormat.sampleRate
        numFrames = Int(sampleRate/60.075)
        currentTime = 0
        initTime = Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        audioPlayer.play()
        
        // code from https://github.com/calebrwells/A-Swiftly-Tilting-Planet/tree/master/2018/UIGestureRecognizers/Handling%20Swipe%20Gestures/Handling%20Swipe%20Gestures
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        // the default direction is right
        
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
    }
    
    //swipe gesture to swap programs
    @objc func handleSwipe(sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            switch sender.direction {
                case .right:
                    didSwipe()
                case .left:
                    didSwipe()
                default:
                    break
            }
        }
    }
    
    //code from https://developer.apple.com/documentation/coremotion/getting_processed_device-motion_data
    func startDeviceMotion() {
        if motionManager.isDeviceMotionAvailable {
            self.motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            self.motionManager.showsDeviceMovementDisplay = true
            self.motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            
            // Configure a timer to fetch the motion data.
            self.sensorTimer = Timer(fire: Date(), interval: (1.0 / 60.0), repeats: true,
                               block: { (timer) in
                                if let data = self.motionManager.deviceMotion {
                                    // Get the attitude relative to the magnetic north reference frame.
                                    let x: Float = Float(data.attitude.pitch)
                                    let y: Float = Float(data.attitude.roll)
                                    if(self.object.active) { // rotation about x
                                        self.rotationByAcc = float3(x*Float.pi/2,
                                                                    y*Float.pi/2,
                                                                    0)
                                    } else {
                                        self.grav = 9.8*normalize(float3(Float(data.userAcceleration.x + data.gravity.x),
                                                                         Float(data.userAcceleration.y + data.gravity.y),
                                                                         Float(data.userAcceleration.z + data.gravity.z)))
                                    }
                                }
            })
            
            // Add the timer to the current run loop.
            RunLoop.current.add(self.sensorTimer!, forMode: RunLoop.Mode.default)
        }
    }
    
    deinit {
        particles.deallocate()
    }
}
