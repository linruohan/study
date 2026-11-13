import '../knowledge/age_band.dart';
import '../knowledge/knowledge_catalog.dart';

/// 学习设置：当前年龄档与关注领域。
///
/// 数据存在数据库里，按设备区分；这里只是内存形态。
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

  /// 从接口或缓存读取设置；未知年龄 id 回到「还没选」。
  static StudyProfile fromJson(Map<String, Object?> json) {
    final catalog = KnowledgeCatalog.maybeInstance;
    return StudyProfile(
      band: catalog?.ageBandById(json['band'] as String?),
      focusDomainId: json['focusDomainId'] as String?,
    );
  }
}
