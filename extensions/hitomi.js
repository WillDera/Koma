/* Koma official extension — Hitomi.la (manga / itemType 0)
 *
 * Catalog: extensions/index.json (GitHub Pages / raw GitHub).
 * Install via Plugin SDK or Extensions → Repos → Koma Official.
 *
 * Indexes live on ltn.gold-usergeneratedcontent.net as big-endian int32
 * `.nozomi` files. Those bytes must not go through a UTF-8 decode — the HTTP
 * bridge accepts `X-Koma-Body: base64` and this source decodes with a pure-JS
 * base64 reader (the injected `atob` also UTF-8-decodes and would corrupt).
 *
 * Page URLs follow Hitomi's gg.js subdomain + path scheme (avif → webp →
 * original). List covers come from galleryblock HTML; bare `tn.` CDN hosts
 * still serve those thumbnails.
 */
const mangayomiSources = [
  {
    "name": "Hitomi",
    "lang": "en",
    "baseUrl": "https://hitomi.la",
    "apiUrl": "https://ltn.gold-usergeneratedcontent.net",
    "iconUrl":
      "https://ltn.gold-usergeneratedcontent.net/favicon-192x192.png",
    "version": "1.0.0",
    "itemType": 0,
    "sourceCodeLanguage": 1,
    "hasCloudflare": false,
    "id": "koma.hitomi",
  },
];

const PAGE_SIZE = 25;
const DOMAIN2 = "gold-usergeneratedcontent.net";
const UA =
  "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36";

const CATALOG = [
  ["Latest", "index-english.nozomi"],
  ["Popular Today", "popular/today-english.nozomi"],
  ["Popular Week", "popular/week-english.nozomi"],
  ["Popular Month", "popular/month-english.nozomi"],
  ["Popular Year", "popular/year-english.nozomi"],
  ["Popular All", "popular-english.nozomi"],
];

const B64 =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

class DefaultExtension extends MProvider {
  constructor() {
    super();
    this._gg = null;
  }

  get supportsLatest() {
    return true;
  }

  getHeaders(url) {
    return {
      Referer: "https://hitomi.la/",
      Origin: "https://hitomi.la",
      Accept: "*/*",
      "User-Agent": UA,
    };
  }

  _ltn() {
    return (this.source.apiUrl || "https://ltn.gold-usergeneratedcontent.net")
      .replace(/\/$/, "");
  }

  /* ---------------------------------------------------------------- *
   * Binary helpers
   * ---------------------------------------------------------------- */

  _decodeBase64(input) {
    const clean = String(input || "").replace(/[^A-Za-z0-9+/]/g, "");
    const out = [];
    let buf = 0;
    let bits = 0;
    for (let i = 0; i < clean.length; i++) {
      const v = B64.indexOf(clean.charAt(i));
      if (v < 0) continue;
      buf = (buf << 6) | v;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        out.push((buf >> bits) & 0xff);
      }
    }
    return out;
  }

  _readUint32BE(bytes, offset) {
    return (
      ((bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3]) >>>
      0
    );
  }

  _header(headers, name) {
    if (!headers) return "";
    const want = name.toLowerCase();
    const keys = Object.keys(headers);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() === want) return String(headers[keys[i]] || "");
    }
    return "";
  }

  _contentTotal(headers) {
    const cr = this._header(headers, "content-range");
    const m = /\/(\d+)\s*$/.exec(cr);
    if (m) return parseInt(m[1], 10);
    const cl = this._header(headers, "content-length");
    if (cl) return parseInt(cl, 10);
    return 0;
  }

  /* ---------------------------------------------------------------- *
   * Nozomi indexes
   * ---------------------------------------------------------------- */

  async _fetchNozomiIds(path, page) {
    const p = page > 0 ? page : 1;
    const start = (p - 1) * PAGE_SIZE * 4;
    const end = start + PAGE_SIZE * 4 - 1;
    const url = this._ltn() + "/" + path.replace(/^\//, "");
    const client = new Client();
    const headers = this.getHeaders(url);
    headers["Range"] = "bytes=" + start + "-" + end;
    headers["X-Koma-Body"] = "base64";
    const res = await client.get(url, headers);
    const code = res.statusCode;
    if (code === 416) return { ids: [], totalBytes: 0 };
    if (code !== 200 && code !== 206) {
      throw new Error("Hitomi HTTP " + code + " for " + path);
    }
    const totalBytes = this._contentTotal(res.headers);
    const bytes = this._decodeBase64(res.body);
    const ids = [];
    const limit = bytes.length - (bytes.length % 4);
    for (let i = 0; i + 3 < limit; i += 4) {
      ids.push(this._readUint32BE(bytes, i));
    }
    return { ids: ids, totalBytes: totalBytes };
  }

  async _galleryBlock(id) {
    const url = this._ltn() + "/galleryblock/" + id + ".html";
    const client = new Client();
    const res = await client.get(url, this.getHeaders(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return { name: "Gallery " + id, link: String(id), imageUrl: "" };
    }
    const html = String(res.body || "");
    let name = "";
    const h1 = /<h1[^>]*>\s*<a[^>]*>([\s\S]*?)<\/a>/i.exec(html);
    if (h1) {
      name = h1[1].replace(/<[^>]+>/g, "").trim();
    }
    if (!name) {
      const t = /<title>([\s\S]*?)<\/title>/i.exec(html);
      if (t) name = t[1].replace(/\s*\|\s*Hitomi.*$/i, "").trim();
    }
    let imageUrl = "";
    const img =
      /data-srcset="(\/\/tn\.[^"\s]+?\.(?:webp|avif|jpg|png))/i.exec(html) ||
      /data-src="(\/\/tn\.[^"]+)"/i.exec(html) ||
      /src="(\/\/tn\.[^"]+)"/i.exec(html);
    if (img) {
      imageUrl = "https:" + img[1].split(/\s+/)[0];
    }
    return {
      name: name || "Gallery " + id,
      link: String(id),
      imageUrl: imageUrl,
    };
  }

  async _browseNozomi(path, page) {
    const p = page > 0 ? page : 1;
    const pack = await this._fetchNozomiIds(path, p);
    const total = pack.totalBytes > 0 ? Math.floor(pack.totalBytes / 4) : 0;
    const list = [];
    const jobs = [];
    for (let i = 0; i < pack.ids.length; i++) {
      jobs.push(this._galleryBlock(pack.ids[i]));
    }
    const items = await Promise.all(jobs);
    for (let i = 0; i < items.length; i++) list.push(items[i]);
    const hasNext =
      total > 0 ? p * PAGE_SIZE < total : pack.ids.length >= PAGE_SIZE;
    return { list: list, hasNextPage: hasNext };
  }

  /* ---------------------------------------------------------------- *
   * gg.js image URL math
   * ---------------------------------------------------------------- */

  async _ensureGg() {
    if (this._gg) return this._gg;
    const url = this._ltn() + "/gg.js";
    const client = new Client();
    const res = await client.get(url, this.getHeaders(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error("Hitomi: failed to load gg.js (" + res.statusCode + ")");
    }
    const js = String(res.body || "");
    const bMatch = /b:\s*'([^']+)'/.exec(js);
    if (!bMatch) throw new Error("Hitomi: gg.js missing b");
    const ones = {};
    const pending = [];
    const re = /case (\d+):|o = (\d+);\s*break;/g;
    let m;
    while ((m = re.exec(js))) {
      if (m[1] != null) {
        pending.push(parseInt(m[1], 10));
      } else {
        const v = parseInt(m[2], 10);
        if (v === 1) {
          for (let i = 0; i < pending.length; i++) ones[pending[i]] = true;
        }
        pending.length = 0;
      }
    }
    this._gg = {
      b: bMatch[1],
      m: function (g) {
        return ones[g] ? 1 : 0;
      },
      s: function (h) {
        const mm = /(..)(.)$/.exec(h);
        return parseInt(mm[2] + mm[1], 16).toString(10);
      },
    };
    return this._gg;
  }

  _subdomainFor(url, dir) {
    const gg = this._gg;
    let retval = "";
    if (dir === "webp") retval = "w";
    else if (dir === "avif") retval = "a";
    const m = /\/[0-9a-f]{61}([0-9a-f]{2})([0-9a-f])/.exec(url);
    if (!m) return retval || "a";
    const g = parseInt(m[2] + m[1], 16);
    if (isNaN(g)) return retval || "a";
    return retval + (1 + gg.m(g));
  }

  _pageUrl(file) {
    const hash = file.hash;
    const gg = this._gg;
    let dir = null;
    let ext = null;
    if (file.hasavif) {
      dir = "avif";
      ext = "avif";
    } else if (file.haswebp) {
      dir = "webp";
      ext = "webp";
    } else {
      const name = file.name || "image.jpg";
      ext = name.split(".").pop() || "jpg";
      dir = "images";
    }
    const path = gg.b + gg.s(hash) + "/" + hash;
    let raw;
    if (dir === "avif" || dir === "webp") {
      raw = "https://a." + DOMAIN2 + "/" + path + "." + ext;
    } else {
      raw = "https://a." + DOMAIN2 + "/" + dir + "/" + path + "." + ext;
    }
    const sub = this._subdomainFor(raw, dir === "images" ? null : dir);
    return raw.replace(
      /\/\/..?\.(?:gold-usergeneratedcontent\.net|hitomi\.la)\//,
      "//" + sub + "." + DOMAIN2 + "/",
    );
  }

  /* ---------------------------------------------------------------- *
   * Gallery detail
   * ---------------------------------------------------------------- */

  _galleryId(url) {
    const s = String(url || "").trim();
    const m =
      /-(\d+)\.html(?:$|\?)/.exec(s) ||
      /\/galleries\/(\d+)/.exec(s) ||
      /^(\d+)$/.exec(s);
    return m ? m[1] : s.replace(/.*\//, "").replace(/\.html.*/, "");
  }

  async _galleryInfo(id) {
    const url = this._ltn() + "/galleries/" + id + ".js";
    const client = new Client();
    const res = await client.get(url, this.getHeaders(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error("Hitomi HTTP " + res.statusCode + " for gallery " + id);
    }
    let body = String(res.body || "").trim();
    const eq = body.indexOf("=");
    if (eq >= 0) body = body.substring(eq + 1).trim();
    if (body.charAt(body.length - 1) === ";") {
      body = body.substring(0, body.length - 1);
    }
    return JSON.parse(body);
  }

  _coverFromFiles(files) {
    if (!files || !files.length) return "";
    const f = files[0];
    if (!f || !f.hash) return "";
    const h = f.hash;
    const path = h.charAt(h.length - 1) + "/" + h.slice(-3, -1) + "/" + h;
    if (f.hasavif) {
      return (
        "https://tn." + DOMAIN2 + "/avifbigtn/" + path + ".avif"
      );
    }
    return "https://tn." + DOMAIN2 + "/webpbigtn/" + path + ".webp";
  }

  _mapDetail(info) {
    const id = String(info.id);
    const artists = (info.artists || [])
      .map((a) => (a && a.artist) || "")
      .filter(Boolean);
    const groups = (info.groups || [])
      .map((g) => (g && g.group) || "")
      .filter(Boolean);
    const genres = [];
    const tags = info.tags || [];
    for (let i = 0; i < tags.length; i++) {
      const t = tags[i];
      if (!t || !t.tag) continue;
      let label = t.tag;
      if (t.female === "1" || t.female === 1) label = "female:" + label;
      else if (t.male === "1" || t.male === 1) label = "male:" + label;
      genres.push(label);
    }
    const parodies = (info.parodys || [])
      .map((p) => (p && p.parody) || "")
      .filter(Boolean);
    for (let i = 0; i < parodies.length; i++) {
      genres.push("series:" + parodies[i]);
    }
    const characters = (info.characters || [])
      .map((c) => (c && c.character) || "")
      .filter(Boolean);
    for (let i = 0; i < characters.length; i++) {
      genres.push("character:" + characters[i]);
    }
    if (info.type) genres.unshift(info.type);
    if (info.language_localname || info.language) {
      genres.push(info.language_localname || info.language);
    }
    const desc = [];
    if (info.japanese_title) desc.push(info.japanese_title);
    if (info.date) desc.push(info.date);
    const files = info.files || [];
    return {
      name: info.title || "Gallery " + id,
      link: id,
      imageUrl: this._coverFromFiles(files),
      description: desc.join("\n"),
      author: artists.concat(groups).join(", "),
      genre: genres,
      status: 1,
      chapters: [
        {
          name: "Gallery",
          url: id,
          dateUpload: info.date || "",
        },
      ],
    };
  }

  /* ---------------------------------------------------------------- *
   * Filters
   * ---------------------------------------------------------------- */

  _selectFilter(name, options) {
    return {
      type: "select",
      name: name,
      state: 0,
      values: options.map((o) => ({
        name: o[0],
        value: o[1],
        type_name: "SelectOption",
      })),
      type_name: "SelectFilter",
    };
  }

  _textFilter(name) {
    return { type: "text", name: name, value: "", state: "", type_name: "TextFilter" };
  }

  _selectValue(filters, name) {
    for (let i = 0; i < filters.length; i++) {
      const f = filters[i];
      if (f && f.name === name && f.type_name === "SelectFilter") {
        return typeof f.state === "number" ? f.state : parseInt(f.state, 10) || 0;
      }
    }
    return 0;
  }

  _textValue(filters, name) {
    for (let i = 0; i < filters.length; i++) {
      const f = filters[i];
      if (f && f.name === name && f.type_name === "TextFilter") {
        return String(f.state != null ? f.state : f.value || "").trim();
      }
    }
    return "";
  }

  _slug(raw) {
    return String(raw || "")
      .trim()
      .toLowerCase()
      .replace(/_/g, " ");
  }

  _nozomiPath(kind, slug) {
    const enc = encodeURI(slug);
    return kind + "/" + enc + "-english.nozomi";
  }

  _resolveIndex(query, filters) {
    const list = Array.isArray(filters) ? filters : [];
    if (this._selectValue(list, "Random") === 1) {
      return { kind: "random" };
    }
    const artist = this._slug(this._textValue(list, "Artist"));
    if (artist) return { kind: "path", path: this._nozomiPath("artist", artist) };
    const series = this._slug(this._textValue(list, "Series"));
    if (series) return { kind: "path", path: this._nozomiPath("series", series) };
    const character = this._slug(this._textValue(list, "Character"));
    if (character) {
      return { kind: "path", path: this._nozomiPath("character", character) };
    }
    const tag = this._slug(this._textValue(list, "Tag"));
    if (tag) return { kind: "path", path: this._nozomiPath("tag", tag) };

    const q = String(query || "").trim();
    if (q) {
      if (/^\d+$/.test(q)) return { kind: "id", id: q };
      const prefixed = /^(artist|series|character|tag):\s*(.+)$/i.exec(q);
      if (prefixed) {
        return {
          kind: "path",
          path: this._nozomiPath(prefixed[1].toLowerCase(), this._slug(prefixed[2])),
        };
      }
      return { kind: "path", path: this._nozomiPath("tag", this._slug(q)) };
    }

    const catalog = this._selectValue(list, "Catalog");
    const entry = CATALOG[catalog] || CATALOG[0];
    return { kind: "path", path: entry[1] };
  }

  async _randomPage() {
    const probe = await this._fetchNozomiIds("popular/year-english.nozomi", 1);
    const total = probe.totalBytes > 0 ? Math.floor(probe.totalBytes / 4) : 0;
    if (total <= 0) return { list: [], hasNextPage: false };
    const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
    const page = 1 + Math.floor(Math.random() * pages);
    const result = await this._browseNozomi("popular/year-english.nozomi", page);
    const list = result.list.slice();
    for (let i = list.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return { list: list, hasNextPage: false };
  }

  /* ---------------------------------------------------------------- *
   * MProvider
   * ---------------------------------------------------------------- */

  async getPopular(page) {
    return await this._browseNozomi("popular/today-english.nozomi", page);
  }

  async getLatestUpdates(page) {
    return await this._browseNozomi("index-english.nozomi", page);
  }

  async search(query, page, filters) {
    const target = this._resolveIndex(query, filters);
    if (target.kind === "random") return await this._randomPage();
    if (target.kind === "id") {
      const block = await this._galleryBlock(target.id);
      return { list: [block], hasNextPage: false };
    }
    return await this._browseNozomi(target.path, page);
  }

  async getDetail(url) {
    const id = this._galleryId(url);
    const info = await this._galleryInfo(id);
    return this._mapDetail(info);
  }

  async getChapterList(url) {
    const id = this._galleryId(url);
    return [{ name: "Gallery", url: id, dateUpload: "" }];
  }

  async getPageList(url) {
    const id = this._galleryId(url);
    const info = await this._galleryInfo(id);
    await this._ensureGg();
    const files = info.files || [];
    const pages = [];
    const headers = {
      Referer: "https://hitomi.la/",
      Origin: "https://hitomi.la",
      "User-Agent": UA,
    };
    for (let i = 0; i < files.length; i++) {
      const f = files[i];
      if (!f || !f.hash) continue;
      pages.push({
        index: i,
        url: this._pageUrl(f),
        headers: headers,
      });
    }
    if (!pages.length) throw new Error("Hitomi: gallery " + id + " has no pages");
    return pages;
  }

  getFilterList() {
    return [
      { type: "header", name: "Browse", type_name: "HeaderFilter" },
      this._selectFilter("Random", [
        ["Off", 0],
        ["On", 1],
      ]),
      this._selectFilter(
        "Catalog",
        CATALOG.map((c, i) => [c[0], i]),
      ),
      { type: "separator", type_name: "SeparatorFilter" },
      { type: "header", name: "Namespaces", type_name: "HeaderFilter" },
      this._textFilter("Artist"),
      this._textFilter("Series"),
      this._textFilter("Tag"),
      this._textFilter("Character"),
    ];
  }

  getSourcePreferences() {
    return [];
  }
}
