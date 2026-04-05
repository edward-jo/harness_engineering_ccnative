// 전역 토스트 알림 상태 관리 훅
// - 단일 토스트를 show/hide 방식으로 관리한다
// - duration 경과 후 자동으로 사라지며 타이머는 재호출 시 리셋된다
import { useCallback, useEffect, useRef, useState } from 'react';

/** 토스트 타입 (success/error로 시각 스타일 구분) */
export type ToastType = 'success' | 'error';

/** 현재 표시 중인 토스트 상태 */
export interface ToastState {
  message: string;
  type: ToastType;
}

interface UseToastResult {
  /** 현재 표시 중인 토스트 (없으면 null) */
  toast: ToastState | null;
  /** 토스트 표시. 기본 duration 3000ms */
  showToast: (message: string, type?: ToastType, duration?: number) => void;
  /** 토스트 즉시 숨기기 */
  hideToast: () => void;
}

export function useToast(): UseToastResult {
  const [toast, setToast] = useState<ToastState | null>(null);
  // 자동 숨김 타이머 ID를 ref에 보관하여 재호출 시 클리어할 수 있게 한다
  const timerRef = useRef<number | null>(null);

  const hideToast = useCallback(() => {
    if (timerRef.current !== null) {
      window.clearTimeout(timerRef.current);
      timerRef.current = null;
    }
    setToast(null);
  }, []);

  const showToast = useCallback(
    (message: string, type: ToastType = 'success', duration = 3000) => {
      // 기존 타이머가 있으면 리셋
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
      }
      setToast({ message, type });
      timerRef.current = window.setTimeout(() => {
        setToast(null);
        timerRef.current = null;
      }, duration);
    },
    [],
  );

  // 언마운트 시 타이머 정리
  useEffect(() => {
    return () => {
      if (timerRef.current !== null) {
        window.clearTimeout(timerRef.current);
      }
    };
  }, []);

  return { toast, showToast, hideToast };
}
