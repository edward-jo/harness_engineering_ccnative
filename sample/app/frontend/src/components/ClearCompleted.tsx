// 완료 항목 일괄 삭제 버튼 컴포넌트
// - 완료 항목이 1개 이상일 때만 부모가 렌더링한다 (조건부 표시)
// - 클릭 시 DELETE /api/todos/completed 호출
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { clearCompleted } from '../api/todos';

interface ClearCompletedProps {
  /** 삭제 대상 완료 항목 개수 (버튼 라벨에 사용) */
  count: number;
}

export default function ClearCompleted({ count }: ClearCompletedProps) {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: clearCompleted,
    onSuccess: () => {
      // 모든 필터(all/active/completed) 목록을 다시 불러온다
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  });

  return (
    <button
      type="button"
      onClick={() => mutation.mutate()}
      disabled={mutation.isPending}
      aria-label="완료된 할일 모두 삭제"
      className="rounded-md border border-red-300 bg-white px-3 py-1.5 text-sm font-medium text-red-600 shadow-sm transition hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50"
    >
      {mutation.isPending ? '삭제 중...' : `완료 삭제 (${count})`}
    </button>
  );
}
