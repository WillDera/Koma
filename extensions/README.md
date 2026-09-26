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
| `novelbuddy.js` | Novel source (itemType 2) |
| `hdoujin.js` | Doujin gallery source (itemType 0, NSFW) |

`sourceCodeUrl` may be relative (`novelbuddy.js`); Koma resolves it against the
repo index URL. The Pages deploy workflow also rewrites absolute URLs.

## HDoujin

Browse, Popular, search, tags, artists, circles and Random all work against
`https://api.hdoujin.org`.

**Page images are capped at 250–350px.** HDoujin serves full-resolution pages
only from `/books/data/{id}/{key}/...` behind a Cloudflare Turnstile clearance
token, which returns `403` to a plain extension. This source reads the public
thumbnail tier instead, so pages look soft in the reader. Everything else —
titles, covers, tags, page counts, dates — is complete.

Other notes:

- `Origin` **and** `Referer` are mandatory; omitting either returns `400` with
  an empty body.
- The API allows ~5 requests per 2–5 seconds. The extension serialises every
  call behind a queue and waits out the window when the rate limit is hit.
- Popular is capped at 1000 entries (13 pages); page 14 is a hard `400`.
- The `Browse` filter set to `Random` returns a single random gallery. Filters
  do not apply to it — HDoujin has no randomised equivalent of `/books`.
- Tag, Artist and Circle terms are fuzzy and AND-ed together, matching the
  site's own search box. HDoujin's exact-anchor syntax (`tag:^term$`) is only
  populated for a handful of tags and cannot be combined with the
  Include/Exclude namespace facets, so it is deliberately not used.
- `Include Tags` / `Exclude Tags` map to HDoujin's Male / Female / Mixed /
  Other namespace facets and render as a combined Ignore / Include / Exclude
  list.

