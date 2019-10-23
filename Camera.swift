import Foundation
import MetalKit
class Camera
{
    enum transform_t {
        case ROTATE
        case TRANSLATE
        case SCALE
    }
    
    init() {
        aspect = 1
        fovy = (Float)(45.0*Double.pi/180.0)
        znear = 0.1
        zfar = 1000.0
        rotations = float2(0)
        translations = float3(0.0, 0.0, 0.0)
        touchPrev = float2(0)
        state = transform_t.SCALE
        rfactor = 0.01
        tfactor = 0.001
        sfactor = 0.005
    }
    func setInitDistance(z: Float) { translations.z = -abs(z) }
    func setAspect(a: Float) { aspect = a }
    func setFovy(f: Float) { fovy = f }
    func setZnear(z: Float) { znear = z }
    func setZfar(z: Float) { zfar = z }
    func setRotationFactor(f: Float) { rfactor = f }
    func setTranslationFactor(f: Float) { tfactor = f }
    func setScaleFactor(f: Float) { sfactor = f }
    func didTap(x: Float, y: Float, shift: Bool, ctrl: Bool, alt: Bool) {
        
    }
    func didMove(x: Float, y: Float) {
        
    }
    func applyProjectionMatrix(P: MatrixStack) {
        let t = TransformationMatrix()
        P.multMatrix(matrix: t.perspective(fovy: fovy, aspect: aspect, znear: znear, zfar: zfar));
    }
    func applyViewMatrix(MV: MatrixStack) {
        MV.translate(trans: translations)
        MV.rotate(angle: rotations.y, axis: float3(1.0, 0.0, 0.0))
        MV.rotate(angle: rotations.x, axis: float3(0.0, 1.0, 0.0))
    }
    
    private var aspect: Float
    private var fovy: Float
    private var znear: Float
    private var zfar: Float
    private var rotations: float2
    private var translations: float3
    private var touchPrev: float2
    private var state: transform_t
    private var rfactor: Float
    private var tfactor: Float
    private var sfactor: Float
}
