import UIKit

/// Lets the user shape a synthesized sound with sliders, hear it, and save it.
final class SoundDesignerViewController: UIViewController {

    private let library = SoundLibrary.shared
    private let editingSound: SoundEffect?
    private var recipe: SynthRecipe

    private let nameField = UITextField()
    private let waveformControl = UISegmentedControl(items: SynthRecipe.Waveform.allCases.map(\.displayName))
    private var sliders: [(view: ParameterSliderView, keyPath: WritableKeyPath<SynthRecipe, Double>)] = []

    /// - Parameter sound: The custom sound being edited, or nil to save a new sound.
    init(recipe: SynthRecipe, name: String, editing sound: SoundEffect? = nil) {
        self.recipe = recipe
        self.editingSound = sound
        super.init(nibName: nil, bundle: nil)
        nameField.text = name
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = editingSound == nil ? "Design a Sound" : "Edit Sound"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [weak self] _ in
            self?.save()
        })

        nameField.placeholder = "Sound name"
        nameField.borderStyle = .roundedRect
        nameField.autocapitalizationType = .words
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.addAction(UIAction { [weak self] _ in self?.nameField.resignFirstResponder() }, for: .editingDidEndOnExit)

        waveformControl.addAction(UIAction { [weak self] _ in self?.waveformChanged() }, for: .valueChanged)

        let percent: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
        let hertz: (Double) -> String = { $0 >= 1000 ? String(format: "%.1f kHz", $0 / 1000) : "\(Int($0.rounded())) Hz" }
        let rate: (Double) -> String = { $0 < 0.05 ? "Off" : String(format: "%.1f Hz", $0) }

        let length: (Double) -> String = { String(format: "%.2f s", $0) }

        addSlider("Start Pitch", range: SynthRecipe.frequencyRange, logarithmic: true, format: hertz, \.startFrequency)
        addSlider("End Pitch", range: SynthRecipe.frequencyRange, logarithmic: true, format: hertz, \.endFrequency)
        addSlider("Length", range: SynthRecipe.durationRange, format: length, \.duration)
        addSlider("Wobble Speed", range: 0...40, format: rate, \.vibratoRate)
        addSlider("Wobble Amount", range: 0...0.5, format: percent, \.vibratoDepth)
        addSlider("Pulse Speed", range: 0...20, format: rate, \.pulseRate)
        addSlider("Fade Out", range: 0...1, format: percent, \.decay)
        addSlider("Grit", range: 0...1, format: percent, \.grit)

        var randomizeConfiguration = UIButton.Configuration.gray()
        randomizeConfiguration.title = "Randomize"
        randomizeConfiguration.image = UIImage(systemName: "dice")
        randomizeConfiguration.imagePadding = 8
        let randomizeButton = UIButton(configuration: randomizeConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.randomize()
        })

        var playConfiguration = UIButton.Configuration.filled()
        playConfiguration.title = "Play"
        playConfiguration.image = UIImage(systemName: "play.fill")
        playConfiguration.imagePadding = 8
        let playButton = UIButton(configuration: playConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.playPreview()
        })

        let buttons = UIStackView(arrangedSubviews: [randomizeButton, playButton])
        buttons.distribution = .fillEqually
        buttons.spacing = 12

        let hint = UILabel()
        hint.text = "Let go of a slider to hear the change."
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        let rows: [UIView] = [nameField, waveformControl, buttons, hint] + sliders.map { $0.view }
        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = 20
        stack.setCustomSpacing(12, after: buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -20),
            playButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])

        updateControls()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SoundPlayer.shared.stopPreview()
    }

    private func addSlider(_ title: String, range: ClosedRange<Double>, logarithmic: Bool = false,
                           format: @escaping (Double) -> String, _ keyPath: WritableKeyPath<SynthRecipe, Double>) {
        let slider = ParameterSliderView(title: title, range: range, logarithmic: logarithmic, format: format)
        slider.onChange = { [weak self] value in self?.recipe[keyPath: keyPath] = value }
        slider.onCommit = { [weak self] in self?.playPreview() }
        sliders.append((view: slider, keyPath: keyPath))
    }

    private func updateControls() {
        waveformControl.selectedSegmentIndex = SynthRecipe.Waveform.allCases.firstIndex(of: recipe.waveform) ?? 0
        for (slider, keyPath) in sliders {
            slider.value = recipe[keyPath: keyPath]
        }
    }

    private func waveformChanged() {
        recipe.waveform = SynthRecipe.Waveform.allCases[waveformControl.selectedSegmentIndex]
        playPreview()
    }

    private func randomize() {
        recipe = .random()
        updateControls()
        playPreview()
    }

    private func playPreview() {
        SoundPlayer.shared.preview(recipe)
    }

    private func save() {
        let trimmedName = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = trimmedName.isEmpty ? "My Sound" : trimmedName

        if var sound = editingSound {
            sound.name = name
            sound.source = .synth(recipe)
            library.save(sound)
        } else {
            let sound = SoundEffect(name: name, source: .synth(recipe))
            library.save(sound)
            library.selectedSound = sound
        }
        dismiss(animated: true)
    }
}
