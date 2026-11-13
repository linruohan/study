export interface ChapterDto {
  title: string;
  content?: string | null;
}

export interface ChapterRef {
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  pointPosition: number;
}