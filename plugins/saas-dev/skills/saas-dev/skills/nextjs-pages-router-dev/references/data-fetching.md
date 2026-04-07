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

## getStaticProps — public pages only

```typescript
export const getStaticProps: GetStaticProps = async () => {
  // Only for public content — no auth
  return { props: { data: ... }, revalidate: 60 }  // ISR
}
```

---