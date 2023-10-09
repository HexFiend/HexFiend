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
    let encoding: HFStringEncoding

    init(label: String, encoding: HFStringEncoding) {
        self.label = label
        self.encoding = encoding
    }
}

class ChooseStringEncodingWindowController: NSWindowController, NSTableViewDelegate {
    @IBOutlet private weak var tableView: NSTableView!
    @IBOutlet private weak var searchField: NSSearchField!
    
    private var encodings = [HFEncodingChoice]()
    private var activeEncodings = [HFEncodingChoice]()
    
    override var windowNibName: String {
        "ChooseStringEncodingDialog"
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
    
    @objc func clearSelection() {
        tableView.selectRowIndexes(IndexSet(), byExtendingSelection: false)
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
        default:
            assertionFailure("Unknown identifier")
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        if row == -1 {
            return
        }
        /* Tell the front document (if any) and the app delegate */
        let encoding = activeEncodings[row].encoding
        if let document = NSDocumentController.shared.currentDocument {
            guard let baseDocument = document as? BaseDataDocument else {
                assertionFailure()
                return
            }
            baseDocument.stringEncoding = encoding
        } else {
            guard let delegate = NSApp.delegate as? AppDelegate else {
                assertionFailure()
                return
            }
            delegate.setStringEncoding(encoding)
        }
    }
}
