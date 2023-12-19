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
    let children: [Node]

    init(label: String?, value: String?, isGroup: Bool, range: HFRange, children: [Node] = []) {
        self.label = label
        self.value = value
        self.isGroup = isGroup
        self.range = range
        self.children = children
    }
    
    init(_ label: String, _ value: String?, isGroup: Bool = false, _ range: HFRange) {
        self.init(label: label, value: value, isGroup: isGroup, range: range)
    }
    
    init(_ label: String,
         _ value: String?,
         isGroup: Bool = false,
         _ range: (location: Int, length: Int),
         _ children: [Node] = []) {
        self.init(label: label,
                  value: value,
                  isGroup: isGroup,
                  range: .init(location: UInt64(range.location), length: UInt64(range.length)),
                  children: children)
    }

    static func group(_ label: String,
                      _ value: String?,
                      _ range: (location: Int, length: Int),
                      _ children: [Node] = []) -> Self {
        .init(label, value, isGroup: true, range, children)
    }
}

final class HFTclTemplateControllerTests: XCTestCase {
    private func childrenToNode(_ children: NSMutableArray) throws -> [Node] {
        let children = try XCTUnwrap(children as? [HFTemplateNode])
        let nodes: [Node] = try children.map { node in
            return Node(label: node.label,
                        value: node.value,
                        isGroup: node.isGroup,
                        range: node.range,
                        children: try childrenToNode(node.children)
            )
        }
        return nodes
    }

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
        let nodes = try childrenToNode(root.children)
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

    func testSection() throws {
        let script = """
section A {
}
"""
        try assertNodes("", script, [
            .group("A", nil, (0, 0)),
        ])
    }

    func testNestedSections() throws {
        let script = """
section A {
    section B {
    }
}
"""
        try assertNodes("", script, [
            .group("A", nil, (0, 0), [
                .group("B", nil, (0, 0)),
            ]),
        ])
    }

    func testNestedSectionsErrors() throws {
        let script = """
proc parse_blah {} {
    section A {
        section B {
            error "Oops"
        }
    }
}
entry top 1
if {[catch parse_blah]} { entry "Error" $errorInfo }
entry top 2
"""
        let errorInfo = """
Oops
    while executing
\"error \"Oops\"\"
    invoked from within
\"section B {
            error \"Oops\"
        }\"
    invoked from within
\"section A {
        section B {
            error \"Oops\"
        }
    }\"
    (procedure \"parse_blah\" line 2)
    invoked from within
\"parse_blah\"
"""
        try assertNodes("", script, [
            .init("top", "1", (0, 0)),
            .group("A", nil, (0, 0), [
                .group("B", nil, (0, 0)),
            ]),
            .init("Error", errorInfo, (0, 0)),
            .init("top", "2", (0, 0)),
        ])
    }

    /// Format a date like HFTemplateController
    private func formatDate(_ date: Date, utcOffset: Int? = nil) -> String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        if let utcOffset {
            formatter.timeZone = NSTimeZone(forSecondsFromGMT: utcOffset) as TimeZone
        }
        return formatter.string(from: date)
    }

    func testMacDate() throws {
        let script = """
macdate Date
"""
        let date = try XCTUnwrap(HFTemplateController.convertMacDateSeconds(0))
        try assertNodes("00000000", script,
                        [.init("Date", formatDate(date), (0, 4))])
    }

    func testMacDateHexError() throws {
        let script = """
macdate -hex Date
"""
        let result = try evaluate("00000000", script)
        XCTAssertTrue(try XCTUnwrap(result.error).hasPrefix("Unknown option -hex"))
        XCTAssertEqual(result.nodes, [])
    }

    func testMacDateUtcOffset() throws {
        let script = """
macdate -utcOffset 0 Date
"""
        let date = try XCTUnwrap(HFTemplateController.convertMacDateSeconds(0))
        try assertNodes("00000000", script,
                        [.init("Date", formatDate(date, utcOffset: 0), (0, 4))])
    }

    func testUnixTime() throws {
        let date = formatDate(Date(timeIntervalSince1970: 0))
        let script32 = """
unixtime32 Date
"""
        try assertNodes("00000000", script32,
                        [.init("Date", date, (0, 4))])
        let script64 = """
unixtime64 Date
"""
        try assertNodes("0000000000000000", script64,
                        [.init("Date", date, (0, 8))])
    }

    func testUnixTimeUtcOffset() throws {
        let date = formatDate(Date(timeIntervalSince1970: 0), utcOffset: 0)
        let script32 = """
unixtime32 -utcOffset 0 Date
"""
        try assertNodes("00000000", script32,
                        [.init("Date", date, (0, 4))])
        let script64 = """
unixtime64 -utcOffset 0 Date
"""
        try assertNodes("0000000000000000", script64,
                        [.init("Date", date, (0, 8))])
    }

}
