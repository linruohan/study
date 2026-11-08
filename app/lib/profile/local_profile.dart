import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../knowledge/age_band.dart';

/// 本机的档位设置：当前年龄档与关注领域。
///
/// 这是设置，不是学习档案；档案仍走 [LocalArchive] 单独导出。
class StudyProfile {
  const StudyProfile({this.band, this.focusDomainId});

  /// 当前年龄档；null 表示还没选，启动时先选年龄。
  final AgeBand? band;

  /// 最近选择的关注领域，用于今日引导的优先级。
  final String? focusDomainId;

  /// 换档时保留关注领域，只换年龄。
  StudyProfile withBand(AgeBand next) {
    return StudyProfile(band: next, focusDomainId: focusDomainId);
  }

  /// 换关注领域时保留年龄档。
  StudyProfile withFocus(String? domainId) {
    return StudyProfile(band: band, focusDomainId: domainId);
  }

  Map<String, Object?> toJson() {
    return {'band': band?.id, 'focusDomainId': focusDomainId};
  }

  static StudyProfile fromJson(Map<String, Object?> json) {
    return StudyProfile(
      band: AgeBand.fromId(json['band'] as String?),
      focusDomainId: json['focusDomainId'] as String?,
    );
  }
}

/// 档位设置的读写。测试可以注入临时目录，不写真实文档目录。
class LocalProfile {
  LocalProfile({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> _file() async {
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}study_profile.json');
  }

  /// 读取设置；文件缺失或损坏时回到「还没选年龄」，不让启动失败。
  Future<StudyProfile> load() async {
    final file = await _file();
    if (!file.existsSync()) {
      return const StudyProfile();
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return const StudyProfile();
      }
      return StudyProfile.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return const StudyProfile();
    }
  }

  Future<void> save(StudyProfile profile) async {
    final file = await _file();
    file.writeAsStringSync(jsonEncode(profile.toJson()));
  }
}
