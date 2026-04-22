// 카테고리별 할일 통계 대시보드 컴포넌트
// - GET /api/stats 결과를 카드 + 완료율 진행바 형식으로 시각화한다
// - 데이터가 비어 있으면 안내 문구를 표시한다
// - Tailwind CSS만으로 간단한 바 차트를 구현한다 (별도 차트 라이브러리 미사용)
import { useQuery } from '@tanstack/react-query';
import { getStats } from '../api/todos';

/** 카테고리별 뱃지 색상 (CategoryBadge와 동일한 팔레트) */
const CATEGORY_BAR_COLORS: Record<string, string> = {
  업무: 'bg-blue-500',
  개인: 'bg-purple-500',
  쇼핑: 'bg-pink-500',
  건강: 'bg-green-500',
  학습: 'bg-yellow-500',
  여가: 'bg-orange-500',
  가사: 'bg-teal-500',
  기타: 'bg-gray-500',
};

interface StatsPanelProps {
  /** 에러 발생 시 부모에 알려 토스트를 띄우기 위한 콜백 */
  onError?: (message: string) => void;
}

export default function StatsPanel({ onError }: StatsPanelProps) {
  const { data, isLoading, isError } = useQuery({
    queryKey: ['stats'],
    queryFn: getStats,
  });

  // 에러 발생 시 부모에 알림 (useEffect 대신 isError 렌더링 시점에 처리)
  if (isError && onError) {
    onError('통계를 불러오지 못했습니다');
  }

  if (isLoading) {
    return (
      <div className="rounded-lg bg-white p-4 shadow-sm sm:p-6">
        <h2 className="mb-3 text-sm font-semibold text-gray-700">카테고리별 통계</h2>
        <p className="text-sm text-gray-400">불러오는 중...</p>
      </div>
    );
  }

  const entries = data ? Object.entries(data) : [];

  if (entries.length === 0) {
    return (
      <div className="rounded-lg bg-white p-4 shadow-sm sm:p-6">
        <h2 className="mb-3 text-sm font-semibold text-gray-700">카테고리별 통계</h2>
        <p className="text-sm text-gray-400">표시할 통계가 없습니다</p>
      </div>
    );
  }

  // 전체 합계 계산 (상단 요약용)
  const totalAll = entries.reduce((acc, [, v]) => acc + v.total, 0);
  const completedAll = entries.reduce((acc, [, v]) => acc + v.completed, 0);

  return (
    <div className="rounded-lg bg-white p-4 shadow-sm sm:p-6" data-testid="stats-panel">
      <div className="mb-4 flex items-baseline justify-between">
        <h2 className="text-sm font-semibold text-gray-700">카테고리별 통계</h2>
        <span className="text-xs text-gray-500">
          전체 {completedAll}/{totalAll} 완료
        </span>
      </div>
      <ul className="space-y-3">
        {entries.map(([category, stat]) => {
          const ratio = stat.total > 0 ? (stat.completed / stat.total) * 100 : 0;
          const barColor = CATEGORY_BAR_COLORS[category] ?? 'bg-gray-400';
          return (
            <li key={category} data-testid={`stats-row-${category}`}>
              <div className="mb-1 flex items-center justify-between text-xs">
                <span className="font-medium text-gray-700">{category}</span>
                <span className="text-gray-500">
                  {stat.completed}/{stat.total} ({Math.round(ratio)}%)
                </span>
              </div>
              <div
                className="h-2 w-full overflow-hidden rounded-full bg-gray-200"
                role="progressbar"
                aria-valuenow={Math.round(ratio)}
                aria-valuemin={0}
                aria-valuemax={100}
              >
                <div
                  className={`h-full rounded-full ${barColor} transition-all`}
                  style={{ width: `${ratio}%` }}
                />
              </div>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
