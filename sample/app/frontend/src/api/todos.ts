// 할일(Todo) REST API 호출 함수 모음
// - Vite 프록시(`/api` → http://localhost:8000)를 통해 FastAPI 백엔드와 통신한다
import axios from 'axios';

/** 서버가 반환하는 할일 항목 타입 */
export interface Todo {
  id: number;
  title: string;
  completed: boolean;
  created_at: string; // ISO 8601 형식
}

// 공통 Axios 인스턴스 — 모든 요청은 /api 프리픽스를 사용한다
const client = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
});

/** 전체 할일 목록을 최신순으로 조회한다. */
export async function getTodos(): Promise<Todo[]> {
  const response = await client.get<Todo[]>('/todos');
  return response.data;
}

/** 새 할일을 생성한다. */
export async function createTodo(title: string): Promise<Todo> {
  const response = await client.post<Todo>('/todos', { title });
  return response.data;
}

/** 지정 ID의 할일 완료 상태를 반전시킨다. */
export async function toggleTodo(id: number): Promise<Todo> {
  const response = await client.patch<Todo>(`/todos/${id}/toggle`);
  return response.data;
}

/** 지정 ID의 할일을 삭제한다. */
export async function deleteTodo(id: number): Promise<void> {
  await client.delete(`/todos/${id}`);
}
