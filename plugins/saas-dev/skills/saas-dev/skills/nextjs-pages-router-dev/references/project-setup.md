# Next.js Pages Router: Project Setup

## Create project (Pages Router)

```bash
npx create-next-app@latest frontend
# ✔ TypeScript?       → Yes
# ✔ ESLint?           → Yes
# ✔ Tailwind CSS?     → Yes
# ✔ src/ directory?   → Yes
# ✔ App Router?       → No  ← CRITICAL — choose No for Pages Router
# ✔ Import alias?     → Yes → @/*
cd frontend

# Install dependencies
npm install @reduxjs/toolkit react-redux
npm install react-hook-form @hookform/resolvers zod
npm install swr
npm install next-auth          # NextAuth.js v4 for Pages Router
npm install clsx tailwind-merge
npx shadcn@latest init
```

---

## Pages Router folder structure

```
src/
├── pages/
│   ├── _app.tsx           ← Redux Provider, SessionProvider, global layout
│   ├── _document.tsx      ← custom <html>, <head>, <body> attributes
│   ├── index.tsx          ← / redirect to /dashboard
│   ├── login.tsx          ← /login
│   ├── dashboard.tsx      ← /dashboard (protected)
│   ├── jobs/
│   │   ├── index.tsx      ← /jobs list
│   │   └── [id].tsx       ← /jobs/[id] detail
│   └── api/               ← BFF Route Handlers
│       ├── auth/
│       │   ├── [...nextauth].ts  ← NextAuth handler
│       │   ├── login.ts
│       │   └── logout.ts
│       ├── jobs/
│       │   ├── index.ts   ← GET /api/jobs, POST /api/jobs
│       │   └── [id].ts    ← GET/PATCH/DELETE /api/jobs/[id]
│       └── vehicles/
│           └── index.ts
├── components/
│   └── shared/
├── store/
│   ├── index.ts
│   ├── api.ts             ← RTK Query base (baseUrl: '/api')
│   └── features/
│       └── jobsSlice.ts
└── types/
    └── index.ts
```

---

## _app.tsx — Redux Provider wraps everything

```tsx
// src/pages/_app.tsx
import type { AppProps } from 'next/app'
import { Provider } from 'react-redux'
import { SessionProvider } from 'next-auth/react'   // only if NextAuth
import { store } from '@/store'
import '@/styles/globals.css'

export default function App({ Component, pageProps: { session, ...pageProps } }: AppProps) {
  return (
    <SessionProvider session={session}>
      <Provider store={store}>
        <Component {...pageProps} />
      </Provider>
    </SessionProvider>
  )
}
```

---

## .env.local

```
DJANGO_API_URL=http://localhost:8000
AUTH_SECRET=your-nextauth-secret
NEXTAUTH_URL=http://localhost:3000
NEXT_PUBLIC_APP_NAME=AutoServe
```
