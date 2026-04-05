// 우선순위 정렬 토글 컨트롤 컴포넌트
// - 비활성(default): 생성일 내림차순 (서버 기본 순서 유지)
// - 활성: 우선순위 기준 정렬 (high > medium > low)
import type { ReactElement } from 'react';

interface SortControlsProps {
  /** 우선순위 정렬 활성 여부 */
  sortByPriority: boolean;
  /** 토글 콜백 */
  onToggle: (next: boolean) => void;
}

export default function SortControls({
  sortByPriority,
  onToggle,
}: SortControlsProps): ReactElement {
  return (
    <button
      type="button"
      onClick={() => onToggle(!sortByPriority)}
      data-testid="sort-by-priority-toggle"
      data-active={sortByPriority}
      aria-pressed={sortByPriority}
      className={`inline-flex items-center gap-1.5 rounded-md border px-3 py-1.5 text-xs font-medium transition sm:text-sm ${
        sortByPriority
          ? 'border-blue-500 bg-blue-500 text-white shadow-sm hover:bg-blue-600'
          : 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50'
      }`}
    >
      <span aria-hidden>{sortByPriority ? '↓' : '↕'}</span>
      우선순위 정렬
    </button>
  );
}
