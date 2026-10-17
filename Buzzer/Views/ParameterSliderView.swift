import UIKit

/// A titled slider that shows its current value, with optional logarithmic scaling
/// (useful for pitch, where each octave should take the same slider distance).
final class ParameterSliderView: UIView {

    /// Called continuously while the slider moves.
    var onChange: ((Double) -> Void)?
    /// Called once when the user lets go.
    var onCommit: (() -> Void)?

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private let range: ClosedRange<Double>
    private let isLogarithmic: Bool
    private let format: (Double) -> String

    var value: Double {
        get { value(forPosition: Double(slider.value)) }
        set {
            slider.value = Float(position(for: newValue))
            updateValueLabel()
        }
    }

    init(title: String, range: ClosedRange<Double>, logarithmic: Bool = false,
         format: @escaping (Double) -> String) {
        self.range = range
        self.isLogarithmic = logarithmic
        self.format = format
        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.font = .monospacedDigitSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize, weight: .regular)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.accessibilityLabel = title
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderReleased), for: [.touchUpInside, .touchUpOutside])

        let header = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        let stack = UIStackView(arrangedSubviews: [header, slider])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        updateValueLabel()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func sliderChanged() {
        updateValueLabel()
        onChange?(value)
    }

    @objc private func sliderReleased() {
        onCommit?()
    }

    private func updateValueLabel() {
        valueLabel.text = format(value)
        slider.accessibilityValue = valueLabel.text
    }

    private func value(forPosition position: Double) -> Double {
        if isLogarithmic {
            return range.lowerBound * pow(range.upperBound / range.lowerBound, position)
        }
        return range.lowerBound + (range.upperBound - range.lowerBound) * position
    }

    private func position(for value: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        if isLogarithmic {
            return log(clamped / range.lowerBound) / log(range.upperBound / range.lowerBound)
        }
        return (clamped - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}
