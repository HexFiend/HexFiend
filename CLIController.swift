//
//  CLIController.swift
//  HexFiend_2
//
//  Created as CLIController.m by Kevin Wojniak on 2013/3/19.
//  Converted to CLIController.swift by Reed Harston on 11/7/22.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

import Cocoa

@objc class CLIController: NSObject {
    private func runAlert(messageText: String) {
        let alert = NSAlert()
        alert.messageText = messageText
        alert.runModal()
    }
    
    @IBAction func installCommandLineTools(_: Any) {
        let fileName = "hexf"
        
        guard let srcFile = Bundle.main.path(forResource: fileName, ofType: nil),
              let destDir = URL(string: "/usr/local/bin") else {
            self.runAlert(messageText: "The \(fileName) tool failed to install.")
            return
        }
            
        let destFile = destDir.appendingPathComponent(fileName).absoluteString
        
        let cmd = "mkdir -p \\\"\(destDir.absoluteString)\\\" && ln -fs \\\"\(srcFile)\\\" \\\"\(destFile)\\\" && chmod 755 \\\"\(destFile)\\\""
        let script = "do shell script \"\(cmd)\" with administrator privileges"
        let appleScript = NSAppleScript(source: script)
        
        var errInfo: NSDictionary?
        // NOTE: running this in Debug mode in Xcode often hangs and fails
        guard appleScript?.executeAndReturnError(&errInfo) != nil else {
            if let errInfo = errInfo {
                if let errNum = errInfo[NSAppleScript.errorNumber] as? NSNumber,
                   errNum.intValue == -128 {
                    // User cancelled
                    return
                }
                if let errMsg = errInfo[NSAppleScript.errorMessage] as? String {
                    self.runAlert(messageText: errMsg)
                }
            }
            return
        }
        
        if false {
            // if NSAppleScript above turns out problematic, try the osascript variant instead
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            let standardErrorPipe = Pipe()
            task.standardError = standardErrorPipe
            do {
                if #available(macOS 10.13, *) {
                    try task.run()
                } else {
                    // Use a special wrapper to catch Obj-C exceptions that Swift cannot catch.
                    try ObjC.catchException { task.launch() }
                }
            } catch {
                self.runAlert(messageText: "Failed to run command.")
                return
            }
            task.waitUntilExit()

            let standardErrorFile = standardErrorPipe.fileHandleForReading
            let standardErrorData = standardErrorFile.readDataToEndOfFile()

            if task.terminationStatus != 0,
               let standardErrorStr = String(data: standardErrorData, encoding: .utf8) {
                if standardErrorStr.range(of: "User canceled", options: [.caseInsensitive]) != nil {
                    self.runAlert(messageText: "The \(fileName) tool failed to install (\(standardErrorStr)).")
                    return
                } else {
                    // If the error message included User canceled then just return so we don't get to the
                    // "successfully installed" bit below
                    return
                }
            }
        }
        
        self.runAlert(messageText: "\(fileName) has been successfully installed.")
    }
}

#if MacAppStore
// NSMenuItemValidation conformance is required for validateMenuItem(_:) to be called
extension CLIController: NSMenuItemValidation {
    // We cannot install hexf in MAS builds.
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(installCommandLineTools(_:)) {
            item.isHidden = true
            return false
        }
        return true
    }
}
#endif
