# Urge Surfer

A local-first, open-source web app that turns the moment of an impulsive urge into a meditative pause. It runs in any modern browser, on a phone or a computer.

When the urge to gamble, scroll, drink, smoke, or otherwise act on an impulse hits, you open Urge Surfer instead. You name what you want to do. You rate how strong the urge feels. You complete a slow drawing meditation — tracing self-compassion phrases in cursive, with simulated weight that forces the practice to be unhurried. You rate the urge again. You log the wave you just surfed.

Over time, the count of waves surfed grows. There are no streaks to break. Every pause counts as a win.

## Status

Early development. Formerly a Flutter phone app; now a plain HTML/CSS/JavaScript web app with no build step and no dependencies.

## Running it

### Development

```sh
git clone <repository-url>
cd urge-surfer
docker compose up dev --build
```

Open **<http://localhost>** to play with the app. Development mode live-mounts the source tree, so edits appear after a browser refresh. It includes **Just write** and the **pen lag** checkbox. Stop it with `docker compose down`.

Without Docker, run `python3 -m http.server 8000` and open <http://localhost:8000>. Opening `index.html` directly from disk does not work because browsers refuse ES modules over `file://`.

### Production

`SITE_ADDRESS` already defaults to `urgesurfer.surf`. Point that domain at the server, then run:

```sh
docker compose up prod -d --build
```

Production removes both development-only controls. Caddy obtains and renews HTTPS automatically. Run `docker compose down` before switching between development and production because both use port 80.

## Principles

- **Local-first.** Only your wave count is stored in your browser's `localStorage`. What you typed, how you rated the urge and which phrase you traced are discarded and never sent anywhere.
- **No accounts. No ads.** The app does not know who you are, and is not trying to find out.
- **Open source under [AGPL-3.0](LICENSE).** Privacy claims need to be verifiable. This means anyone — you, a friend, an auditor — can read the source and confirm what the app does and doesn't do.
- **Harm reduction over abstinence.** No "X days clean" counters. Every wave you surf is a win regardless of what came before or after.
- **Self-compassion over affirmations.** Phrases follow Kristin Neff's framework (mindfulness, common humanity, self-kindness). Generic "you are worthy" affirmations can backfire for people with low self-esteem; we do not use them.

## Threat model

What this app protects:
- Your wave count stays in `localStorage` under the origin you loaded the page from. It is never uploaded, and there is no cloud sync, analytics, or crash reporting. `tool/check_no_network.sh` proves the source contains no networking calls and references no remote hosts; CI runs it on every change.
- Browser profile sync (Chrome, Firefox) does not sync `localStorage`, so your waves do not follow you to other devices.

What this app does **not** protect against, and where a web app is genuinely weaker than the phone app it replaces:
- **`localStorage` is not encrypted.** Anyone who can use your unlocked browser profile can read it, including from the developer tools. The phone app kept an encrypted database with the key in the OS secure enclave; a browser has no equivalent.
- **Whoever serves the page can see that you requested it**, from their server logs. If that matters, self-host it or run it locally.
- **The URL lands in your browser history**, and the page may appear in tab-switcher screenshots.
- Browser extensions with access to the page can read everything on it.
- Someone with physical access to your unlocked device, or a compromised operating system.

## Contributing

Contributions are welcome — code, translations, phrase reviews, and especially clinical or peer-support input on the phrase library. See [CONTRIBUTING.md](CONTRIBUTING.md).

The phrase library is the highest-leverage content artifact. Phrases are reviewed against Kristin Neff's self-compassion framework and the Wood, Perunovic & Lee (2009) self-affirmation backfire criteria before any release. Linguistic and cultural translation is a real contribution category — not a mechanical translation task.

## License

Source code: [AGPL-3.0](LICENSE).

Phrase library content (`assets/phrases/`): [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Sacramento reference font: [SIL Open Font License 1.1](vendor/sacramento/OFL.txt).

## Acknowledgements

Mechanically informed by:
- Urge surfing — Bowen, Marlatt, and Mindfulness-Based Relapse Prevention research.
- GamblingLess: Curb Your Urge (Deakin University, 2021) — the closest existing tool, which validated several core mechanics.
- Kristin Neff's research on self-compassion.
- Peter Gollwitzer's research on implementation intentions ("if-then" plans).
- Mueller & Oppenheimer (2014) and James & Engelhardt (2012) on the cognitive effects of handwriting versus typing.

The editable lowercase centerlines are seeded from the MIT-licensed letterpaths dataset. Brian J. Bonislawsky's Sacramento typeface is distributed under the SIL Open Font License 1.1 and is vendored as an aligned reference overlay for the glyph editor.

This project is not affiliated with any of the researchers, institutions, or projects above.
