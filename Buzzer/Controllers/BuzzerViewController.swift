import UIKit

/// The main screen: one big buzzer and the name of the sound it plays.
final class BuzzerViewController: UIViewController {

    private let library = SoundLibrary.shared
    private let buzzer = BuzzerButton()
    private let soundButton = UIButton(configuration: .gray())
    private let flashView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buzzer"
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.1, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "music.note.list"), style: .plain,
            target: self, action: #selector(showSounds))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Sounds"

        flashView.backgroundColor = buzzer.capColor
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        flashView.frame = view.bounds
        flashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(flashView)

        buzzer.translatesAutoresizingMaskIntoConstraints = false
        buzzer.addTarget(self, action: #selector(buzz), for: .touchDown)
        view.addSubview(buzzer)

        soundButton.configuration?.image = UIImage(systemName: "speaker.wave.2.fill")
        soundButton.configuration?.imagePadding = 8
        soundButton.configuration?.cornerStyle = .capsule
        soundButton.addTarget(self, action: #selector(showSounds), for: .touchUpInside)
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(soundButton)

        let safeArea = view.safeAreaLayoutGuide
        let preferredWidth = buzzer.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.78)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            buzzer.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            buzzer.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor, constant: -30),
            buzzer.heightAnchor.constraint(equalTo: buzzer.widthAnchor),
            buzzer.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            buzzer.heightAnchor.constraint(lessThanOrEqualTo: safeArea.heightAnchor, multiplier: 0.6),
            preferredWidth,

            soundButton.topAnchor.constraint(equalTo: buzzer.bottomAnchor, constant: 40),
            soundButton.centerXAnchor.constraint(equalTo: safeArea.centerXAnchor),
            soundButton.leadingAnchor.constraint(greaterThanOrEqualTo: safeArea.leadingAnchor, constant: 16),
            soundButton.trailingAnchor.constraint(lessThanOrEqualTo: safeArea.trailingAnchor, constant: -16),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(soundsChanged),
                                               name: SoundLibrary.didChangeNotification, object: library)
        soundsChanged()
    }

    @objc private func soundsChanged() {
        let sound = library.selectedSound
        soundButton.configuration?.title = sound.name
        soundButton.accessibilityHint = "Choose a different sound"
        SoundPlayer.shared.prepare(sound)
    }

    @objc private func buzz() {
        SoundPlayer.shared.play(library.selectedSound)
        flashScreen()
    }

    private func flashScreen() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        flashView.layer.removeAllAnimations()
        flashView.alpha = 0.22
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.flashView.alpha = 0
        }
    }

    @objc private func showSounds() {
        navigationController?.pushViewController(SoundListViewController(), animated: true)
    }
}
