# Next.js Pages Router: Data Fetching

## getServerSideProps — SSR (auth-required pages)

```typescript
// src/pages/jobs/index.tsx
import type { GetServerSideProps } from 'next'
import { getCookie } from 'cookies-next'

interface Props { jobs: JobCard[]; count: number }

export const getServerSideProps: GetServerSideProps<Props> = async (ctx) => {
  const token = getCookie('access_token', ctx)

  if (!token) {
    return {
      redirect: { destination: `/login?callbackUrl=/jobs`, permanent: false },
    }
  }

  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/jobs/`, {
    headers: { 'Authorization': `Bearer ${token}` },
  })

  if (res.status === 401) {
    return { redirect: { destination: '/login', permanent: false } }
  }

  const data = await res.json()
  return { props: { jobs: data.results, count: data.count } }
}

export default function JobsPage({ jobs, count }: Props) {
  return <JobsView initialJobs={jobs} count={count} />
}
```

## getStaticProps + getStaticPaths — public pages + ISR

```typescript
// pages/blog/[slug].tsx — static generation with ISR
export const getStaticProps: GetStaticProps = async ({ params }) => {
  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/posts/${params?.slug}/`)
  if (!res.ok) return { notFound: true }
  const post = await res.json()
  return {
    props: { post },
    revalidate: 60,  // ISR — regenerate at most every 60 seconds
  }
}

export const getStaticPaths: GetStaticPaths = async () => {
  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/posts/`)
  const { results } = await res.json()
  return {
    paths: results.map((p: { slug: string }) => ({ params: { slug: p.slug } })),
    fallback: 'blocking',  // generate unknown paths on demand
  }
}
```

---

## SWR — client-side data fetching in Pages Router

```typescript
// For data that updates after initial SSR — filter changes, polling, etc.
import useSWR from 'swr'
import { apiClient } from '@/lib/api-client'  // calls Next.js BFF /api/*

const fetcher = (url: string) => apiClient.get(url)

// In a component (receives SSR data as initial fallback)
export function JobsView({ initialJobs }: { initialJobs: JobCard[] }) {
  const [statusFilter, setStatusFilter] = useState('')

  const { data, isLoading } = useSWR(
    statusFilter ? `/jobs?status=${statusFilter}` : '/jobs',
    fetcher,
    {
      fallbackData: { results: initialJobs },  // SSR data shown immediately
      revalidateOnFocus: false,
    }
  )

  return <JobTable jobs={data?.results ?? initialJobs} isLoading={isLoading} />
}
```

---