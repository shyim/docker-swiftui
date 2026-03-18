import AppKit
import CoreText
import SpecttyTerminal

/// A native macOS terminal view using CoreText for rendering.
/// Handles keyboard input, rendering the cell grid, and cursor display.
final class TerminalNSView: NSView {
    private let emulator: GhosttyTerminalEmulator
    private var displayLink: CVDisplayLink?

    var onKeyData: ((Data) -> Void)?
    var onResize: ((Int, Int) -> Void)?

    private let cellFont = CTFontCreateWithName("Menlo" as CFString, 13, nil)
    private var cellWidth: CGFloat = 0
    private var cellHeight: CGFloat = 0
    private var cellDescent: CGFloat = 0

    // Colors
    private let defaultFG: (UInt8, UInt8, UInt8) = (230, 230, 230)
    private let defaultBG: (UInt8, UInt8, UInt8) = (30, 30, 30)

    init(emulator: GhosttyTerminalEmulator) {
        self.emulator = emulator
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 30/255, green: 30/255, blue: 30/255, alpha: 1).cgColor

        // Measure cell size from font metrics
        let ascent = CTFontGetAscent(cellFont)
        let descent = CTFontGetDescent(cellFont)
        let leading = CTFontGetLeading(cellFont)
        cellHeight = ceil(ascent + descent + leading)
        cellDescent = ceil(descent)

        // Measure 'M' width for monospace
        var glyph = CTFontGetGlyphWithName(cellFont, "M" as CFString)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(cellFont, .horizontal, &glyph, &advance, 1)
        cellWidth = ceil(advance.width)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        startDisplayLink()
    }

    override func removeFromSuperview() {
        stopDisplayLink()
        super.removeFromSuperview()
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        var dl: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&dl)
        guard let dl else { return }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkSetOutputCallback(dl, { (_, _, _, _, _, userInfo) -> CVReturn in
            let view = Unmanaged<TerminalNSView>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async { view.needsDisplay = true }
            return kCVReturnSuccess
        }, selfPtr)

        CVDisplayLinkStart(dl)
        displayLink = dl
    }

    private func stopDisplayLink() {
        if let dl = displayLink {
            CVDisplayLinkStop(dl)
            displayLink = nil
        }
    }

    // MARK: - Layout & Resize

    override func layout() {
        super.layout()
        let cols = max(1, Int(bounds.width / cellWidth))
        let rows = max(1, Int(bounds.height / cellHeight))
        let state = emulator.state
        if cols != state.columns || rows != state.rows {
            emulator.resize(columns: cols, rows: rows)
            onResize?(cols, rows)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let state = emulator.state
        let screen = state.activeScreen

        // Background fill
        let bgColor = NSColor(calibratedRed: CGFloat(defaultBG.0)/255,
                              green: CGFloat(defaultBG.1)/255,
                              blue: CGFloat(defaultBG.2)/255, alpha: 1)
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        let rows = screen.lines.count
        let cols = screen.lines.first?.cells.count ?? 0

        for row in 0..<rows {
            let line = screen.lines[row]
            let y = bounds.height - CGFloat(row + 1) * cellHeight

            for col in 0..<min(cols, line.cells.count) {
                let cell = line.cells[col]
                let x = CGFloat(col) * cellWidth

                // Cell background (if not default)
                let resolvedBG: (UInt8, UInt8, UInt8)
                let resolvedFG: (UInt8, UInt8, UInt8)

                if cell.attributes.contains(.inverse) {
                    resolvedBG = cell.fg.resolved(defaultColor: defaultFG)
                    resolvedFG = cell.bg.resolved(defaultColor: defaultBG)
                } else {
                    resolvedBG = cell.bg.resolved(defaultColor: defaultBG)
                    resolvedFG = cell.fg.resolved(defaultColor: defaultFG)
                }

                if cell.bg != .default || cell.attributes.contains(.inverse) {
                    let bgCG = CGColor(red: CGFloat(resolvedBG.0)/255,
                                       green: CGFloat(resolvedBG.1)/255,
                                       blue: CGFloat(resolvedBG.2)/255, alpha: 1)
                    ctx.setFillColor(bgCG)
                    ctx.fill(CGRect(x: x, y: y, width: cellWidth, height: cellHeight))
                }

                // Character
                let ch = cell.character
                guard ch != " " && !cell.attributes.contains(.hidden) else { continue }

                let fgCG = CGColor(red: CGFloat(resolvedFG.0)/255,
                                   green: CGFloat(resolvedFG.1)/255,
                                   blue: CGFloat(resolvedFG.2)/255, alpha: 1)

                var font = cellFont
                if cell.attributes.contains(.bold) {
                    font = CTFontCreateCopyWithSymbolicTraits(cellFont, 0, nil, .boldTrait, .boldTrait) ?? cellFont
                }

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor(cgColor: fgCG) ?? NSColor.white,
                ]
                let str = NSAttributedString(string: String(ch), attributes: attrs)
                let line = CTLineCreateWithAttributedString(str)

                ctx.textPosition = CGPoint(x: x, y: y + cellDescent)
                CTLineDraw(line, ctx)
            }
        }

        // Draw cursor
        let cursor = screen.cursor
        if cursor.visible && cursor.row >= 0 && cursor.row < rows {
            let cursorX = CGFloat(cursor.col) * cellWidth
            let cursorY = bounds.height - CGFloat(cursor.row + 1) * cellHeight

            let cursorColor = CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.8)
            ctx.setFillColor(cursorColor)
            ctx.fill(CGRect(x: cursorX, y: cursorY, width: cellWidth, height: cellHeight))

            // Redraw character under cursor with inverted colors if present
            if cursor.row < rows && cursor.col < cols {
                let cell = screen.lines[cursor.row].cells[cursor.col]
                if cell.character != " " {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: cellFont,
                        .foregroundColor: NSColor(calibratedRed: CGFloat(defaultBG.0)/255,
                                                  green: CGFloat(defaultBG.1)/255,
                                                  blue: CGFloat(defaultBG.2)/255, alpha: 1),
                    ]
                    let str = NSAttributedString(string: String(cell.character), attributes: attrs)
                    let line = CTLineCreateWithAttributedString(str)
                    ctx.textPosition = CGPoint(x: cursorX, y: cursorY + cellDescent)
                    CTLineDraw(line, ctx)
                }
            }
        }
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        let mods = modifiersFrom(event.modifierFlags)
        let keyEvent = KeyEvent(
            keyCode: UInt32(event.keyCode),
            modifiers: mods,
            isKeyDown: true,
            characters: event.characters ?? ""
        )
        let data = emulator.encodeKey(keyEvent)
        if !data.isEmpty {
            onKeyData?(data)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // No-op, handled in keyDown
    }

    private func modifiersFrom(_ flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var mods = KeyModifiers()
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.option) { mods.insert(.alt) }
        if flags.contains(.control) { mods.insert(.control) }
        if flags.contains(.command) { mods.insert(.super) }
        return mods
    }

    // MARK: - Paste

    @objc func paste(_ sender: Any?) {
        guard let str = NSPasteboard.general.string(forType: .string) else { return }
        let data = Data(str.utf8)
        onKeyData?(data)
    }
}
