//
//  main.swift
//  hexf
//
//  Created as main.m by Kevin Wojniak on 9/24/17.
//  Converted to main.swift by Reed Harston on 10/31/22.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

import Cocoa
import ArgumentParser

private struct Controller {
    private static let kAppIdentifier = "com.ridiculousfish.HexFiend"
    
    struct HexfError: Error, CustomStringConvertible {
        var description: String
        init(_ description: String) {
            self.description = description
        }
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
            throw HexfError("Failed to get url to app bundle for: \(Self.kAppIdentifier)")
        }
        
        if #available(macOS 10.15, *) {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = args
            var openError: Error?
            let semaphore = DispatchSemaphore(value: 0)
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                openError = error
                semaphore.signal()
            }
            let result = semaphore.wait(timeout: .now() + .seconds(15))
            if result == .timedOut {
                throw HexfError("Launch app timeout")
            }
            if let openError {
                throw HexfError("Launch error: \(openError)")
            }
        } else {
            let config = [NSWorkspace.LaunchConfigurationKey.arguments: args]
            do {
                try NSWorkspace.shared.launchApplication(at: url, options: NSWorkspace.LaunchOptions.default, configuration: config)
            } catch {
                throw HexfError("Launch app failed: \(error.localizedDescription)")
            }
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
            throw HexfError("No data")
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
        try launchApp(with: ["-HFOpenData", data.base64EncodedString()])
    }
    
    private enum Commands: Equatable {
        case diff(leftFile: String, rightFile: String)
        case open(files: [String])
    }
    
    private enum Options: Equatable {
        case command(_ command: Commands)
        case none

        init(args: Hexf) {
            if args.files.isEmpty {
                self = .none
            } else if args.files.count == 2, args.diff {
                self = .command(.diff(leftFile: standardize(path: args.files[0]),
                                      rightFile: standardize(path: args.files[1])))
            } else {
                let filesToOpen: [String] = args.files.map { file in
                    standardize(path: file)
                }
                self = .command(.open(files: filesToOpen))
            }
        }
    }
    
    func process(args: Hexf) throws {
        switch Options(args: args) {
        case .none:
            try processStandardInput()
            return
            
        case let .command(command):
            if self.appRunning {
                // App is already running so post distributed notification
                let name: String
                let userInfo: [String: [String]]
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

@main
struct Hexf: ParsableCommand {
    static var configuration = CommandConfiguration(version: HFVersion())

    @Flag(name: .shortAndLong, help: "Compare two files.")
    var diff = false

    @Argument(help: ArgumentHelp(
        "Files to open.",
        discussion: "If no input files are provided, hexf reads from stdin.",
        valueName: "file"))
    var files: [String] = []

    mutating func validate() throws {
        if diff, files.count != 2 {
            throw ValidationError("Diff mode requires exactly two files.")
        }
    }

    mutating func run() throws {
        try Controller().process(args: self)
    }
}
