/* Koma official extension — HDoujin (manga / itemType 0)
 *
 * Catalog: extensions/index.json (GitHub Pages / raw GitHub).
 * Install via Plugin SDK or Extensions → Repos → Koma Official.
 *
 * Backend notes (all verified against api.hdoujin.org):
 *
 * - Origin AND Referer are mandatory. Omitting either returns HTTP 400 with an
 *   empty body, so both are sent on every API call. User-Agent is always
 *   overwritten downstream by the app with a real browser UA.
 * - The API is rate limited to 5 requests per ~2-5s sliding window and
 *   advertises x-ratelimit-{limit,remaining,reset}. Every call is serialised
 *   through a queue with a minimum gap, and the queue waits out the window
 *   when the remaining counter hits zero.
 * - List endpoints answer {entries, limit, page, total}. A search with no hits
 *   answers {limit, page, matches} instead — no `entries`, no `total`.
 * - /books/popular is capped at 1000 entries: page 13 is the last valid page,
 *   page 14 returns HTTP 400. /books paginates to ~2473 pages and returns an
 *   empty `entries` array past the end rather than an error.
 *
 * Page image limitation: HDoujin only serves full-resolution pages from
 * /books/data/{id}/{key}/... behind a Cloudflare Turnstile clearance token
 * (`crt`), which returns 403 to a plain extension. This source therefore reads
 * the public thumbnail tier, 250-350px wide WebP from erocdn.net. Everything
 * else (browse, popular, search, tags, artists, random, metadata) is complete.
 *
 * Tag matching: the site's own exact-anchor syntax ("tag:^term$") is only
 * populated for a handful of tags and cannot be combined with the
 * include/exclude namespace facets, so this source uses the fuzzy namespace
 * form (`tag:term`) throughout. Space separated terms are AND-ed, which is how
 * HDoujin's own search box behaves.
 */
const mangayomiSources = [
  {
    "name": "HDoujin",
    "lang": "en",
    "baseUrl": "https://hdoujin.org",
    "apiUrl": "https://api.hdoujin.org",
    "iconUrl": "https://hdoujin.org/icon.jpg",
    "version": "1.0.0",
    "itemType": 0,
    "sourceCodeLanguage": 1,
    "hasCloudflare": false,
    "id": "koma.hdoujin",
  },
];

/* Popular tops out at 1000 entries; page 14 is a hard HTTP 400. */
const POPULAR_MAX_PAGE = 13;
/* Server side page size for /books. */
const PAGE_LIMIT = 80;
/* Sort ids, matching the site's ordering menu. */
const SORT_DATE = 4;
/* Minimum spacing between API calls (rate limit is 5 per ~2-5s). */
const MIN_GAP_MS = 900;
/* Detail payloads are reused between getDetail and getPageList. */
const DETAIL_CACHE_MAX = 24;

/* General tag namespaces — the only ones the /books include|exclude facets accept. */
const NS_MALE = 8;
const NS_FEMALE = 9;
const NS_MIXED = 10;
const NS_OTHER = 12;

const CATEGORY_LABELS = {
  1: "Manga",
  2: "Doujinshi",
  3: "Illustration",
};

const LANGUAGE_LABELS = {
  2: "English",
  4: "Japanese",
  8: "Chinese",
  16: "Korean",
};

/* Namespace 11 carries translation qualifiers alongside the language itself. */
const LANGUAGE_QUALIFIERS = {
  translated: true,
  untranslated: true,
  original: true,
  "machine translation": true,
  "fan translation": true,
};

const NAMESPACE_LABELS = {
  0: "General",
  1: "Artist",
  2: "Circle",
  3: "Parody",
  4: "Magazine",
  5: "Character",
  6: "Cosplayer",
  7: "Uploader",
  8: "Male",
  9: "Female",
  10: "Mixed",
  11: "Language",
  12: "Other",
  13: "Reclass",
};

/* Snapshot of the 50 highest ranked general tags on /books/tags, deduped by
 * name across the Male / Female / Mixed namespaces. getFilterList() is invoked
 * synchronously, so the list cannot be fetched at runtime. */
const POPULAR_TAGS = [
  "sole female",
  "big breasts",
  "sole male",
  "nakadashi",
  "blowjob",
  "group",
  "stockings",
  "lolicon",
  "schoolgirl uniform",
  "x-ray",
  "ahegao",
  "anal",
  "shotacon",
  "paizuri",
  "yaoi",
  "milf",
  "twintails",
  "netorare",
  "kissing",
  "rape",
  "males only",
  "ffm threesome",
  "big penis",
  "ponytail",
  "kemonomimi",
  "incest",
  "halo",
  "impregnation",
  "very long hair",
  "femdom",
  "defloration",
  "hairy",
  "collar",
  "sex toys",
  "bondage",
  "swimsuit",
  "dilf",
  "big ass",
  "glasses",
  "bbm",
  "anal intercourse",
  "muscle",
  "double penetration",
  "dark skin",
  "gloves",
  "bikini",
  "huge breasts",
  "fingering",
  "pantyhose",
  "beauty mark",
];

/* ------------------------------------------------------------------ *
 * Request queue — serialises every API call and honours the rate limit.
 * ------------------------------------------------------------------ */

let _queue = Promise.resolve();
let _lastCallAt = 0;

function _sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function _enqueue(task) {
  const run = _queue.then(async () => {
    const wait = _lastCallAt + MIN_GAP_MS - Date.now();
    if (wait > 0) await _sleep(wait);
    try {
      return await task();
    } finally {
      _lastCallAt = Date.now();
    }
  });
  /* Keep the chain alive so one rejected link does not poison the rest. */
  _queue = run.then(
    () => {},
    () => {},
  );
  return run;
}

class DefaultExtension extends MProvider {
  get supportsLatest() {
    return true;
  }

  getHeaders(url) {
    return {
      Referer: this.source.baseUrl + "/",
      Origin: this.source.baseUrl,
      Accept: "application/json",
      "User-Agent":
        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36",
    };
  }

  _api() {
    const api = (this.source.apiUrl || "https://api.hdoujin.org").replace(
      /\/$/,
      "",
    );
    return api;
  }

  _qs(params) {
    const parts = [];
    for (const key of Object.keys(params)) {
      const value = params[key];
      if (value === undefined || value === null || value === "") continue;
      parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(value));
    }
    return parts.length ? "?" + parts.join("&") : "";
  }

  /// Pause when the server reports the window exhausted. Values are unix
  /// seconds; anything implausible is ignored rather than slept on.
  async _rateGate(res) {
    const headers = res.headers || {};
    if (headers["x-ratelimit-remaining"] !== "0") return;
    const reset = parseInt(headers["x-ratelimit-reset"], 10);
    if (!reset || isNaN(reset)) return;
    const wait = reset * 1000 - Date.now();
    if (wait > 0 && wait < 20000) await _sleep(wait + 250);
  }

  /// GET + JSON parse with one retry for throttled responses. 400 is not
  /// retried: on this API it means a rejected Origin/Referer, not a blip.
  async _getJson(path, params) {
    const url = this._api() + path + this._qs(params || {});
    const client = new Client();
    for (let attempt = 0; attempt < 3; attempt++) {
      const res = await _enqueue(async () => {
        const r = await client.get(url, this.getHeaders(url));
        await this._rateGate(r);
        return r;
      });
      const code = res.statusCode;
      if (code === 429 || code === 503) {
        await _sleep(1500 * (attempt + 1));
        continue;
      }
      if (code < 200 || code >= 300) {
        throw new Error(
          "HDoujin HTTP " +
            code +
            " for " +
            path +
            (code === 400 ? " (origin/referer rejected)" : ""),
        );
      }
      const body =
        typeof res.body === "string" ? JSON.parse(res.body) : res.body;
      return body || {};
    }
    throw new Error("HDoujin rate limited on " + path);
  }

  /* ---------------------------------------------------------------- *
   * Response shaping
   * ---------------------------------------------------------------- */

  _page(json) {
    const entries =
      json && Array.isArray(json.entries) ? json.entries : [];
    const limit =
      json && typeof json.limit === "number" && json.limit > 0
        ? json.limit
        : PAGE_LIMIT;
    const total = json && typeof json.total === "number" ? json.total : null;
    const hasMore = (page) => {
      if (total === null) return entries.length >= limit;
      return page * limit < total;
    };
    return { entries, limit, total, hasMore };
  }

  _browsePage(json, page) {
    const view = this._page(json);
    return {
      list: view.entries.map((e) => this._mapEntry(e)),
      hasNextPage: view.hasMore(page),
    };
  }

  _mapEntry(entry) {
    const id = entry && entry.id !== undefined ? String(entry.id) : "";
    const key = entry && entry.key ? String(entry.key) : "";
    const thumb = entry && entry.thumbnail ? entry.thumbnail : null;
    return {
      name: (entry && entry.title) || "Book " + id,
      /* Carries id + key through to getDetail / getPageList. */
      link: id + "/" + key,
      imageUrl: (thumb && thumb.path) || "",
    };
  }

  _readIdKey(url) {
    const parts = (url || "")
      .replace(/^https?:\/\/[^/]+/, "")
      .replace(/^\/+/, "")
      .split("/")
      .filter(Boolean);
    return {
      id: parts[0] || "",
      key: parts[1] || "",
    };
  }

  _mapOptionList(labels) {
    const out = [["All", 0]];
    for (const key of Object.keys(labels)) {
      const flag = parseInt(key, 10);
      out.push([labels[flag], flag]);
    }
    return out;
  }

  _isoDate(ms) {
    const stamp = typeof ms === "number" ? ms : parseInt(ms, 10);
    if (!stamp || isNaN(stamp)) return "";
    const d = new Date(stamp);
    const pad = (n) => (n < 10 ? "0" + n : "" + n);
    return (
      d.getUTCFullYear() +
      "-" +
      pad(d.getUTCMonth() + 1) +
      "-" +
      pad(d.getUTCDate())
    );
  }

  /* ---------------------------------------------------------------- *
   * Detail cache — getDetail and getPageList resolve the same payload.
   * ---------------------------------------------------------------- */

  _cacheDetail(id, key, detail) {
    this._detailCache = this._detailCache || new Map();
    const cacheKey = id + "/" + key;
    this._detailCache.delete(cacheKey);
    this._detailCache.set(cacheKey, detail);
    while (this._detailCache.size > DETAIL_CACHE_MAX) {
      const oldest = this._detailCache.keys().next();
      if (oldest.done) break;
      this._detailCache.delete(oldest.value);
    }
  }

  async _fetchDetail(id, key) {
    const cache = this._detailCache;
    const cacheKey = id + "/" + key;
    if (cache && cache.has(cacheKey)) {
      const hit = cache.get(cacheKey);
      cache.delete(cacheKey);
      cache.set(cacheKey, hit);
      return hit;
    }
    const detail = await this._getJson(
      "/books/detail/" + encodeURIComponent(id) + "/" + encodeURIComponent(key),
      {},
    );
    this._cacheDetail(id, key, detail);
    return detail;
  }

  _mapChapter(url, detail) {
    return {
      name: "Chapter 1",
      url,
      dateUpload: detail.created_at || 0,
    };
  }

  /// /books/detail omits `language` (only the list endpoints carry it), so the
  /// description reads it off the namespace 11 tags instead. Those tags mix
  /// the language with qualifiers like "translated", which are dropped.
  _detailLanguages(detail) {
    const out = [];
    for (const tag of detail.tags || []) {
      if (!tag || tag.namespace !== 11) continue;
      const name = (tag.name ? tag.name : "").toString().trim();
      if (!name) continue;
      if (LANGUAGE_QUALIFIERS[name.toLowerCase()]) continue;
      if (out.indexOf(name) < 0) out.push(name);
    }
    return out;
  }

  _describe(detail) {
    const parts = [];
    const pages =
      detail.thumbnails && Array.isArray(detail.thumbnails.entries)
        ? detail.thumbnails.entries.length
        : 0;
    if (pages > 0) parts.push(pages + " pages");
    if (detail.category && CATEGORY_LABELS[detail.category]) {
      parts.push(CATEGORY_LABELS[detail.category]);
    }
    parts.push(this._detailLanguages(detail).join(", "));
    const added = this._isoDate(detail.created_at);
    if (added) parts.push("added " + added);
    return parts
      .filter((p) => p !== "")
      .join(" · ");
  }

  /// Genre chips mirror the site's namespace grouping, so an artist is not
  /// indistinguishable from a genre in the details list.
  _mapGenres(detail) {
    const authors = [];
    const genres = [];
    for (const tag of detail.tags || []) {
      const name = (tag && tag.name ? tag.name : "").toString().trim();
      if (!name) continue;
      const ns = tag.namespace || 0;
      if (ns === 1) {
        authors.push(name);
        continue;
      }
      const label = NAMESPACE_LABELS[ns] || "";
      genres.push(label ? label + ": " + name : name);
    }
    return { authors, genres };
  }

  /* ---------------------------------------------------------------- *
   * Filters
   * ---------------------------------------------------------------- */

  _filterByName(filters, name) {
    for (let i = 0; i < filters.length; i++) {
      const f = filters[i];
      if (f && f.name === name) return f;
    }
    return null;
  }

  /// The browse screen stores a select's *selected index* (the key of the
  /// DropdownMenuItem), not the option's value, so `state` has to be
  /// translated through `values` before it is usable as an API bitmask.
  /// Without this, "Doujinshi" (index 2) would be sent as `cat=2`, which is
  /// Manga. Out-of-range states fall back to the first option, mirroring the
  /// UI's own `selIdx < opts.length ? selIdx : 0`.
  _selectValue(filters, name) {
    const f = this._filterByName(filters, name);
    if (!f || !Array.isArray(f.values) || !f.values.length) return 0;
    const index = typeof f.state === "number" ? f.state : 0;
    const option = f.values[index >= 0 && index < f.values.length ? index : 0];
    return option ? option.value : 0;
  }

  _textValue(filters, name) {
    const f = this._filterByName(filters, name);
    return f && typeof f.state === "string" ? f.state.trim() : "";
  }

  /// Values of the ticked checkboxes in a group filter.
  _checkedValues(filters, name) {
    const f = this._filterByName(filters, name);
    const out = [];
    if (!f || !Array.isArray(f.state)) return out;
    for (const sub of f.state) {
      if (sub && sub.state === true && sub.value !== undefined) {
        out.push(sub.value);
      }
    }
    return out;
  }

  _selectFilter(name, options) {
    const values = options.map((o) => ({
      name: o[0],
      value: o[1],
      type_name: "SelectOption",
    }));
    return {
      type: "select",
      name,
      state: 0,
      values,
      type_name: "SelectFilter",
    };
  }

  _textFilter(name) {
    return { type: "text", name, value: "", state: "", type_name: "TextFilter" };
  }

  _checkGroup(name, options) {
    return {
      type: "group",
      name,
      state: options.map((o) => ({
        type: "check",
        name: o[0],
        value: o[1],
        state: false,
        type_name: "CheckBox",
      })),
      type_name: "GroupFilter",
    };
  }

  /* ---------------------------------------------------------------- *
   * MProvider
   * ---------------------------------------------------------------- */

  async getPopular(page) {
    const p = page > 0 ? page : 1;
    if (p > POPULAR_MAX_PAGE) return { list: [], hasNextPage: false };
    const json = await this._getJson("/books/popular", { page: p });
    return this._browsePage(json, p);
  }

  async getLatestUpdates(page) {
    const p = page > 0 ? page : 1;
    const json = await this._getJson("/books", { page: p, sort: SORT_DATE });
    return this._browsePage(json, p);
  }

  /// /books/random answers a bare {id, key}, so a detail call is needed to
  /// fill in the title and cover. Filters do not apply — HDoujin has no
  /// randomised equivalent of /books.
  async _randomPage() {
    const pick = await this._getJson("/books/random", {});
    const id = pick && pick.id !== undefined ? String(pick.id) : "";
    const key = pick && pick.key ? String(pick.key) : "";
    if (!id || !key) return { list: [], hasNextPage: false };
    const detail = await this._fetchDetail(id, key);
    const thumbs = detail.thumbnails || {};
    const cover =
      thumbs.base && thumbs.main ? thumbs.base + thumbs.main.path : "";
    return {
      list: [
        {
          name:
            detail.title || detail.title_short || "Book " + id,
          link: id + "/" + key,
          imageUrl: cover,
        },
      ],
      hasNextPage: false,
    };
  }

  async search(query, page, filters) {
    const list = Array.isArray(filters) ? filters : [];
    const p = page > 0 ? page : 1;

    if (this._selectValue(list, "Browse") === 1) return await this._randomPage();

    const params = { page: p };

    const sort = this._selectValue(list, "Sort by");
    params.sort = sort > 0 ? sort : SORT_DATE;
    const cat = this._selectValue(list, "Content");
    if (cat > 0) params.cat = cat;
    const lang = this._selectValue(list, "Language");
    if (lang > 0) params.lang = lang;

    /* Space separated terms are AND-ed by the API. */
    const terms = [];
    const q = (query || "").trim();
    if (q) terms.push(q);
    const tag = this._textValue(list, "Tag");
    if (tag) terms.push("tag:" + tag);
    const artist = this._textValue(list, "Artist");
    if (artist) terms.push("artist:" + artist);
    const circle = this._textValue(list, "Circle");
    if (circle) terms.push("circle:" + circle);
    for (const name of this._checkedValues(list, "Popular Tags")) {
      terms.push("tag:" + name);
    }
    if (terms.length) params.s = terms.join(" ");

    const include = this._checkedValues(list, "Include Tags");
    if (include.length) {
      params.include = include.join(",");
      params.i = 1;
    }
    const exclude = this._checkedValues(list, "Exclude Tags");
    if (exclude.length) {
      params.exclude = exclude.join(",");
      params.e = 1;
    }

    const json = await this._getJson("/books", params);
    return this._browsePage(json, p);
  }

  async getDetail(url) {
    const parts = this._readIdKey(url);
    if (!parts.id || !parts.key) {
      throw new Error("HDoujin: bad gallery url " + url);
    }
    const detail = await this._fetchDetail(parts.id, parts.key);
    const mapped = this._mapGenres(detail);
    const link = parts.id + "/" + parts.key;
    const thumbs = detail.thumbnails || {};
    const cover =
      thumbs.base && thumbs.main ? thumbs.base + thumbs.main.path : "";
    return {
      name: detail.title || detail.title_short || "Book " + parts.id,
      link,
      imageUrl: cover,
      description: this._describe(detail),
      author: mapped.authors.join(", "),
      genre: mapped.genres,
      status: 1,
      chapters: [this._mapChapter(link, detail)],
    };
  }

  /// Library Updates — the chapter list needs no extra request.
  async getChapterList(url) {
    const parts = this._readIdKey(url);
    if (!parts.id || !parts.key) {
      throw new Error("HDoujin: bad gallery url " + url);
    }
    const detail = await this._fetchDetail(parts.id, parts.key);
    return [this._mapChapter(parts.id + "/" + parts.key, detail)];
  }

  /// Public thumbnail tier only — see the header note on resolution.
  async getPageList(url) {
    const parts = this._readIdKey(url);
    if (!parts.id || !parts.key) {
      throw new Error("HDoujin: bad gallery url " + url);
    }
    const detail = await this._fetchDetail(parts.id, parts.key);
    const thumbs = detail.thumbnails || {};
    const base = thumbs.base || "";
    const entries = Array.isArray(thumbs.entries) ? thumbs.entries : [];
    const pages = [];
    for (let i = 0; i < entries.length; i++) {
      const path = entries[i] && entries[i].path;
      if (!path) continue;
      pages.push({
        index: i,
        url: path.charAt(0) === "/" ? base + path : path,
      });
    }
    if (!pages.length) throw new Error("HDoujin: gallery has no pages");
    return pages;
  }

  getFilterList() {
    const namespaceOptions = [
      ["Male", NS_MALE],
      ["Female", NS_FEMALE],
      ["Mixed", NS_MIXED],
      ["Other", NS_OTHER],
    ];
    return [
      { type: "header", name: "Browse Mode", type_name: "HeaderFilter" },
      this._selectFilter("Browse", [
        ["Default", 0],
        ["Random", 1],
      ]),
      this._selectFilter("Content", [
        ["All", 0],
        ["Manga", 2],
        ["Doujinshi", 4],
        ["Illustration", 8],
      ]),
      this._selectFilter("Language", this._mapOptionList(LANGUAGE_LABELS)),
      this._selectFilter("Sort by", [
        ["Date", SORT_DATE],
        ["Title", 2],
        ["Pages", 3],
        ["Views", 8],
        ["Favorites", 9],
      ]),
      { type: "separator", type_name: "SeparatorFilter" },
      { type: "header", name: "Namespaces", type_name: "HeaderFilter" },
      this._textFilter("Tag"),
      this._textFilter("Artist"),
      this._textFilter("Circle"),
      { type: "separator", type_name: "SeparatorFilter" },
      { type: "header", name: "Tags", type_name: "HeaderFilter" },
      this._checkGroup(
        "Popular Tags",
        POPULAR_TAGS.map((t) => [t, t]),
      ),
      this._checkGroup("Include Tags", namespaceOptions),
      this._checkGroup("Exclude Tags", namespaceOptions),
    ];
  }

  getSourcePreferences() {
    return [];
  }
}
