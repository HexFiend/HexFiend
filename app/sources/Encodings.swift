//
//  Encodings.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 10/11/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import Foundation

class Encodings: NSObject {
    private var chooseStringEncoding: ChooseStringEncodingWindowController?

    var menuSystemEncodingsNumbers: [NSNumber] {
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
    
    @objc func menuSystemEncodings() -> [HFNSStringEncoding] {
        let encodingManager = HFEncodingManager.shared()
        return menuSystemEncodingsNumbers.compactMap { encoding in
            guard let encodingObj = encodingManager.systemEncoding(encoding.uintValue) else {
                print("Unknown encoding \(encoding)")
                return nil
            }
            return encodingObj
        }.sorted {
            $0.name < $1.name
        }
    }
    
    @objc func showEncodingsWindow() {
        let choose: ChooseStringEncodingWindowController
        if let chooseStringEncoding {
            choose = chooseStringEncoding
        } else {
            choose = ChooseStringEncodingWindowController()
            self.chooseStringEncoding = choose
        }
        choose.showWindow(nil)
    }
    
    @objc func reloadEncodingsWindowIfLoaded() {
        if let chooseStringEncoding {
            chooseStringEncoding.reload()
        }
    }
}
