# Next.js Pages Router: SEO — next/head

```tsx
// Use next/head in every page (not layout — Pages Router has no persistent layouts)
import Head from 'next/head'

export default function JobsPage() {
  return (
    <>
      <Head>
        <title>Job Cards | AutoServe</title>
        <meta name="description" content="Manage vehicle service job cards" />
        <meta property="og:title" content="Job Cards | AutoServe" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </Head>
      <main>...</main>
    </>
  )
}
```

---