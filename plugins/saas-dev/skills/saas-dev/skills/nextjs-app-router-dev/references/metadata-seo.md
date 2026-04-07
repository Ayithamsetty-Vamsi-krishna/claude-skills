# Next.js App Router: Metadata + SEO

## Static metadata

```typescript
// app/layout.tsx or any page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    template: '%s | AutoServe',
    default:  'AutoServe — Vehicle Service Management',
  },
  description: 'Manage vehicle service jobs, track status, and handle payments.',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'),
  openGraph: {
    type:        'website',
    siteName:    'AutoServe',
    description: 'Vehicle Service Management SaaS',
  },
}
```

---

## Dynamic metadata (per page)

```typescript
// app/(dashboard)/jobs/[id]/page.tsx
import type { Metadata } from 'next'
import { djangoGet } from '@/lib/api'

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params
  const job = await djangoGet<{ code: string; status_display: string }>(`/api/v1/jobs/${id}/`)

  return {
    title: `${job.code} — ${job.status_display}`,
    description: `Job card ${job.code}`,
  }
}
```

---

## next/image — always use this, never bare `<img>`

```tsx
import Image from 'next/image'

// ✓ Correct — automatic optimisation, lazy loading, responsive
<Image
  src={vehicle.photo_url}
  alt={`${vehicle.make} ${vehicle.model_name}`}
  width={400}
  height={300}
  className="rounded-lg object-cover"
/>

// ✗ Wrong — no optimisation, causes CLS, fails Lighthouse
<img src={vehicle.photo_url} alt="..." />
```

---

## next/font — eliminate CLS from web fonts

```typescript
// app/layout.tsx
import { Inter } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```

---

## robots.txt + sitemap.ts (auto-generated)

```typescript
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: { userAgent: '*', allow: '/', disallow: ['/dashboard/', '/portal/'] },
    sitemap: `${process.env.NEXT_PUBLIC_APP_URL}/sitemap.xml`,
  }
}

// app/sitemap.ts
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: `${process.env.NEXT_PUBLIC_APP_URL}`, lastModified: new Date() },
    { url: `${process.env.NEXT_PUBLIC_APP_URL}/login`, lastModified: new Date() },
  ]
}
```
