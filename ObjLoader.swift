//
//  ObjLoader.swift
//  SwiftObjLoader
//
//  Created by Hugo Tunius on 02/09/15.
//  Copyright © 2015 Hugo Tunius. All rights reserved.
//

import Foundation

enum ObjLoadingError: Error {
    case UnexpectedFileFormat(error: String)
}


public final class ObjLoader {
    // Represent the state of parsing
    // at any point in time
    class State {
        var objectName: NSString?
        var vertices: [Vector] = []
        var normals: [Vector] = []
        var textureCoords: [Vector] = []
        var faces: [[VertexIndex]] = []
//        var material: Material?
    }

    // Source markers
    private static let commentMarker = NSString(string: "#").character(at: 0)
    private static let vertexMarker = NSString(string: "v").character(at: 0)
    private static let normalMarker = "vn"
    private static let textureCoordMarker = "vt"
    private static let objectMarker = NSString(string: "o").character(at: 0)
    private static let groupMarker = NSString(string: "g").character(at: 0)
    private static let faceMarker = NSString(string: "f").character(at: 0)
//    private static let materialLibraryMarker = "mtllib"
//    private static let useMaterialMarker = "usemtl"

    private let scanner: ObjScanner
    private let basePath: NSString
//    private var materialCache: [NSString: Material] = [:]

    private var state = State()
    private var vertexCount = 0
    private var normalCount = 0
    private var textureCoordCount = 0

    // Init an objloader with the
    // source of the .obj file as a string
    //
    public init(source: String, basePath: NSString) {
        scanner = ObjScanner(source: source)
        self.basePath = basePath
    }

    // Read the specified source.
    // This operation is singled threaded and
    // should not be invoked again before
    // the call has returned
    public func read() throws -> [Shape] {
        var shapes: [Shape] = []

        resetState()

        do {
            while scanner.dataAvailable {
                let marker = scanner.readMarker()

                guard let m = marker, m.length > 0 else {
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isComment(marker: m) {
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isVertex(marker: m) {
                    if let v = try readVertex() {
                        state.vertices.append(v)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isNormal(marker: m) {
                    if let n = try readVertex() {
                        state.normals.append(n)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isTextureCoord(marker: m) {
                    if let vt = scanner.readTextureCoord() {
                        state.textureCoords.append(vt)
                    }

                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isObject(marker: m) {
                    if let s = buildShape() {
                        shapes.append(s)
                    }

                    state = State()
                    state.objectName = scanner.readLine()
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isGroup(marker: m) {
                    if let s = buildShape() {
                        shapes.append(s)
                    }

                    state = State()
                    state.objectName = try scanner.readString()
                    scanner.moveToNextLine()
                    continue
                }

                if ObjLoader.isFace(marker: m) {
                    if let indices = try scanner.readFace() {
                        state.faces.append(normalizeVertexIndices(unnormalizedIndices: indices))
                    }

                    scanner.moveToNextLine()
                    continue
                }

//                if ObjLoader.isMaterialLibrary(marker: m) {
//                    let filenames = try scanner.readTokens()
//                    try parseMaterialFiles(filenames: filenames)
//                    scanner.moveToNextLine()
//                    continue
//                }

//                if ObjLoader.isUseMaterial(marker: m) {
//                    let materialName = try scanner.readString()
//
//                    guard let material = self.materialCache[materialName] else {
//                        throw ObjLoadingError.UnexpectedFileFormat(error: "Material \(materialName) referenced before it was definied")
//                    }
//
//                    state.material = material
//                    scanner.moveToNextLine()
//                    continue
//                }

                scanner.moveToNextLine()
            }

            if let s = buildShape() {
                shapes.append(s)
            }
            state = State()
        } catch let e {
            resetState()
            throw e
        }
        return shapes
    }

    private static func isComment(marker: NSString) -> Bool {
        return marker.character(at: 0) == commentMarker
    }

    private static func isVertex(marker: NSString) -> Bool {
        return marker.length == 1 && marker.character(at: 0) == vertexMarker
    }

    private static func isNormal(marker: NSString) -> Bool {
        return marker.length == 2 && marker.substring(to: 2) == normalMarker
    }

    private static func isTextureCoord(marker: NSString) -> Bool {
        return marker.length == 2 && marker.substring(to: 2) == textureCoordMarker
    }

    private static func isObject(marker: NSString) -> Bool {
        return marker.length == 1 && marker.character(at: 0) == objectMarker
    }

    private static func isGroup(marker: NSString) -> Bool {
        return marker.length == 1 && marker.character(at: 0) == groupMarker
    }

    private static func isFace(marker: NSString) -> Bool {
        return marker.length == 1 && marker.character(at: 0) == faceMarker
    }

//    private static func isMaterialLibrary(marker: NSString) -> Bool {
//        return marker as String == materialLibraryMarker
//    }

//    private static func isUseMaterial(marker: NSString) -> Bool {
//        return marker as String == useMaterialMarker
//    }

    private func readVertex() throws -> [Double]? {
        do {
            return try scanner.readVertex()
        } catch ScannerErrors.UnreadableData(let error) {
            throw ObjLoadingError.UnexpectedFileFormat(error: error)
        }
    }

    private func resetState() {
        scanner.reset()
        state = State()
        vertexCount = 0
        normalCount = 0
        textureCoordCount = 0
    }

    private func buildShape() -> Shape? {
        if state.vertices.count == 0 && state.normals.count == 0 && state.textureCoords.count == 0 {
            return nil
        }


        let result =  Shape(name: (state.objectName as String?), vertices: state.vertices, normals: state.normals, textureCoords: state.textureCoords, faces: state.faces)
        vertexCount += state.vertices.count
        normalCount += state.normals.count
        textureCoordCount += state.textureCoords.count

        return result
    }

    private func normalizeVertexIndices(unnormalizedIndices: [VertexIndex]) -> [VertexIndex] {
        return unnormalizedIndices.map {
            return VertexIndex(vIndex: ObjLoader.normalizeIndex(index: $0.vIndex, count: vertexCount),
                               nIndex: ObjLoader.normalizeIndex(index: $0.nIndex, count: normalCount),
                               tIndex: ObjLoader.normalizeIndex(index: $0.tIndex, count: textureCoordCount))
        }
    }

    private static func normalizeIndex(index: Int?, count: Int) -> Int? {
        guard let i = index else {
            return nil
        }

        if i == 0 {
            return 0
        }

        return i - count - 1
    }
}
