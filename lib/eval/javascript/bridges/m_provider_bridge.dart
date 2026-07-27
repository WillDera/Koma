import 'package:flutter_qjs/flutter_qjs.dart';

const mProviderBaseClass = '''
class MProvider {
  constructor() {
    this.baseUrl = '';
    this.headers = {};
  }

  async getManga(url) {
    const response = await MClient.fetch(this.baseUrl + url, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    return {
      url: url,
      title: doc.querySelector('h1')?.textContent?.trim() || '',
      thumbnail_url: doc.querySelector('img')?.getAttribute('src') || '',
      description: doc.querySelector('.description')?.textContent?.trim() || '',
      status: 0,
      genre: '',
    };
  }

  async getChapterList(manga) {
    const response = await MClient.fetch(this.baseUrl + manga.url, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const chapters = [];
    for (const el of doc.querySelectorAll('.chapter-list a')) {
      chapters.push({
        url: el.getAttribute('href'),
        name: el.textContent?.trim() || '',
      });
    }
    return chapters;
  }

  async getPageList(chapter) {
    const response = await MClient.fetch(this.baseUrl + chapter.url, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const pages = [];
    for (const img of doc.querySelectorAll('.reader-content img')) {
      pages.push({
        url: img.getAttribute('src') || '',
        headers: this.headers,
      });
    }
    return pages;
  }

  async search(query, page, filters) {
    const response = await MClient.fetch(this.baseUrl + '/search?q=' + encodeURIComponent(query) + '&page=' + page, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const results = [];
    for (const el of doc.querySelectorAll('.search-item')) {
      results.push({
        url: el.querySelector('a')?.getAttribute('href') || '',
        title: el.querySelector('h3')?.textContent?.trim() || '',
        thumbnail_url: el.querySelector('img')?.getAttribute('src') || '',
      });
    }
    return results;
  }

  async getPopular(page) {
    const response = await MClient.fetch(this.baseUrl + '/popular?page=' + page, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const results = [];
    for (const el of doc.querySelectorAll('.popular-item')) {
      results.push({
        url: el.querySelector('a')?.getAttribute('href') || '',
        title: el.querySelector('h3')?.textContent?.trim() || '',
        thumbnail_url: el.querySelector('img')?.getAttribute('src') || '',
      });
    }
    return results;
  }

  async getLatestUpdates(page) {
    const response = await MClient.fetch(this.baseUrl + '/latest?page=' + page, { headers: this.headers });
    const html = response.body;
    const doc = new DOMParser().parseFromString(html, 'text/html');
    const results = [];
    for (const el of doc.querySelectorAll('.latest-item')) {
      results.push({
        url: el.querySelector('a')?.getAttribute('href') || '',
        title: el.querySelector('h3')?.textContent?.trim() || '',
        thumbnail_url: el.querySelector('img')?.getAttribute('src') || '',
      });
    }
    return results;
  }

  async getFilterList() {
    return [];
  }

  async getSortingOptions() {
    return [];
  }

  async getSourcePreferences() {
    return [];
  }

  async saveSourcePreference(key, value) {
    const prefs = await SourcePreferences.getInstance(this.baseUrl);
    await prefs.putString(key, JSON.stringify(value));
  }
}

globalThis.MProvider = MProvider;
''';

Future<void> injectMProvider(QuickJsRuntime2 engine) async {
  engine.evaluate(mProviderBaseClass);
}
