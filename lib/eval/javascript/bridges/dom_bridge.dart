import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

/// Mangayomi-style Document (`new Document(htmlString)`) + Element handles,
/// while keeping `MDOMParser.parseFromString` for legacy helpers.
const domBridgeCode = r'''
var __domCallbacks = {};
var __domCallbackId = 0;

class Document {
    constructor(html) {
        this.html = (html == null) ? "" : String(html);
    }
    getElement(type) {
        const key = sendMessage(
            "get_doc_element",
            JSON.stringify([this.html, type])
        );
        return new Element(key);
    }
    get body() {
        return this.getElement('body');
    }
    get documentElement() {
        return this.getElement('documentElement');
    }
    get head() {
        return this.getElement('head');
    }
    get parent() {
        return this.getElement('parent');
    }
    getString(type) {
        return sendMessage(
            "get_doc_string",
            JSON.stringify([this.html, type]));
    }
    get text() {
        return this.getString('text');
    }
    get outerHtml() {
        return this.getString('outerHtml');
    }
    selectFirst(selector) {
        const key = sendMessage(
            "doc_select_first",
            JSON.stringify([this.html, selector])
        );
        return key > 0 ? new Element(key) : null;
    }
    querySelector(selector) {
        return this.selectFirst(selector);
    }
    select(selector) {
        try {
            const raw = sendMessage(
                "doc_select",
                JSON.stringify([this.html, selector])
            );
            const keys = JSON.parse(raw || "[]") || [];
            return keys.map((key) => new Element(key));
        } catch (e) {
            return [];
        }
    }
    querySelectorAll(selector) {
        return this.select(selector);
    }
    xpathFirst(xpath) {
        return sendMessage(
            "doc_xpath_first",
            JSON.stringify([this.html, xpath])
        );
    }
    xpath(xpath) {
        return JSON.parse(sendMessage(
            "doc_xpath",
            JSON.stringify([this.html, xpath]))
        );
    }
    getElementsListBy(type, name) {
        name = name || '';
        let elements = [];
        JSON.parse(sendMessage(
            "doc_get_elements_by",
            JSON.stringify([this.html, type, name]))
        ).forEach((key) => {
            elements.push(new Element(key));
        });
        return elements;
    }
    get children() {
        return this.getElementsListBy('children');
    }
    getElementsByTagName(name) {
        return this.getElementsListBy('getElementsByTagName', name);
    }
    getElementsByClassName(name) {
        return this.getElementsListBy('getElementsByClassName', name);
    }
    getElementById(id) {
        const key = sendMessage(
            "doc_get_element_by_id",
            JSON.stringify([this.html, id])
        );
        return key > 0 ? new Element(key) : null;
    }
    attr(attr) {
        return sendMessage(
            "doc_attr",
            JSON.stringify([this.html, attr])
        );
    }
    hasAttr(attr) {
        return sendMessage(
            "doc_has_attr",
            JSON.stringify([this.html, attr])
        );
    }
}

class Element {
    constructor(key) {
        this.key = key;
    }
    getString(type) {
        return sendMessage(
            "get_element_string",
            JSON.stringify([type, this.key])
        );
    }
    get text() {
        return this.getString("text");
    }
    get outerHtml() {
        return this.getString("outerHtml");
    }
    get innerHtml() {
        return this.getString("innerHtml");
    }
    get className() {
        return this.getString("className");
    }
    get localName() {
        return this.getString("localName");
    }
    get getSrc() {
        return this.getString("getSrc");
    }
    get getImg() {
        return this.getString("getImg");
    }
    get getHref() {
        return this.getString("getHref");
    }
    get getDataSrc() {
        return this.getString("getDataSrc");
    }
    getElementSibling(type) {
        const key = sendMessage(
            "ele_element_sibling",
            JSON.stringify([type, this.key])
        );
        return key > 0 ? new Element(key) : null;
    }
    get previousElementSibling() {
        return this.getElementSibling("previousElementSibling");
    }
    get nextElementSibling() {
        return this.getElementSibling("nextElementSibling");
    }
    getElementsListBy(type, name) {
        name = name || '';
        let elements = [];
        JSON.parse(sendMessage(
            "ele_get_elements_by",
            JSON.stringify([type, name, this.key]))
        ).forEach((key) => {
            elements.push(new Element(key));
        });
        return elements;
    }
    get children() {
        return this.getElementsListBy('children');
    }
    getElementsByTagName(name) {
        return this.getElementsListBy('getElementsByTagName', name);
    }
    getElementsByClassName(name) {
        return this.getElementsListBy('getElementsByClassName', name);
    }
    xpath(xpath) {
        return JSON.parse(sendMessage(
            "ele_xpath",
            JSON.stringify([xpath, this.key]))
        );
    }
    xpathFirst(xpath) {
        return sendMessage(
            "ele_xpathFirst",
            JSON.stringify([xpath, this.key])
        );
    }
    attr(attr) {
        return sendMessage(
            "ele_attr",
            JSON.stringify([attr, this.key])
        );
    }
    getAttribute(name) {
        return this.attr(name);
    }
    hasAttr(attr) {
        return sendMessage(
            "ele_has_attr",
            JSON.stringify([attr, this.key])
        );
    }
    selectFirst(selector) {
        const key = sendMessage(
            "ele_selectFirst",
            JSON.stringify([selector, this.key])
        );
        return key > 0 ? new Element(key) : null;
    }
    querySelector(selector) {
        return this.selectFirst(selector);
    }
    select(selector) {
        try {
            const raw = sendMessage(
                "ele_select",
                JSON.stringify([selector, this.key])
            );
            const keys = JSON.parse(raw || "[]") || [];
            return keys.map((key) => new Element(key));
        } catch (e) {
            return [];
        }
    }
    querySelectorAll(selector) {
        return this.select(selector);
    }
}

globalThis.Document = Document;
globalThis.Element = Element;

globalThis.MDOMParser = {
  parseFromString: function(html) {
    return new Document(html);
  }
};

globalThis.DOMParser = function() {};
DOMParser.prototype.parseFromString = function(html) {
  return new Document(html);
};
''';

class _DomBridgeState {
  final Map<int, html_dom.Element?> elements = {};
  int _nextKey = 0;

  int store(html_dom.Element? el) {
    final k = ++_nextKey;
    elements[k] = el;
    return k;
  }

  html_dom.Element? get(int key) => elements[key];

  void dispose() {
    elements.clear();
    _nextKey = 0;
  }
}

Future<void> injectDomBridge(JavascriptRuntime engine) async {
  final state = _DomBridgeState();

  List<dynamic> asList(dynamic args) => args is List ? args : <dynamic>[];

  engine.onMessage('get_doc_element', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final type = list[1] as String? ?? '';
    final doc = html_parser.parse(input);
    final element = switch (type) {
      'body' => doc.body,
      'documentElement' => doc.documentElement,
      'head' => doc.head,
      _ => null,
    };
    return state.store(element);
  });

  engine.onMessage('get_doc_string', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final type = list[1] as String? ?? '';
    final doc = html_parser.parse(input);
    return switch (type) {
          'text' => doc.text,
          _ => doc.outerHtml,
        } ??
        '';
  });

  engine.onMessage('get_element_string', (dynamic args) {
    final list = asList(args);
    final type = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    final element = state.get(key);
    if (element == null) return '';
    return switch (type) {
      'text' => element.text,
      'innerHtml' => element.innerHtml,
      'outerHtml' => element.outerHtml,
      'className' => element.className,
      'localName' => element.localName ?? '',
      'getSrc' => _extractAttr(element, ['src', 'data-src', 'data-lazy-src']),
      'getImg' => _extractAttr(element, ['src', 'data-src', 'data-lazy-src']),
      'getHref' => element.attributes['href'] ?? '',
      'getDataSrc' => _extractAttr(element, ['data-src', 'data-lazy-src', 'src']),
      _ => '',
    };
  });

  engine.onMessage('doc_select_first', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final selector = list[1] as String? ?? '';
    return state.store(html_parser.parse(input).querySelector(selector));
  });

  engine.onMessage('doc_select', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final selector = list[1] as String? ?? '';
    final elements = html_parser.parse(input).querySelectorAll(selector);
    return jsonEncode(elements.map(state.store).toList());
  });

  engine.onMessage('doc_attr', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final attr = list[1] as String? ?? '';
    return html_parser.parse(input).documentElement?.attributes[attr] ?? '';
  });

  engine.onMessage('doc_has_attr', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final attr = list[1] as String? ?? '';
    return html_parser
            .parse(input)
            .documentElement
            ?.attributes
            .containsKey(attr) ??
        false;
  });

  engine.onMessage('doc_xpath_first', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final xpath = list[1] as String? ?? '';
    return _xpathStrings(
          html_parser.parse(input).documentElement,
          xpath,
        ).firstOrNull ??
        '';
  });

  engine.onMessage('doc_xpath', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final xpath = list[1] as String? ?? '';
    return jsonEncode(
      _xpathStrings(html_parser.parse(input).documentElement, xpath),
    );
  });

  engine.onMessage('doc_get_elements_by', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final type = list[1] as String? ?? '';
    final name = list.length > 2 ? (list[2] as String? ?? '') : '';
    final doc = html_parser.parse(input);
    final elements = switch (type) {
      'children' => doc.children,
      'getElementsByTagName' => doc.getElementsByTagName(name),
      _ => doc.getElementsByClassName(name),
    };
    return jsonEncode(elements.map(state.store).toList());
  });

  engine.onMessage('doc_get_element_by_id', (dynamic args) {
    final list = asList(args);
    final input = list[0] as String? ?? '';
    final id = list[1] as String? ?? '';
    return state.store(html_parser.parse(input).getElementById(id));
  });

  engine.onMessage('ele_selectFirst', (dynamic args) {
    final list = asList(args);
    final selector = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    return state.store(state.get(key)?.querySelector(selector));
  });

  engine.onMessage('ele_select', (dynamic args) {
    final list = asList(args);
    final selector = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    final found = state.get(key)?.querySelectorAll(selector) ?? [];
    return jsonEncode(found.map(state.store).toList());
  });

  engine.onMessage('ele_element_sibling', (dynamic args) {
    final list = asList(args);
    final type = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    final el = state.get(key);
    if (el == null) return 0;
    final siblings = el.parent?.children ?? [];
    final idx = siblings.indexOf(el);
    if (idx < 0) return 0;
    final targetIdx =
        type == 'previousElementSibling' ? idx - 1 : idx + 1;
    if (targetIdx < 0 || targetIdx >= siblings.length) return 0;
    return state.store(siblings[targetIdx]);
  });

  engine.onMessage('ele_attr', (dynamic args) {
    final list = asList(args);
    final attr = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    return state.get(key)?.attributes[attr] ?? '';
  });

  engine.onMessage('ele_has_attr', (dynamic args) {
    final list = asList(args);
    final attr = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    return state.get(key)?.attributes.containsKey(attr) ?? false;
  });

  engine.onMessage('ele_xpathFirst', (dynamic args) {
    final list = asList(args);
    final xpath = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    return _xpathStrings(state.get(key), xpath).firstOrNull ?? '';
  });

  engine.onMessage('ele_xpath', (dynamic args) {
    final list = asList(args);
    final xpath = list[0] as String? ?? '';
    final key = list[1] as int? ?? 0;
    return jsonEncode(_xpathStrings(state.get(key), xpath));
  });

  engine.onMessage('ele_get_elements_by', (dynamic args) {
    final list = asList(args);
    final type = list[0] as String? ?? '';
    final name = list.length > 1 ? (list[1] as String? ?? '') : '';
    final key = list.length > 2 ? (list[2] as int? ?? 0) : 0;
    final element = state.get(key);
    final elements = switch (type) {
      'children' => element?.children,
      'getElementsByTagName' => element?.getElementsByTagName(name),
      _ => element?.getElementsByClassName(name),
    };
    return jsonEncode((elements ?? []).map(state.store).toList());
  });

  // Legacy ParseDom callback still accepted; resolve to Document(html).
  engine.onMessage('ParseDom', (dynamic args) {
    final html = args is Map ? (args['html'] as String? ?? '') : '';
    final callbackId = args is Map ? (args['callbackId'] as int? ?? 0) : 0;
    engine.evaluate(
      '__domCallbacks[$callbackId].resolve(new Document(${jsonEncode(html)}))',
    );
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

List<String> _xpathStrings(html_dom.Element? root, String expr) {
  if (root == null) return [];
  try {
    final results = <String>[];
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
