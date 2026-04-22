// 할일 목록 컴포넌트
// - TanStack Query로 GET /api/todos(?status=...)를 호출해 목록을 렌더링한다
// - 빈 목록일 때는 안내 문구를 표시한다
// - 필터 상태(status)와 우선순위 정렬 여부(sortByPriority)는 상위에서 주입받는다
import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getTodos, type Priority, type Todo, type TodoStatus } from '../api/todos';
import TodoItem from './TodoItem';

interface TodoListProps {
  status: TodoStatus;
  sortByPriority?: boolean;
}

/** 우선순위 가중치 (high > medium > low) */
const PRIORITY_WEIGHT: Record<Priority, number> = {
  high: 0,
  medium: 1,
  low: 2,
};

/** 우선순위 가중치 조회 (알 수 없는 값은 가장 낮게 취급) */
function priorityRank(priority: string): number {
  return PRIORITY_WEIGHT[priority as Priority] ?? PRIORITY_WEIGHT.low;
}

export default function TodoList({
  status,
  sortByPriority = false,
}: TodoListProps) {
  const { data, isLoading, isError, error } = useQuery({
    queryKey: ['todos', status],
    queryFn: () => getTodos(status),
  });

  // 우선순위 정렬 활성 시 클라이언트 측에서 재정렬 (동일 우선순위는 서버 순서 유지)
  const visibleTodos = useMemo<Todo[]>(() => {
    const todos = data ?? [];
    if (!sortByPriority) return todos;
    return [...todos].sort(
      (a, b) => priorityRank(a.priority) - priorityRank(b.priority),
    );
  }, [data, sortByPriority]);

  if (isLoading) {
    return (
      <p className="py-6 text-center text-sm text-gray-500">불러오는 중...</p>
    );
  }

  if (isError) {
    const message = error instanceof Error ? error.message : '알 수 없는 오류';
    return (
      <p className="py-6 text-center text-sm text-red-600">
        목록을 불러오지 못했습니다: {message}
      </p>
    );
  }

  if (visibleTodos.length === 0) {
    return (
      <p className="py-10 text-center text-sm text-gray-500 sm:text-base">
        할 일이 없습니다
      </p>
    );
  }

  return (
    <ul className="flex flex-col gap-2">
      {visibleTodos.map((todo) => (
        <TodoItem key={todo.id} todo={todo} />
      ))}
    </ul>
  );
}
