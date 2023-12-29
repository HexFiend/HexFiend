//
//  HFByteTheme.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/21/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import Foundation

private extension NSColor {
    func toRGB() -> NSColor {
        guard let rgb = usingType(.componentBased) else {
            fatalError("Can't convert color to calibratedRGB")
        }
        return rgb
    }
}

extension HFByteTheme {
    @objc static func from(url: URL) -> Self? {
        guard #available(macOS 12, *) else {
            print("Byte themes only available on macOS 12 and later.")
            return nil
        }
        let topDict: NSDictionary
        do {
            let data = try Data(contentsOf: url)
            guard let dict = try JSONSerialization.jsonObject(with: data, options: [.json5Allowed]) as? NSDictionary else {
                print("Top-level object not a dictionary at \(url)")
                return nil
            }
            topDict = dict
        } catch {
            print("Invalid json at \(url): \(error)")
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
        let theme = Self()
        theme.darkColorTable = .init(mutating: Self.colorTableToPointer(Self.colorTableFromDict(darkDict)))
        theme.lightColorTable = .init(mutating: Self.colorTableToPointer(Self.colorTableFromDict(lightDict)))
        return theme
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
    mainLoop: for b in 0..<table.count {
            let substitutionVars = ["b": b]
            for item in custom {
                for (formatStr, colorValue) in item {
                    var evaluated = false
                    if let exception = HFTry({
                        let predicate = NSPredicate(format: formatStr)
                        evaluated = predicate.evaluate(with: nil, substitutionVariables: substitutionVars)
                    }) {
                        print("Predicate error: \(exception)")
                        continue
                    }
                    if evaluated, let color = Self.valueToColor(colorValue: colorValue) {
                        table[b] = Self.nscolorToThemeColor(color)
                        continue mainLoop
                    }
                }
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
    
    private static var namesToColors: [String: NSColor?] = {
        var map: [String: NSColor] = [
            "black": .black.toRGB(),
            "blue": .blue.toRGB(),
            "brown": .brown.toRGB(),
            "clear": .clear.toRGB(),
            "cyan": .cyan.toRGB(),
            "darkGray": .darkGray.toRGB(),
            "gray": .gray.toRGB(),
            "green": .green.toRGB(),
            "lightGray": .lightGray.toRGB(),
            "magenta": .magenta.toRGB(),
            "orange": .orange.toRGB(),
            "purple": .purple.toRGB(),
            "red": .red.toRGB(),
            "systemBlue": .systemBlue.toRGB(),
            "systemBrown": .systemBrown.toRGB(),
            "systemGray": .systemGray.toRGB(),
            "systemGreen": .systemGreen.toRGB(),
            "systemMint": .systemMint.toRGB(),
            "systemOrange": .systemOrange.toRGB(),
            "systemPink": .systemPink.toRGB(),
            "systemPurple": .systemPurple.toRGB(),
            "systemRed": .systemRed.toRGB(),
            "systemTeal": .systemTeal.toRGB(),
            "systemYellow": .systemYellow.toRGB(),
            "white": .white.toRGB(),
            "yellow": .yellow.toRGB(),
        ]
        if #available(macOS 10.15, *) {
            map["systemIndigo"] = .systemIndigo.toRGB()
        }
        if #available(macOS 12, *) {
            map["systemCyan"] = .systemCyan.toRGB()
        }
        return map
    }()
    
    private static func valueToColor(colorValue: Any) -> NSColor? {
        switch colorValue {
        case let colorString as String:
            guard let color = Self.namesToColors[colorString] else {
                print("Unknown color \(colorString)")
                return nil
            }
            return color
        case let colorNumber as UInt:
            return uintToColor(value: colorNumber)
        default:
            print("Unknown color value \(colorValue)")
            return nil
        }
    }
    
    private static func uintToColor(value: UInt) -> NSColor {
        let red = CGFloat((value & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((value & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat((value & 0x0000FF)) / 255.0
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0).toRGB()
    }
    
    private static func nscolorToThemeColor(_ color: NSColor) -> HFByteThemeColor {
        var r = CGFloat.zero
        var g = CGFloat.zero
        var b = CGFloat.zero
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return HFByteThemeColor(r: r, g: g, b: b, set: true)
    }
}
