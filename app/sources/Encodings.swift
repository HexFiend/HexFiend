//
//  Encodings.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 10/11/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import Foundation

class Encodings: NSObject {
    @objc var menuSystemEncodingsNumbers: [NSNumber] {
        get {
            if let encodingsFromDefaults = UserDefaults.standard.object(forKey: "MenuSystemEncodings") as? [NSNumber] {
                return encodingsFromDefaults
            }
            return [
                NSASCIIStringEncoding,
                NSMacOSRomanStringEncoding,
                NSISOLatin1StringEncoding,
                NSISOLatin2StringEncoding,
                NSUTF16LittleEndianStringEncoding,
                NSUTF16BigEndianStringEncoding,
            ].map {
                $0 as NSNumber
            }
        }
        set(newEncodings) {
            UserDefaults.standard.set(newEncodings, forKey: "MenuSystemEncodings")
            AppDelegate.shared.buildEncodingMenu()
        }        
    }
}
