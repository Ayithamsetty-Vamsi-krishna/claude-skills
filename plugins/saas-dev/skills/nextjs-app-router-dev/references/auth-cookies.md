# Next.js App Router: Auth — Custom httpOnly Cookie

## When to use this over NextAuth
- You want full control over the auth flow
- No NextAuth dependency
- Simple email/password only (no OAuth providers needed)
- Team is comfortable managing token refresh manually

---

## How it works
```
POST /api/auth/login  (Next.js Route Handler)
        │ receives email + password
        │ calls Django /api/v1/auth/[type]/login/
        │ Django returns { access, refresh, user }
        │ Route Handler sets httpOnly cookies:
        │   access_token  (expires: 60min)
        │   refresh_token (expires: 7 days)
        ▼
All subsequent requests include cookies automatically
        │
        ▼
djangoFetch() in lib/api.ts reads cookie → Authorization header
```

---

## app/api/auth/login/route.ts

```typescript
import { NextRequest, NextResponse } from 'next/server'
import { cookies } from 'next/headers'

const DJANGO_API_URL = process.env.DJANGO_API_URL

export async function POST(request: NextRequest) {
  const { email, password, user_type = 'staff' } = await request.json()

  // Call Django login endpoint
  const res = await fetch(
    `${DJANGO_API_URL}/api/v1/auth/${user_type}/login/`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    }
  )

  const data = await res.json()

  if (!res.ok || !data.success) {
    return NextResponse.json(
      { success: false, message: data.message ?? 'Invalid credentials', errors: data.errors ?? {} },
      { status: 400 }
    )
  }

  // Set httpOnly cookies — never accessible from JavaScript
  const cookieStore = await cookies()
  const isProduction = process.env.NODE_ENV === 'production'

  // Cookie security flags explained:
  //   httpOnly: true      — JavaScript cannot read the cookie (XSS protection)
  //   secure: isProduction — HTTPS-only in production; allows http://localhost in dev.
  //                          DO NOT hardcode secure:true — dev server breaks.
  //                          DO NOT hardcode secure:false — production leaks cookies.
  //   sameSite: 'lax'     — sent on top-level navigations; blocks CSRF
  //   path: '/'           — cookie sent to all paths
  cookieStore.set('access_token', data.data.access, {
    httpOnly: true,
    secure:   isProduction,
    sameSite: 'lax',
    maxAge:   60 * 60,         // 60 minutes
    path:     '/',
  })

  cookieStore.set('refresh_token', data.data.refresh, {
    httpOnly: true,
    secure:   isProduction,
    sameSite: 'lax',
    maxAge:   60 * 60 * 24 * 7,  // 7 days
    path:     '/',
  })

  cookieStore.set('user_type', user_type, {
    httpOnly: true,
    secure:   isProduction,
    sameSite: 'lax',
    maxAge:   60 * 60 * 24 * 7,
    path:     '/',
  })

  // Return safe user data (no tokens)
  return NextResponse.json({
    success: true,
    data: { user: data.data.user },
  })
}
```

---

## app/api/auth/logout/route.ts

```typescript
import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'
import { djangoFetch } from '@/lib/api'

export async function POST() {
  const cookieStore = await cookies()
  const refreshToken = cookieStore.get('refresh_token')?.value

  // Blacklist token in Django
  if (refreshToken) {
    const userType = cookieStore.get('user_type')?.value ?? 'staff'
    await djangoFetch(`/api/v1/auth/${userType}/logout/`, {
      method: 'POST',
      body: JSON.stringify({ refresh: refreshToken }),
    }).catch(() => {})  // fire and forget — clear cookies regardless
  }

  // Clear all auth cookies
  cookieStore.delete('access_token')
  cookieStore.delete('refresh_token')
  cookieStore.delete('user_type')

  return NextResponse.json({ success: true })
}
```

---

## app/api/auth/refresh/route.ts

```typescript
import { NextResponse } from 'next/server'
import { cookies } from 'next/headers'

export async function POST() {
  const cookieStore = await cookies()
  const refreshToken = cookieStore.get('refresh_token')?.value
  const userType     = cookieStore.get('user_type')?.value ?? 'staff'

  if (!refreshToken) {
    return NextResponse.json({ success: false }, { status: 401 })
  }

  const res = await fetch(
    `${process.env.DJANGO_API_URL}/api/v1/auth/${userType}/refresh/`,
    {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ refresh: refreshToken }),
    }
  )

  if (!res.ok) {
    // Refresh token expired — clear all cookies
    cookieStore.delete('access_token')
    cookieStore.delete('refresh_token')
    cookieStore.delete('user_type')
    return NextResponse.json({ success: false }, { status: 401 })
  }

  const data = await res.json()
  const isProduction = process.env.NODE_ENV === 'production'

  cookieStore.set('access_token', data.data.access, {
    httpOnly: true,
    secure:   isProduction,
    sameSite: 'lax',
    maxAge:   60 * 60,
    path:     '/',
  })

  return NextResponse.json({ success: true })
}
```

---

## lib/api.ts — reads cookie for server-side requests

```typescript
// src/lib/api.ts — updated to read cookie
import { cookies } from 'next/headers'

export async function djangoFetch(path: string, options: RequestInit = {}) {
  const cookieStore = await cookies()
  const token = cookieStore.get('access_token')?.value

  return fetch(`${process.env.DJANGO_API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {}),
      ...((options as any).headers ?? {}),
    },
    cache: 'no-store',
  })
}
```

---

## Login form — calls BFF, not Django directly

```tsx
// app/(auth)/login/LoginForm.tsx
'use client'
import { useRouter } from 'next/navigation'
import { useCallback } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { apiClient } from '@/lib/api-client'

const schema = z.object({
  email:    z.string().email(),
  password: z.string().min(1),
})

export function LoginForm() {
  const router = useRouter()
  const { register, handleSubmit, setError, formState: { errors, isSubmitting } }
    = useForm({ resolver: zodResolver(schema) })

  const onSubmit = useCallback(async (data: z.infer<typeof schema>) => {
    try {
      await apiClient.post('/auth/login', { ...data, user_type: 'staff' })
      router.push('/dashboard')
      router.refresh()   // re-run Server Component data fetching
    } catch (err: any) {
      if (err?.errors) {
        Object.entries(err.errors).forEach(([field, msgs]: [string, any]) => {
          setError(field as any, { type: 'server', message: msgs[0] })
        })
      } else {
        setError('root', { message: err?.message ?? 'Login failed' })
      }
    }
  }, [router, setError])

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <input {...register('email')}    type="email"    className="w-full border rounded p-2" />
      {errors.email && <p className="text-red-600 text-xs">{errors.email.message}</p>}
      <input {...register('password')} type="password" className="w-full border rounded p-2" />
      {errors.password && <p className="text-red-600 text-xs">{errors.password.message}</p>}
      {errors.root && <p className="text-red-600 text-sm">{errors.root.message}</p>}
      <button type="submit" disabled={isSubmitting}
        className="w-full bg-blue-600 text-white py-2 rounded disabled:opacity-50">
        {isSubmitting ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  )
}
```
