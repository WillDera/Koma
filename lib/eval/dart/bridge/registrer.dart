import 'package:d4rt/d4rt.dart';
import 'package:koma/eval/dart/bridge/document.dart';
import 'package:koma/eval/dart/bridge/element.dart';
import 'package:koma/eval/dart/bridge/filter.dart';
import 'package:koma/eval/dart/bridge/http.dart';
import 'package:koma/eval/dart/bridge/m_chapter.dart';
import 'package:koma/eval/dart/bridge/m_manga.dart';
import 'package:koma/eval/dart/bridge/m_pages.dart';
import 'package:koma/eval/dart/bridge/m_provider.dart';
import 'package:koma/eval/dart/bridge/m_source.dart';
import 'package:koma/eval/dart/bridge/m_status.dart';
import 'package:koma/eval/dart/bridge/m_track.dart';
import 'package:koma/eval/dart/bridge/m_video.dart';
import 'package:koma/eval/dart/bridge/source_preference.dart';

class RegistrerBridge {
  static void registerBridge(D4rt interpreter) {
    MDocumentBridge().registerBridgedClasses(interpreter);
    MElementBridge().registerBridgedClasses(interpreter);
    FilterBridge().registerBridgedClasses(interpreter);
    HttpBridge().registerBridgedClasses(interpreter);
    MMangaBridge().registerBridgedClasses(interpreter);
    MChapterBridge().registerBridgedClasses(interpreter);
    MPagesBridge().registerBridgedClasses(interpreter);
    MProviderBridged().registerBridgedClasses(interpreter);
    MSourceBridge().registerBridgedClasses(interpreter);
    MStatusBridge().registerBridgedEnum(interpreter);
    MTrackBridge().registerBridgedClasses(interpreter);
    MVideoBridge().registerBridgedClasses(interpreter);
    SourcePreferenceBridge().registerBridgedClasses(interpreter);
  }
}
