/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  darkMode: 'class',
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', '-apple-system', 'BlinkMacSystemFont', '"SF Pro Text"', 'sans-serif'],
        display: ['"SF Pro Rounded"', '"Plus Jakarta Sans"', '-apple-system', 'sans-serif'],
        mono: ['"JetBrains Mono"', '"SF Mono"', 'Menlo', 'monospace'],
      },
      colors: {
        paper: {
          DEFAULT: '#F7F9FC',
          subtle: '#EDF1F7',
          card: '#FFFFFF',
          dark: '#0E1118',
          'subtle-dark': '#151924',
          'card-dark': '#1A1F2C',
        },
        ink: {
          DEFAULT: '#141E3C',
          muted: '#4B587E',
          subtle: '#6C789B',
          dark: '#F2F5FC',
          'muted-dark': '#A3AFCC',
        },
        tape: {
          red: '#D83125',
          gold: '#EDB123',
          navy: '#1C2A5E',
          dark: '#0F1219',
        },
        pen: {
          DEFAULT: '#254EDB',
          light: '#486DEB',
          dark: '#5E82FF',
        },
      },
    },
  },
  plugins: [],
}
