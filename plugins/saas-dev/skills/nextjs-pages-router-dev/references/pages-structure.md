# Next.js Pages Router: File Structure

## Pages routing — file = URL

```
src/pages/
├── _app.tsx           ← wraps all pages (Redux, SessionProvider)
├── _document.tsx      ← custom html/body attributes, lang
├── index.tsx          ← / → redirect
├── login.tsx          ← /login
├── dashboard.tsx      ← /dashboard
├── jobs/
│   ├── index.tsx      ← /jobs
│   └── [id].tsx       ← /jobs/abc-123 (dynamic route)
└── api/               ← BFF handlers (pages/api/)
    ├── auth/
    │   ├── [...nextauth].ts
    │   ├── login.ts
    │   └── logout.ts
    └── jobs/
        ├── index.ts   ← /api/jobs
        └── [id].ts    ← /api/jobs/[id]
```

## Persistent layout pattern (no layout.tsx in Pages Router)

```tsx
// components/layouts/DashboardLayout.tsx
export function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen">
      <Sidebar />
      <main className="flex-1 overflow-auto p-6">{children}</main>
    </div>
  )
}

// pages/jobs/index.tsx — attach layout to page
import { DashboardLayout } from '@/components/layouts/DashboardLayout'
import type { NextPageWithLayout } from '@/types'

const JobsPage: NextPageWithLayout = () => <JobsView />
JobsPage.getLayout = (page) => <DashboardLayout>{page}</DashboardLayout>
export default JobsPage

// pages/_app.tsx — honour getLayout
export default function App({ Component, pageProps }: AppProps) {
  const getLayout = (Component as any).getLayout ?? ((page: React.ReactNode) => page)
  return <Provider store={store}>{getLayout(<Component {...pageProps} />)}</Provider>
}
```

---

## Centralised auth guard (Pages Router middleware equivalent)

Pages Router has no `middleware.ts` in the App Router sense.
Use `getServerSideProps` per page OR a shared `withAuth` HOC:

```typescript
// src/lib/withAuth.ts — Higher-Order Component for auth protection
import type { GetServerSidePropsContext, GetServerSidePropsResult } from 'next'
import { getCookie } from 'cookies-next'

type GSPHandler<T> = (
  ctx: GetServerSidePropsContext,
  token: string
) => Promise<GetServerSidePropsResult<T>>

export function withAuth<T extends Record<string, unknown>>(
  handler: GSPHandler<T>,
  redirectTo = '/login'
) {
  return async (ctx: GetServerSidePropsContext): Promise<GetServerSidePropsResult<T>> => {
    const token = getCookie('access_token', ctx) as string | undefined

    if (!token) {
      return {
        redirect: {
          destination: `${redirectTo}?callbackUrl=${ctx.resolvedUrl}`,
          permanent: false,
        },
      }
    }

    return handler(ctx, token)
  }
}

// Usage — replaces repeating the auth check in every getServerSideProps:
export const getServerSideProps = withAuth(async (ctx, token) => {
  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/jobs/`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  const data = await res.json()
  return { props: { jobs: data.results, count: data.count } }
})
```
