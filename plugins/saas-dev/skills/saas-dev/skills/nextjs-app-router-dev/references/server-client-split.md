# Next.js App Router: Server vs Client Components

## The single most important rule

**Server Component is the DEFAULT.** No directive needed.
Add `'use client'` ONLY when you need:
- React hooks (useState, useEffect, useCallback, etc.)
- Browser APIs (window, document, localStorage, navigator)
- Event handlers (onClick, onChange, onSubmit)
- Third-party client-only libraries (charts, maps, Stripe.js)

If your component just renders data and has no interactivity → Server Component.

---

## Decision flowchart

```
Does this component need...

useState / useEffect / useReducer?
  YES → 'use client'
  NO  ↓

onClick / onChange / form onSubmit?
  YES → 'use client'
  NO  ↓

window / document / localStorage?
  YES → 'use client'
  NO  ↓

A library that says "use client" (Stripe.js, charts, etc.)?
  YES → 'use client'
  NO  ↓

→ Server Component. No directive needed. Fetch data directly with async/await.
```

---

## Server Component (default — no directive)

```tsx
// app/(dashboard)/jobs/page.tsx
// No 'use client' — this is a Server Component by default
// Can be async, can fetch data directly, runs on server

import { djangoGet } from '@/lib/api'
import { JobTable } from './JobTable'       // Client Component
import type { JobCard } from '@/types'

interface JobsPageProps {
  searchParams: Promise<{ status?: string; page?: string }>  // Next.js 15: async
}

export default async function JobsPage({ searchParams }: JobsPageProps) {
  const { status, page } = await searchParams

  // Direct server-side fetch — no useEffect, no loading state
  const jobs = await djangoGet<{ results: JobCard[]; count: number }>(
    '/api/v1/jobs/',
    { status: status ?? '', page: page ?? '1' }
  )

  return (
    <div className="p-6">
      <h1 className="text-2xl font-medium mb-6">Job Cards</h1>
      {/* Pass data DOWN to Client Component — never the other way */}
      <JobTable initialJobs={jobs.results} count={jobs.count} />
    </div>
  )
}
```

---

## Client Component — leaf node pattern

```tsx
// components/jobs/JobTable.tsx
'use client'   // ← needed: has onClick, useState

import React, { useState, useCallback } from 'react'
import type { JobCard } from '@/types'
import { apiClient } from '@/lib/api-client'

interface JobTableProps {
  initialJobs: JobCard[]   // received from Server Component parent
  count: number
}

export const JobTable = React.memo<JobTableProps>(({ initialJobs, count }) => {
  // Client-side state for optimistic updates
  const [jobs, setJobs] = useState(initialJobs)

  const handleStatusUpdate = useCallback(async (id: string, status: string) => {
    try {
      const updated = await apiClient.patch<JobCard>(`/jobs/${id}`, { status })
      setJobs(prev => prev.map(j => j.id === id ? updated : j))
    } catch (err) {
      // handle error
    }
  }, [])

  return (
    <table>
      {jobs.map(job => (
        <tr key={job.id}>
          <td>{job.code}</td>
          <td>
            <button onClick={() => handleStatusUpdate(job.id, 'in_progress')}>
              Start
            </button>
          </td>
        </tr>
      ))}
    </table>
  )
})
JobTable.displayName = 'JobTable'
```

---

## What you CANNOT do — common mistakes

```tsx
// ✗ WRONG: Server Component imported inside Client Component
'use client'
import { ServerDataFetcher } from './ServerDataFetcher'  // breaks the boundary

// ✗ WRONG: async Client Component
'use client'
export default async function MyComponent() { ... }  // async + 'use client' = error

// ✗ WRONG: window access in Server Component (no 'use client')
export default function MyPage() {
  const width = window.innerWidth  // window does not exist on server
}

// ✗ WRONG: useState in Server Component
export default function MyPage() {
  const [count, setCount] = useState(0)  // hooks only work in Client Components
}
```

---

## Passing data across the boundary

```tsx
// Pattern: Server fetches → passes as props → Client renders interactively

// Server Component (parent)
export default async function Page() {
  const data = await djangoGet('/api/v1/jobs/')
  return <InteractiveTable data={data} />   // ← must be serialisable
}

// Client Component (child)
'use client'
export function InteractiveTable({ data }: { data: Job[] }) {
  const [selected, setSelected] = useState<string | null>(null)
  ...
}

// ⚠️ Data passed from Server → Client must be serialisable:
// ✓ strings, numbers, arrays, plain objects, Dates
// ✗ functions, class instances, undefined, Symbols
```

---

## Loading UI (Suspense boundary per route)

```tsx
// app/(dashboard)/jobs/loading.tsx
// Shown automatically while page.tsx is fetching data
export default function JobsLoading() {
  return (
    <div className="p-6">
      <div className="h-8 bg-gray-200 rounded w-48 mb-6 animate-pulse" />
      <div className="space-y-3">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="h-12 bg-gray-200 rounded animate-pulse" />
        ))}
      </div>
    </div>
  )
}
```

---

## Error boundary (must be Client Component)

```tsx
// app/(dashboard)/jobs/error.tsx
'use client'   // ← required for error boundaries
import { useEffect } from 'react'

export default function JobsError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error(error)
  }, [error])

  return (
    <div className="p-6 text-center">
      <p className="text-red-600 mb-4">Failed to load jobs</p>
      <button onClick={reset} className="px-4 py-2 bg-blue-600 text-white rounded-lg">
        Try again
      </button>
    </div>
  )
}
```
