// 앱 최상위 컴포넌트
// - 반응형 컨테이너 레이아웃을 정의한다 (모바일 375px, 데스크톱 1280px 대응)
// - URL 쿼리 파라미터(?status=...)와 동기화된 필터 상태를 관리한다
// - 완료 항목 존재 시 ClearCompleted 버튼을 노출한다
// - 우선순위 정렬 토글(SortControls)을 제공한다
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import TodoForm from './components/TodoForm';
import TodoList from './components/TodoList';
import FilterTabs from './components/FilterTabs';
import ClearCompleted from './components/ClearCompleted';
import SortControls from './components/SortControls';
import { useStatusFilter } from './hooks/useStatusFilter';
import { getTodos } from './api/todos';

export default function App() {
  const { status, setStatus } = useStatusFilter();

  // 우선순위 정렬 토글 상태 (기본 false → 서버 순서 유지)
  const [sortByPriority, setSortByPriority] = useState(false);

  // 완료 항목 개수 조회 — "완료 삭제" 버튼 노출 여부 판단용
  // (별도 쿼리 키로 캐시하여 필터 전환과 무관하게 유지)
  const { data: completedTodos } = useQuery({
    queryKey: ['todos', 'completed'],
    queryFn: () => getTodos('completed'),
  });
  const completedCount = completedTodos?.length ?? 0;

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="mx-auto w-full max-w-2xl px-4 py-6 sm:px-6 sm:py-10">
        <header className="mb-6 sm:mb-8">
          <h1 className="text-2xl font-bold text-gray-900 sm:text-3xl">
            AI Todo Manager
          </h1>
          <p className="mt-1 text-sm text-gray-500">
            할 일을 추가하고 관리하세요
          </p>
        </header>

        <section className="mb-6 rounded-lg bg-white p-4 shadow-sm sm:p-6">
          <TodoForm />
        </section>

        <section className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="sm:flex-1">
            <FilterTabs value={status} onChange={setStatus} />
          </div>
          <div className="flex items-center gap-2">
            <SortControls
              sortByPriority={sortByPriority}
              onToggle={setSortByPriority}
            />
            {completedCount > 0 && (
              <ClearCompleted count={completedCount} />
            )}
          </div>
        </section>

        <section>
          <TodoList status={status} sortByPriority={sortByPriority} />
        </section>
      </div>
    </div>
  );
}
