//
//  main.swift
//  hexf
//
//  Created as main.m by Kevin Wojniak on 9/24/17.
//  Converted to main.swift by Reed Harston on 10/31/22.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

import Cocoa

enum HexfError: Error {
    case invalidUsage
    case standardInputNoData
    case launchAppNoUrl
    case launchAppFailure
}

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
    
    private static func standardize(path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.path // get absolute path
    }
    
    private var appRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.kAppIdentifier).first != nil
    }
    
    private func launchApp(with args: [String]) throws {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.kAppIdentifier) else {
            fputs("Failed to get url to app bundle for: \(Self.kAppIdentifier)", stderr)
            throw HexfError.launchAppNoUrl
        }
        
        let config = [NSWorkspace.LaunchConfigurationKey.arguments: args]
        
        do {
            // TODO: Heed deprecation warning, and get right config type. This will require an availability check.
            //            try NSWorkspace.shared.openApplication(at: url, configuration: config)
            try NSWorkspace.shared.launchApplication(at: url, options: NSWorkspace.LaunchOptions.default, configuration: config)
        } catch {
            fputs("Launch app failed: \(error.localizedDescription)", stderr)
            throw HexfError.launchAppFailure
        }
    }
    
    private func processStandardInput() throws {
        let inFile = FileHandle.standardInput
        let data: Data?
        if #available(macOS 10.15.4, *) {
            data = try inFile.readToEnd()
        } else {
            data = inFile.readDataToEndOfFile()
        }
        guard let data, !data.isEmpty else {
            throw HexfError.standardInputNoData
        }
        
        if self.appRunning {
            // App is already running so post distributed notification
            let center = DistributedNotificationCenter.default()
            center.postNotificationName(NSNotification.Name(rawValue: "HFOpenDataNotification"),
                                        object: nil,
                                        userInfo: ["data" : data],
                                        deliverImmediately: true)
            return
        }
        
        // App isn't running so launch it with custom args
        try launchApp(with: [
            "-HFOpenData",
            data.base64EncodedString(options: .init(rawValue: 0))
            // I'm not sure what 0 is for the options, but that is what the Obj-C code passed in... so I kept it.
            //        NSString *base64Str = [data base64EncodedStringWithOptions:0];
        ])
    }
    
    enum Commands: Equatable {
        case diff(leftFile: String, rightFile: String)
        case open(files: [String])
    }
    
    enum Options: Equatable {
        case command(_ command: Commands)
        case none
        case help
        case invalid
        
        init(args: [String]) {
            if args.count == 1 {
                self = .none
            } else if args.count == 4, args[1] == "-d" {
                self = .command(.diff(leftFile: standardize(path:args[2]), rightFile: standardize(path:args[3])))
            } else {
                var filesToOpen = [String]()
                for arg in args.dropFirst() {
                    if arg.hasPrefix("-") {
                        if arg == "-h" || arg == "--help" {
                            self = .help
                            return
                        }
                        self = .invalid
                        return
                    }
                    filesToOpen.append(standardize(path: arg))
                }
                self = .command(.open(files: filesToOpen))
            }
        }
    }
    
    func process(arguments args: [String]) throws {
        switch Options(args: args) {
        case .invalid:
            printUsage()
            throw HexfError.invalidUsage
            
        case .help:
            printUsage()
            return
            
        case .none:
            try processStandardInput()
            return
            
        case let .command(command):
            if self.appRunning {
                // App is already running so post distributed notification
                let name: String
                let userInfo: [String: [Any]]
                switch command {
                case let .diff(diffLeftFile, diffRightFile):
                    name = "HFDiffFilesNotification"
                    userInfo = ["files": [diffLeftFile, diffRightFile]]
                case let .open(files):
                    name = "HFOpenFileNotification"
                    userInfo = ["files": files]
                }
                let center = DistributedNotificationCenter.default()
                center.postNotificationName(NSNotification.Name(rawValue: name),
                                            object: nil,
                                            userInfo: userInfo,
                                            deliverImmediately: true)
            } else {
                // App isn't running so launch it with custom args
                let launchArgs: [String]
                switch command {
                case let .diff(diffLeftFile, diffRightFile):
                    launchArgs = [
                        "-HFDiffLeftFile",
                        diffLeftFile,
                        "-HFDiffRightFile",
                        diffRightFile
                    ]
                case let .open(files):
                    launchArgs = files.flatMap { file in
                        [
                            "-HFOpenFile",
                            file
                        ]
                    }
                }
                try launchApp(with: launchArgs)
            }
        }
    }
}

let controller = Controller()
try controller.process(arguments: ProcessInfo.processInfo.arguments)
