//
//  ScrollViewRepresenter.swift
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/24.
//  Copyright © 2024 ridiculous_fish. All rights reserved.
//

class ScrollViewRepresenter: HFRepresenter {

    private let hexRep = HFHexTextRepresenter()
    private var documentView: ScrollViewRepresenterDocumentView?

    override func createView() -> NSView {
        let frame = NSMakeRect(0, 0, 100, 100)
        let scrollView = NSScrollView(frame: frame)
        scrollView.autoresizingMask = .height
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.usesPredominantAxisScrolling = true
        let documentView = ScrollViewRepresenterDocumentView(representer: self,
                                                             hexRep: hexRep)
        scrollView.documentView = documentView
        self.documentView = documentView
        return scrollView
    }

    override func controllerDidChange(_ bits: HFControllerPropertyBits) {
        if bits.rawValue == UInt(bitPattern: -1),
           let documentView,
           hexRep.controller() == nil,
           let controller = controller() {
            controller.addRepresenter(hexRep)
            documentView.addHexRep()
        }
    }

    override func minimumViewWidth(forBytesPerLine bytesPerLine: UInt) -> CGFloat {
        let width = hexRep.minimumViewWidth(forBytesPerLine: bytesPerLine)
        return width
    }

    override class func defaultLayoutPosition() -> NSPoint {
        NSMakePoint(5, 0)
    }

}

class ScrollViewRepresenterDocumentView: NSView {

    private weak var representer: ScrollViewRepresenter?
    private let hexRep: HFHexTextRepresenter
    private var showingHexRep = false

    init(representer: ScrollViewRepresenter, hexRep: HFHexTextRepresenter) {
        self.representer = representer
        self.hexRep = hexRep
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addHexRep() {
        addSubview(hexRep.view())
        showingHexRep = true
        updateFrame()
    }

    private func updateFrame() {
        guard let superview = enclosingScrollView else {
            return
        }
        frame.size = NSMakeSize(superview.frame.size.width, 1000)
        guard showingHexRep else {
            return
        }
        guard let controller = hexRep.controller() else {
            return
        }
        let view = hexRep.view()
        var frame = bounds
        let width = hexRep.minimumViewWidth(forBytesPerLine: controller.bytesPerLine())
        frame.size.width = width
        view.frame = frame
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateFrame()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async {
            self.scrollToTop()
        }
    }

    private func scrollToTop() {
        scroll(NSMakePoint(0, bounds.size.height))
    }

}
