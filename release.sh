gh release create v2.52.0+389 --target feat/optimization --generate-notes --latest --notes "## v2.52.0+389

### Changelog
Shipped in **2.52.0+389**. Tracker-backed catalog depth on manga detail, personal scores/reviews, alternate-title library search, plus app lock and update/sheet messaging fixes.

## Tracker metadata
- Fetch and cache catalog details (format, release status, scores, popularity, genres/tags, titles) from **AniList**, **MAL**, and **MangaUpdates**
- Tracked titles: detail **status chip** uses tracker publication status
- Separate **Tracking** pill with brand icon (AniList > MAL > MU when multiple)
- Compact tracker metadata block under the description

## Scores, reviews, Track UI
- Linked section shows which services are bound; service rows mark **Linked**
- Personal **score** on AniList + MAL; **reviews** + **comments** on AniList
- Manage sheet: change title / unlink; bind errors toast on the Track screen

## Alternate titles
- Synonyms / romaji / english / native stored on \`MangaExtras\` (backup JSON included)
- Library find + in-app Search match alts (\`matched via …\` when relevant)
- Tap a library hit opens the title; **Global search** action on the results header

## Reader & updates
- Paged manga: while zoomed, drag pans the panel instead of flipping pages
- Update sheet shows APK size; install adopts a cached download if the in-memory path was lost
- Update/install errors surface **on the sheet** (not under the modal)

## Security & messaging
- App lock: \`FlutterFragmentActivity\` + AppCompat themes for biometrics; no re-lock on \`inactive\`
- Emulator / no device PIN: enable with confirm fallback
- Settings sub-pages own their \`ScaffoldMessenger\` so SnackBars are not buried under the list
- Tracking settings use toasts on the current screen
"
