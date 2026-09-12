/* Koma Plugin SDK sample — NovelBuddy (novel / itemType 2)
 *
 * Install from Settings → Sources → Plugin SDK, or sideload this file.
 */
const mangayomiSources = [
  {
    "name": "NovelBuddy",
    "lang": "en",
    "baseUrl": "https://novelbuddy.me",
    "apiUrl": "https://api.novelbuddy.me",
    "iconUrl":
      "https://novelbuddy.me/static/sites/novelbuddy-me/logo.webp",
    "version": "1.0.2",
    "itemType": 2,
    "sourceCodeLanguage": 1,
    "hasCloudflare": false,
    "dateFormat": "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
    "dateFormatLocale": "en",
    "id": "koma.novelbuddy",
  },
];

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
    const api = (this.source.apiUrl || "https://api.novelbuddy.me").replace(
      /\/$/,
      "",
    );
    return api;
  }

  async _getJson(path) {
    const client = new Client({ headers: this.getHeaders("") });
    const res = await client.get(this._api() + path);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw new Error("NovelBuddy HTTP " + res.statusCode + " for " + path);
    }
    const body =
      typeof res.body === "string" ? JSON.parse(res.body) : res.body;
    if (!body || body.success === false) {
      throw new Error(
        (body && body.message) || "NovelBuddy request failed: " + path,
      );
    }
    return body.data;
  }

  _status(raw) {
    const s = (raw || "").toString().toLowerCase();
    if (s.includes("complete") || s.includes("finish")) return 1;
    if (s.includes("hiatus")) return 2;
    return 0;
  }

  /// Home sections mix shapes: `latest` is `{items:[...]}`, while
  /// `popular` / `trending` are bare arrays.
  _sectionItems(section) {
    if (!section) return [];
    if (Array.isArray(section)) return section;
    if (Array.isArray(section.items)) return section.items;
    if (Array.isArray(section.titles)) return section.titles;
    return [];
  }

  _mapTitle(item) {
    const id = item.id || item.hsid || "";
    const name = item.name || item.title || "";
    const cover = item.cover || item.thumbnail || "";
    return {
      name: name,
      link: id,
      imageUrl: cover,
    };
  }

  _titleId(url) {
    return (url || "").replace(/^\/+/, "").split("/")[0];
  }

  _mapChapter(titleId, ch) {
    return {
      name: ch.name || ch.title || "Chapter",
      url: titleId + "/" + ch.id,
      dateUpload: ch.updated_at || ch.updatedAt || ch.date || null,
    };
  }

  /// Genres + tags (deduped), matching the site's tag chips.
  _genreList(title) {
    const out = [];
    const seen = {};
    const push = (raw) => {
      const name = ((raw && raw.name) || raw || "").toString().trim();
      if (!name) return;
      const key = name.toLowerCase();
      if (seen[key]) return;
      seen[key] = true;
      out.push(name);
    };
    (title.genres || []).forEach(push);
    (title.tags || []).forEach(push);
    (title.themes || []).forEach(push);
    return out;
  }

  async _fetchChapters(titleId) {
    // API rejects limit > 500; any valid limit returns the full list.
    const chaptersData = await this._getJson(
      "/titles/" +
        encodeURIComponent(titleId) +
        "/chapters?page=1&limit=500",
    );
    return (chaptersData.chapters || []).map((ch) =>
      this._mapChapter(titleId, ch),
    );
  }

  async getPopular(page) {
    const data = await this._getJson("/titles/home");
    const items =
      this._sectionItems(data.popular).length > 0
        ? this._sectionItems(data.popular)
        : this._sectionItems(data.trending);
    if (page > 1) return { list: [], hasNextPage: false };
    return {
      list: items.map((e) => this._mapTitle(e)),
      hasNextPage: false,
    };
  }

  async getLatestUpdates(page) {
    const data = await this._getJson("/titles/home");
    const items = this._sectionItems(data.latest);
    if (page > 1) return { list: [], hasNextPage: false };
    return {
      list: items.map((e) => this._mapTitle(e)),
      hasNextPage: false,
    };
  }

  async search(query, page, filters) {
    const q = encodeURIComponent((query || "").trim());
    if (!q) return { list: [], hasNextPage: false };
    const data = await this._getJson(
      "/titles/search?q=" + q + "&page=" + page,
    );
    const items = data.items || data.results || [];
    return {
      list: items.map((e) => this._mapTitle(e)),
      hasNextPage: items.length >= 20,
    };
  }

  async getDetail(url) {
    const id = this._titleId(url);
    const data = await this._getJson("/titles/" + encodeURIComponent(id));
    const title = data.title || data;
    const chapters = await this._fetchChapters(id);
    const authors = (title.authors || [])
      .map((a) => a.name || a)
      .filter(Boolean)
      .join(", ");
    return {
      name: title.name || title.title || id,
      link: id,
      imageUrl: title.cover || "",
      description: (title.summary || "").replace(/<[^>]+>/g, " ").trim(),
      author: authors,
      genre: this._genreList(title),
      status: this._status(title.status),
      chapters: chapters,
    };
  }

  /// Used by library Updates — chapter list only (no title metadata).
  async getChapterList(url) {
    const id = this._titleId(url);
    return await this._fetchChapters(id);
  }

  async getPageList(url) {
    // Novels use getHtmlContent — image page lists are unused.
    return [];
  }

  async getHtmlContent(name, url) {
    const parts = (url || "").replace(/^\/+/, "").split("/");
    if (parts.length < 2) {
      throw new Error("NovelBuddy chapter url must be mangaId/chapterId");
    }
    const mangaId = parts[0];
    const chapterId = parts[1];
    const data = await this._getJson(
      "/titles/" +
        encodeURIComponent(mangaId) +
        "/chapters/" +
        encodeURIComponent(chapterId),
    );
    const chapter = data.chapter || data;
    let html = chapter.content || "";
    if (!html) throw new Error("Empty chapter content");
    return await this.cleanHtmlContent(html);
  }

  async cleanHtmlContent(html) {
    let body = (html || "").toString();
    body = body.replace(
      /<div[^>]*>\s*<div[^>]*style="[^"]*font-size:0[^"]*"[^>]*>[\s\S]*?<\/div>\s*<\/div>/gi,
      "",
    );
    body = body.replace(/<script[\s\S]*?<\/script>/gi, "");
    body = body.replace(/<style[\s\S]*?<\/style>/gi, "");
    if (!/<(p|div|br|h[1-6])\b/i.test(body)) {
      body = body
        .split(/\n+/)
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => "<p>" + line + "</p>")
        .join("");
    }
    return (
      '<html><head><meta charset="utf-8"></head><body>' +
      body +
      "</body></html>"
    );
  }

  getFilterList() {
    return [];
  }

  getSourcePreferences() {
    return [];
  }
}
