// URL 쿼리 파라미터(?status=...)와 동기화되는 필터 상태 훅
// - react-router 미사용: 브라우저 네이티브 URLSearchParams + history API로 처리
// - 뒤로가기/앞으로가기(popstate)를 지원한다
import { useCallback, useEffect, useState } from 'react';
import type { TodoStatus } from '../api/todos';

/** 쿼리 파라미터 값을 TodoStatus로 정규화 (알 수 없는 값은 'all') */
function parseStatus(raw: string | null): TodoStatus {
  if (raw === 'active' || raw === 'completed') {
    return raw;
  }
  return 'all';
}

/** 현재 URL에서 status 파라미터를 읽어 반환 */
function readStatusFromUrl(): TodoStatus {
  if (typeof window === 'undefined') return 'all';
  const params = new URLSearchParams(window.location.search);
  return parseStatus(params.get('status'));
}

/**
 * URL 쿼리 파라미터와 연동된 필터 상태 훅.
 *
 * 반환:
 *   status: 현재 필터 ('all' | 'active' | 'completed')
 *   setStatus: 필터 변경 함수 (URL도 함께 갱신)
 */
export function useStatusFilter(): {
  status: TodoStatus;
  setStatus: (next: TodoStatus) => void;
} {
  const [status, setStatusState] = useState<TodoStatus>(() => readStatusFromUrl());

  // popstate(뒤로가기/앞으로가기) 이벤트 처리
  useEffect(() => {
    const handler = () => {
      setStatusState(readStatusFromUrl());
    };
    window.addEventListener('popstate', handler);
    return () => window.removeEventListener('popstate', handler);
  }, []);

  const setStatus = useCallback((next: TodoStatus) => {
    const params = new URLSearchParams(window.location.search);
    if (next === 'all') {
      params.delete('status');
    } else {
      params.set('status', next);
    }
    const search = params.toString();
    const newUrl =
      window.location.pathname + (search ? `?${search}` : '') + window.location.hash;
    window.history.pushState({}, '', newUrl);
    setStatusState(next);
  }, []);

  return { status, setStatus };
}
