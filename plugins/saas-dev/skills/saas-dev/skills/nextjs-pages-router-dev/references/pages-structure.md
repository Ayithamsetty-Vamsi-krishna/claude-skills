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
