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

final class HFTclTemplateControllerTests: XCTestCase {
    private func evaluate(_ hexBytes: String, _ tclScript: String) throws -> (error: NSString?, root: HFTemplateNode) {
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
        return (error, root)
    }
    
    func testUInt32WithLabel() throws {
        let result = try evaluate("DEADBEEF", "uint32 Magic")
        XCTAssertNil(result.error)
        XCTAssertTrue(result.root.isGroup)
        XCTAssertEqual(result.root.children.count, 1)
        let node = try XCTUnwrap(result.root.children[0] as? HFTemplateNode)
        XCTAssertEqual(node.label, "Magic")
        XCTAssertEqual(node.value, "4022250974")
        XCTAssertEqual(node.range, HFRangeMake(0, 4))
        XCTAssertFalse(node.isGroup)
    }
}
