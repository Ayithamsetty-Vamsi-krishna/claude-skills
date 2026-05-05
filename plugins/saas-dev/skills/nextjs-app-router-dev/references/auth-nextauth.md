# Next.js App Router: Auth — NextAuth.js v4 (Stable) + Django

## Why v4, not v5
NextAuth.js v5 (Auth.js) is still in beta as of 2025. The API changes
between beta versions without warning. Use v4 — it is stable, battle-tested,
and works correctly with both App Router and Pages Router.

## Install

```bash
npm install next-auth    # v4 stable — no @beta tag
```

---

## How it works with App Router

```
User submits login form
        │
        ▼
NextAuth v4 CredentialsProvider
        │  calls Django /api/v1/auth/[type]/login/
        ▼
Django returns { access, refresh, user }
        │
        ▼
NextAuth stores tokens in encrypted JWT cookie
(httpOnly, signed, never in localStorage)
        │
        ▼
getServerSession(authOptions) reads session in Route Handlers + Server Components
getToken(req) reads raw JWT (includes access_token) in Route Handlers
```

---

## app/api/auth/[...nextauth]/route.ts

```typescript
// src/app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth'
import { authOptions } from '@/lib/auth'

const handler = NextAuth(authOptions)
export { handler as GET, handler as POST }
```

---

## lib/auth.ts — authOptions (shared across all files)

```typescript
// src/lib/auth.ts
import type { NextAuthOptions } from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'

const DJANGO_API_URL = process.env.DJANGO_API_URL

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email:     { label: 'Email',     type: 'email' },
        password:  { label: 'Password',  type: 'password' },
        user_type: { label: 'User Type', type: 'text' },
      },
      async authorize(credentials) {
        const userType = (credentials?.user_type as string) ?? 'staff'

        const res = await fetch(
          `${DJANGO_API_URL}/api/v1/auth/${userType}/login/`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email:    credentials?.email,
              password: credentials?.password,
            }),
          }
        )

        if (!res.ok) return null
        const data = await res.json()
        if (!data.success) return null

        return {
          id:            data.data.user.id,
          email:         data.data.user.email,
          name:          data.data.user.full_name,
          user_type:     userType,
          role:          data.data.user.role ?? null,
          access_token:  data.data.access,
          refresh_token: data.data.refresh,
        }
      },
    }),
  ],

  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.user_id       = user.id
        token.user_type     = (user as any).user_type
        token.role          = (user as any).role
        token.access_token  = (user as any).access_token
        token.refresh_token = (user as any).refresh_token
      }
      return token
    },

    async session({ session, token }) {
      session.user.id        = token.user_id as string
      session.user.user_type = token.user_type as string
      session.user.role      = token.role as string | undefined
      // Never expose access_token in session — use getToken() in Route Handlers
      return session
    },
  },

  pages: { signIn: '/login', error: '/login' },
  session: { strategy: 'jwt' },
  secret:  process.env.AUTH_SECRET,
}
```

---

## types/next-auth.d.ts

```typescript
// src/types/next-auth.d.ts
import 'next-auth'
import 'next-auth/jwt'

declare module 'next-auth' {
  interface Session {
    user: { id: string; email: string; name: string; user_type: string; role?: string }
  }
  interface User {
    user_type: string; role?: string; access_token: string; refresh_token: string
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    user_id: string; user_type: string; role?: string
    access_token: string; refresh_token: string
  }
}
```

---

## Getting access_token in Route Handlers — getToken (preferred)

```typescript
// src/app/api/jobs/route.ts
import { getToken } from 'next-auth/jwt'
import { NextRequest, NextResponse } from 'next/server'

export async function GET(request: NextRequest) {
  // getToken reads the raw JWT — includes access_token
  const token = await getToken({ req: request, secret: process.env.AUTH_SECRET! })

  if (!token) {
    return NextResponse.json({ success: false, message: 'Unauthorised' }, { status: 401 })
  }

  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/jobs/`, {
    headers: { 'Authorization': `Bearer ${token.access_token}` },
    cache:   'no-store',
  })

  const data = await res.json()
  return NextResponse.json(data, { status: res.status })
}
```

---

## Getting session in Server Components

```typescript
// src/app/(dashboard)/jobs/page.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'

export default async function JobsPage() {
  const session = await getServerSession(authOptions)
  if (!session) redirect('/login')

  return (
    <div>
      <h1>Welcome {session.user.name}</h1>
    </div>
  )
}
```

---

## SessionProvider in root layout

```tsx
// src/app/layout.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { Providers } from '@/components/Providers'

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions)
  return (
    <html lang="en">
      <body><Providers session={session}>{children}</Providers></body>
    </html>
  )
}

// src/components/Providers.tsx
'use client'
import { SessionProvider } from 'next-auth/react'
import type { Session } from 'next-auth'

export function Providers({ children, session }: { children: React.ReactNode; session: Session | null }) {
  return <SessionProvider session={session}>{children}</SessionProvider>
}
```

---

## useSession in Client Components

```tsx
'use client'
import { useSession, signOut } from 'next-auth/react'

export function Navbar() {
  const { data: session, status } = useSession()
  if (status === 'loading') return <div className="h-12 animate-pulse bg-gray-100" />
  if (!session) return null
  return (
    <nav className="flex items-center justify-between px-6 py-3 border-b">
      <span className="text-sm">{session.user.name} · {session.user.user_type}</span>
      <button onClick={() => signOut({ callbackUrl: '/login' })}
        className="text-sm text-red-600 hover:text-red-800">Sign out</button>
    </nav>
  )
}
```

---

## Login form

```tsx
// src/app/(auth)/login/LoginForm.tsx
'use client'
import { signIn } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { useState, useCallback } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'

const schema = z.object({
  email:    z.string().email(),
  password: z.string().min(1),
})

export function LoginForm({ userType = 'staff' }: { userType?: string }) {
  const router = useRouter()
  const [authError, setAuthError] = useState<string | null>(null)
  const { register, handleSubmit, formState: { errors, isSubmitting } }
    = useForm({ resolver: zodResolver(schema) })

  const onSubmit = useCallback(async (data: z.infer<typeof schema>) => {
    setAuthError(null)
    const result = await signIn('credentials', {
      ...data, user_type: userType, redirect: false,
    })
    if (result?.error) {
      setAuthError('Invalid email or password')
    } else {
      router.push(userType === 'staff' ? '/dashboard' : '/portal')
      router.refresh()
    }
  }, [router, userType])

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <input {...register('email')} type="email" placeholder="Email"
          className="w-full border rounded-lg p-2 text-sm" />
        {errors.email && <p className="text-red-600 text-xs mt-1">{errors.email.message}</p>}
      </div>
      <div>
        <input {...register('password')} type="password" placeholder="Password"
          className="w-full border rounded-lg p-2 text-sm" />
        {errors.password && <p className="text-red-600 text-xs mt-1">{errors.password.message}</p>}
      </div>
      {authError && <p className="text-red-600 text-sm">{authError}</p>}
      <button type="submit" disabled={isSubmitting}
        className="w-full bg-blue-600 text-white py-2 rounded-lg text-sm disabled:opacity-50">
        {isSubmitting ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  )
}
```

---

## middleware.ts — withAuth (NextAuth v4 built-in)

```typescript
// src/middleware.ts
import { withAuth } from 'next-auth/middleware'
import { NextResponse } from 'next/server'

export default withAuth(
  function middleware(req) {
    const token    = req.nextauth.token
    const pathname = req.nextUrl.pathname

    if (pathname.startsWith('/dashboard') && token?.user_type !== 'staff') {
      return NextResponse.redirect(new URL('/portal', req.url))
    }
    if (pathname.startsWith('/portal') && token?.user_type !== 'customer') {
      return NextResponse.redirect(new URL('/dashboard', req.url))
    }
    return NextResponse.next()
  },
  {
    callbacks: {
      authorized: ({ token }) => !!token,
    },
  }
)

export const config = {
  matcher: ['/((?!_next|favicon|public|api/auth).*)'],
}
```
