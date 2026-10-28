import Foundation
import WidgetKit

/// The sound the Lock Screen widget plays: whichever buzzer was pressed or given a new
/// sound most recently. Kept in the app group so the widget can show its name.
struct LastSound: Codable, Equatable {

    static let appGroup = "group.one.alexsmith.Buzzer"
    static let widgetKind = "LastSoundWidget"

    var soundID: UUID
    var name: String

    private static let storageKey = "lastSound"
    private static let defaults = UserDefaults(suiteName: appGroup)

    /// Setting a different sound refreshes the widget.
    static var current: LastSound? {
        get {
            defaults?.data(forKey: storageKey).flatMap { try? JSONDecoder().decode(LastSound.self, from: $0) }
        }
        set {
            guard newValue != current else { return }
            defaults?.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: storageKey)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }
}
