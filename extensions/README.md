# Official Koma extension catalog

Ship JS (and later Dart) sources here. GitHub Pages publishes this folder to:

`https://willdera.github.io/Koma/extensions/`

## Add in the app

1. **Extensions → Repos → Add repo**
2. Paste: `https://willdera.github.io/Koma/extensions/index.json`
3. Install **NovelBuddy** (or any listed source) from Available

Or: **Settings → Sources → Plugin SDK → Add official extensions repo**.

Until Pages is enabled, the same files work from raw GitHub:

`https://raw.githubusercontent.com/WillDera/Koma/<branch>/extensions/index.json`

## Layout

| File | Role |
|------|------|
| `index.json` / `index.min.json` | Catalog (`{ "name", "extensions": [...] }`) |
| `novelbuddy.js` | Sample novel source |

`sourceCodeUrl` may be relative (`novelbuddy.js`); Koma resolves it against the
repo index URL. The Pages deploy workflow also rewrites absolute URLs.
