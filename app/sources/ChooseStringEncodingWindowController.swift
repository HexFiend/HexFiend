//
//  ChooseStringEncodingWindowController.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 10/9/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

import Cocoa

private class HFEncodingChoice {
    let label: String
    let encoding: HFNSStringEncoding

    init(label: String, encoding: HFNSStringEncoding) {
        self.label = label
        self.encoding = encoding
    }
}

class ChooseStringEncodingWindowController: NSWindowController, NSTableViewDelegate {
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var searchField: NSSearchField!
    
    private var encodings = [HFEncodingChoice]()
    private var activeEncodings = [HFEncodingChoice]()
    private var menuEncodings = [NSNumber]()
    
    override var windowNibName: String {
        "ChooseStringEncodingDialog"
    }
    
    init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func populateStringEncodings() {
        encodings = HFEncodingManager.shared().systemEncodings.map({ encoding in
            let label: String
            if encoding.name == encoding.identifier {
                label = encoding.name
            } else {
                label = "\(encoding.name) (\(encoding.identifier))"
            }
            return HFEncodingChoice(label: label, encoding: encoding)
        }).sorted(by: {
            $0.label < $1.label
        })
        activeEncodings = encodings
        menuEncodings = AppDelegate.shared.encodings.menuSystemEncodingsNumbers
        tableView.reloadData()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        populateStringEncodings()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let searchText = searchField.stringValue
        if searchText.count > 0 {
            activeEncodings = encodings.compactMap({ choice in
                let encoding = choice.encoding
                if encoding.name.localizedCaseInsensitiveContains(searchText) || encoding.identifier.localizedCaseInsensitiveContains(searchText) {
                    return choice
                } else {
                    return nil
                }
            })
        } else {
            activeEncodings = encodings
        }
        tableView.reloadData()
    }
    
    @objc func reload() {
        tableView.reloadData()
    }
}

extension ChooseStringEncodingWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        activeEncodings.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard let tableColumn else {
            assertionFailure()
            return nil
        }
        switch tableColumn.identifier.rawValue {
        case "name":
            return activeEncodings[row].encoding.name
        case "identifier":
            return activeEncodings[row].encoding.identifier
        case "show":
            let number = activeEncodings[row].encoding.encoding as NSNumber
            if menuEncodings.contains(number) {
                return NSControl.StateValue.on as NSNumber
            }
            return NSControl.StateValue.off as NSNumber
        default:
            assertionFailure("Unknown identifier")
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard let tableColumn else {
            assertionFailure()
            return
        }
        switch tableColumn.identifier.rawValue {
        case "show":
            guard let newState = object as? NSNumber else {
                assertionFailure("Invalid object")
                return
            }
            let addToMenu = newState.boolValue
            let number = activeEncodings[row].encoding.encoding as NSNumber
            menuEncodings.removeAll {
                $0 == number
            }
            if addToMenu {
                menuEncodings.append(number)
            }
            AppDelegate.shared.encodings.menuSystemEncodingsNumbers = menuEncodings
        default:
            assertionFailure("Unknown identifier")
        }
    }
    
    func tableView(_ tableView: NSTableView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, row: Int) {
        guard let tableColumn else {
            assertionFailure()
            return
        }
        guard tableColumn.identifier.rawValue == "show" else {
            return
        }
        guard let buttonCell = cell as? NSButtonCell else {
            assertionFailure()
            return
        }
        let defaultEncoding = AppDelegate.shared.defaultStringEncoding
        buttonCell.isEnabled = activeEncodings[row].encoding.identifier != defaultEncoding.identifier
    }
}
