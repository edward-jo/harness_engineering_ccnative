import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Vite 개발 서버 설정
// - 포트: 5173
// - 프록시: `/api` 요청은 FastAPI 백엔드(localhost:8000)로 전달한다
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
});
