import UIKit

/// Draws a clip's waveform with two handles for choosing the part to keep.
/// Sends `.valueChanged` while a handle moves and `.editingDidEnd` when it's let go.
final class WaveformTrimView: UIControl {

    static let minimumLength: TimeInterval = 0.1

    private(set) var trimStart: TimeInterval = 0
    private(set) var trimEnd: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// Where playback is, in seconds, or nil when nothing is playing.
    var playheadTime: TimeInterval? {
        didSet { setNeedsDisplay() }
    }

    var trimmedLength: TimeInterval { trimEnd - trimStart }
    var isTrimmed: Bool { trimStart > 0.01 || trimEnd < duration - 0.01 }

    private enum Handle {
        case start, end
    }

    private var peaks: [Float] = []
    private var activeHandle: Handle?
    private let handleWidth: CGFloat = 16
    /// Matches the buzzer and record button.
    private let selectionColor = UIColor.systemRed
    private lazy var startElement = HandleAccessibilityElement(accessibilityContainer: self)
    private lazy var endElement = HandleAccessibilityElement(accessibilityContainer: self)

    /// The waveform sits between the handles' outer edges so both stay grabbable.
    private var waveformRect: CGRect { bounds.insetBy(dx: handleWidth, dy: 0) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw

        startElement.onAdjust = { [weak self] step in self?.nudge(.start, by: step) }
        endElement.onAdjust = { [weak self] step in self?.nudge(.end, by: step) }
        startElement.accessibilityLabel = "Trim start"
        endElement.accessibilityLabel = "Trim end"
        startElement.accessibilityTraits = .adjustable
        endElement.accessibilityTraits = .adjustable
    }

    func load(peaks: [Float], duration: TimeInterval) {
        self.peaks = peaks
        self.duration = duration
        trimStart = 0
        trimEnd = duration
        playheadTime = nil
        updateAccessibility()
        setNeedsDisplay()
    }

    func reset() {
        load(peaks: [], duration: 0)
    }

    // MARK: - Geometry

    private func x(for time: TimeInterval) -> CGFloat {
        guard duration > 0 else { return waveformRect.minX }
        return waveformRect.minX + waveformRect.width * CGFloat(time / duration)
    }

    private func time(for x: CGFloat) -> TimeInterval {
        guard waveformRect.width > 0 else { return 0 }
        let fraction = (x - waveformRect.minX) / waveformRect.width
        return duration * Double(min(max(fraction, 0), 1))
    }

    private func move(_ handle: Handle, to time: TimeInterval) {
        switch handle {
        case .start:
            trimStart = min(max(time, 0), trimEnd - Self.minimumLength)
        case .end:
            trimEnd = max(min(time, duration), trimStart + Self.minimumLength)
        }
        updateAccessibility()
        setNeedsDisplay()
    }

    // MARK: - Touch tracking

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard duration > 0 else { return false }
        let x = touch.location(in: self).x
        let startDistance = abs(x - (self.x(for: trimStart) - handleWidth / 2))
        let endDistance = abs(x - (self.x(for: trimEnd) + handleWidth / 2))
        // Generous hit area: whichever handle is closer, within a finger's width.
        guard min(startDistance, endDistance) < 44 else { return false }
        activeHandle = startDistance <= endDistance ? .start : .end
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard let activeHandle else { return false }
        move(activeHandle, to: time(for: touch.location(in: self).x))
        sendActions(for: .valueChanged)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        activeHandle = nil
        sendActions(for: .editingDidEnd)
    }

    override func cancelTracking(with event: UIEvent?) {
        activeHandle = nil
        sendActions(for: .editingDidEnd)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        let background = UIBezierPath(roundedRect: waveformRect, cornerRadius: 8)
        UIColor.secondarySystemFill.setFill()
        background.fill()

        guard duration > 0, !peaks.isEmpty else { return }

        // Bars, bright inside the selection and faded outside it. Kept neutral so the
        // red selection frame stands out against them.
        let barSlot = waveformRect.width / CGFloat(peaks.count)
        let barWidth = max(1, barSlot * 0.6)
        let maxBarHeight = waveformRect.height - 16
        let startX = x(for: trimStart)
        let endX = x(for: trimEnd)
        for (index, peak) in peaks.enumerated() {
            let centerX = waveformRect.minX + barSlot * (CGFloat(index) + 0.5)
            let height = max(2, CGFloat(peak) * maxBarHeight)
            let bar = CGRect(x: centerX - barWidth / 2, y: waveformRect.midY - height / 2,
                             width: barWidth, height: height)
            let isSelected = centerX >= startX && centerX <= endX
            (isSelected ? UIColor.label : UIColor.tertiaryLabel).setFill()
            UIBezierPath(roundedRect: bar, cornerRadius: barWidth / 2).fill()
        }

        // Selection frame with a handle on each side.
        let frameWidth: CGFloat = 3
        selectionColor.setFill()
        UIRectFill(CGRect(x: startX, y: 0, width: endX - startX, height: frameWidth))
        UIRectFill(CGRect(x: startX, y: bounds.height - frameWidth, width: endX - startX, height: frameWidth))
        for handleRect in [CGRect(x: startX - handleWidth, y: 0, width: handleWidth, height: bounds.height),
                           CGRect(x: endX, y: 0, width: handleWidth, height: bounds.height)] {
            UIBezierPath(roundedRect: handleRect, cornerRadius: 4).fill()
            let grip = CGRect(x: handleRect.midX - 1, y: handleRect.midY - 8, width: 2, height: 16)
            UIColor.white.withAlphaComponent(0.8).setFill()
            UIBezierPath(roundedRect: grip, cornerRadius: 1).fill()
            selectionColor.setFill()
        }

        if let playheadTime {
            selectionColor.setFill()
            UIRectFill(CGRect(x: x(for: playheadTime) - 1, y: frameWidth, width: 2,
                              height: bounds.height - frameWidth * 2))
        }
    }

    // MARK: - Accessibility

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAccessibility()
    }

    private func nudge(_ handle: Handle, by step: Int) {
        let amount = Double(step) * Self.minimumLength
        move(handle, to: (handle == .start ? trimStart : trimEnd) + amount)
        sendActions(for: .valueChanged)
        sendActions(for: .editingDidEnd)
    }

    private func updateAccessibility() {
        guard duration > 0 else {
            accessibilityElements = []
            return
        }
        startElement.accessibilityValue = String(format: "%.1f seconds", trimStart)
        endElement.accessibilityValue = String(format: "%.1f seconds", trimEnd)
        startElement.accessibilityFrameInContainerSpace =
            CGRect(x: x(for: trimStart) - handleWidth, y: 0, width: handleWidth, height: bounds.height)
        endElement.accessibilityFrameInContainerSpace =
            CGRect(x: x(for: trimEnd), y: 0, width: handleWidth, height: bounds.height)
        accessibilityElements = [startElement, endElement]
    }
}

/// A trim handle VoiceOver users adjust by swiping up or down.
private final class HandleAccessibilityElement: UIAccessibilityElement {

    var onAdjust: ((Int) -> Void)?

    override func accessibilityIncrement() {
        onAdjust?(1)
    }

    override func accessibilityDecrement() {
        onAdjust?(-1)
    }
}
