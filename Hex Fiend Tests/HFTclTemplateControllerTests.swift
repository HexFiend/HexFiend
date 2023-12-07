//
//  HFTclTemplateControllerTests.swift
//  Hex Fiend Tests
//
//  Created by Kevin Wojniak on 12/5/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import XCTest

extension HFRange: Equatable {
    public static func == (lhs: HFRange, rhs: HFRange) -> Bool {
        HFRangeEqualsRange(lhs, rhs)
    }
}

private struct Node: Equatable {
    let label: String?
    let value: String?
    let isGroup: Bool
    let range: HFRange
    
    init(label: String?, value: String?, isGroup: Bool, range: HFRange) {
        self.label = label
        self.value = value
        self.isGroup = isGroup
        self.range = range
    }
    
    init(_ label: String, _ value: String?, isGroup: Bool = false, _ range: HFRange) {
        self.init(label: label, value: value, isGroup: isGroup, range: range)
    }
    
    init(_ label: String, _ value: String?, isGroup: Bool = false, _ range: (location: Int, length: Int)) {
        self.init(label: label, value: value, isGroup: isGroup, range: .init(location: UInt64(range.location), length: UInt64(range.length)))
    }
}

final class HFTclTemplateControllerTests: XCTestCase {
    private func evaluate(_ hexBytes: String, _ tclScript: String) throws -> (error: NSString?, root: HFTemplateNode, nodes: [Node]) {
        let uuid = UUID().uuidString
        let url = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent("\(uuid).tcl")
        try tclScript.write(to: url, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: url)
        }

        let controller = HFController()
        var missing = ObjCBool(false)
        let data = try XCTUnwrap((HFDataFromHexString(hexBytes, &missing) as NSData).mutableCopy() as? NSMutableData)
        let byteSlice = HFSharedMemoryByteSlice(data: data)
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(byteSlice, in: HFRangeMake(0, 0))
        controller.byteArray = byteArray
        
        var error: NSString?
        let template = HFTclTemplateController()
        let root = template.evaluateScript(url.path, for: controller, error: &error)
        let rootChildren = try XCTUnwrap(root.children as? [HFTemplateNode])
        let nodes: [Node] = rootChildren.map { node in
                .init(label: node.label, value: node.value, isGroup: node.isGroup, range: node.range)
        }
        return (error, root, nodes)
    }

    private func assertNodes(_ hexBytes: String,
                             _ tclScript: String,
                             _ expected: [Node]) throws {
        let result = try evaluate(hexBytes, tclScript)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.nodes, expected)
    }

    func testUInt32() throws {
        let script = """
uint32 "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "4022250974", (0, 4))])
    }
    
    func testLittleEndianUInt32() throws {
        let script = """
little_endian
uint32 "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "4022250974", (0, 4))])
    }
    
    func testBigEndianUInt32() throws {
        let script = """
big_endian
uint32 "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "3735928559", (0, 4))])
    }
    
    func testUInt32Hex() throws {
        let script = """
uint32 -hex "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "0xEFBEADDE", (0, 4))])
    }

    func testUInt32NoLabelWithEntry() throws {
        let script = """
set magic [uint32]
entry "Magic" $magic
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "4022250974", (0, 0))])
    }

    func testUInt32UnknownOption() throws {
        let script = """
uint32 -asdf "Magic"
"""
        let result = try evaluate("DEADBEEF", script)
        XCTAssertTrue(try XCTUnwrap(result.error).hasPrefix("Unknown option -asdf"))
        XCTAssertEqual(result.nodes, [])
    }

    func testUInt32WithCommand() throws {
        let script = """
proc myproc {value} {
    return "abc-$value-123"
}

uint32 -cmd myproc "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "abc-4022250974-123", (0, 4))])
    }

    func testUInt32HexWithCommand() throws {
        let script = """
proc myproc {value} {
    return "abc-$value-123"
}

uint32 -hex -cmd myproc "Magic"
"""
        try assertNodes("DEADBEEF", script,
                        [.init("Magic", "abc-0xEFBEADDE-123", (0, 4))])
    }

}
