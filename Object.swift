import Foundation
import Metal

class Object
{
    private var vertices: [AAPLVertex] = []
    public var material: Material
    public var active = false
    init(source: String, mat: Material) {
        material = mat
        initShape(source: source)
    }
    
    func initShape(source: String) {
        var shapes: [Shape]
        do {
            let fixtureHelper = FixtureHelper()
            let source = try? fixtureHelper.loadObjFixture(name: source)
            let loader = ObjLoader(source: source!, basePath: fixtureHelper.resourcePath as NSString)
            shapes = try loader.read()
        } catch let e {
            print(e)
            exit(0) // terminate the app!
        }
        for i in 0...(shapes[0].faces.count - 1) { // loop over faces in the shape
            for j in 0...(shapes[0].faces[i].count - 1) { // loop over each vertex in the current face
                vertices.append(AAPLVertex(position: float4(Float(shapes[0].vertices[shapes[0].faces[i][j].vIndex!][0]),
                                                            Float(shapes[0].vertices[shapes[0].faces[i][j].vIndex!][1]),
                                                            Float(shapes[0].vertices[shapes[0].faces[i][j].vIndex!][2]),
                                                            1.0),
                                           normal: float4(Float(shapes[0].normals[shapes[0].faces[i][j].nIndex!][0]),
                                                          Float(shapes[0].normals[shapes[0].faces[i][j].nIndex!][1]),
                                                          Float(shapes[0].normals[shapes[0].faces[i][j].nIndex!][2]),
                                                          0.0),
                                           texCoord: float2(Float(shapes[0].textureCoords[shapes[0].faces[i][j].tIndex!][0]),
                                                            Float(shapes[0].textureCoords[shapes[0].faces[i][j].tIndex!][1])),
                                           color: float4(1)))
            }
        }
    }
    
    public func setMaterial(mat: Material) { material = mat }
    
    public func draw(device: MTLDevice, renderEncoder: MTLRenderCommandEncoder) {
        let dataSize = MemoryLayout.size(ofValue: vertices[0]) * vertices.count
        let vertexBuffer = device.makeBuffer(bytes: vertices, length: dataSize, options: [])
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count, instanceCount: 1)
    }
    
    public func toggle() {
        active = !active
    }
}
