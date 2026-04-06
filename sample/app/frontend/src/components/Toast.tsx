// 토스트 알림 컴포넌트
// - 화면 우측 하단에 고정 위치로 렌더링된다
// - success(초록)/error(빨강) 타입에 따라 색상이 달라진다
// - onClose 클릭 시 즉시 닫기
import type { ToastType } from '../hooks/useToast';

interface ToastProps {
  message: string;
  type: ToastType;
  onClose: () => void;
}

/** 타입별 Tailwind 색상 매핑 */
const TYPE_STYLES: Record<ToastType, string> = {
  success: 'bg-green-600 text-white border-green-700',
  error: 'bg-red-600 text-white border-red-700',
};

export default function Toast({ message, type, onClose }: ToastProps) {
  return (
    <div
      role="alert"
      aria-live="polite"
      data-testid="toast"
      data-toast-type={type}
      className={`fixed bottom-4 right-4 z-50 flex max-w-sm items-start gap-3 rounded-lg border px-4 py-3 shadow-lg ${TYPE_STYLES[type]}`}
    >
      <span className="flex-1 text-sm leading-relaxed">{message}</span>
      <button
        type="button"
        onClick={onClose}
        aria-label="알림 닫기"
        className="shrink-0 rounded text-white/80 hover:text-white focus:outline-none focus:ring-2 focus:ring-white/50"
      >
        ✕
      </button>
    </div>
  );
}
