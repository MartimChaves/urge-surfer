# Contributing

Thanks for helping improve Urge Surfer.

## Getting started

1. Fork and clone the repository.
2. Start the development build with `docker compose up dev --build`.
3. Open <http://localhost>.
4. Make a focused change and add or update tests where appropriate.

Development mode includes the **Just write** screen and the pen-lag control. These controls are intentionally excluded from production builds.

## Before opening a pull request

Run the same checks used by CI:

```sh
npm test
python -m unittest tool.test_glyphdata
bash tool/check_no_network.sh
docker compose build dev prod
```

Keep the app privacy-respecting: do not add analytics, trackers, remote assets, or network calls. User activity and wave totals must remain on the user's device.

For changes to coping phrases, use clear, supportive language and explain the reasoning in the pull request. Clinical or peer-support review is especially welcome.

By contributing code, you agree that it may be distributed under the repository's AGPL-3.0 license. Phrase-library contributions are distributed under CC BY-SA 4.0.
