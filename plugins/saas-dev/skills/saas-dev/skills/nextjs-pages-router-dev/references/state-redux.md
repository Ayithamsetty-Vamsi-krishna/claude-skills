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

## store/index.ts — configure Redux store

```typescript
// src/store/index.ts
import { configureStore } from '@reduxjs/toolkit'
import { api } from './api'

export const store = configureStore({
  reducer: {
    [api.reducerPath]: api.reducer,
    // Add other slice reducers here
  },
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware().concat(api.middleware),
})

export type RootState   = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch
```

## Store wiring in _app.tsx — required for Pages Router

```tsx
// src/pages/_app.tsx
import type { AppProps } from 'next/app'
import { Provider } from 'react-redux'
import { store } from '@/store'

export default function App({ Component, pageProps }: AppProps) {
  return (
    // Provider must wrap everything — RTK Query hooks need the store
    <Provider store={store}>
      <Component {...pageProps} />
    </Provider>
  )
}
```

## Typed hooks — always use these, not raw useSelector/useDispatch

```typescript
// src/store/hooks.ts
import { useDispatch, useSelector } from 'react-redux'
import type { RootState, AppDispatch } from '.'

export const useAppDispatch = () => useDispatch<AppDispatch>()
export const useAppSelector = <T>(selector: (s: RootState) => T) => useSelector(selector)
```