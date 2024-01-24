//
//  Settings.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/23/24.
//  Copyright © 2024 ridiculous_fish. All rights reserved.
//

import Cocoa

@objc class Settings: NSWindowController {

    init() {
        let font = NSFont.systemFont(ofSize: 11)
        let boldFont = NSFontManager().convert(font, toHaveTrait: .boldFontMask)

        let generalLabel = NSTextField(labelWithString: NSLocalizedString("General", comment: ""))
        generalLabel.font = boldFont

        let editModeLabel = NSTextField(labelWithString: NSLocalizedString("Default edit mode for opening files:", comment: ""))
        editModeLabel.font = font

        let editModePopUp = NSPopUpButton(frame: .zero, pullsDown: false)
        editModePopUp.font = font
        editModePopUp.controlSize = .small
        editModePopUp.addItems(withTitles: [
            NSLocalizedString("Insert", comment: ""),
            NSLocalizedString("Overwrite", comment: ""),
            NSLocalizedString("Read-Only", comment: ""),
        ])
        editModePopUp.sizeToFit()

        let aliasesCheckbox = NSButton(checkboxWithTitle: NSLocalizedString("Resolve aliases when opening files", comment: ""), target: nil, action: nil)
        aliasesCheckbox.controlSize = .small

        let byteGroupingLabel = NSTextField(labelWithString: NSLocalizedString("Byte grouping for copying bytes:", comment: ""))
        byteGroupingLabel.font = font

        let padding: CGFloat = 20

        let indentView: (NSView) -> NSView = {
            let spacer = NSView(frame: NSRect())
            spacer.translatesAutoresizingMaskIntoConstraints = false

            let stackView = NSStackView(views: [spacer, $0])
            stackView.orientation = .horizontal
            stackView.spacing = 0
            stackView.addConstraint(.init(item: spacer, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 16))
            return stackView
        }

        let stackView = NSStackView(views: [
            generalLabel,
            editModeLabel,
            indentView(editModePopUp),
            aliasesCheckbox,
            byteGroupingLabel,
        ])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.edgeInsets = .init(top: padding, left: padding, bottom: padding, right: padding)
        stackView.setHuggingPriority(.defaultHigh, for: .horizontal)

        let rect = stackView.frame
        let window = NSWindow(contentRect: rect,
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered,
                              defer: false)
        window.contentView = stackView

        if #available(macOS 13, *) {
            window.title = NSLocalizedString("Settings", comment: "")
        } else {
            window.title = NSLocalizedString("Preferences", comment: "")
        }
        window.center()

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
