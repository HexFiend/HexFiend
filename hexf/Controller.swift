//
//  Controller.swift
//  hexf
//
//  Created by Reed Harston on 10/31/22.
//  Copyright © 2022 ridiculous_fish. All rights reserved.
//

import Cocoa

struct Controller {
    private static let kAppIdentifier = "com.ridiculousfish.HexFiend"
    
    func printUsage() {
        fputs("""
Usage:

  Open files:
    hexf file1 [file2 file3 ...]

  Compare files:
    hexf -d file1 file2

  Open piped data:
    echo hello | hexf

  Show help:
    hexf -h | --help

""", stderr)
    }
    
    private func standardize(path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.path // get absolute path
    }
    
    private var appRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.kAppIdentifier).first != nil
    }
    
    private func launchApp(with args: [String]) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.kAppIdentifier) else {
            fputs("Failed to get url to app bundle for: \(Self.kAppIdentifier)", stderr)
            return false
        }
        
        let config = [NSWorkspace.LaunchConfigurationKey.arguments: args]
        
        do {
            // TODO: Heed deprecation warning, and get right config type. This will require an availability check.
//            try NSWorkspace.shared.openApplication(at: url, configuration: config)
            try NSWorkspace.shared.launchApplication(at: url, options: NSWorkspace.LaunchOptions.default, configuration: config)
            return true
        } catch {
            fputs("Launch app failed: \(error.localizedDescription)", stderr)
            return false
        }
    }
    
    func processStandardInput() -> Bool {
        let inFile = FileHandle.standardInput
        // TODO: Heed deprecation warning. This will require an availability check.
        let data = inFile.readDataToEndOfFile()
        
        guard data.count != 0 else {
            return false
        }
        
        if self.appRunning {
            // App is already running so post distributed notification
            let center = DistributedNotificationCenter.default()
            center.postNotificationName(NSNotification.Name(rawValue: "HFOpenDataNotification"),
                                        object: nil,
                                        userInfo: ["data" : data],
                                        deliverImmediately: true)
            return true
        }

        // App isn't running so launch it with custom args
        return launchApp(with: [
            "-HFOpenData",
            data.base64EncodedString(options: .init(rawValue: 0))
            // I'm not sure what 0 is for the options, but that is what the Obj-C code passed in... so I kept it.
            //        NSString *base64Str = [data base64EncodedStringWithOptions:0];
        ])
    }
    
    func process(arguments args: [String]) -> Int32 {
        var filesToOpen = [String]()
        let argsCount = args.count
        
        var diffLeftFile: String?
        var diffRightFile: String?

        if argsCount == 4, args[1] == "-d" {
            diffLeftFile = standardize(path:args[2])
            diffRightFile = standardize(path:args[3])
        } else {
            for arg in args.dropFirst() {
                if arg.hasPrefix("-") {
                    if arg == "-h" || arg == "--help" {
                        printUsage()
                        return EXIT_SUCCESS
                    }
                    printUsage()
                    return EXIT_FAILURE
                }
                filesToOpen.append(standardize(path: arg))
            }
        }
        if self.appRunning {
            // App is already running so post distributed notification
            let name: String
            let userInfo: [String: [Any]]
            if let diffLeftFile = diffLeftFile,
               let diffRightFile = diffRightFile {
                name = "HFDiffFilesNotification"
                userInfo = ["files": [diffLeftFile, diffRightFile]]
            } else {
                name = "HFOpenFileNotification"
                userInfo = ["files": filesToOpen]
            }
            let center = DistributedNotificationCenter.default()
            center.postNotificationName(NSNotification.Name(rawValue: name),
                                        object: nil,
                                        userInfo: userInfo,
                                        deliverImmediately: true)
        } else {
            // App isn't running so launch it with custom args
            var launchArgs: [String]
            if let diffLeftFile = diffLeftFile,
               let diffRightFile = diffRightFile {
                launchArgs = [
                    "-HFDiffLeftFile",
                    diffLeftFile,
                    "-HFDiffRightFile",
                    diffRightFile
                ]
            } else {
                launchArgs = []
                for fileToOpen in filesToOpen {
                    launchArgs.append("-HFOpenFile")
                    launchArgs.append(fileToOpen)
                }
            }
            if !launchApp(with: launchArgs) {
                return EXIT_FAILURE
            }
        }
        return EXIT_SUCCESS
    }
}

