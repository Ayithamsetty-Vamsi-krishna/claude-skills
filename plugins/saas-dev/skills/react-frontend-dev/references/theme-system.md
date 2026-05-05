# Frontend: Dark/Light Theme System

---

## Setup — CSS variables + Tailwind dark mode

```typescript
// tailwind.config.js
module.exports = {
  darkMode: 'class',   // class-based dark mode (not media query)
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Semantic colors that change between themes
        background: {
          primary: 'var(--bg-primary)',
          secondary: 'var(--bg-secondary)',
        },
        text: {
          primary: 'var(--text-primary)',
          secondary: 'var(--text-secondary)',
        },
      }
    }
  }
}
```

```css
/* src/styles/themes.css */
:root {
  --bg-primary: #ffffff;
  --bg-secondary: #f9fafb;
  --text-primary: #111827;
  --text-secondary: #6b7280;
  --border: #e5e7eb;
  --shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.dark {
  --bg-primary: #111827;
  --bg-secondary: #1f2937;
  --text-primary: #f9fafb;
  --text-secondary: #9ca3af;
  --border: #374151;
  --shadow: 0 1px 3px rgba(0,0,0,0.4);
}
```

---

## Theme context + hook

```typescript
// src/contexts/ThemeContext.tsx
import React, { createContext, useContext, useEffect, useState } from 'react'

type Theme = 'light' | 'dark' | 'system'

interface ThemeContextValue {
  theme: Theme
  resolvedTheme: 'light' | 'dark'
  setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue | null>(null)

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setThemeState] = useState<Theme>(() => {
    return (localStorage.getItem('theme') as Theme) ?? 'system'
  })

  const getSystemTheme = (): 'light' | 'dark' =>
    window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'

  const resolvedTheme = theme === 'system' ? getSystemTheme() : theme

  useEffect(() => {
    const root = document.documentElement
    root.classList.remove('light', 'dark')
    root.classList.add(resolvedTheme)
  }, [resolvedTheme])

  // Listen for system theme changes
  useEffect(() => {
    if (theme !== 'system') return
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const handler = () => {
      document.documentElement.classList.remove('light', 'dark')
      document.documentElement.classList.add(getSystemTheme())
    }
    mq.addEventListener('change', handler)
    return () => mq.removeEventListener('change', handler)
  }, [theme])

  const setTheme = (newTheme: Theme) => {
    localStorage.setItem('theme', newTheme)
    setThemeState(newTheme)
  }

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider')
  return ctx
}
```

---

## Theme toggle component

```tsx
// src/components/shared/ThemeToggle.tsx
import React from 'react'
import { useTheme } from '@/contexts/ThemeContext'
import { Button } from './Button'

export const ThemeToggle = React.memo(() => {
  const { resolvedTheme, setTheme } = useTheme()

  return (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
      aria-label={`Switch to ${resolvedTheme === 'dark' ? 'light' : 'dark'} mode`}
    >
      {resolvedTheme === 'dark' ? '☀️' : '🌙'}
    </Button>
  )
})
ThemeToggle.displayName = 'ThemeToggle'
```

---

## App setup

```tsx
// src/main.tsx
import { ThemeProvider } from './contexts/ThemeContext'
import { RouterProvider } from 'react-router-dom'
import { Provider } from 'react-redux'
import { store } from './app/store'
import { router } from './app/router'

createRoot(document.getElementById('root')!).render(
  <Provider store={store}>
    <ThemeProvider>
      <RouterProvider router={router} />
    </ThemeProvider>
  </Provider>
)
```
