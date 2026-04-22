// AI 일일 브리핑 컴포넌트
// - "오늘의 브리핑 받기" 버튼 클릭 시 POST /api/briefing을 호출한다
// - 응답 텍스트를 카드 영역에 3~5문장으로 표시한다
// - 에러 발생 시 부모에 알림을 전달해 토스트를 띄운다
import { useMutation } from '@tanstack/react-query';
import { getBriefing } from '../api/todos';

interface DailyBriefingProps {
  onError?: (message: string) => void;
  onSuccess?: (message: string) => void;
}

export default function DailyBriefing({ onError, onSuccess }: DailyBriefingProps) {
  const mutation = useMutation({
    mutationFn: getBriefing,
    onError: () => {
      if (onError) {
        onError('브리핑을 불러오지 못했습니다');
      }
    },
    onSuccess: () => {
      if (onSuccess) {
        onSuccess('브리핑을 받았습니다');
      }
    },
  });

  return (
    <div
      className="rounded-lg bg-white p-4 shadow-sm sm:p-6"
      data-testid="daily-briefing"
    >
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-sm font-semibold text-gray-700">오늘의 브리핑</h2>
        <button
          type="button"
          onClick={() => mutation.mutate()}
          disabled={mutation.isPending}
          className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-medium text-white shadow-sm hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:cursor-not-allowed disabled:bg-blue-400"
        >
          {mutation.isPending ? '생성 중...' : '오늘의 브리핑 받기'}
        </button>
      </div>
      {mutation.data ? (
        <p
          data-testid="briefing-text"
          className="whitespace-pre-line text-sm leading-relaxed text-gray-700"
        >
          {mutation.data}
        </p>
      ) : (
        <p className="text-sm text-gray-400">
          버튼을 눌러 오늘의 우선 할 일 요약을 받아보세요.
        </p>
      )}
    </div>
  );
}
