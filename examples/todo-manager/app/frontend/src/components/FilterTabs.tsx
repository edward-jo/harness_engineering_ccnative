// 필터 탭 컴포넌트 (전체/진행중/완료)
// - 현재 status 값에 따라 활성 탭을 표시한다
// - 클릭 시 부모 setStatus를 호출하고, 부모는 URL과 동기화한다
import type { TodoStatus } from '../api/todos';

interface FilterTabsProps {
  value: TodoStatus;
  onChange: (next: TodoStatus) => void;
}

interface TabOption {
  key: TodoStatus;
  label: string;
}

// 탭 목록 정의 (순서가 UI에 반영됨)
const TABS: TabOption[] = [
  { key: 'all', label: '전체' },
  { key: 'active', label: '진행중' },
  { key: 'completed', label: '완료' },
];

export default function FilterTabs({ value, onChange }: FilterTabsProps) {
  return (
    <div
      role="tablist"
      aria-label="할일 필터"
      className="flex items-center gap-1 rounded-md border border-gray-200 bg-white p-1 shadow-sm"
    >
      {TABS.map((tab) => {
        const isActive = value === tab.key;
        return (
          <button
            key={tab.key}
            type="button"
            role="tab"
            aria-selected={isActive}
            onClick={() => onChange(tab.key)}
            className={`flex-1 rounded px-3 py-1.5 text-sm font-medium transition ${
              isActive
                ? 'bg-blue-600 text-white shadow-sm'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            {tab.label}
          </button>
        );
      })}
    </div>
  );
}
