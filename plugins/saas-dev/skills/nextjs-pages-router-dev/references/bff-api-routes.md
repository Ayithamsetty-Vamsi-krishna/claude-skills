# Next.js Pages Router: BFF API Routes

## Pattern — identical to App Router BFF

```typescript
// src/pages/api/jobs/index.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { getCookie } from 'cookies-next'

const DJANGO_API_URL = process.env.DJANGO_API_URL

async function djangoProxy(req: NextApiRequest, res: NextApiResponse) {
  const token = getCookie('access_token', { req, res })
  const url   = `${DJANGO_API_URL}/api/v1/jobs/${req.query.id ?? ''}`

  const djangoRes = await fetch(url, {
    method:  req.method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
    },
    ...(req.body ? { body: JSON.stringify(req.body) } : {}),
  })

  const data = await djangoRes.json().catch(() => null)
  res.status(djangoRes.status).json(data)
}

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === 'GET' || req.method === 'POST') {
    return djangoProxy(req, res)
  }
  res.status(405).json({ message: 'Method not allowed' })
}
```

```bash
npm install cookies-next   # cookie helper for Pages Router API routes
```

---