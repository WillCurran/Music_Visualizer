//
//  Scanner.swift
//  SwiftObjLoader
//
//  Created by Hugo Tunius on 07/09/15.
//  Copyright © 2015 Hugo Tunius. All rights reserved.
//

import Foundation

enum ScannerErrors: Error {
    case UnreadableData(error: String)
    case InvalidData(error: String)
}

// A general Scanner for .obj and .tml files
class ScannerGeneral {
    var dataAvailable: Bool {
        get {
            return false == scanner.isAtEnd
        }
    }

    let scanner: Scanner
    let source: String

    init(source: String) {
        scanner = Scanner(string: source)
        self.source = source
        scanner.charactersToBeSkipped = NSCharacterSet.whitespaces
    }

    func moveToNextLine() {
        scanner.scanUpToCharacters(from: NSCharacterSet.newlines, into: nil)
        scanner.scanCharacters(from: NSCharacterSet.whitespacesAndNewlines, into: nil)
    }

    // Read from current scanner location up to the next
    // whitespace
    func readMarker() -> NSString? {
        var marker: NSString?
        scanner.scanUpToCharacters(from: NSCharacterSet.whitespaces, into: &marker)

        return marker
    }

    // Read rom the current scanner location till the end of the line
    func readLine() -> NSString? {
        var string: NSString?
        scanner.scanUpToCharacters(from: NSCharacterSet.newlines, into: &string)
        return string
    }

    // Read a single Int32 value
    func readInt() throws -> Int32 {
        var value = Int32.max
        if scanner.scanInt32(&value) {
            return value
        }

        throw ScannerErrors.InvalidData(error: "Invalid Int value")
    }

    // Read a single Double value
    func readDouble() throws -> Double {
        var value = Double.infinity
        if scanner.scanDouble(&value) {
            return value
        }

        throw ScannerErrors.InvalidData(error: "Invalid Double value")
    }


    func readString() throws -> NSString {
        var string: NSString?

        scanner.scanUpToCharacters(from: NSCharacterSet.whitespacesAndNewlines, into: &string)

        if let string = string {
            return string
        }

        throw ScannerErrors.InvalidData(error: "Invalid String value")
    }

    func readTokens() throws -> [NSString] {
        var string: NSString?
        var result: [NSString] = []

        while scanner.scanUpToCharacters(from: NSCharacterSet.whitespacesAndNewlines, into: &string) {
            result.append(string!)
        }

        return result
    }

    func reset() {
        scanner.scanLocation = 0
    }
}

// A Scanner with specific logic for .obj
// files. Inherits common logic from Scanner
final class ObjScanner: ScannerGeneral {
    // Parses face declarations
    //
    // Example:
    //
    //     f v1/vt1/vn1 v2/vt2/vn2 ....
    //
    // Possible cases
    // v1//
    // v1//vn1
    // v1/vt1/
    // v1/vt1/vn1
    func readFace() throws -> [VertexIndex]? {
        var result: [VertexIndex] = []
        while true {
            var v, vn, vt: Int?
            var tmp: Int32 = -1

            guard scanner.scanInt32(&tmp) else {
                break
            }
            v = Int(tmp)

            guard scanner.scanString("/", into: nil) else {
                throw ObjLoadingError.UnexpectedFileFormat(error: "Lack of '/' when parsing face definition, each vertex index should contain 2 '/'")
            }

            if scanner.scanInt32(&tmp) { // v1/vt1/
                vt = Int(tmp)
            }
            guard scanner.scanString("/", into: nil) else {
                throw ObjLoadingError.UnexpectedFileFormat(error: "Lack of '/' when parsing face definition, each vertex index should contain 2 '/'")
            }

            if scanner.scanInt32(&tmp) {
                vn = Int(tmp)
            }

            result.append(VertexIndex(vIndex: v, nIndex: vn, tIndex: vt))
        }

        return result
    }

    // Read 3(optionally 4) space separated double values from the scanner
    // The fourth w value defaults to 1.0 if not present
    // Example:
    //  19.2938 1.29019 0.2839
    //  1.29349 -0.93829 1.28392 0.6
    //
    func readVertex() throws -> [Double]? {
        var x = Double.infinity
        var y = Double.infinity
        var z = Double.infinity
        var w = 1.0

        guard scanner.scanDouble(&x) else {
            throw ScannerErrors.UnreadableData(error: "Bad vertex definition missing x component")
        }

        guard scanner.scanDouble(&y) else {
            throw ScannerErrors.UnreadableData(error: "Bad vertex definition missing y component")
        }

        guard scanner.scanDouble(&z) else {
            throw ScannerErrors.UnreadableData(error: "Bad vertex definition missing z component")
        }

        scanner.scanDouble(&w)

        return [x, y, z, w]
    }

    // Read 1, 2 or 3 texture coords from the scanner
    func readTextureCoord() -> [Double]? {
        var u = Double.infinity
        var v = 0.0
        var w = 0.0

        guard scanner.scanDouble(&u) else {
            return nil
        }

        if scanner.scanDouble(&v) {
            scanner.scanDouble(&w)
        }
        
        return [u, v, w]
    }
}
