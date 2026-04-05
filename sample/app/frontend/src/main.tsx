// React 앱 진입점
// - TanStack Query 클라이언트를 초기화하고 App 컴포넌트를 렌더링한다
import React from 'react';
import ReactDOM from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import App from './App';
import './index.css';

// React Query 기본 클라이언트 설정
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // 네트워크 재요청 최소화 — 같은 쿼리 키는 1분 동안 fresh 상태 유지
      staleTime: 60 * 1000,
      // 창 포커스 시 자동 리페치 비활성화 (사용자 혼란 방지)
      refetchOnWindowFocus: false,
    },
  },
});

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  </React.StrictMode>,
);
