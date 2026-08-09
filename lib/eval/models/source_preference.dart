import 'dart:math';

/// Mangayomi-shaped source preference (nested embeds).
///
/// Isar [SourcePreference] collection deferred — PrefsCache / SharedPreferences
/// is the value store for JS (`getJsPreferenceValue` / `setJsPreferenceValue`).
class SourcePreference {
  String? key;
  CheckBoxPreference? checkBoxPreference;
  SwitchPreferenceCompat? switchPreferenceCompat;
  ListPreference? listPreference;
  MultiSelectListPreference? multiSelectListPreference;
  EditTextPreference? editTextPreference;

  SourcePreference({
    this.key,
    this.checkBoxPreference,
    this.switchPreferenceCompat,
    this.listPreference,
    this.multiSelectListPreference,
    this.editTextPreference,
  });

  /// Typed value used by JS `SharedPreferences.get` / UI persistence
  /// (mangayomi [getPreferenceValue]).
  dynamic get typedValue {
    if (listPreference != null) {
      final pref = listPreference!;
      final values = pref.entryValues;
      final idx = pref.valueIndex ?? 0;
      if (values != null && values.isNotEmpty) {
        return values[idx.clamp(0, values.length - 1)];
      }
      return '';
    }
    if (checkBoxPreference != null) {
      return checkBoxPreference!.value;
    }
    if (switchPreferenceCompat != null) {
      return switchPreferenceCompat!.value;
    }
    if (editTextPreference != null) {
      return editTextPreference!.value;
    }
    if (multiSelectListPreference != null) {
      return multiSelectListPreference!.values ?? <String>[];
    }
    return null;
  }

  /// Overlay a PrefsCache / SharedPreferences stored value onto embeds for UI.
  void applyStoredValue(dynamic stored) {
    if (stored == null) return;
    if (listPreference != null) {
      final values = listPreference!.entryValues;
      if (values != null) {
        final idx = values.indexOf(stored.toString());
        if (idx >= 0) listPreference!.valueIndex = idx;
      }
    } else if (checkBoxPreference != null) {
      checkBoxPreference!.value = stored == true || stored == 'true';
    } else if (switchPreferenceCompat != null) {
      switchPreferenceCompat!.value = stored == true || stored == 'true';
    } else if (editTextPreference != null) {
      editTextPreference!.value = stored.toString();
    } else if (multiSelectListPreference != null) {
      if (stored is List) {
        multiSelectListPreference!.values =
            stored.map((e) => e.toString()).toList();
      }
    }
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        if (checkBoxPreference != null)
          'checkBoxPreference': checkBoxPreference!.toJson(),
        if (switchPreferenceCompat != null)
          'switchPreferenceCompat': switchPreferenceCompat!.toJson(),
        if (listPreference != null) 'listPreference': listPreference!.toJson(),
        if (multiSelectListPreference != null)
          'multiSelectListPreference': multiSelectListPreference!.toJson(),
        if (editTextPreference != null)
          'editTextPreference': editTextPreference!.toJson(),
      };

  factory SourcePreference.fromJson(Map<String, dynamic> json) {
    return SourcePreference(
      key: json['key']?.toString(),
      checkBoxPreference: json['checkBoxPreference'] != null
          ? CheckBoxPreference.fromJson(
              _asMap(json['checkBoxPreference']),
            )
          : null,
      switchPreferenceCompat: json['switchPreferenceCompat'] != null
          ? SwitchPreferenceCompat.fromJson(
              _asMap(json['switchPreferenceCompat']),
            )
          : null,
      listPreference: json['listPreference'] != null
          ? ListPreference.fromJson(_asMap(json['listPreference']))
          : null,
      multiSelectListPreference: json['multiSelectListPreference'] != null
          ? MultiSelectListPreference.fromJson(
              _asMap(json['multiSelectListPreference']),
            )
          : null,
      editTextPreference: json['editTextPreference'] != null
          ? EditTextPreference.fromJson(_asMap(json['editTextPreference']))
          : null,
    );
  }

  factory SourcePreference.fromDynamic(dynamic d) {
    if (d is Map<String, dynamic>) return SourcePreference.fromJson(d);
    if (d is Map) {
      return SourcePreference.fromJson(Map<String, dynamic>.from(d));
    }
    throw ArgumentError('Expected Map, got ${d.runtimeType}');
  }
}

class CheckBoxPreference {
  String? title;
  String? summary;
  bool? value;

  CheckBoxPreference({this.title, this.summary, this.value});

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'value': value,
      };

  factory CheckBoxPreference.fromJson(Map<String, dynamic> json) {
    return CheckBoxPreference(
      title: json['title']?.toString(),
      summary: json['summary']?.toString(),
      value: _asBool(json['value']),
    );
  }
}

class SwitchPreferenceCompat {
  String? title;
  String? summary;
  bool? value;

  SwitchPreferenceCompat({this.title, this.summary, this.value});

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'value': value,
      };

  factory SwitchPreferenceCompat.fromJson(Map<String, dynamic> json) {
    return SwitchPreferenceCompat(
      title: json['title']?.toString(),
      summary: json['summary']?.toString(),
      value: _asBool(json['value']),
    );
  }
}

class ListPreference {
  String? title;
  String? summary;
  int? valueIndex;
  List<String>? entries;
  List<String>? entryValues;

  ListPreference({
    this.title,
    this.summary,
    this.valueIndex,
    this.entries,
    this.entryValues,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'valueIndex': valueIndex,
        'entries': entries,
        'entryValues': entryValues,
      };

  factory ListPreference.fromJson(Map<String, dynamic> json) {
    return ListPreference(
      title: json['title']?.toString(),
      summary: json['summary']?.toString(),
      valueIndex: json['valueIndex'] != null
          ? max(0, (json['valueIndex'] as num).toInt())
          : null,
      entries: _asStringList(json['entries']),
      entryValues: _asStringList(json['entryValues']),
    );
  }
}

class MultiSelectListPreference {
  String? title;
  String? summary;
  List<String>? entries;
  List<String>? entryValues;
  List<String>? values;

  MultiSelectListPreference({
    this.title,
    this.summary,
    this.entries,
    this.entryValues,
    this.values,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'entries': entries,
        'entryValues': entryValues,
        'values': values,
      };

  factory MultiSelectListPreference.fromJson(Map<String, dynamic> json) {
    return MultiSelectListPreference(
      title: json['title']?.toString(),
      summary: json['summary']?.toString(),
      entries: _asStringList(json['entries']),
      entryValues: _asStringList(json['entryValues']),
      values: _asStringList(json['values']),
    );
  }
}

class EditTextPreference {
  String? title;
  String? summary;
  String? value;
  String? dialogTitle;
  String? dialogMessage;
  String? text;

  EditTextPreference({
    this.title,
    this.summary,
    this.value,
    this.dialogTitle,
    this.dialogMessage,
    this.text,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'value': value,
        'dialogTitle': dialogTitle,
        'dialogMessage': dialogMessage,
        'text': text,
      };

  factory EditTextPreference.fromJson(Map<String, dynamic> json) {
    return EditTextPreference(
      title: json['title']?.toString(),
      summary: json['summary']?.toString(),
      value: json['value']?.toString(),
      dialogTitle: json['dialogTitle']?.toString(),
      dialogMessage: json['dialogMessage']?.toString(),
      text: json['text']?.toString(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<String>? _asStringList(dynamic v) {
  if (v == null) return null;
  if (v is List) return v.map((e) => e.toString()).toList();
  return null;
}

bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true') return true;
  if (s == 'false') return false;
  return null;
}
