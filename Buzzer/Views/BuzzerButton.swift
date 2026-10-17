import UIKit

/// A big arcade-style dome button. The cap sinks into its housing while held,
/// springs back on release, and sends a ring rippling outward on every press.
final class BuzzerButton: UIControl {

    var capColor: UIColor = .systemRed {
        didSet { updateColors() }
    }

    private let housingView = UIView()
    private let wellView = UIView()
    private let skirtView = UIView()
    private let capView = UIView()
    private let capGradient = CAGradientLayer()
    private let shineView = UIView()

    private let pressFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let releaseFeedback = UIImpactFeedbackGenerator(style: .light)

    private var laidOutSize: CGSize = .zero

    /// How far the cap stands proud of the housing.
    private var travel: CGFloat { bounds.width * 0.045 }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            animatePress(isHighlighted)
        }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // Only the round button counts, not the square corners around it.
        let radius = min(bounds.width, bounds.height) / 2
        return hypot(point.x - bounds.midX, point.y - bounds.midY) <= radius
    }

    override func accessibilityActivate() -> Bool {
        // VoiceOver sends a tap, but the buzzer fires on touch down.
        animatePress(true)
        sendActions(for: .touchDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.animatePress(false)
        }
        return true
    }

    // MARK: - Setup

    private func setUp() {
        isAccessibilityElement = true
        accessibilityLabel = "Buzzer"
        accessibilityTraits = .button
        clipsToBounds = false

        housingView.backgroundColor = UIColor(white: 0.17, alpha: 1)
        housingView.layer.shadowColor = UIColor.black.cgColor
        housingView.layer.shadowOpacity = 0.6
        housingView.layer.shadowRadius = 24
        housingView.layer.shadowOffset = CGSize(width: 0, height: 14)
        housingView.layer.borderColor = UIColor(white: 0.28, alpha: 1).cgColor
        housingView.layer.borderWidth = 2

        wellView.backgroundColor = UIColor(white: 0.03, alpha: 1)

        capView.layer.shadowColor = UIColor.black.cgColor
        capView.layer.shadowOpacity = 0.5
        capGradient.type = .radial
        capGradient.startPoint = CGPoint(x: 0.4, y: 0.32)
        capGradient.endPoint = CGPoint(x: 1.1, y: 1.1)
        capGradient.masksToBounds = true
        capView.layer.addSublayer(capGradient)

        shineView.backgroundColor = UIColor(white: 1, alpha: 0.3)

        for view in [housingView, wellView, skirtView, capView] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        shineView.isUserInteractionEnabled = false
        capView.addSubview(shineView)

        updateColors()
    }

    private func updateColors() {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        capColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let light = UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(brightness * 1.15, 1), alpha: 1)
        let dark = UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.7, alpha: 1)
        capGradient.colors = [light.cgColor, capColor.cgColor, dark.cgColor]
        capGradient.locations = [0, 0.45, 1]
        skirtView.backgroundColor = UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.5, alpha: 1)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size

        let side = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        func place(_ view: UIView, diameter: CGFloat, at point: CGPoint) {
            view.transform = .identity
            view.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            view.center = point
            view.layer.cornerRadius = diameter / 2
        }

        place(housingView, diameter: side, at: center)
        housingView.layer.shadowPath = UIBezierPath(ovalIn: housingView.bounds).cgPath

        place(wellView, diameter: side * 0.88, at: center)

        let capDiameter = side * 0.78
        let restingCenter = CGPoint(x: center.x, y: center.y + travel * 0.5)
        place(skirtView, diameter: capDiameter, at: restingCenter)
        place(capView, diameter: capDiameter, at: restingCenter)

        capGradient.frame = capView.bounds
        capGradient.cornerRadius = capDiameter / 2
        capView.layer.shadowPath = UIBezierPath(ovalIn: capView.bounds).cgPath

        shineView.bounds = CGRect(x: 0, y: 0, width: capDiameter * 0.46, height: capDiameter * 0.22)
        shineView.center = CGPoint(x: capDiameter * 0.4, y: capDiameter * 0.22)
        shineView.layer.cornerRadius = shineView.bounds.height / 2

        applyCapState(pressed: isHighlighted)
    }

    // MARK: - Animation

    private func applyCapState(pressed: Bool) {
        if pressed {
            capView.transform = CGAffineTransform(translationX: 0, y: -travel * 0.1).scaledBy(x: 0.97, y: 0.97)
            capView.layer.shadowRadius = 2
            capView.layer.shadowOffset = CGSize(width: 0, height: 1)
        } else {
            capView.transform = CGAffineTransform(translationX: 0, y: -travel)
            capView.layer.shadowRadius = 10
            capView.layer.shadowOffset = CGSize(width: 0, height: travel)
        }
    }

    private func animatePress(_ pressed: Bool) {
        if pressed {
            pressFeedback.impactOccurred()
            emitRipple()
            UIView.animate(withDuration: 0.06, delay: 0, options: [.beginFromCurrentState, .curveEaseIn]) {
                self.applyCapState(pressed: true)
            }
            pressFeedback.prepare()
        } else {
            releaseFeedback.impactOccurred()
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.4, initialSpringVelocity: 0.8,
                           options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.applyCapState(pressed: false)
            }
        }
    }

    private func emitRipple() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let frame = housingView.frame
        let ring = CAShapeLayer()
        ring.bounds = CGRect(origin: .zero, size: frame.size)
        ring.position = CGPoint(x: frame.midX, y: frame.midY)
        ring.path = UIBezierPath(ovalIn: ring.bounds).cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = capColor.cgColor
        ring.lineWidth = 6
        ring.opacity = 0
        layer.insertSublayer(ring, at: 0)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 1.5
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.8
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 0.6
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        ring.add(group, forKey: "ripple")
        CATransaction.commit()
    }
}
