import Foundation

/// One buzzer on the main screen: the sound it plays and the color of its cap.
struct BuzzerPad: Codable, Equatable {

    enum Color: String, Codable, CaseIterable {
        case red, blue, green, yellow, orange, purple

        var displayName: String { rawValue.capitalized }
    }

    /// A color the user picked themselves, as sRGB components.
    struct CustomColor: Codable, Equatable {
        var red: Double
        var green: Double
        var blue: Double
    }

    var soundID: UUID
    var color: Color
    /// Overrides `color` when set.
    var customColor: CustomColor?
}

/// How many buzzers are on screen and how each one is set up. Every pad is kept, even
/// ones not showing, so lowering the count and raising it again brings back their sounds.
/// Saved as JSON in UserDefaults.
final class BuzzerBoard {

    static let shared = BuzzerBoard()
    static let didChangeNotification = Notification.Name("BuzzerBoardDidChange")
    static let maximumCount = 6

    private(set) var pads: [BuzzerPad]
    private(set) var count: Int

    private let library: SoundLibrary
    private let defaults: UserDefaults
    private static let storageKey = "buzzerBoard"
    /// Where the single-buzzer version of the app kept its sound.
    private static let legacySelectedSoundKey = "selectedSoundID"

    private struct Stored: Codable {
        var count: Int
        var pads: [BuzzerPad]
    }

    init(library: SoundLibrary = .shared, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults

        let starterSounds = Self.starterSounds(firstSoundID: defaults.string(forKey: Self.legacySelectedSoundKey)
            .flatMap(UUID.init(uuidString:)))
        let starterPads = zip(starterSounds, BuzzerPad.Color.allCases).map { BuzzerPad(soundID: $0, color: $1) }

        if let data = defaults.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            // Top up from the starters in case an older save has fewer pads.
            pads = stored.pads + starterPads.dropFirst(stored.pads.count)
            count = min(max(stored.count, 1), Self.maximumCount)
        } else {
            pads = starterPads
            count = 1
        }
    }

    /// The pads currently on screen.
    var visiblePads: [BuzzerPad] { Array(pads.prefix(count)) }

    func setCount(_ newCount: Int) {
        count = min(max(newCount, 1), Self.maximumCount)
        persistAndNotify()
    }

    /// The sound a pad plays, falling back to the first built-in if its sound was deleted.
    func sound(forPadAt index: Int) -> SoundEffect {
        library.sound(withID: pads[index].soundID) ?? library.builtInSounds[0]
    }

    func setSound(_ sound: SoundEffect, forPadAt index: Int) {
        pads[index].soundID = sound.id
        persistAndNotify()
    }

    func setColor(_ color: BuzzerPad.Color, forPadAt index: Int) {
        pads[index].color = color
        pads[index].customColor = nil
        persistAndNotify()
    }

    func setCustomColor(_ color: BuzzerPad.CustomColor, forPadAt index: Int) {
        guard pads[index].customColor != color else { return }
        pads[index].customColor = color
        persistAndNotify()
    }

    /// A mix of different sounds so new buzzers are easy to tell apart.
    private static func starterSounds(firstSoundID: UUID?) -> [UUID] {
        let builtIns = SoundEffect.builtIns
        let picks = [0, 2, 1, 3, 7, 4].map { builtIns[$0].id }
        guard let firstSoundID else { return picks }
        return [firstSoundID] + picks.filter { $0 != firstSoundID }.prefix(maximumCount - 1)
    }

    private func persistAndNotify() {
        if let data = try? JSONEncoder().encode(Stored(count: count, pads: pads)) {
            defaults.set(data, forKey: Self.storageKey)
        }
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
