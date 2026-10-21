import Foundation

/// Owns the built-in sounds and the user's own sounds.
/// Custom sounds are saved as JSON next to their recordings in Documents/Sounds.
final class SoundLibrary {

    static let shared = SoundLibrary()
    static let didChangeNotification = Notification.Name("SoundLibraryDidChange")

    let builtInSounds = SoundEffect.builtIns
    private(set) var customSounds: [SoundEffect] = []

    private let fileManager: FileManager
    private let directory: URL

    private var indexURL: URL { directory.appendingPathComponent("sounds.json") }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("Sounds", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    /// The game show sounds that have finished downloading.
    var classicSounds: [SoundEffect] {
        SoundEffect.classics.filter { sound in
            if case .downloaded(let fileName) = sound.source {
                return SoundDownloader.shared.localURL(for: fileName) != nil
            }
            return false
        }
    }

    var hasMissingClassicSounds: Bool {
        classicSounds.count < SoundEffect.classics.count
    }

    var allSounds: [SoundEffect] { customSounds + classicSounds + builtInSounds }

    /// Called when a downloaded sound arrives, so screens can show it.
    func downloadedSoundsDidChange() {
        notifyChange()
    }

    func sound(withID id: UUID) -> SoundEffect? {
        allSounds.first { $0.id == id }
    }

    /// Adds a new custom sound, or replaces the existing one with the same ID.
    func save(_ sound: SoundEffect) {
        if let index = customSounds.firstIndex(where: { $0.id == sound.id }) {
            customSounds[index] = sound
        } else {
            customSounds.insert(sound, at: 0)
        }
        persist()
        notifyChange()
    }

    func delete(_ sound: SoundEffect) {
        customSounds.removeAll { $0.id == sound.id }
        if case .recording(let fileName) = sound.source {
            try? fileManager.removeItem(at: recordingURL(for: fileName))
        }
        persist()
        notifyChange()
    }

    func recordingURL(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func makeRecordingFileName() -> String {
        "\(UUID().uuidString).m4a"
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let sounds = try? JSONDecoder().decode([SoundEffect].self, from: data) else { return }
        customSounds = sounds
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(customSounds)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("Failed to save sounds: \(error)")
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
