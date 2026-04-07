# Next.js App Router: BFF Route Handlers (Django Proxy)

## Architecture (ALWAYS this pattern)

```
Browser / Server Component
         │
         ▼
  Next.js Route Handler  ←── reads auth cookie, forwards to Django
  (app/api/**/ route.ts)
         │
         ▼
   Django REST API       ←── receives request from Next.js server, not browser
```

**Why BFF always:**
- Django never needs browser CORS — only allows Next.js server IP
- Auth tokens stay server-side in httpOnly cookies — never in JS memory
- Secrets (Stripe keys, API keys) never reach the browser
- Rate limiting can be applied at the BFF layer
- Can transform/aggregate multiple Django calls into one response

---

## lib/api.ts — server-side fetch utility (BFF → Django)

```typescript
// src/lib/api.ts
// Used ONLY in Route Handlers and Server Components
// Never import this in Client Components

import { cookies } from 'next/headers'

const DJANGO_API_URL = process.env.DJANGO_API_URL   // no NEXT_PUBLIC_ prefix

interface FetchOptions extends RequestInit {
  params?: Record<string, string>
}

export async function djangoFetch(
  path: string,
  options: FetchOptions = {}
): Promise<Response> {
  const { params, ...fetchOptions } = options
  const cookieStore = await cookies()
  const token = cookieStore.get('access_token')?.value

  const url = new URL(path, DJANGO_API_URL)
  if (params) {
    Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))
  }

  return fetch(url.toString(), {
    ...fetchOptions,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      ...fetchOptions.headers,
    },
    // No caching for API data by default — opt-in with { next: { revalidate: 60 } }
    cache: fetchOptions.cache ?? 'no-store',
  })
}

// Typed helper — throws on non-2xx
export async function djangoGet<T>(path: string, params?: Record<string, string>): Promise<T> {
  const res = await djangoFetch(path, { method: 'GET', params })
  if (!res.ok) {
    const error = await res.json().catch(() => ({}))
    throw { status: res.status, ...error }
  }
  return res.json()
}
```

---

## lib/api-client.ts — client-side fetch (Browser → BFF)

```typescript
// src/lib/api-client.ts
// Used ONLY in Client Components ('use client')
// Calls /api/* Route Handlers, never Django directly

const API_BASE = '/api'   // relative URL — calls Next.js BFF

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public errors: Record<string, string[]> = {}
  ) {
    super(message)
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    credentials: 'include',   // send cookies (httpOnly auth cookie)
  })

  const data = await res.json().catch(() => ({}))

  if (!res.ok) {
    throw new ApiError(
      res.status,
      data.message ?? 'Request failed',
      data.errors ?? {}
    )
  }
  return data
}

export const apiClient = {
  get:    <T>(path: string) => request<T>(path),
  post:   <T>(path: string, body: unknown) => request<T>(path, { method: 'POST', body: JSON.stringify(body) }),
  patch:  <T>(path: string, body: unknown) => request<T>(path, { method: 'PATCH', body: JSON.stringify(body) }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
}
```

---

## Route Handler pattern — GET list + POST create

```typescript
// app/api/jobs/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { djangoFetch } from '@/lib/api'

// GET /api/jobs/ — proxies to Django GET /api/v1/jobs/
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url)

  try {
    const res = await djangoFetch('/api/v1/jobs/', {
      params: Object.fromEntries(searchParams),
    })

    const data = await res.json()

    if (!res.ok) {
      return NextResponse.json(data, { status: res.status })
    }

    return NextResponse.json(data)
  } catch (error) {
    return NextResponse.json(
      { success: false, message: 'Failed to fetch jobs', errors: {} },
      { status: 500 }
    )
  }
}

// POST /api/jobs/ — proxies to Django POST /api/v1/jobs/
export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const res = await djangoFetch('/api/v1/jobs/', {
      method: 'POST',
      body: JSON.stringify(body),
    })

    const data = await res.json()
    return NextResponse.json(data, { status: res.status })
  } catch (error) {
    return NextResponse.json(
      { success: false, message: 'Failed to create job', errors: {} },
      { status: 500 }
    )
  }
}
```

---

## Route Handler pattern — GET detail + PATCH + DELETE

```typescript
// app/api/jobs/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { djangoFetch } from '@/lib/api'

type Params = { params: Promise<{ id: string }> }   // Next.js 15: params is async

export async function GET(request: NextRequest, { params }: Params) {
  const { id } = await params
  const res = await djangoFetch(`/api/v1/jobs/${id}/`)
  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}

export async function PATCH(request: NextRequest, { params }: Params) {
  const { id } = await params
  const body = await request.json()
  const res = await djangoFetch(`/api/v1/jobs/${id}/`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}

export async function DELETE(request: NextRequest, { params }: Params) {
  const { id } = await params
  const res = await djangoFetch(`/api/v1/jobs/${id}/`, { method: 'DELETE' })
  if (res.status === 204) {
    return new NextResponse(null, { status: 204 })
  }
  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}
```

---

## Django CORS configuration (BFF architecture)

```python
# settings/base.py — Django only allows Next.js server, not browser

CORS_ALLOWED_ORIGINS = [
    'http://localhost:3000',           # Next.js dev server
    # Production: Next.js server IP or internal Docker network
    # 'http://nextjs:3000',            # Docker internal
    # 'https://yourapp.vercel.app',    # Vercel
]

# Never set CORS_ALLOW_ALL_ORIGINS = True in production
# Browser never calls Django directly — only Next.js server does
CORS_ALLOW_CREDENTIALS = True   # needed for cookie passing if same-domain
```

---

## Error forwarding — always preserve Django error shape

```typescript
// Always forward Django's error response unchanged
// Django returns: { success: false, message: "...", errors: { field: [...] } }
// Next.js BFF must return the SAME shape — client error handling relies on it

const res = await djangoFetch(...)
const data = await res.json()

// ✓ Correct — preserves Django error shape
return NextResponse.json(data, { status: res.status })

// ✗ Wrong — swallows Django's field-level errors
if (!res.ok) return NextResponse.json({ error: 'failed' }, { status: 500 })
```
