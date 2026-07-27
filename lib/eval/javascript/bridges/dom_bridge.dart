import 'dart:async';
import 'dart:convert';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

const domBridgeCode = '''
var __domCallbacks = {};
var __domCallbackId = 0;

globalThis.MDOMParser = {
  parseFromString: function(html) {
    var id = __domCallbackId++;
    return new Promise(function(resolve, reject) {
      __domCallbacks[id] = { resolve: resolve, reject: reject };
      sendMessage('ParseDom', JSON.stringify({ html: html, callbackId: id }));
    });
  }
};

function _wrapNode(raw) {
  if (raw === null || raw === undefined) return null;
  var node = {
    _tag: raw.t,
    _attrs: raw.a || {},
    _children: (raw.c || []).map(function(c) { return _wrapNode(c); }),
    _text: raw.x || "",
    get tagName() { return this._tag ? this._tag.toUpperCase() : null; },
    get textContent() {
      if (this._tag === "#text") return this._text;
      return (this._children || []).map(function(c) { return c.textContent; }).join("");
    },
    get attributes() { return this._attrs; },
    get className() { return this._attrs.class || ""; },
    get children() { return this._children || []; },
    querySelector: function(sel) { return _querySelector(this, sel); },
    querySelectorAll: function(sel) { return _querySelectorAll(this, sel); },
    getAttribute: function(name) { return this._attrs[name] || null; }
  };
  return node;
}

function _matches(el, selector) {
  if (!el || !el._tag) return false;
  var tag = selector.split(/[#.]/)[0];
  if (tag && el._tag !== tag.toLowerCase()) return false;
  if (selector.indexOf("#") >= 0) {
    var id = selector.match(/#([^.#]+)/);
    if (id && el._attrs.id !== id[1]) return false;
  }
  if (selector.indexOf(".") >= 0) {
    var cls = (el._attrs.class || "").split(" ");
    var classes = selector.match(/\\.([^.#]+)/g);
    if (classes) {
      for (var i = 0; i < classes.length; i++) {
        if (cls.indexOf(classes[i].slice(1)) === -1) return false;
      }
    }
  }
  return true;
}

function _querySelector(el, selector) {
  if (_matches(el, selector)) return el;
  for (var i = 0; i < (el._children || []).length; i++) {
    var found = _querySelector(el._children[i], selector);
    if (found) return found;
  }
  return null;
}

function _querySelectorAll(el, selector) {
  var results = [];
  if (_matches(el, selector)) results.push(el);
  for (var i = 0; i < (el._children || []).length; i++) {
    results = results.concat(_querySelectorAll(el._children[i], selector));
  }
  return results;
}
''';

Future<void> injectDomBridge(QuickJsRuntime2 engine) async {
  engine.setupBridge('ParseDom', (args) {
    final html = args['html'] as String? ?? '';
    final callbackId = args['callbackId'] as int? ?? 0;
    _handleParseDom(engine, html, callbackId);
  });

  engine.evaluate(domBridgeCode);
}

void _handleParseDom(QuickJsRuntime2 engine, String html, int callbackId) {
  try {
    final doc = html_parser.parse(html);
    final tree = _serializeNode(doc);
    final result = jsonEncode(tree);
    engine.evaluate('__domCallbacks[$callbackId].resolve(\'${_escapeJs(result)}\')');
  } catch (e) {
    engine.evaluate('__domCallbacks[$callbackId].reject("Parse error")');
  }
}

String _escapeJs(String s) {
  return s.replaceAll("'", "\\'").replaceAll('\n', '\\n').replaceAll('\r', '\\r');
}

Map<String, dynamic> _serializeNode(html_dom.Node node) {
  if (node is html_dom.Text) {
    return {
      't': '#text',
      'a': <String, String>{},
      'c': <Map<String, dynamic>>[],
      'x': node.text,
    };
  }

  if (node is html_dom.Element) {
    return {
      't': node.localName ?? '',
      'a': Map<String, String>.from(node.attributes),
      'c': node.nodes.map(_serializeNode).toList(),
      'x': '',
    };
  }

  if (node is html_dom.Document) {
    return {
      't': '#document',
      'a': <String, String>{},
      'c': node.nodes.map(_serializeNode).toList(),
      'x': '',
    };
  }

  return {
    't': '#text',
    'a': <String, String>{},
    'c': <Map<String, dynamic>>[],
    'x': node.toString(),
  };
}
