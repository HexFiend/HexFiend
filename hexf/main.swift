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

private let kAppIdentifier = "com.ridiculousfish.HexFiend"

private func printUsage() {
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
    NSRunningApplication.runningApplications(withBundleIdentifier: kAppIdentifier).first != nil
}

private func launchApp(with args: [String]) throws {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: kAppIdentifier) else {
        fputs("Failed to get url to app bundle for: \(kAppIdentifier)", stderr)
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
    // TODO: Heed deprecation warning. This will require an availability check.
    let data = inFile.readDataToEndOfFile()
    
    guard data.count != 0 else {
        throw HexfError.standardInputNoData
    }
    
    if appRunning {
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

enum CommandOption: Equatable {
    case diff(leftFile: String, rightFile: String)
    case open(files: [String])
}

enum Command: Equatable {
    case command(_ command: CommandOption)
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

func process(command: Command) throws {
    switch command {
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
        if appRunning {
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

try process(command: Command(args: ProcessInfo.processInfo.arguments))
