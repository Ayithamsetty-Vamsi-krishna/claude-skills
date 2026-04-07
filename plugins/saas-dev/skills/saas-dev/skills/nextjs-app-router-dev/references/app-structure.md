# Next.js App Router: File Structure

## Root layout — providers, fonts, global styles

```tsx
// src/app/layout.tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import { Providers } from '@/components/Providers'
import '@/styles/globals.css'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter', display: 'swap' })

export const metadata: Metadata = {
  title: { template: '%s | AutoServe', default: 'AutoServe' },
  description: 'Vehicle Service Management',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans antialiased bg-gray-50">
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

```tsx
// src/components/Providers.tsx
'use client'  // ← Zustand and SWR providers need client boundary
import { SWRConfig } from 'swr'
import { SessionProvider } from 'next-auth/react'  // only if using NextAuth

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <SWRConfig value={{ revalidateOnFocus: false }}>
      {children}
    </SWRConfig>
  )
}
```

---

## Route groups — organise without affecting URL

```
app/
├── (auth)/                ← URL: /login  (group name excluded from URL)
│   ├── layout.tsx         ← minimal layout: no nav, centered card
│   ├── login/
│   │   └── page.tsx
│   └── register/
│       └── page.tsx
│
├── (dashboard)/           ← URL: /dashboard, /jobs, /settings
│   ├── layout.tsx         ← full layout: sidebar + topnav
│   ├── dashboard/
│   │   ├── page.tsx
│   │   └── loading.tsx
│   ├── jobs/
│   │   ├── page.tsx       ← /jobs list
│   │   ├── loading.tsx    ← shown while page.tsx fetches
│   │   ├── error.tsx      ← shown if page.tsx throws (must be 'use client')
│   │   └── [id]/
│   │       ├── page.tsx   ← /jobs/[id] detail
│   │       └── loading.tsx
│   └── settings/
│       └── page.tsx
│
├── (customer)/            ← URL: /portal, /my-jobs
│   ├── layout.tsx
│   └── portal/
│       └── page.tsx
│
├── api/                   ← BFF Route Handlers (never URL-accessible as pages)
│   ├── auth/
│   │   ├── login/route.ts
│   │   ├── logout/route.ts
│   │   └── refresh/route.ts
│   ├── jobs/
│   │   ├── route.ts           ← GET list, POST create
│   │   └── [id]/route.ts      ← GET detail, PATCH, DELETE
│   └── vehicles/
│       ├── route.ts
│       └── [id]/route.ts
│
├── layout.tsx             ← root layout (html, body, fonts, global providers)
├── page.tsx               ← / redirect to /dashboard or /login
├── not-found.tsx          ← global 404
└── error.tsx              ← global error boundary ('use client')
```

---

## Dashboard layout with sidebar

```tsx
// app/(dashboard)/layout.tsx
import { auth } from '@/auth'    // or custom cookie reader
import { redirect } from 'next/navigation'
import { Sidebar } from '@/components/shared/Sidebar'
import { Topnav } from '@/components/shared/Topnav'

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const session = await auth()
  if (!session) redirect('/login')

  return (
    <div className="flex h-screen overflow-hidden">
      <Sidebar userType={session.user.user_type} />
      <div className="flex flex-col flex-1 overflow-hidden">
        <Topnav user={session.user} />
        <main className="flex-1 overflow-auto p-6">
          {children}
        </main>
      </div>
    </div>
  )
}
```

---

## Dynamic routes

```
app/jobs/[id]/page.tsx           ← /jobs/abc-123
app/jobs/[id]/edit/page.tsx      ← /jobs/abc-123/edit

// params are async in Next.js 15
export default async function JobDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const job = await djangoGet(`/api/v1/jobs/${id}/`)
  return <JobDetail job={job} />
}
```

---

## Special files summary

| File | Purpose |
|---|---|
| `layout.tsx` | Shared UI wrapper. Persists across navigations. |
| `page.tsx` | Route endpoint. Only this file makes the route public. |
| `loading.tsx` | Skeleton shown while page.tsx fetches (automatic Suspense). |
| `error.tsx` | Error boundary for the route. Must have `'use client'`. |
| `not-found.tsx` | Shown when `notFound()` is called or route not matched. |
| `route.ts` | API Route Handler (BFF). No UI — returns Response. |
| `middleware.ts` | Runs before every matched request. Auth guard lives here. |
