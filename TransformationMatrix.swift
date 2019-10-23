import MetalKit
import GLKit

class TransformationMatrix {
    func translationMatrix(position: float3) -> float4x4 {
        var matrix = float4x4(1)
        matrix[3][0] = position.x
        matrix[3][1] = position.y
        matrix[3][2] = position.z
        return matrix
    }
    
    func scalingMatrix(scale: Float) -> float4x4 {
        var matrix = float4x4(scale)
        matrix[3][3] = 1
        return matrix
    }
    
    func scalingMatrix(scale: float3) -> float4x4 {
        var matrix = float4x4(1)
        matrix[0][0] = scale.x
        matrix[1][1] = scale.y
        matrix[2][2] = scale.z
        return matrix
    }
    
    func rotationXMatrix(angle: Float) -> float4x4 {
        var matrix = float4x4(1)
        let s = sin(angle)
        let c = cos(angle)
        matrix[1][1] = c
        matrix[1][2] = s
        matrix[2][1] = -s
        matrix[2][2] = c
        return matrix
    }
    
    func rotationYMatrix(angle: Float) -> float4x4 {
        var matrix = float4x4(1)
        let s = sin(angle)
        let c = cos(angle)
        matrix[0][0] = c
        matrix[0][2] = -s
        matrix[2][0] = s
        matrix[2][2] = c
        return matrix
    }
    
    func rotationZMatrix(angle: Float) -> float4x4 {
        var matrix = float4x4(1)
        let s = sin(angle)
        let c = cos(angle)
        matrix[0][0] = c
        matrix[0][1] = s
        matrix[1][0] = -s
        matrix[1][1] = c
        return matrix
    }
    
    func rotationMatrix(angles: float3) -> float4x4 {
        return rotationZMatrix(angle: angles[0]) * rotationYMatrix(angle: angles[1]) * rotationXMatrix(angle: angles[2])
    }
    
    func rotationMatrix(angle: Float, axis: float3) -> float4x4 {
        var matrix = float4x4(1)
        let c = cos(angle)
        let s = sin(angle)
        let u = normalize(axis)
        matrix[0][0] = c + u[0]*u[0]*(1 - c)
        matrix[0][1] = u[0]*u[1]*(1 - c) + u[2]*s
        matrix[0][2] = u[0]*u[2]*(1 - c) - u[1]*s
        matrix[1][0] = u[0]*u[1]*(1 - c) - u[2]*s
        matrix[1][1] = c + u[1]*u[1]*(1 - c)
        matrix[1][2] = u[1]*u[2]*(1 - c) + u[0]*s
        matrix[2][0] = u[0]*u[2]*(1 - c) + u[1]*s
        matrix[2][1] = u[1]*u[2]*(1 - c) - u[0]*s
        matrix[2][2] = c + u[2]*u[2]*(1 - c)
        return matrix
    }
    
    // projection matrix for 2x2x1 "cube"
    func perspective(fovy: Float, aspect: Float, znear: Float, zfar: Float) -> float4x4 {
        let m = GLKMatrix4MakePerspective(fovy, aspect, znear, zfar)
        var ret = float4x4(0)
        ret[0][0] = m.m00
        ret[1][0] = m.m10
        ret[2][0] = m.m20
        ret[3][0] = m.m30
        ret[0][1] = m.m01
        ret[1][1] = m.m11
        ret[2][1] = m.m21
        ret[3][1] = m.m31
        ret[0][2] = m.m02
        ret[1][2] = m.m12
        ret[2][2] = m.m22
        ret[3][2] = m.m32
        ret[0][3] = m.m03
        ret[1][3] = m.m13
        ret[2][3] = m.m23
        ret[3][3] = m.m33
        return ret
    }
}
