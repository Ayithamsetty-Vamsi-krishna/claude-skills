# Next.js App Router: Project Setup

## Create Next.js 15 project

```bash
# Interactive setup — answer the prompts as shown below
npx create-next-app@latest frontend

# Prompts:
# ✔ Would you like to use TypeScript?        → Yes
# ✔ Would you like to use ESLint?            → Yes
# ✔ Would you like to use Tailwind CSS?      → Yes
# ✔ Would you like your code inside a `src/` directory? → Yes
# ✔ Would you like to use App Router?        → Yes  ← CRITICAL
# ✔ Would you like to use Turbopack?         → Yes  (faster dev builds)
# ✔ Would you like to customise the import alias? → Yes → @/*

cd frontend
```

---

## next.config.ts — always use TypeScript config

```typescript
// next.config.ts
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // BFF: requests to /api/* are handled by Next.js Route Handlers
  // Django is never called from the browser directly

  // Standalone output for Docker deployment
  output: process.env.NEXT_OUTPUT === 'standalone' ? 'standalone' : undefined,

  // Image domains (add Django media server if serving images)
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: process.env.NEXT_PUBLIC_DJANGO_HOST ?? 'localhost',
      },
    ],
  },

  // Security headers
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ]
  },
}

export default nextConfig
```

---

## tsconfig.json paths (already set up by create-next-app)

```json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

---

## Initial folder structure (src/app/)

```
frontend/src/
├── app/
│   ├── layout.tsx          ← root layout (html, body, fonts, providers)
│   ├── page.tsx            ← home page (Server Component)
│   ├── loading.tsx         ← root loading UI (Suspense fallback)
│   ├── error.tsx           ← root error boundary ('use client')
│   ├── not-found.tsx       ← 404 page
│   ├── (auth)/             ← route group — no segment in URL
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── layout.tsx      ← auth-specific layout (no nav)
│   ├── (dashboard)/        ← protected route group
│   │   ├── layout.tsx      ← dashboard layout (nav, sidebar)
│   │   ├── jobs/
│   │   │   ├── page.tsx    ← job list (Server Component)
│   │   │   ├── [id]/
│   │   │   │   └── page.tsx ← job detail
│   │   │   └── loading.tsx
│   │   └── settings/
│   │       └── page.tsx
│   └── api/                ← BFF Route Handlers (proxy to Django)
│       ├── auth/
│       │   ├── login/route.ts
│       │   ├── logout/route.ts
│       │   └── refresh/route.ts
│       └── jobs/
│           ├── route.ts    ← GET /api/jobs/, POST /api/jobs/
│           └── [id]/
│               └── route.ts ← GET/PATCH/DELETE /api/jobs/[id]/
├── components/
│   ├── shared/             ← reusable UI
│   │   ├── StatusBadge.tsx
│   │   ├── TableSkeleton.tsx
│   │   └── ErrorBanner.tsx
│   └── ui/                 ← shadcn components
├── lib/
│   ├── api.ts             ← server-side fetch utility (BFF → Django)
│   ├── api-client.ts      ← client-side fetch utility (→ BFF)
│   └── utils.ts
├── stores/                 ← Zustand stores (client-side only)
│   └── authStore.ts
└── types/
    └── index.ts
```

---

## Install core dependencies

```bash
# Auth (choose one)
npm install next-auth@beta                          # NextAuth.js v5
# OR: no extra package for custom cookie auth

# State management
npm install zustand

# Data fetching (client-side)
npm install swr

# Forms + validation
npm install react-hook-form @hookform/resolvers zod

# UI components
npx shadcn@latest init
npx shadcn@latest add button input label card table badge

# Utilities
npm install clsx tailwind-merge
```

---

## .env.local (never commit — add to .gitignore)

```
# Django API URL — server-side only (no NEXT_PUBLIC_)
DJANGO_API_URL=http://localhost:8000

# Auth secret (NextAuth or custom cookie encryption)
AUTH_SECRET=generate-with-openssl-rand-base64-32

# Public vars (safe to expose to browser)
NEXT_PUBLIC_APP_NAME=AutoServe

# For standalone Docker output
# NEXT_OUTPUT=standalone
```

---

## .env.example (commit this)

```
DJANGO_API_URL=http://localhost:8000
AUTH_SECRET=
NEXT_PUBLIC_APP_NAME=YourAppName
```
