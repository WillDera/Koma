import 'dart:async';
import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

const domBridgeCode = r'''
var __domCallbacks = {};
var __domCallbackId = 0;
var __domElements = {};
var __domElementKey = 0;

function _newHandle(key) {
  return {
    _key: key,
    get text() { return sendMessage('ele_string', JSON.stringify(['text', this._key])); },
    get outerHtml() { return sendMessage('ele_string', JSON.stringify(['outerHtml', this._key])); },
    get innerHtml() { return sendMessage('ele_string', JSON.stringify(['innerHtml', this._key])); },
    get className() { return sendMessage('ele_string', JSON.stringify(['className', this._key])); },
    get getSrc() { return sendMessage('ele_string', JSON.stringify(['getSrc', this._key])); },
    get getHref() { return sendMessage('ele_string', JSON.stringify(['getHref', this._key])); },
    get children() {
      var keys = JSON.parse(sendMessage('ele_children', JSON.stringify([this._key])));
      return keys.map(function(k) { return _newHandle(k); });
    },
    get previousElementSibling() {
      var k = sendMessage('ele_sibling', JSON.stringify(['prev', this._key]));
      return k >= 0 ? _newHandle(k) : null;
    },
    get nextElementSibling() {
      var k = sendMessage('ele_sibling', JSON.stringify(['next', this._key]));
      return k >= 0 ? _newHandle(k) : null;
    },
    get parent() {
      var k = sendMessage('ele_parent', JSON.stringify([this._key]));
      return k >= 0 ? _newHandle(k) : null;
    },
    attr: function(name) { return sendMessage('ele_attr', JSON.stringify([name, this._key])); },
    hasAttr: function(name) { return sendMessage('ele_has_attr', JSON.stringify([name, this._key])) === 'true'; },
    getAttribute: function(name) { return this.attr(name); },
    selectFirst: function(sel) {
      var k = sendMessage('ele_select_first', JSON.stringify([sel, this._key]));
      return k >= 0 ? _newHandle(k) : null;
    },
    querySelector: function(sel) { return this.selectFirst(sel); },
    select: function(sel) {
      var keys = JSON.parse(sendMessage('ele_select', JSON.stringify([sel, this._key])));
      return keys.map(function(k) { return _newHandle(k); });
    },
    querySelectorAll: function(sel) { return this.select(sel); },
    xpath: function(expr) { return JSON.parse(sendMessage('ele_xpath', JSON.stringify([expr, this._key]))); },
    xpathFirst: function(expr) { return sendMessage('ele_xpath_first', JSON.stringify([expr, this._key])); },
    getElementsByTagName: function(name) {
      var keys = JSON.parse(sendMessage('ele_by_tag', JSON.stringify([name, this._key])));
      return keys.map(function(k) { return _newHandle(k); });
    },
    getElementsByClassName: function(name) {
      var keys = JSON.parse(sendMessage('ele_by_class', JSON.stringify([name, this._key])));
      return keys.map(function(k) { return _newHandle(k); });
    },
  };
}

globalThis.MDOMParser = {
  parseFromString: function(html) {
    var id = __domCallbackId++;
    return new Promise(function(resolve, reject) {
      __domCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('ParseDom', JSON.stringify({ html: html, callbackId: id }));
    });
  }
};

globalThis.Document = function(rootKey) {
  this._key = rootKey;
};
Document.prototype = {
  get body() {
    var k = sendMessage('doc_body', JSON.stringify([this._key]));
    return k >= 0 ? _newHandle(k) : null;
  },
  get documentElement() { return _newHandle(this._key); },
  selectFirst: function(sel) {
    var k = sendMessage('doc_select_first', JSON.stringify([sel, this._key]));
    return k >= 0 ? _newHandle(k) : null;
  },
  querySelector: function(sel) { return this.selectFirst(sel); },
  select: function(sel) {
    var keys = JSON.parse(sendMessage('doc_select', JSON.stringify([sel, this._key])));
    return keys.map(function(k) { return _newHandle(k); });
  },
  querySelectorAll: function(sel) { return this.select(sel); },
  getElementById: function(id) {
    var k = sendMessage('doc_by_id', JSON.stringify([id, this._key]));
    return k >= 0 ? _newHandle(k) : null;
  },
  getElementsByTagName: function(name) {
    var keys = JSON.parse(sendMessage('doc_by_tag', JSON.stringify([name, this._key])));
    return keys.map(function(k) { return _newHandle(k); });
  },
  getElementsByClassName: function(name) {
    var keys = JSON.parse(sendMessage('doc_by_class', JSON.stringify([name, this._key])));
    return keys.map(function(k) { return _newHandle(k); });
  },
  xpath: function(expr) { return JSON.parse(sendMessage('doc_xpath', JSON.stringify([expr, this._key]))); },
  xpathFirst: function(expr) { return sendMessage('doc_xpath_first', JSON.stringify([expr, this._key])); },
  attr: function(name) { return sendMessage('doc_attr', JSON.stringify([name, this._key])); },
  hasAttr: function(name) { return sendMessage('doc_has_attr', JSON.stringify([name, this._key])) === 'true'; },
};
''';

class _DomBridgeState {
  final Map<int, html_dom.Element?> elements = {};
  int _nextKey = 0;

  int store(html_dom.Element? el) {
    final k = _nextKey++;
    elements[k] = el;
    return k;
  }

  html_dom.Element? get(int key) => elements[key];

  void dispose() {
    elements.clear();
    _nextKey = 0;
  }
}

Future<void> injectDomBridge(QuickJsRuntime2 engine) async {
  final state = _DomBridgeState();

  engine.onMessage('ParseDom', (args) {
    final html = args['html'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    state.dispose();
    try {
      final doc = html_parser.parse(html);
      final rootEl = doc.documentElement ?? doc.body;
      final key = state.store(rootEl);
      engine.evaluate(
        '__domCallbacks[$callbackId].resolve(new Document($key))',
      );
    } catch (_) {
      engine.evaluate('__domCallbacks[$callbackId].reject("Parse error")');
    }
  });

  engine.onMessage('doc_body', (args) {
    final list = args as List;
    final rootKey = list[0] as int;
    final root = state.get(rootKey);
    final body = root?.querySelector('body') ?? root;
    return state.store(body).toString();
  });

  engine.onMessage('doc_select_first', (args) {
    final list = args as List;
    final sel = list[0] as String;
    final rootKey = list[1] as int;
    final root = state.get(rootKey);
    final found = root?.querySelector(sel);
    return found != null ? state.store(found).toString() : '-1';
  });

  engine.onMessage('doc_select', (args) {
    final list = args as List;
    final sel = list[0] as String;
    final rootKey = list[1] as int;
    final root = state.get(rootKey);
    final found = root?.querySelectorAll(sel) ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('doc_by_id', (args) {
    final list = args as List;
    final id = list[0] as String;
    final rootKey = list[1] as int;
    final root = state.get(rootKey);
    final found = root?.querySelector('#$id');
    return found != null ? state.store(found).toString() : '-1';
  });

  engine.onMessage('doc_by_tag', (args) {
    final list = args as List;
    final tag = list[0] as String;
    final rootKey = list[1] as int;
    final root = state.get(rootKey);
    final found = root?.querySelectorAll(tag) ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('doc_by_class', (args) {
    final list = args as List;
    final cls = list[0] as String;
    final rootKey = list[1] as int;
    final root = state.get(rootKey);
    final found = root?.querySelectorAll('.$cls') ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('doc_attr', (args) {
    final list = args as List;
    final name = list[0] as String;
    final rootKey = list[1] as int;
    return state.get(rootKey)?.attributes[name] ?? '';
  });

  engine.onMessage('doc_has_attr', (args) {
    final list = args as List;
    final name = list[0] as String;
    final rootKey = list[1] as int;
    return (state.get(rootKey)?.attributes.containsKey(name) ?? false)
        .toString();
  });

  engine.onMessage('doc_xpath', (args) {
    final list = args as List;
    final expr = list[0] as String;
    final rootKey = list[1] as int;
    return jsonEncode(_xpathStrings(state.get(rootKey), expr));
  });

  engine.onMessage('doc_xpath_first', (args) {
    final list = args as List;
    final expr = list[0] as String;
    final rootKey = list[1] as int;
    return _xpathStrings(state.get(rootKey), expr).firstOrNull ?? '';
  });

  engine.onMessage('ele_string', (args) {
    final list = args as List;
    final type = list[0] as String;
    final key = list[1] as int;
    final el = state.get(key);
    if (el == null) return '';
    return switch (type) {
      'text' => el.text,
      'outerHtml' => el.outerHtml,
      'innerHtml' => el.innerHtml,
      'className' => el.className,
      'getSrc' => _extractAttr(el, ['src', 'data-src', 'data-lazy-src']),
      'getHref' => el.attributes['href'] ?? '',
      _ => '',
    };
  });

  engine.onMessage('ele_attr', (args) {
    final list = args as List;
    final name = list[0] as String;
    final key = list[1] as int;
    return state.get(key)?.attributes[name] ?? '';
  });

  engine.onMessage('ele_has_attr', (args) {
    final list = args as List;
    final name = list[0] as String;
    final key = list[1] as int;
    return (state.get(key)?.attributes.containsKey(name) ?? false).toString();
  });

  engine.onMessage('ele_children', (args) {
    final list = args as List;
    final key = list[0] as int;
    final children = state.get(key)?.children ?? [];
    return jsonEncode(children.map((e) => state.store(e)).toList());
  });

  engine.onMessage('ele_parent', (args) {
    final list = args as List;
    final key = list[0] as int;
    final parent = state.get(key)?.parent;
    if (parent is html_dom.Element) return state.store(parent).toString();
    return '-1';
  });

  engine.onMessage('ele_sibling', (args) {
    final list = args as List;
    final dir = list[0] as String;
    final key = list[1] as int;
    final el = state.get(key);
    if (el == null) return '-1';
    final siblings = el.parent?.children ?? [];
    final idx = siblings.indexOf(el);
    if (idx < 0) return '-1';
    final targetIdx = dir == 'prev' ? idx - 1 : idx + 1;
    if (targetIdx < 0 || targetIdx >= siblings.length) return '-1';
    return state.store(siblings[targetIdx]).toString();
  });

  engine.onMessage('ele_select_first', (args) {
    final list = args as List;
    final sel = list[0] as String;
    final key = list[1] as int;
    final found = state.get(key)?.querySelector(sel);
    return found != null ? state.store(found).toString() : '-1';
  });

  engine.onMessage('ele_select', (args) {
    final list = args as List;
    final sel = list[0] as String;
    final key = list[1] as int;
    final found = state.get(key)?.querySelectorAll(sel) ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('ele_by_tag', (args) {
    final list = args as List;
    final tag = list[0] as String;
    final key = list[1] as int;
    final found = state.get(key)?.querySelectorAll(tag) ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('ele_by_class', (args) {
    final list = args as List;
    final cls = list[0] as String;
    final key = list[1] as int;
    final found = state.get(key)?.querySelectorAll('.$cls') ?? [];
    return jsonEncode(found.map((e) => state.store(e)).toList());
  });

  engine.onMessage('ele_xpath', (args) {
    final list = args as List;
    final expr = list[0] as String;
    final key = list[1] as int;
    return jsonEncode(_xpathStrings(state.get(key), expr));
  });

  engine.onMessage('ele_xpath_first', (args) {
    final list = args as List;
    final expr = list[0] as String;
    final key = list[1] as int;
    return _xpathStrings(state.get(key), expr).firstOrNull ?? '';
  });

  engine.evaluate(domBridgeCode);
}

String _extractAttr(html_dom.Element el, List<String> attrs) {
  for (final a in attrs) {
    final v = el.attributes[a];
    if (v != null && v.isNotEmpty) return v;
  }
  return '';
}

// Minimal XPath: supports //tag, //tag[@attr='val'], //@attr, //tag/text()
List<String> _xpathStrings(html_dom.Element? root, String expr) {
  if (root == null) return [];
  try {
    final results = <String>[];
    // //tag[@attr='value'] or //tag
    final tagAttr = RegExp(
      "^//(\\w+)(?:\\[@(\\w+)=['\"]([^'\"]*)['\"])?(?:/text\\(\\))?\$",
    );
    final attrOnly = RegExp(r'^//@(\w+)$');
    final m = tagAttr.firstMatch(expr);
    if (m != null) {
      final tag = m.group(1)!;
      final attrName = m.group(2);
      final attrVal = m.group(3);
      final getText = expr.endsWith('/text()');
      final nodes = root.querySelectorAll(tag);
      for (final n in nodes) {
        if (attrName != null && n.attributes[attrName] != attrVal) continue;
        results.add(getText ? n.text : n.outerHtml);
      }
      return results;
    }
    final am = attrOnly.firstMatch(expr);
    if (am != null) {
      final attrName = am.group(1)!;
      _walkAttr(root, attrName, results);
      return results;
    }
  } catch (_) {}
  return [];
}

void _walkAttr(html_dom.Element el, String attr, List<String> out) {
  final v = el.attributes[attr];
  if (v != null) out.add(v);
  for (final child in el.children) {
    _walkAttr(child, attr, out);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
