# Buzzer

A simple iOS buzzer app (UIKit, Swift, MVC). Press the big button and it sinks
in, springs back, ripples, flashes the screen, gives a haptic thump, and plays
a buzzer sound.

## Features

- **Arcade-style buzzer** fires on touch down, with a press animation and haptics.
  Rapid presses restart the sound, and it plays even with the silent switch on.
- **11 built-in sounds** (Game Show Buzzer, Wrong Answer, Correct Ding, Air Horn,
  Laser, Alarm, Siren, Boing, Ref Whistle, Static Zap, Power Up). The app
  synthesizes them at runtime instead of shipping audio files, so there are no
  licensing concerns.
- **Game Show sounds**: recorded effects bundled from `Buzzer/Sounds` (see below).
- **Design a sound**: pick a waveform and shape pitch glide, length, wobble,
  pulse, fade and grit with sliders, or hit Randomize. Built-in sounds can be
  remixed (swipe left).
- **Record a sound**: record up to 10 seconds with the microphone.
- Custom sounds can be edited, renamed and deleted, and are saved on device.

## Adding the Game Show sounds

Drop audio files (m4a, mp3, wav, caf or aiff) into `Buzzer/Sounds` with these
names, and each one appears in the app's Game Show section. Missing files are
simply hidden. Use CC0 or otherwise free-to-use clips, e.g. from Pixabay or
Freesound filtered to CC0.

| File name      | Shown as            |
| -------------- | ------------------- |
| `correct`      | Correct Answer      |
| `wrong`        | Wrong Answer Buzzer |
| `times-up`     | Time's Up           |
| `drumroll`     | Drumroll            |
| `applause`     | Applause            |
| `aww`          | Aww                 |
| `rimshot`      | Rimshot             |
| `sad-trombone` | Sad Trombone        |

## Running

Open `Buzzer.xcodeproj` in Xcode 16 or later, choose a simulator or device, and run.
Requires iOS 17. To run on a device, set your team under Signing & Capabilities.

## Layout

```
Buzzer/
  App/          AppDelegate, SceneDelegate
  Models/       SynthRecipe, SoundEffect (+ built-in presets), SoundLibrary
  Sounds/       Bundled game show sound effects
  Services/     SoundSynthesizer (recipe -> WAV), SoundPlayer (AVAudioPlayer)
  Views/        BuzzerButton, ParameterSliderView
  Controllers/  Buzzer, SoundList, SoundDesigner, SoundRecorder
```
