// 카테고리 색상 뱃지 컴포넌트
// - AI가 분류한 카테고리(8종)를 서로 다른 배경색 뱃지로 시각화한다
// - 색상 매핑:
//   업무=blue, 개인=purple, 쇼핑=pink, 건강=green,
//   학습=yellow, 여가=orange, 가사=teal, 기타=gray
import type { ReactElement } from 'react';

interface CategoryBadgeProps {
  category: string;
}

/** 카테고리 → Tailwind 배경/텍스트 클래스 매핑 테이블 */
const CATEGORY_STYLES: Record<string, string> = {
  업무: 'bg-blue-100 text-blue-800 border-blue-200',
  개인: 'bg-purple-100 text-purple-800 border-purple-200',
  쇼핑: 'bg-pink-100 text-pink-800 border-pink-200',
  건강: 'bg-green-100 text-green-800 border-green-200',
  학습: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  여가: 'bg-orange-100 text-orange-800 border-orange-200',
  가사: 'bg-teal-100 text-teal-800 border-teal-200',
  기타: 'bg-gray-100 text-gray-800 border-gray-200',
};

/** 알려지지 않은 카테고리는 회색(기타)으로 폴백한다 */
const DEFAULT_STYLE = CATEGORY_STYLES['기타'];

export default function CategoryBadge({
  category,
}: CategoryBadgeProps): ReactElement {
  const styleClass = CATEGORY_STYLES[category] ?? DEFAULT_STYLE;
  return (
    <span
      data-testid="category-badge"
      data-category={category}
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${styleClass}`}
    >
      {category}
    </span>
  );
}
