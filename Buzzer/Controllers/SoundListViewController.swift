import UIKit

/// Lists the user's sounds and the built-in ones. Tap to choose and hear a sound;
/// use + to design or record a new one.
final class SoundListViewController: UITableViewController {

    private enum Section: Int, CaseIterable {
        case custom, classic, builtIn
    }

    private let library = SoundLibrary.shared
    private let cellIdentifier = "SoundCell"

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Sounds"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)

        let menu = UIMenu(children: [
            UIAction(title: "Design a Sound", image: UIImage(systemName: "slider.horizontal.3")) { [weak self] _ in
                self?.presentDesigner(recipe: .random(), name: "My Sound")
            },
            UIAction(title: "Record a Sound", image: UIImage(systemName: "mic")) { [weak self] _ in
                self?.presentModally(SoundRecorderViewController())
            },
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, menu: menu)
        navigationItem.rightBarButtonItem?.accessibilityLabel = "New Sound"

        NotificationCenter.default.addObserver(self, selector: #selector(soundsChanged),
                                               name: SoundLibrary.didChangeNotification, object: library)
    }

    @objc private func soundsChanged() {
        tableView.reloadData()
    }

    private func sounds(in section: Int) -> [SoundEffect] {
        switch Section(rawValue: section)! {
        case .custom: return library.customSounds
        case .classic: return library.classicSounds
        case .builtIn: return library.builtInSounds
        }
    }

    private func sound(at indexPath: IndexPath) -> SoundEffect {
        sounds(in: indexPath.section)[indexPath.row]
    }

    // MARK: - Data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sounds(in: section).count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .custom: return "My Sounds"
        case .classic: return "Game Show"
        case .builtIn: return "Synthesized"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .custom:
            return library.customSounds.isEmpty ? "Tap + to design a sound or record your own." : nil
        case .classic:
            return library.hasMissingClassicSounds
                ? "Some game show sounds haven't downloaded yet. They'll appear the next time you open the app with a connection."
                : nil
        case .builtIn:
            return "These sounds are synthesized by the app. Swipe left on one to remix it."
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        let sound = sound(at: indexPath)

        var content = UIListContentConfiguration.subtitleCell()
        content.text = sound.name
        content.secondaryText = sound.subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        switch sound.source {
        case .synth: content.image = UIImage(systemName: "waveform")
        case .recording: content.image = UIImage(systemName: "mic.fill")
        case .downloaded: content.image = UIImage(systemName: "speaker.wave.2.fill")
        }
        cell.contentConfiguration = content
        cell.accessoryType = sound.id == library.selectedSound.id ? .checkmark : .none
        return cell
    }

    // MARK: - Delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let sound = sound(at: indexPath)
        library.selectedSound = sound
        SoundPlayer.shared.play(sound)
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let sound = sound(at: indexPath)

        let remix = UIContextualAction(style: .normal, title: "Remix") { [weak self] _, _, done in
            if let recipe = sound.recipe {
                self?.presentDesigner(recipe: recipe, name: "\(sound.name) Remix")
            }
            done(true)
        }
        remix.backgroundColor = .systemIndigo
        remix.image = UIImage(systemName: "slider.horizontal.3")

        if sound.isBuiltIn {
            return sound.recipe == nil ? nil : UISwipeActionsConfiguration(actions: [remix])
        }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            self?.library.delete(sound)
            done(true)
        }
        delete.image = UIImage(systemName: "trash")

        let rename = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, done in
            self?.promptRename(sound)
            done(true)
        }
        rename.backgroundColor = .systemBlue
        rename.image = UIImage(systemName: "pencil")

        guard let recipe = sound.recipe else {
            return UISwipeActionsConfiguration(actions: [delete, rename])
        }
        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, done in
            self?.presentDesigner(recipe: recipe, name: sound.name, editing: sound)
            done(true)
        }
        edit.backgroundColor = .systemIndigo
        edit.image = UIImage(systemName: "slider.horizontal.3")
        return UISwipeActionsConfiguration(actions: [delete, rename, edit])
    }

    /// Long press shows the same actions as swiping, plus Play.
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                            point: CGPoint) -> UIContextMenuConfiguration? {
        let sound = sound(at: indexPath)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self else { return nil }
            var actions: [UIMenuElement] = [
                UIAction(title: "Play", image: UIImage(systemName: "play.fill")) { _ in
                    SoundPlayer.shared.play(sound)
                },
            ]

            if sound.isBuiltIn {
                if let recipe = sound.recipe {
                    actions.append(UIAction(title: "Remix", image: UIImage(systemName: "slider.horizontal.3")) { _ in
                        self.presentDesigner(recipe: recipe, name: "\(sound.name) Remix")
                    })
                }
                return UIMenu(children: actions)
            }

            actions.append(UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.promptRename(sound)
            })
            if let recipe = sound.recipe {
                actions.append(UIAction(title: "Edit Sound", image: UIImage(systemName: "slider.horizontal.3")) { _ in
                    self.presentDesigner(recipe: recipe, name: sound.name, editing: sound)
                })
            }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.library.delete(sound)
            }
            actions.append(UIMenu(options: .displayInline, children: [delete]))
            return UIMenu(children: actions)
        }
    }

    // MARK: - Navigation

    private func presentDesigner(recipe: SynthRecipe, name: String, editing sound: SoundEffect? = nil) {
        presentModally(SoundDesignerViewController(recipe: recipe, name: name, editing: sound))
    }

    private func presentModally(_ viewController: UIViewController) {
        let navigationController = UINavigationController(rootViewController: viewController)
        // Avoid losing unsaved work to an accidental swipe down.
        navigationController.isModalInPresentation = true
        present(navigationController, animated: true)
    }

    private func promptRename(_ sound: SoundEffect) {
        let alert = UIAlertController(title: "Rename Sound", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = sound.name
            field.autocapitalizationType = .words
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            var renamed = sound
            renamed.name = name
            self?.library.save(renamed)
        })
        present(alert, animated: true)
    }
}
