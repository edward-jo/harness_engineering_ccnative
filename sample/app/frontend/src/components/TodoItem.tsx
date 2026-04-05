// 개별 할일 항목 컴포넌트
// - 체크박스로 완료 상태 토글 (취소선 표시)
// - 더블클릭으로 인라인 수정 모드 전환 (Enter 저장 / Escape 취소)
// - 마감일이 오늘 이전이면 빨간색으로 표시
// - 삭제 버튼으로 항목 제거
import { KeyboardEvent, useEffect, useRef, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { deleteTodo, toggleTodo, updateTodo, Todo } from '../api/todos';

interface TodoItemProps {
  todo: Todo;
}

/** YYYY-MM-DD 문자열을 로컬 Date 객체로 변환 (시간대 어긋남 방지) */
function parseLocalDate(value: string): Date {
  const [year, month, day] = value.split('-').map((v) => parseInt(v, 10));
  return new Date(year, (month ?? 1) - 1, day ?? 1);
}

/** 오늘 날짜(로컬 기준, 00:00:00)를 반환 */
function getTodayMidnight(): Date {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

/** 마감일이 오늘보다 이전(지난 날짜)인지 판정 */
function isOverdue(dueDate: string | null): boolean {
  if (!dueDate) return false;
  return parseLocalDate(dueDate) < getTodayMidnight();
}

export default function TodoItem({ todo }: TodoItemProps) {
  const queryClient = useQueryClient();

  // 인라인 수정 모드 상태
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(todo.title);
  const [editDueDate, setEditDueDate] = useState<string>(todo.due_date ?? '');
  const inputRef = useRef<HTMLInputElement>(null);

  // 편집 모드 진입 시 input에 포커스 및 전체 선택
  useEffect(() => {
    if (isEditing) {
      inputRef.current?.focus();
      inputRef.current?.select();
    }
  }, [isEditing]);

  // 외부(부모)에서 todo가 바뀌면 편집 버퍼 동기화
  useEffect(() => {
    setEditTitle(todo.title);
    setEditDueDate(todo.due_date ?? '');
  }, [todo.title, todo.due_date]);

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

  // 수정 뮤테이션 (제목/마감일)
  const updateMutation = useMutation({
    mutationFn: (payload: { title: string; due_date: string | null }) =>
      updateTodo(todo.id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['todos'] });
      setIsEditing(false);
    },
  });

  const isBusy =
    toggleMutation.isPending ||
    deleteMutation.isPending ||
    updateMutation.isPending;

  // 편집 모드 진입
  const handleEnterEdit = () => {
    if (isBusy) return;
    setEditTitle(todo.title);
    setEditDueDate(todo.due_date ?? '');
    setIsEditing(true);
  };

  // 편집 저장
  const handleSave = () => {
    const trimmed = editTitle.trim();
    if (!trimmed) {
      // 빈 제목은 저장 거부 (편집 모드 유지)
      return;
    }
    updateMutation.mutate({
      title: trimmed,
      due_date: editDueDate === '' ? null : editDueDate,
    });
  };

  // 편집 취소
  const handleCancel = () => {
    setEditTitle(todo.title);
    setEditDueDate(todo.due_date ?? '');
    setIsEditing(false);
  };

  // Enter/Escape 키 처리
  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      handleSave();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      handleCancel();
    }
  };

  const overdue = isOverdue(todo.due_date);

  return (
    <li className="flex flex-col gap-2 rounded-md border border-gray-200 bg-white px-3 py-2 shadow-sm sm:px-4 sm:py-3">
      <div className="flex items-center gap-3">
        <input
          type="checkbox"
          checked={todo.completed}
          onChange={() => toggleMutation.mutate()}
          disabled={isBusy}
          aria-label={`${todo.title} 완료 상태 토글`}
          className="h-5 w-5 cursor-pointer rounded border-gray-300 text-blue-600 focus:ring-blue-500 disabled:cursor-not-allowed"
        />

        {isEditing ? (
          <input
            ref={inputRef}
            type="text"
            value={editTitle}
            onChange={(event) => setEditTitle(event.target.value)}
            onKeyDown={handleKeyDown}
            onBlur={handleSave}
            aria-label="할일 제목 수정"
            className="flex-1 rounded-md border border-blue-400 bg-white px-2 py-1 text-sm text-gray-900 shadow-sm focus:border-blue-600 focus:outline-none focus:ring-1 focus:ring-blue-500 sm:text-base"
          />
        ) : (
          <span
            onDoubleClick={handleEnterEdit}
            title="더블클릭하여 수정"
            className={`flex-1 cursor-pointer break-words text-sm sm:text-base ${
              todo.completed ? 'text-gray-400 line-through' : 'text-gray-900'
            }`}
          >
            {todo.title}
          </span>
        )}

        <button
          type="button"
          onClick={() => deleteMutation.mutate()}
          disabled={isBusy}
          aria-label={`${todo.title} 삭제`}
          className="rounded-md border border-red-200 bg-white px-2 py-1 text-xs font-medium text-red-600 transition hover:bg-red-50 disabled:cursor-not-allowed disabled:opacity-50 sm:px-3 sm:text-sm"
        >
          삭제
        </button>
      </div>

      {/* 마감일 표시/편집 영역 */}
      {isEditing ? (
        <div className="flex items-center gap-2 pl-8">
          <label className="text-xs text-gray-500 sm:text-sm" htmlFor={`due-${todo.id}`}>
            마감일:
          </label>
          <input
            id={`due-${todo.id}`}
            type="date"
            value={editDueDate}
            onChange={(event) => setEditDueDate(event.target.value)}
            onKeyDown={handleKeyDown}
            className="rounded-md border border-gray-300 bg-white px-2 py-1 text-xs text-gray-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500 sm:text-sm"
          />
          {editDueDate && (
            <button
              type="button"
              onClick={() => setEditDueDate('')}
              className="text-xs text-gray-500 underline hover:text-gray-700"
            >
              지우기
            </button>
          )}
        </div>
      ) : (
        todo.due_date && (
          <div className="pl-8">
            <span
              data-testid="due-date"
              className={`text-xs sm:text-sm ${
                overdue && !todo.completed
                  ? 'font-medium text-red-600'
                  : 'text-gray-500'
              }`}
            >
              마감일: {todo.due_date}
            </span>
          </div>
        )
      )}
    </li>
  );
}
