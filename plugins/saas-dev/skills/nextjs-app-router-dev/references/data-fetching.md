# Next.js App Router: Data Fetching Patterns

## Server Component — direct async fetch (primary pattern)

```typescript
// Fetches on every request — no stale data
const data = await djangoGet('/api/v1/jobs/')

// Revalidate every 60 seconds (for semi-static data)
const data = await fetch(url, { next: { revalidate: 60 } })

// Cache indefinitely until manually revalidated
const data = await fetch(url, { next: { tags: ['jobs'] } })
// Invalidate with: revalidateTag('jobs') in a Server Action or Route Handler
```

---

## Parallel data fetching — don't await sequentially

```typescript
// ✗ Sequential — slow (waterfall)
const jobs     = await djangoGet('/api/v1/jobs/')
const vehicles = await djangoGet('/api/v1/vehicles/')

// ✓ Parallel — both fetch simultaneously
const [jobs, vehicles] = await Promise.all([
  djangoGet('/api/v1/jobs/'),
  djangoGet('/api/v1/vehicles/'),
])
```

---

## Client Component — SWR for interactive data

```tsx
'use client'
import useSWR from 'swr'

const fetcher = (url: string) => fetch(url).then(r => r.json())

export function LiveJobStatus({ jobId }: { jobId: string }) {
  const { data, isLoading, mutate } = useSWR(
    `/api/jobs/${jobId}`,
    fetcher,
    { refreshInterval: 5000 }   // poll every 5s
  )

  if (isLoading) return <Skeleton />
  return (
    <div>
      <StatusBadge status={data?.status} label={data?.status_display} />
      <button onClick={() => mutate()}>Refresh</button>
    </div>
  )
}
```

---

## Streaming with Suspense (progressive page load)

```tsx
// app/(dashboard)/jobs/page.tsx
import { Suspense } from 'react'
import { TableSkeleton } from '@/components/shared'

// Wrap slow data in Suspense — rest of page loads immediately
export default function JobsPage() {
  return (
    <div className="p-6">
      <h1>Job Cards</h1>
      <Suspense fallback={<TableSkeleton rows={6} cols={5} />}>
        <JobList />   {/* async Server Component — loads independently */}
      </Suspense>
    </div>
  )
}

async function JobList() {
  const jobs = await djangoGet('/api/v1/jobs/')   // fetches while above renders
  return <JobTable jobs={jobs.results} />
}
```
