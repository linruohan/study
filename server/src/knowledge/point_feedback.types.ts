export interface PointRef {
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  position: number;
}

export interface CommentDto {
  id: string;
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  position: number;
  deviceId: string;
  body: string;
  createdAt: string;
}

export interface CorrectionDto {
  id: string;
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  position: number;
  deviceId: string;
  body: string;
  suggestedText: string | null;
  status: 'pending' | 'approved' | 'rejected';
  reviewedAt: string | null;
  reviewerDeviceId: string | null;
  pointsAwarded: number;
  createdAt: string;
}