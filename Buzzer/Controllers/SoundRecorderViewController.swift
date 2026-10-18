import AVFoundation
import UIKit

/// Records a short clip with the microphone and saves it as a buzzer sound.
final class SoundRecorderViewController: UIViewController {

    private static let maxDuration: TimeInterval = 10

    private let library = SoundLibrary.shared
    private let fileName: String
    private var recordingURL: URL { library.recordingURL(for: fileName) }

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var recordedDuration: TimeInterval = 0
    private var hasRecording = false
    private var didSave = false

    private let recordButton = UIButton(type: .system)
    private let timeLabel = UILabel()
    private let levelView = UIProgressView(progressViewStyle: .bar)
    private let playButton = UIButton(configuration: .gray())
    private let clearButton = UIButton(configuration: .gray())
    private let nameField = UITextField()

    private var isRecording: Bool { recorder?.isRecording == true }

    init() {
        fileName = SoundLibrary.shared.makeRecordingFileName()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Record a Sound"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .save, primaryAction: UIAction { [weak self] _ in
            self?.save()
        })

        recordButton.tintColor = .white
        recordButton.backgroundColor = .systemRed
        recordButton.layer.cornerRadius = 60
        recordButton.addAction(UIAction { [weak self] _ in self?.recordTapped() }, for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .semibold)
        timeLabel.textAlignment = .center

        levelView.progressTintColor = .systemGreen
        levelView.trackTintColor = .tertiarySystemFill
        levelView.isAccessibilityElement = false

        playButton.configuration?.title = "Play Back"
        playButton.configuration?.image = UIImage(systemName: "play.fill")
        playButton.configuration?.imagePadding = 8
        playButton.addAction(UIAction { [weak self] _ in self?.playBack() }, for: .touchUpInside)

        clearButton.configuration?.title = "Clear"
        clearButton.configuration?.image = UIImage(systemName: "trash")
        clearButton.configuration?.imagePadding = 8
        clearButton.configuration?.baseForegroundColor = .systemRed
        clearButton.accessibilityHint = "Deletes this recording so you can start over"
        clearButton.addAction(UIAction { [weak self] _ in self?.clearRecording() }, for: .touchUpInside)

        let playbackButtons = UIStackView(arrangedSubviews: [playButton, clearButton])
        playbackButtons.spacing = 12
        playbackButtons.distribution = .fillEqually

        nameField.text = "My Recording"
        nameField.placeholder = "Sound name"
        nameField.borderStyle = .roundedRect
        nameField.autocapitalizationType = .words
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.addAction(UIAction { [weak self] _ in self?.nameField.resignFirstResponder() }, for: .editingDidEndOnExit)

        let hint = UILabel()
        hint.text = "Tap to record up to \(Int(Self.maxDuration)) seconds. Tap again to stop."
        hint.font = .preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.textAlignment = .center
        hint.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [recordButton, timeLabel, levelView, hint, playbackButtons, nameField])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.setCustomSpacing(8, after: timeLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 40),
            stack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            recordButton.widthAnchor.constraint(equalToConstant: 120),
            recordButton.heightAnchor.constraint(equalToConstant: 120),
            levelView.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.6),
            nameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        updateUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recorder?.stop()
        stopMeterTimer()
        SoundPlayer.shared.stopPreview()
        if !didSave {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        SoundPlayer.shared.activatePlaybackSession()
    }

    // MARK: - Recording

    private func recordTapped() {
        if isRecording {
            recorder?.stop()
            return
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            startRecording()
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.startRecording()
                    } else {
                        self?.showPermissionAlert()
                    }
                }
            }
        default:
            showPermissionAlert()
        }
    }

    private func startRecording() {
        SoundPlayer.shared.stopPreview()
        recordButton.isEnabled = false
        SoundPlayer.shared.activateRecordingSession { [weak self] error in
            guard let self else { return }
            self.recordButton.isEnabled = true
            if let error {
                self.showAlert(title: "Couldn't Record", message: error.localizedDescription)
            } else if self.viewIfLoaded?.window != nil {
                self.beginRecorder()
            }
        }
    }

    private func beginRecorder() {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: Self.maxDuration)
            self.recorder = recorder
            hasRecording = false
            recordedDuration = 0
            startMeterTimer()
        } catch {
            showAlert(title: "Couldn't Record", message: error.localizedDescription)
        }
        updateUI()
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.updateMeter()
        }
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        levelView.setProgress(0, animated: false)
    }

    private func updateMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        // averagePower is in decibels, roughly -60 (quiet) to 0 (loud).
        let level = max(0, (recorder.averagePower(forChannel: 0) + 60) / 60)
        levelView.setProgress(level, animated: false)
        recordedDuration = recorder.currentTime
        updateTimeLabel()
    }

    private func playBack() {
        guard hasRecording else { return }
        SoundPlayer.shared.preview(contentsOf: recordingURL)
    }

    /// Throws away the current take so the user can start over without leaving the screen.
    private func clearRecording() {
        guard !isRecording else { return }
        SoundPlayer.shared.stopPreview()
        recorder = nil
        try? FileManager.default.removeItem(at: recordingURL)
        hasRecording = false
        recordedDuration = 0
        updateUI()
    }

    private func save() {
        guard hasRecording else { return }
        let trimmedName = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sound = SoundEffect(name: trimmedName.isEmpty ? "My Recording" : trimmedName,
                                source: .recording(fileName: fileName))
        didSave = true
        library.save(sound)
        library.selectedSound = sound
        dismiss(animated: true)
    }

    // MARK: - UI

    private func updateUI() {
        let symbol = isRecording ? "stop.fill" : "mic.fill"
        recordButton.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 44)),
                              for: .normal)
        recordButton.accessibilityLabel = isRecording ? "Stop Recording" : "Record"
        playButton.isEnabled = hasRecording && !isRecording
        clearButton.isEnabled = hasRecording && !isRecording
        navigationItem.rightBarButtonItem?.isEnabled = hasRecording && !isRecording
        updateTimeLabel()
    }

    private func updateTimeLabel() {
        timeLabel.text = String(format: "%.1f / %.0f s", recordedDuration, Self.maxDuration)
    }

    private func showPermissionAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Needed",
            message: "Allow microphone access in Settings to record your own sounds.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AVAudioRecorderDelegate

extension SoundRecorderViewController: AVAudioRecorderDelegate {

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        stopMeterTimer()
        hasRecording = flag && recordedDuration > 0.1
        updateUI()
    }
}
