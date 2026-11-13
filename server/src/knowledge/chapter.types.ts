export interface ChapterDto {
  chapterPosition?: number;
  title: string;
  content?: string | null;
}

export interface ChapterRef {
  conceptId: string;
  ageBandId: string;
  degreeId: string;
  pointPosition: number;
}
