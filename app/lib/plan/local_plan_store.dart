import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'study_plan.dart';

/// 计划的本机存储：一个 JSON 文件，和档案分开。
///
/// 测试可以注入临时目录，不写真实文档目录。
class LocalPlanStore {
  LocalPlanStore({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> _file() async {
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}study_plans.json');
  }

  /// 读取全部计划，按开始时间排序；文件缺失或损坏时返回空列表。
  Future<List<StudyPlan>> load() async {
    final file = await _file();
    if (!file.existsSync()) {
      return [];
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) {
        return [];
      }
      final raw = decoded['plans'];
      if (raw is! List) {
        return [];
      }
      final plans = <StudyPlan>[];
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final plan = StudyPlan.fromJson(Map<String, Object?>.from(item));
        if (plan != null) {
          plans.add(plan);
        }
      }
      plans.sort((a, b) => a.startAt.compareTo(b.startAt));
      return plans;
    } catch (_) {
      return [];
    }
  }

  /// 覆盖保存全部计划。
  Future<void> save(List<StudyPlan> plans) async {
    final file = await _file();
    final payload = {
      'plans': [for (final plan in plans) plan.toJson()],
    };
    file.writeAsStringSync(jsonEncode(payload));
  }
}
