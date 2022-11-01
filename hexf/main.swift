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
try controller.process(arguments: ProcessInfo.processInfo.arguments)
