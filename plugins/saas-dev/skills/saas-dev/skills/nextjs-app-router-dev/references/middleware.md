# Next.js App Router: Middleware

## middleware.ts — runs on every matched request, before rendering

```typescript
// src/middleware.ts  ← must be at src/ root
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Public routes — no auth required
const PUBLIC_ROUTES = ['/login', '/register', '/api/auth/login', '/api/auth/refresh']

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  // Skip middleware for public routes, static files, Next.js internals
  if (
    PUBLIC_ROUTES.some(r => pathname.startsWith(r)) ||
    pathname.startsWith('/_next') ||
    pathname.startsWith('/favicon')
  ) {
    return NextResponse.next()
  }

  // Check auth cookie
  const accessToken = request.cookies.get('access_token')?.value

  if (!accessToken) {
    // No token — redirect to login
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('callbackUrl', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Token exists — allow through
  // Note: we don't verify the JWT here (too slow for every request)
  // Verification happens in Route Handlers when Django rejects invalid tokens
  return NextResponse.next()
}

export const config = {
  matcher: [
    // Match all routes except static files and Next.js internals
    '/((?!_next/static|_next/image|favicon.ico|public/).*)',
  ],
}
```

---

## Middleware with NextAuth.js v5

```typescript
// src/middleware.ts — simpler with NextAuth
export { auth as middleware } from '@/auth'

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api/auth).*)'],
}
```

---

## Role-based middleware (staff vs customer)

```typescript
// src/middleware.ts — RBAC in middleware
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

const STAFF_ONLY_ROUTES = ['/dashboard', '/jobs', '/settings']
const CUSTOMER_ONLY_ROUTES = ['/portal', '/my-jobs']

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  const accessToken = request.cookies.get('access_token')?.value
  const userType    = request.cookies.get('user_type')?.value   // 'staff' or 'customer'

  if (!accessToken) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Route guard by user type
  if (STAFF_ONLY_ROUTES.some(r => pathname.startsWith(r)) && userType !== 'staff') {
    return NextResponse.redirect(new URL('/portal', request.url))
  }

  if (CUSTOMER_ONLY_ROUTES.some(r => pathname.startsWith(r)) && userType !== 'customer') {
    return NextResponse.redirect(new URL('/dashboard', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/((?!_next|favicon|public|api/auth).*)'],
}
```

---

## Injecting user context into headers (for Server Components)

```typescript
// src/middleware.ts — pass user info to Server Components via headers
export async function middleware(request: NextRequest) {
  const accessToken = request.cookies.get('access_token')?.value
  const userType    = request.cookies.get('user_type')?.value

  if (!accessToken) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  // Clone request headers and add user context
  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-user-type', userType ?? '')
  // Don't set x-access-token in headers — use cookie directly in lib/api.ts

  return NextResponse.next({ request: { headers: requestHeaders } })
}
```

```typescript
// Server Component — read middleware-injected headers
import { headers } from 'next/headers'

export default async function Page() {
  const headersList = await headers()
  const userType = headersList.get('x-user-type')
  ...
}
```
