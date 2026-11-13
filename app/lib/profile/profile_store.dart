import '../data/study_repository.dart';
import 'study_profile.dart';

/// 学习设置的读写入口：界面只和它打交道，具体同步交给仓库。
class ProfileStore {
  ProfileStore(this._repository);

  final StudyRepository _repository;

  /// 读取当前设置。
  Future<StudyProfile> load() async => _repository.profile;

  /// 保存设置并同步到数据库；断网时写缓存，等下次启动补推。
  Future<void> save(StudyProfile profile) {
    return _repository.saveProfile(profile);
  }
}
