// 할일 추가 폼 컴포넌트
// - 텍스트 입력과 "추가" 버튼을 제공한다
// - Enter 키 또는 버튼 클릭으로 제출한다 (form submit으로 통합 처리)
import { FormEvent, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { createTodo } from '../api/todos';

export default function TodoForm() {
  const [title, setTitle] = useState('');
  const queryClient = useQueryClient();

  // 할일 생성 뮤테이션 — 성공 시 목록 쿼리 무효화해 자동 리페치
  // (createTodo가 선택 인자 dueDate를 받으므로 래퍼로 명시적 1-arg 호출)
  const mutation = useMutation({
    mutationFn: (nextTitle: string) => createTodo(nextTitle),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
      setTitle('');
    },
  });

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trimmed = title.trim();
    // 빈 문자열 전송 방지 (백엔드 422와 무관하게 클라이언트에서 조기 차단)
    if (!trimmed || mutation.isPending) {
      return;
    }
    mutation.mutate(trimmed);
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="flex flex-col gap-2 sm:flex-row sm:gap-3"
    >
      <input
        type="text"
        value={title}
        onChange={(event) => setTitle(event.target.value)}
        placeholder="할 일을 입력하세요"
        aria-label="할 일 입력"
        className="flex-1 rounded-md border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
        disabled={mutation.isPending}
      />
      <button
        type="submit"
        disabled={mutation.isPending || title.trim().length === 0}
        className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:bg-gray-400"
      >
        {mutation.isPending ? '추가 중...' : '추가'}
      </button>
    </form>
  );
}
