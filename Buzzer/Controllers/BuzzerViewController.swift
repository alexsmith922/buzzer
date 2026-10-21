import UIKit

/// The main screen: one to six buzzers, each with its own sound and color. Tap the
/// sound under a buzzer to pick a different one without leaving the screen.
final class BuzzerViewController: UIViewController {

    private let library = SoundLibrary.shared
    private let board = BuzzerBoard.shared
    private let flashView = UIView()
    private let grid = UIStackView()
    private var padViews: [BuzzerPadView] = []

    /// The arrangement the grid was last built for, so it's only rebuilt when that changes.
    private var gridShape: (count: Int, columns: Int)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Buzzer"
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.1, alpha: 1)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "music.note.list"), style: .plain,
            target: self, action: #selector(showSoundLibrary))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "Sounds"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "square.grid.2x2"),
                                                           primaryAction: nil, menu: nil)
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Number of Buzzers"

        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        flashView.frame = view.bounds
        flashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(flashView)

        padViews = (0..<BuzzerBoard.maximumCount).map { index in
            let padView = BuzzerPadView()
            padView.buzzer.addAction(UIAction { [weak self] _ in self?.buzz(padAt: index) }, for: .touchDown)
            return padView
        }

        grid.axis = .vertical
        grid.distribution = .fillEqually
        grid.spacing = 12
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            grid.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
            grid.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
        ])

        NotificationCenter.default.addObserver(self, selector: #selector(padsChanged),
                                               name: SoundLibrary.didChangeNotification, object: library)
        NotificationCenter.default.addObserver(self, selector: #selector(padsChanged),
                                               name: BuzzerBoard.didChangeNotification, object: board)
        padsChanged()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layOutGrid()
    }

    // MARK: - Updating

    @objc private func padsChanged() {
        for (index, padView) in padViews.enumerated() where index < board.count {
            configure(padView, at: index)
        }
        navigationItem.leftBarButtonItem?.menu = countMenu()
        layOutGrid()
    }

    private func configure(_ padView: BuzzerPadView, at index: Int) {
        let sound = board.sound(forPadAt: index)
        let color = board.pads[index].color
        padView.buzzer.capColor = color.uiColor
        padView.buzzer.accessibilityLabel = board.count > 1 ? "Buzzer \(index + 1)" : "Buzzer"
        padView.buzzer.accessibilityValue = sound.name
        padView.soundButton.configuration?.title = sound.name
        padView.soundButton.accessibilityHint = "Choose a different sound"
        padView.soundButton.menu = soundMenu(forPadAt: index)
        SoundPlayer.shared.prepare(sound)
    }

    /// Fills the grid with the buzzers on screen: stacked in portrait, side by side in landscape.
    private func layOutGrid() {
        let count = board.count
        let isLandscape = view.bounds.width > view.bounds.height
        let columns: Int
        switch count {
        case 1: columns = 1
        case 2: columns = isLandscape ? 2 : 1
        case 4: columns = 2
        default: columns = isLandscape ? 3 : 2
        }
        if gridShape?.count == count, gridShape?.columns == columns { return }
        gridShape = (count, columns)

        for row in grid.arrangedSubviews {
            row.removeFromSuperview()
        }
        for padView in padViews {
            padView.removeFromSuperview()
        }
        for rowStart in stride(from: 0, to: count, by: columns) {
            let row = UIStackView(arrangedSubviews: Array(padViews[rowStart..<min(rowStart + columns, count)]))
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = 12
            grid.addArrangedSubview(row)
        }
    }

    // MARK: - Menus

    private func soundMenu(forPadAt index: Int) -> UIMenu {
        let currentID = board.pads[index].soundID

        func section(_ title: String, _ sounds: [SoundEffect]) -> UIMenu {
            UIMenu(title: title, options: .displayInline, children: sounds.map { sound in
                UIAction(title: sound.name, state: sound.id == currentID ? .on : .off) { [weak self] _ in
                    self?.board.setSound(sound, forPadAt: index)
                    SoundPlayer.shared.play(sound)
                }
            })
        }

        let currentColor = board.pads[index].color
        let colors = UIMenu(title: "Color", image: UIImage(systemName: "paintpalette"),
                            children: BuzzerPad.Color.allCases.map { color in
            let swatch = UIImage(systemName: "circle.fill")?.withTintColor(color.uiColor, renderingMode: .alwaysOriginal)
            return UIAction(title: color.displayName, image: swatch, state: color == currentColor ? .on : .off) { [weak self] _ in
                self?.board.setColor(color, forPadAt: index)
            }
        })
        let more = UIAction(title: "All Sounds…", image: UIImage(systemName: "music.note.list")) { [weak self] _ in
            self?.showSounds(forPadAt: index)
        }

        var children: [UIMenuElement] = [UIMenu(options: .displayInline, children: [colors, more])]
        if !library.customSounds.isEmpty {
            children.append(section("My Sounds", library.customSounds))
        }
        if !library.classicSounds.isEmpty {
            children.append(section("Game Show", library.classicSounds))
        }
        children.append(section("Synthesized", library.builtInSounds))
        return UIMenu(children: children)
    }

    private func countMenu() -> UIMenu {
        UIMenu(title: "Buzzers", children: (1...BuzzerBoard.maximumCount).map { count in
            UIAction(title: count == 1 ? "1 Buzzer" : "\(count) Buzzers",
                     state: count == board.count ? .on : .off) { [weak self] _ in
                self?.board.setCount(count)
            }
        })
    }

    // MARK: - Actions

    private func buzz(padAt index: Int) {
        SoundPlayer.shared.play(board.sound(forPadAt: index))
        flashScreen(color: board.pads[index].color.uiColor)
    }

    private func flashScreen(color: UIColor) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        flashView.layer.removeAllAnimations()
        flashView.backgroundColor = color
        flashView.alpha = 0.22
        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.flashView.alpha = 0
        }
    }

    /// With one buzzer, the library picks its sound as before. With several, it's for
    /// browsing and making sounds; each buzzer's own menu picks its sound.
    @objc private func showSoundLibrary() {
        if board.count == 1 {
            showSounds(forPadAt: 0)
        } else {
            navigationController?.pushViewController(SoundListViewController(), animated: true)
        }
    }

    private func showSounds(forPadAt index: Int) {
        let list = SoundListViewController(selectedSoundID: board.pads[index].soundID) { [weak self] sound in
            self?.board.setSound(sound, forPadAt: index)
        }
        if board.count > 1 {
            list.title = "Buzzer \(index + 1)"
        }
        navigationController?.pushViewController(list, animated: true)
    }
}
