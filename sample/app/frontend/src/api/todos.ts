// 할일(Todo) REST API 호출 함수 모음
// - Vite 프록시(`/api` → http://localhost:8000)를 통해 FastAPI 백엔드와 통신한다
import axios from 'axios';

/** 필터 상태 타입 (URL 쿼리 파라미터와 1:1 매핑) */
export type TodoStatus = 'all' | 'active' | 'completed';

/** 우선순위 타입 (AI 추천 또는 수동 설정) */
export type Priority = 'high' | 'medium' | 'low';

/** 카테고리 타입 (AI 분류) */
export type Category =
  | '업무'
  | '개인'
  | '쇼핑'
  | '건강'
  | '학습'
  | '여가'
  | '가사'
  | '기타';

/** 서버가 반환하는 할일 항목 타입 */
export interface Todo {
  id: number;
  title: string;
  completed: boolean;
  created_at: string; // ISO 8601 형식
  due_date: string | null; // YYYY-MM-DD (ISO 8601 date) 또는 null
  category: string; // AI가 분류한 카테고리 (8종 중 하나, 확장 대비 string)
  priority: Priority; // AI가 추천한 우선순위
}

/** 수정 요청 본문 타입 (필드는 선택적) */
export interface TodoUpdatePayload {
  title?: string;
  due_date?: string | null;
  category?: string;
  priority?: Priority;
}

// 공통 Axios 인스턴스 — 모든 요청은 /api 프리픽스를 사용한다
const client = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

/** 할일 목록을 조회한다. status 파라미터로 서버 필터링 가능. */
export async function getTodos(status: TodoStatus = 'all'): Promise<Todo[]> {
  const params = status === 'all' ? undefined : { status };
  const response = await client.get<Todo[]>('/todos', { params });
  return response.data;
}

/** 새 할일을 생성한다. (마감일은 선택) */
export async function createTodo(
  title: string,
  dueDate?: string | null,
): Promise<Todo> {
  const payload: { title: string; due_date?: string | null } = { title };
  if (dueDate !== undefined) {
    payload.due_date = dueDate;
  }
  const response = await client.post<Todo>('/todos', payload);
  return response.data;
}

/** 지정 ID의 할일 완료 상태를 반전시킨다. */
export async function toggleTodo(id: number): Promise<Todo> {
  const response = await client.patch<Todo>(`/todos/${id}/toggle`);
  return response.data;
}

/** 지정 ID의 할일 제목/마감일을 수정한다. */
export async function updateTodo(
  id: number,
  payload: TodoUpdatePayload,
): Promise<Todo> {
  const response = await client.put<Todo>(`/todos/${id}`, payload);
  return response.data;
}

/** 지정 ID의 할일을 삭제한다. */
export async function deleteTodo(id: number): Promise<void> {
  await client.delete(`/todos/${id}`);
}

/** 완료된 할일을 전체 삭제한다. 삭제된 개수를 반환한다. */
export async function clearCompleted(): Promise<number> {
  const response = await client.delete<{ deleted: number }>('/todos/completed');
  return response.data.deleted;
}
