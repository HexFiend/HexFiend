//
//  main.swift
//  hexf
//
//  Created as main.m by Kevin Wojniak on 9/24/17.
//  Converted to main.swift by Reed Harston on 10/31/22.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

import Cocoa

let controller = Controller()
let args = ProcessInfo.processInfo.arguments
if args.count <= 1 {
    if (controller.processStandardInput()) {
        exit(EXIT_SUCCESS)
    } else {
        controller.printUsage()
        exit(EXIT_FAILURE)
    }
}
exit(controller.process(arguments: args))
