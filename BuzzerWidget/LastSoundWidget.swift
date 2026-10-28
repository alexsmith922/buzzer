import SwiftUI
import WidgetKit

/// A Lock Screen widget that plays the last buzzer sound when tapped, without opening the app.
@main
struct LastSoundWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: LastSound.widgetKind, provider: LastSoundProvider()) { entry in
            LastSoundWidgetView(entry: entry)
        }
        .configurationDisplayName("Buzzer")
        .description("Plays the sound of the buzzer you used last, without opening the app.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LastSoundEntry: TimelineEntry {
    let date: Date
    /// Nil until a buzzer has been pressed in the app.
    let soundName: String?
}

/// The widget only changes when the app saves a new last sound, which reloads it.
struct LastSoundProvider: TimelineProvider {

    func placeholder(in context: Context) -> LastSoundEntry {
        LastSoundEntry(date: .now, soundName: "Game Show Buzzer")
    }

    func getSnapshot(in context: Context, completion: @escaping (LastSoundEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastSoundEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> LastSoundEntry {
        LastSoundEntry(date: .now, soundName: LastSound.current?.name)
    }
}

struct LastSoundWidgetView: View {

    @Environment(\.widgetFamily) private var family
    let entry: LastSoundEntry

    var body: some View {
        Button(intent: PlayLastSoundIntent()) {
            switch family {
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    Image(systemName: "button.programmable")
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("Buzzer")
                            .font(.headline)
                            .widgetAccentable()
                        Text(entry.soundName ?? "Tap to buzz")
                            .font(.caption)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            default:
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "button.programmable")
                        .font(.title)
                        .widgetAccentable()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(entry.soundName ?? "buzzer sound")")
        .containerBackground(.clear, for: .widget)
    }
}

#Preview(as: .accessoryRectangular) {
    LastSoundWidget()
} timeline: {
    LastSoundEntry(date: .now, soundName: "Air Horn")
    LastSoundEntry(date: .now, soundName: nil)
}
