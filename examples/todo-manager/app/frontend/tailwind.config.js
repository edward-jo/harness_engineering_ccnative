/** @type {import('tailwindcss').Config} */
// Tailwind CSS 설정
// - content: JSX/TSX 파일에서 사용된 클래스만 최종 번들에 포함한다
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {},
  },
  plugins: [],
};
