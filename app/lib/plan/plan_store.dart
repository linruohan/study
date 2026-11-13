import '../data/study_repository.dart';
import 'study_plan.dart';

/// 学习计划的读写入口：界面只和它打交道，具体同步交给仓库。
class PlanStore {
  PlanStore(this._repository);

  final StudyRepository _repository;

  /// 读取全部计划，已按开始时间排序。
  Future<List<StudyPlan>> load() async => _repository.plans;

  /// 覆盖保存全部计划。
  Future<void> save(List<StudyPlan> plans) {
    return _repository.savePlans(plans);
  }
}
