// 앱 최상위 컴포넌트
// - 반응형 컨테이너 레이아웃을 정의한다 (모바일 375px, 데스크톱 1280px 대응)
import TodoForm from './components/TodoForm';
import TodoList from './components/TodoList';

export default function App() {
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

        <section>
          <TodoList />
        </section>
      </div>
    </div>
  );
}
