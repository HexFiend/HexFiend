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
        //        NSString *srcFile = [[NSBundle mainBundle] pathForResource:@"hexf" ofType:nil];
        //        NSString *destDir = @"/usr/local/bin";
        //        NSString *destFile = [destDir stringByAppendingPathComponent:[srcFile lastPathComponent]];
        
        let fileName = "hexf"
        
        if let srcFile = Bundle.main.path(forResource: fileName, ofType: nil) {
            print("🥁 srcFile: \(srcFile)")
            if let destDir = URL(string: "/usr/local/bin") {
                print("🥁 destDir: \(destDir.absoluteString)")
                
                let destFile = destDir.appendingPathComponent(fileName).absoluteString
                print("🥁 destFile: \(destFile)")
                //        NSString *cmd = [NSString stringWithFormat:@"mkdir -p \\\"%@\\\" && ln -fs \\\"%@\\\" \\\"%@\\\" && chmod 755 \\\"%@\\\"",
                //            destDir, srcFile, destFile, destFile];
                let cmd = "mkdir -p \\\"\(destDir.absoluteString)\\\" && ln -fs \\\"\(srcFile)\\\" \\\"\(destFile)\\\" && chmod 755 \\\"\(destFile)\\\""
                print("🥁 cmd: \(cmd)")
                
                let script = "do shell script \"\(cmd)\" with administrator privileges"
                print("🥁 script: \(script)")
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
                
//                if (0) {
//                    // if NSAppleScript above turns out problematic, try the osascript variant instead
//                    NSTask *task = [[NSTask alloc] init];
//                    task.launchPath = @"/usr/bin/osascript";
//                    task.arguments = @[@"-e", script];
//                    NSPipe *standardErrorPipe = [NSPipe pipe];
//                    task.standardError = standardErrorPipe;
//                    @try {
//                        [task launch];
//                    } @catch (NSException *ex) {
//                        [self runAlert:[NSString stringWithFormat:NSLocalizedString(@"Failed to run command: %@", nil), ex]];
//                        return;
//                    }
//                    [task waitUntilExit];
//                    NSFileHandle *standardErrorFile = [standardErrorPipe fileHandleForReading];
//                    NSData *standardErrorData = [standardErrorFile readDataToEndOfFile];
//                    if (task.terminationStatus != 0) {
//                        NSString *standardErrorStr = [[NSString alloc] initWithData:standardErrorData encoding:NSUTF8StringEncoding];
//                        if ([standardErrorStr rangeOfString:@"User canceled" options:NSCaseInsensitiveSearch].location != NSNotFound) {
//                            return;
//                        }
//                        [self runAlert:[NSString stringWithFormat:NSLocalizedString(@"The %@ tool failed to install (%@).", ""), [srcFile lastPathComponent], standardErrorStr]];
//                        return;
//                    }
//                }
                
                self.runAlert(messageText: "\(fileName) has been successfully installed.")
            } else {
                self.runAlert(messageText: "The \(fileName) tool failed to install.")
            }
        }
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
