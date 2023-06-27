//
//  HFByteTheme.swift
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/21/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import Foundation

private extension NSColor {
    func toRGB() -> NSColor {
        guard let rgb = self.usingColorSpaceName(.calibratedRGB) else {
            fatalError("Can't convert color to calibratedRGB")
        }
        return rgb
    }
}

@objc public class HFByteTheme: NSObject {
    @objc public let darkColorTable: UnsafePointer<HFByteThemeColor>
    @objc public let lightColorTable: UnsafePointer<HFByteThemeColor>

    @objc public init?(url: URL) {
        guard #available(macOS 12, *) else {
            print("Byte themes only available on macOS 12 and later.")
            return nil
        }
        guard let data = try? Data(contentsOf: url),
              let topDict = try? JSONSerialization.jsonObject(with: data, options: [.json5Allowed]) as? NSDictionary else {
            print("Invalid json at \(url)")
            return nil
        }
        guard let darkDict = topDict["dark"] as? NSDictionary else {
            print("Invalid \"dark\" at \(url))!")
            return nil
        }
        guard let lightDict = topDict["light"] as? NSDictionary else {
            print("Invalid \"light\" at \(url))!")
            return nil
        }
        self.darkColorTable = Self.colorTableToPointer(Self.colorTableFromDict(darkDict))
        self.lightColorTable = Self.colorTableToPointer(Self.colorTableFromDict(lightDict))
    }

    private static func colorTableToPointer(_ table: [HFByteThemeColor]) -> UnsafePointer<HFByteThemeColor> {
        let pointer = UnsafeMutablePointer<HFByteThemeColor>.allocate(capacity: table.count)
        pointer.initialize(from: table, count: table.count)
        return UnsafePointer<HFByteThemeColor>(pointer)
    }
    
    private static let whitespace: Set = [
        UnicodeScalar(" ").value,
        UnicodeScalar("\n").value,
        UnicodeScalar("\r").value,
        UnicodeScalar("\t").value,
    ]
    
    private static func colorTableFromDict(_ dict: NSDictionary) -> [HFByteThemeColor] {
        var table = [HFByteThemeColor](repeating: .init(), count: 256)
        var custom: [[String: String]] = []
        if let customDict = dict["custom"] as? [[String: String]] {
            custom = customDict
        }
        for b in 0..<table.count {
            let substitutionVars = ["b": b]
            var setCustom = false
            for item in custom {
                for (formatStr, colorValue) in item {
                    // TODO: handle exceptions
                    let predicate = NSPredicate(format: formatStr)
                    if predicate.evaluate(with: nil, substitutionVariables: substitutionVars) {
                        if let color = Self.valueToColor(colorValue: colorValue) {
                            table[b] = Self.nscolorToThemeColor(color)
                            setCustom = true
                            break
                        }
                    }
                }
            }
            if setCustom {
                continue
            }
            let key: String
            if whitespace.contains(UInt32(b)) {
                key = "whitespace"
            } else if b >= 33 && b <= 126 {
                key = "printable"
            } else if b == 0 {
                key = "null"
            } else if (b & 0x80) != 0 {
                key = "extended"
            } else {
                key = "other"
            }
            guard let colorValue = dict[key],
                  let color = Self.valueToColor(colorValue: colorValue) else {
                continue
            }
            table[b] = Self.nscolorToThemeColor(color)
        }
        return table
    }
    
    private static var _namesToColors: [String: NSColor?]?
    private static var namesToColors: [String: NSColor?] {
        if let namesToColors = Self._namesToColors {
            return namesToColors
        }
        var map: [String: NSColor] = [
            "darkGray": .darkGray.toRGB(),
            "systemGreen": .systemGreen.toRGB(),
            "systemYellow": .systemYellow.toRGB(),
            "systemRed": .systemRed.toRGB(),
            "systemPurple": .systemPurple.toRGB(),
            "systemBlue": .systemBlue.toRGB(),
            "systemOrange": .systemOrange.toRGB(),
            "systemBrown": .systemBrown.toRGB(),
            "systemPink": .systemPink.toRGB(),
            "systemGray": .systemGray.toRGB(),
            "systemTeal": .systemTeal.toRGB(),
            "systemMint": .systemMint.toRGB(),
        ]
        if #available(macOS 10.15, *) {
            map["systemIndigo"] = .systemIndigo.toRGB()
        }
        if #available(macOS 12, *) {
            map["systemCyan"] = .systemCyan.toRGB()
        }
        Self._namesToColors = map
        return map
    }
    
    private static func valueToColor(colorValue: Any) -> NSColor? {
        if let colorString = colorValue as? String {
            guard let color = Self.namesToColors[colorString] else {
                print("Unknown color \(colorString)")
                return nil
            }
            return color
        } else if let colorNumber = colorValue as? UInt {
            let red = CGFloat((colorNumber & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((colorNumber & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat((colorNumber & 0x0000FF)) / 255.0
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0).toRGB()
        } else {
            print("Unknown color value \(colorValue)")
        }
        return nil
    }
    
    private static func nscolorToThemeColor(_ color: NSColor) -> HFByteThemeColor {
        var r = CGFloat.zero
        var g = CGFloat.zero
        var b = CGFloat.zero
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return HFByteThemeColor(r: r, g: g, b: b)
    }
}
