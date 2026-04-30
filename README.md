# Urge Surfer

A local-first, open-source mobile app that turns the moment of an impulsive urge into a meditative pause.

When the urge to gamble, scroll, drink, smoke, or otherwise act on an impulse hits, you open Urge Surfer instead. You name what you want to do. You rate how strong the urge feels. You complete a slow drawing meditation — tracing self-compassion phrases letter-by-letter, with simulated weight that forces the practice to be unhurried. You rate the urge again. You log the wave you just surfed.

Over time, the count of waves surfed grows. There are no streaks to break. Every pause counts as a win.

## Status

Early development. See the project plan for design and scope.

## Principles

- **Local-first.** Your data does not leave your device. The app declares no network permissions on either platform; the binary cannot make network calls.
- **No accounts. No telemetry. No ads.** The app does not know who you are, and is not trying to find out.
- **Open source under [AGPL-3.0](LICENSE).** Privacy claims need to be verifiable. This means anyone — you, a friend, an auditor — can read the source and confirm what the app does and doesn't do.
- **Harm reduction over abstinence.** No "X days clean" counters. Every wave you surf is a win regardless of what came before or after.
- **Self-compassion over affirmations.** Phrases follow Kristin Neff's framework (mindfulness, common humanity, self-kindness). Generic "you are worthy" affirmations can backfire for people with low self-esteem; we do not use them.

## Threat model

What this app protects:
- Your gambling, scrolling, smoking, drinking, etc. history is stored locally in an encrypted SQLite database. The encryption key is held in the platform secure enclave (Android Keystore / iOS Keychain).
- The app makes no outbound network connections. There is no cloud sync, no analytics, no crash reporting that leaves your device.

What this app does **not** protect against:
- Someone with physical access to your unlocked device.
- A compromised operating system.
- Backups taken by the OS that include app data (configure your OS backup settings if this matters to you).
- Other apps on the device with sufficient permissions to read app data (rare, but possible on rooted/jailbroken devices).

## Building

Once Flutter is installed:

```sh
flutter pub get
flutter run
```

## Contributing

Contributions are welcome — code, translations, phrase reviews, and especially clinical or peer-support input on the phrase library. See `CONTRIBUTING.md` (to be added).

The phrase library is the highest-leverage content artifact. Phrases are reviewed against Kristin Neff's self-compassion framework and the Wood, Perunovic & Lee (2009) self-affirmation backfire criteria before any release. Linguistic and cultural translation is a real contribution category — not a mechanical translation task.

## License

Source code: [AGPL-3.0](LICENSE).

Phrase library content (`assets/phrases/`): [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

## Acknowledgements

Mechanically informed by:
- Urge surfing — Bowen, Marlatt, and Mindfulness-Based Relapse Prevention research.
- GamblingLess: Curb Your Urge (Deakin University, 2021) — the closest existing tool, which validated several core mechanics.
- Kristin Neff's research on self-compassion.
- Peter Gollwitzer's research on implementation intentions ("if-then" plans).
- Mueller & Oppenheimer (2014) and James & Engelhardt (2012) on the cognitive effects of handwriting versus typing.

This project is not affiliated with any of the researchers, institutions, or projects above.
