//
//  ScrollViewRepresenter.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/24.
//  Copyright © 2024 ridiculous_fish. All rights reserved.
//

class ScrollViewRepresenter: HFRepresenter {

    private let width: CGFloat = 100

    override func createView() -> NSView {
        let frame = NSMakeRect(0, 0, width, 0)
        let scrollView = NSScrollView(frame: frame)
        scrollView.autoresizingMask = .height
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.clipsToBounds = true
        scrollView.usesPredominantAxisScrolling = true
        let documentView = ScrollViewRepresenterDocumentView()
        scrollView.documentView = documentView
        return scrollView
    }

    override func minimumViewWidth(forBytesPerLine bytesPerLine: UInt) -> CGFloat {
        return width
    }

    override class func defaultLayoutPosition() -> NSPoint {
        NSMakePoint(5, 0)
    }

}

class ScrollViewRepresenterDocumentView: NSView {

    private func updateFrame() {
        guard let superview = enclosingScrollView else {
            print("Not in a scroll view")
            return
        }
        frame.size = NSMakeSize(min(superview.frame.size.width, 500), 1000)
    }

    override func viewDidMoveToSuperview() {
        updateFrame()
    }

    override func viewDidMoveToWindow() {
        DispatchQueue.main.async {
            self.scroll(NSMakePoint(0, self.bounds.size.height))
        }
    }

}
