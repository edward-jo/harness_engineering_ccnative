// 개별 할일 항목 컴포넌트
// - 체크박스로 완료 상태 토글 (취소선 표시)
// - 삭제 버튼으로 항목 제거
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { deleteTodo, toggleTodo, Todo } from '../api/todos';

interface TodoItemProps {
  todo: Todo;
}

export default function TodoItem({ todo }: TodoItemProps) {
  const queryClient = useQueryClient();

  // 완료 상태 토글 뮤테이션
  const toggleMutation = useMutation({
    mutationFn: () => toggleTodo(todo.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  });

  // 삭제 뮤테이션
  const deleteMutation = useMutation({
    mutationFn: () => deleteTodo(todo.id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  });

  const isBusy = toggleMutation.isPending || deleteMutation.isPending;

  return (
    <li className="flex items-center gap-3 rounded-md border border-gray-200 bg-white px-3 py-2 shadow-sm sm:px-4 sm:py-3">
      <input
        type="checkbox"
        checked={todo.completed}
        onChange={() => toggleMutation.mutate()}
        disabled={isBusy}
        aria-label={`${todo.title} 완료 상태 토글`}
        className="h-5 w-5 cursor-pointer rounded border-gray-300 text-blue-600 focus:ring-blue-500 disabled:cursor-not-allowed"
      />
      <span
        className={`flex-1 break-words text-sm sm:text-base ${
          todo.completed ? 'text-gray-400 line-through' : 'text-gray-900'
        }`}
      >
        {todo.title}
      </span>
      <button
        type="button"
        onClick={() => deleteMutation.mutate()}
        disabled={isBusy}
        aria-label={`${todo.title} 삭제`}
        className="rounded-md border border-red-200 bg-white px-2 py-1 text-xs font-medium text-red-600 transition hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 sm:px-3 sm:text-sm"
      >
        삭제
      </button>
    </li>
  );
}
