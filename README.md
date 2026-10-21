# Buzzer

A simple iOS buzzer app (UIKit, Swift, MVC). Press the big button and it sinks
in, springs back, ripples, flashes the screen, gives a haptic thump, and plays
a buzzer sound.

## Features

- **Arcade-style buzzer** fires on touch down, with a press animation and haptics.
  Rapid presses restart the sound, and it plays even with the silent switch on.
- **Up to six buzzers at once**, each with its own sound and color. Pick how many
  with the grid button, then tap the sound under any buzzer to change it from a
  menu without leaving the screen. Buzzers can be pressed at the same time.
- **11 built-in sounds** (Game Show Buzzer, Wrong Answer, Correct Ding, Air Horn,
  Laser, Alarm, Siren, Boing, Ref Whistle, Static Zap, Power Up). The app
  synthesizes them at runtime instead of shipping audio files, so there are no
  licensing concerns.
- **Game Show sounds**: recorded effects downloaded once on first open, then kept for offline use (see below).
- **Design a sound**: pick a waveform and shape pitch glide, length, wobble,
  pulse, fade and grit with sliders, or hit Randomize. Built-in sounds can be
  remixed (swipe left).
- **Record a sound**: record up to 10 seconds with the microphone, then drag the
  handles on the waveform to trim it before saving.
- Custom sounds can be edited, renamed and deleted, and are saved on device.

## Game Show sounds

These recorded effects aren't built into the app. The app downloads them from
this repo's `Sounds/` folder (via raw.githubusercontent.com) and keeps them in
Application Support, so after one successful download they work offline. If the
first open has no connection, the app retries each time it becomes active.
Sounds not downloaded yet are simply hidden. The repo must stay public for the
download to work.

| File in `Sounds/`  | Shown as            |
| ------------------ | ------------------- |
| `correct.mp3`      | Correct Answer      |
| `wrong.mp3`        | Wrong Answer Buzzer |
| `times-up.mp3`     | Time's Up           |
| `drumroll.mp3`     | Drumroll            |
| `applause.mp3`     | Applause            |
| `aww.mp3`          | Aww                 |
| `rimshot.mp3`      | Rimshot             |
| `sad-trombone.mp3` | Sad Trombone        |

Only use CC0 or otherwise free-to-use clips, and record where each came from in
`Sounds/CREDITS.md`.

## Running

Open `Buzzer.xcodeproj` in Xcode 16 or later, choose a simulator or device, and run.
Requires iOS 17. To run on a device, set your team under Signing & Capabilities.

## Layout

```
Buzzer/
  App/          AppDelegate, SceneDelegate
  Models/       SynthRecipe, SoundEffect (+ built-in presets), SoundLibrary,
                BuzzerBoard (how many buzzers and each one's sound and color)
  Services/     SoundSynthesizer (recipe -> WAV), SoundPlayer (AVAudioPlayer),
                SoundDownloader (game show sounds), AudioClipEditor (waveform + trim)
  Views/        BuzzerButton, BuzzerPadView, ParameterSliderView, WaveformTrimView
  Controllers/  Buzzer, SoundList, SoundDesigner, SoundRecorder
Sounds/         Game show sound files the app downloads (not bundled)
```
