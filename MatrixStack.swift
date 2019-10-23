import MetalKit

class MatrixStack {
    var mstack = Stack<float4x4>.init()
    let transforms = TransformationMatrix()
    
    init()
    {
        mstack.push(float4x4(1))
    }
    
    func pushMatrix()
    {
        let top = mstack.top()
        mstack.push(top)
        assert(mstack.size() < 100)
    }
    
    func popMatrix()
    {
        assert(!mstack.empty())
        mstack.pop()
        assert(!mstack.empty())
    }
    
    func loadIdentity()
    {
        assert(!mstack.empty())
        mstack.pop()
        mstack.push(float4x4(1))
    }
    
    func multMatrix(matrix: float4x4)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * matrix)
    }
    
    func translate(trans: float3)
    {
//        print("Translating")
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.translationMatrix(position: trans))
    }
    
    func translate(x: Float, y: Float, z: Float)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.translationMatrix(position: float3(x, y, x)))
    }
    
    func scale(scale: Float)
    {
//        print("Scaling by ", scale)
        assert(!mstack.empty())
        let top = mstack.pop()
//        print("Top: ", top.debugDescription)
//        print("New: ", (top * transforms.scalingMatrix(scale: scale)).debugDescription)
        mstack.push(top * transforms.scalingMatrix(scale: scale))
//        print("On stack: ", mstack.top().debugDescription)
    }
    
    func scale(scale: float3)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.scalingMatrix(scale: scale))
    }

    func scale(x: Float, y: Float, z: Float)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.scalingMatrix(scale: float3(x, y, z)))
    }
    
    func rotate(angle: Float, axis: float3)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.rotationMatrix(angle: angle, axis: axis))
    }
    
    func rotate(angle: Float, x: Float, y: Float, z: Float)
    {
        assert(!mstack.empty())
        let top = mstack.pop()
        mstack.push(top * transforms.rotationMatrix(angle: angle, axis: float3(x, y, z)))
    }
    
    func topMatrix() -> float4x4
    {
        return mstack.top()
    }
    
//    func print(mat: float4x4)
//    {
//        for i in 0...3 {
//            for j in 0...3 {
//                // mat[j] returns the jth column
//                Swift.print(mat[j][i])
//            }
//        }
//    }
}
