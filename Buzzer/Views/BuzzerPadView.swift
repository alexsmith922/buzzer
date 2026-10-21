import UIKit

/// A buzzer with a button underneath showing the sound it plays. Sizes the buzzer to
/// fit whatever space it's given, so several can share the screen.
final class BuzzerPadView: UIView {

    let buzzer = BuzzerButton()
    let soundButton = UIButton(configuration: .gray())

    private var buttonSpacing: NSLayoutConstraint!
    private var isCompact: Bool?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        soundButton.configuration?.image = UIImage(systemName: "speaker.wave.2.fill")
        soundButton.configuration?.imagePadding = 8
        soundButton.configuration?.cornerStyle = .capsule
        soundButton.configuration?.titleLineBreakMode = .byTruncatingTail
        soundButton.showsMenuAsPrimaryAction = true
        // Keep the sounds in the order they're listed, wherever the menu opens.
        soundButton.preferredMenuElementOrder = .fixed
        soundButton.setContentCompressionResistancePriority(.required, for: .vertical)

        for view in [buzzer, soundButton] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        // Buzzer and button, centered together.
        let content = UILayoutGuide()
        addLayoutGuide(content)

        buttonSpacing = soundButton.topAnchor.constraint(equalTo: buzzer.bottomAnchor, constant: 16)
        buttonSpacing.isActive = true

        let preferredWidth = buzzer.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: buzzer.topAnchor),
            content.bottomAnchor.constraint(equalTo: soundButton.bottomAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            buzzer.centerXAnchor.constraint(equalTo: centerXAnchor),
            buzzer.heightAnchor.constraint(equalTo: buzzer.widthAnchor),
            buzzer.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.9),
            buzzer.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            preferredWidth,

            soundButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            soundButton.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            soundButton.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
        ])
    }

    /// In small grid cells, a smaller sound label tucked closer leaves more room for the buzzer.
    override func layoutSubviews() {
        let compact = bounds.height < 260 || bounds.width < 200
        if compact != isCompact {
            isCompact = compact
            buttonSpacing.constant = compact ? 8 : 16
            soundButton.configuration?.buttonSize = compact ? .small : .medium
            soundButton.configuration?.imagePadding = compact ? 4 : 8
        }
        super.layoutSubviews()
    }
}

extension BuzzerPad {

    var uiColor: UIColor {
        customColor?.uiColor ?? color.uiColor
    }
}

extension BuzzerPad.CustomColor {

    init(_ color: UIColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }

    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

extension BuzzerPad.Color {

    var uiColor: UIColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        }
    }
}
