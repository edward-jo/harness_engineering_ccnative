// React 앱 진입점
// - TanStack Query 클라이언트를 초기화하고 App 컴포넌트를 렌더링한다
// - 모든 쿼리/뮤테이션의 전역 에러는 CustomEvent('app:toast')로 App.tsx에 전달된다
import React from 'react';
import ReactDOM from 'react-dom/client';
import {
  MutationCache,
  QueryCache,
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query';
import App from './App';
import './index.css';

/** 앱 전역 토스트 이벤트 타입 (App.tsx에서 구독해 useToast로 렌더링) */
export interface AppToastDetail {
  message: string;
  type: 'success' | 'error';
}

function dispatchToast(detail: AppToastDetail) {
  window.dispatchEvent(new CustomEvent<AppToastDetail>('app:toast', { detail }));
}

/** 쿼리/뮤테이션 실패 시 공통 에러 메시지 추출 */
function extractErrorMessage(error: unknown): string {
  if (error && typeof error === 'object' && 'message' in error) {
    const message = (error as { message?: unknown }).message;
    if (typeof message === 'string' && message.length > 0) {
      return `네트워크 오류: ${message}`;
    }
  }
  return '네트워크 오류가 발생했습니다';
}

// React Query 기본 클라이언트 설정
const queryClient = new QueryClient({
  queryCache: new QueryCache({
    onError: (error) => {
      dispatchToast({ message: extractErrorMessage(error), type: 'error' });
    },
  }),
  mutationCache: new MutationCache({
    onError: (error) => {
      dispatchToast({ message: extractErrorMessage(error), type: 'error' });
    },
  }),
  defaultOptions: {
    queries: {
      // 네트워크 재요청 최소화 — 같은 쿼리 키는 1분 동안 fresh 상태 유지
      staleTime: 60 * 1000,
      // 창 포커스 시 자동 리페치 비활성화 (사용자 혼란 방지)
      refetchOnWindowFocus: false,
      // 실패 시 재시도 비활성화 (토스트가 반복되지 않도록)
      retry: false,
    },
    mutations: {
      retry: false,
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
