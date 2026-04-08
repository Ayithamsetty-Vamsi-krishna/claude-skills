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

## _document.tsx — global HTML attributes + font preloads

```tsx
// src/pages/_document.tsx
// Only rendered on server — customise <html>, <head>, <body>
import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {
  return (
    <Html lang="en">
      <Head>
        {/* Global meta tags that apply to every page */}
        <meta charSet="utf-8" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <body className="antialiased">
        <Main />
        <NextScript />
      </body>
    </Html>
  )
}
```

---

## next/image and next/font — same as App Router

```tsx
// next/image — always use instead of bare <img>
import Image from 'next/image'
<Image src={url} alt="..." width={400} height={300} className="rounded-lg" />

// next/font — in _app.tsx to apply globally
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })

export default function App({ Component, pageProps }: AppProps) {
  return (
    <main className={inter.variable}>
      <Component {...pageProps} />
    </main>
  )
}
```

---