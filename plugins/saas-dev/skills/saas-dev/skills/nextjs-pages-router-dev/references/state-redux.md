# Next.js Pages Router: Redux + RTK Query (BFF-aware)

## store/api.ts — RTK Query base URL is /api (BFF, not Django)

```typescript
// src/store/api.ts
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react'

export const api = createApi({
  reducerPath: 'api',
  // ← /api not DJANGO_API_URL — all requests go through Next.js BFF
  baseQuery: fetchBaseQuery({
    baseUrl: '/api',
    credentials: 'include',   // send cookies
  }),
  tagTypes: ['Job', 'Vehicle'],
  endpoints: () => ({}),
})
```

## store/features/jobsApi.ts — RTK Query endpoints

```typescript
// src/store/features/jobsApi.ts
import { api } from '../api'
import type { JobCard } from '@/types'

interface JobsResponse { results: JobCard[]; count: number }

export const jobsApi = api.injectEndpoints({
  endpoints: (build) => ({
    getJobs: build.query<JobsResponse, { status?: string }>({
      query: ({ status }) => ({
        url: '/jobs',
        params: status ? { status } : {},
      }),
      providesTags: ['Job'],
    }),

    createJob: build.mutation<JobCard, Partial<JobCard>>({
      query: (body) => ({ url: '/jobs', method: 'POST', body }),
      invalidatesTags: ['Job'],
    }),

    updateJob: build.mutation<JobCard, { id: string } & Partial<JobCard>>({
      query: ({ id, ...body }) => ({ url: `/jobs/${id}`, method: 'PATCH', body }),
      invalidatesTags: ['Job'],
    }),
  }),
})

export const { useGetJobsQuery, useCreateJobMutation, useUpdateJobMutation } = jobsApi
```

## Component using RTK Query

```tsx
// components/jobs/JobsView.tsx
import { useGetJobsQuery, useCreateJobMutation } from '@/store/features/jobsApi'

export function JobsView({ initialJobs }: { initialJobs: JobCard[] }) {
  const [statusFilter, setStatusFilter] = useState('')

  // RTK Query — refreshes from BFF on filter change
  const { data, isLoading } = useGetJobsQuery(
    { status: statusFilter },
    { skip: false }
  )

  const jobs = data?.results ?? initialJobs   // SSR data as fallback

  return <JobTable jobs={jobs} isLoading={isLoading} />
}
```

---