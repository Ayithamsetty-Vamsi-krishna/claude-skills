# Next.js Pages Router: Auth — Custom httpOnly Cookie

## Pattern (same security as App Router)

```typescript
// src/pages/api/auth/login.ts
import type { NextApiRequest, NextApiResponse } from 'next'
import { setCookie, deleteCookie } from 'cookies-next'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') return res.status(405).end()

  const { email, password, user_type = 'staff' } = req.body
  const djangoRes = await fetch(
    `${process.env.DJANGO_API_URL}/api/v1/auth/${user_type}/login/`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    }
  )

  const data = await djangoRes.json()
  if (!djangoRes.ok || !data.success) {
    return res.status(400).json({
      success: false,
      message: data.message ?? 'Invalid credentials',
      errors: data.errors ?? {},
    })
  }

  const isProd = process.env.NODE_ENV === 'production'

  // Cookie security flags explained:
  //   httpOnly: true — JavaScript cannot read the cookie (XSS protection)
  //   secure: isProd — HTTPS-only in production; allows http://localhost in dev.
  //                    DO NOT hardcode secure:true or the dev server breaks;
  //                    DO NOT hardcode secure:false or production leaks cookies.
  //   sameSite: 'lax' — sent on top-level navigations; blocks CSRF
  //   maxAge in seconds
  setCookie('access_token',  data.data.access,  { req, res, httpOnly: true, secure: isProd, sameSite: 'lax', maxAge: 3600 })
  setCookie('refresh_token', data.data.refresh, { req, res, httpOnly: true, secure: isProd, sameSite: 'lax', maxAge: 604800 })
  setCookie('user_type',     user_type,          { req, res, httpOnly: true, secure: isProd, sameSite: 'lax', maxAge: 604800 })

  return res.status(200).json({ success: true, data: { user: data.data.user } })
}
```

```typescript
// src/pages/api/auth/logout.ts
import { deleteCookie, getCookie } from 'cookies-next'

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  const refresh   = getCookie('refresh_token', { req, res })
  const userType  = getCookie('user_type', { req, res }) ?? 'staff'

  if (refresh) {
    await fetch(`${process.env.DJANGO_API_URL}/api/v1/auth/${userType}/logout/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh }),
    }).catch(() => {})
  }

  deleteCookie('access_token',  { req, res })
  deleteCookie('refresh_token', { req, res })
  deleteCookie('user_type',     { req, res })

  res.status(200).json({ success: true })
}
```

## Reading cookie in getServerSideProps

```typescript
import { getCookie } from 'cookies-next'

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  const token = getCookie('access_token', ctx)
  if (!token) return { redirect: { destination: '/login', permanent: false } }

  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/jobs/`, {
    headers: { Authorization: `Bearer ${token}` },
  })
  const data = await res.json()
  return { props: { jobs: data.results } }
}
```
