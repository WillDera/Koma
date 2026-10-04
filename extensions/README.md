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
| `hitomi.js` | Hitomi.la gallery source (itemType 0, NSFW) |

`sourceCodeUrl` may be relative (`novelbuddy.js`); Koma resolves it against the
repo index URL. The Pages deploy workflow also rewrites absolute URLs.

## HDoujin

Browse, Popular, search, tags, artists, circles and Random all work against
`https://api.hdoujin.org`.

**Full-resolution pages** come from `/books/data/{id}/{key}/{dataId}/{dataKey}/{width}`
after the site's clearance exchange. The source asks for 1920px, then 1280px.
The first chapter in a session can take a few seconds while that token is
issued. Thumbnails (250–350px) are only a fallback if the token request fails.

Other notes:

- `Origin` **and** `Referer` are mandatory; omitting either returns `400` with
  an empty body.
- The API allows ~5 requests per 2–5 seconds. The extension serialises every
  call behind a queue and waits out the window when the rate limit is hit.
- Popular is capped at 1000 entries (13 pages); page 14 is a hard `400`.
- The `Random` filter set to `On` returns a single random gallery. Other
  filters do not apply to it — HDoujin has no randomised equivalent of `/books`.
- `Artist`, `Tag`, and `Circle` are text filters. `Popular Tags` is a checkbox
  list: ticking a tag includes it (`tag:name`). Terms are fuzzy and AND-ed,
  matching the site's own search box. Exact-anchor syntax (`tag:^term$`) is
  only populated for a handful of tags and cannot be combined with the
  Include/Exclude namespace facets, so it is deliberately not used.
- `Include Tags` / `Exclude Tags` map to HDoujin's Male / Female / Mixed /
  Other namespace facets and render as a combined Ignore / Include / Exclude
  list.

## Hitomi

English galleries from [hitomi.la](https://hitomi.la). Popular / Latest use
`.nozomi` int32 indexes on `ltn.gold-usergeneratedcontent.net`; the HTTP bridge
returns those as base64 (`X-Koma-Body: base64`) so the bytes stay intact.

- **Popular** → today's English popular index. **Latest** → full English index.
- **Catalog** filter (search with an empty query): Latest, Popular Today /
  Week / Month / Year / All.
- **Random** → shuffled page from Popular Year.
- **Artist / Series / Tag / Character** text filters use Hitomi slugs
  (`female:glasses`, `artist:name`, etc.). A bare search query is treated as a
  tag; `artist:…` / `series:…` / `character:…` / `tag:…` prefixes work; a
  numeric query opens that gallery id.
- Reader pages prefer AVIF, then WebP, then the original file, using Hitomi's
  `gg.js` subdomain math. List covers come from galleryblock thumbnails.

