/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: 'var(--color-primary)',
        },
        "primary-content": 'var(--color-primary-content)',
        "primary-opacity": 'var(--color-primary-opacity)',
        "menu-bg": 'var(--color-menu-bg)',
        "menu-item": 'var(--color-menu-item)',
        "menu-darker": 'var(--color-menu-darker)',
        "menu-border": 'var(--color-menu-border)',
        "menu-divider": 'var(--color-menu-divider)',
        "danger": 'var(--color-danger)',
        "danger-alpha": 'var(--color-danger-alpha)',
        "success": 'var(--color-success)',
        "hud-bg": 'var(--color-hud-bg)',
        "hud-bg-alpha": 'var(--color-hud-bg-alpha)',
        "health-label": 'var(--color-health-label)',
        "health-bar": 'var(--color-health-bar)',
        "armor-bar": 'var(--color-armor-bar)',
        "chat-header": 'var(--color-chat-header)',
        "chat-header-alpha": 'var(--color-chat-header-alpha)',
      },
      screens: {
        "xl": "1920px",
      },
      animation: {
        opacity: "opacity 0.25s ease-in-out",
        appearFromRight: "appearFromRight 300ms ease-in-out",
        appearFromBottom: "appearFromBottom 300ms ease-in-out",
        appearFromLeft: "appearFromLeft 300ms ease-in-out",
        wiggle: "wiggle 1.5s ease-in-out infinite",
        popup: "popup 0.25s ease-in-out",
        shimmer: "shimmer 3s ease-out infinite alternate",
      },
      keyframes: {
        opacity: {
          "0%": { opacity: 0 },
          "100%": { opacity: 1 },
        },
        appearFromRight: {
          "0%": { opacity: 0.3, transform: "translate(15%, 0px);" },
          "100%": { opacity: 1, transform: "translate(0);" },
        },
        appearFromLeft: {
          "0%": { opacity: 0.3, transform: "translate(-15%, 0px);" },
          "100%": { opacity: 1, transform: "translate(0);" },
        },
        appearFromBottom: {
          "0%": { opacity: 0.3, transform: "translate(0, 15%);" },
          "100%": { opacity: 1, transform: "translate(0);" },
        },
        wiggle: {
          "0%, 20%, 80%, 100%": {
            transform: "rotate(0deg)",
          },
          "30%, 60%": {
            transform: "rotate(-2deg)",
          },
          "40%, 70%": {
            transform: "rotate(2deg)",
          },
          "45%": {
            transform: "rotate(-4deg)",
          },
          "55%": {
            transform: "rotate(4deg)",
          },
        },
        popup: {
          "0%": { transform: "scale(0.8)", opacity: 0.8 },
          "50%": { transform: "scale(1.1)", opacity: 1 },
          "100%": { transform: "scale(1)", opacity: 1 },
        },
        shimmer: {
          "0%": { backgroundPosition: "0 50%" },
          "50%": { backgroundPosition: "100% 50%" },
          "100%": { backgroundPosition: "0% 50%" },
        },
      },
    }
  },
  plugins: [
    function ({ addUtilities }) {
      addUtilities({
        '.flex-center': {
          display: 'flex',
          'justify-content': 'center',
          'align-items': 'center',
        },
      }, ['responsive', 'hover']);
    }
  ],
}
