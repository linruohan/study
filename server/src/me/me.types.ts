/// 设备维度的用户数据：设置、计划和学习记录。
export interface ProfileDto {
  /// 当前年龄档 id；还没选时为空。
  band: string | null;
  /// 关注领域 id，可空。
  focusDomainId: string | null;
}

export interface PlanDto {
  id: string;
  domainId: string;
  depth: 'brief' | 'deep';
  conceptId: string | null;
  degree: string | null;
  startAt: string;
  remind: boolean;
  done: boolean;
  remindedAt: string | null;
  snoozedUntil: string | null;
}

export interface LearningRecordDto {
  id: string;
  at: string;
  source: string;
  subject: string;
  body: string;
  conceptId: string | null;
  domainId: string | null;
  ageBandId: string | null;
}

export interface UserDataDto {
  profile: ProfileDto;
  plans: PlanDto[];
  records: LearningRecordDto[];
}
