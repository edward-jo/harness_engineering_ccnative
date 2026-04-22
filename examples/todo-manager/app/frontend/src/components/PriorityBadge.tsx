// 우선순위 색상 뱃지 컴포넌트
// - AI가 추천한 우선순위(high/medium/low)를 서로 다른 색상으로 시각화한다
// - 색상 매핑: high=red, medium=yellow, low=green
import type { ReactElement } from 'react';
import type { Priority } from '../api/todos';

interface PriorityBadgeProps {
  priority: Priority;
}

/** 우선순위 → Tailwind 배경/텍스트 클래스 매핑 */
const PRIORITY_STYLES: Record<Priority, string> = {
  high: 'bg-red-100 text-red-800 border-red-200',
  medium: 'bg-yellow-100 text-yellow-800 border-yellow-200',
  low: 'bg-green-100 text-green-800 border-green-200',
};

/** 우선순위 → 한국어 라벨 */
const PRIORITY_LABELS: Record<Priority, string> = {
  high: '높음',
  medium: '보통',
  low: '낮음',
};

export default function PriorityBadge({
  priority,
}: PriorityBadgeProps): ReactElement {
  const styleClass = PRIORITY_STYLES[priority] ?? PRIORITY_STYLES.medium;
  const label = PRIORITY_LABELS[priority] ?? PRIORITY_LABELS.medium;
  return (
    <span
      data-testid="priority-badge"
      data-priority={priority}
      className={`inline-flex items-center rounded-full border px-2 py-0.5 text-xs font-medium ${styleClass}`}
    >
      {label}
    </span>
  );
}
