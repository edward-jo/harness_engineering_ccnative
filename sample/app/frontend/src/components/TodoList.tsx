// 할일 목록 컴포넌트
// - TanStack Query로 GET /api/todos를 호출해 목록을 렌더링한다
// - 빈 목록일 때는 안내 문구를 표시한다
import { useQuery } from '@tanstack/react-query';
import { getTodos } from '../api/todos';
import TodoItem from './TodoItem';

export default function TodoList() {
  const { data, isLoading, isError, error } = useQuery({
    queryKey: ['todos'],
    queryFn: getTodos,
  });

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

  const todos = data ?? [];

  if (todos.length === 0) {
    return (
      <p className="py-10 text-center text-sm text-gray-500 sm:text-base">
        할 일이 없습니다
      </p>
    );
  }

  return (
    <ul className="flex flex-col gap-2">
      {todos.map((todo) => (
        <TodoItem key={todo.id} todo={todo} />
      ))}
    </ul>
  );
}
