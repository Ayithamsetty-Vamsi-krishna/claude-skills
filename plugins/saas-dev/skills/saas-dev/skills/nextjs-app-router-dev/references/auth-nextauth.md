# Next.js App Router: Auth — NextAuth.js v5 + Django

## How it works
```
User submits login form
        │
        ▼
NextAuth.js CredentialsProvider
        │  calls Django /api/v1/auth/staff/login/
        ▼
Django returns { access, refresh, user }
        │
        ▼
NextAuth stores tokens in encrypted session cookie
(httpOnly, secure, sameSite=lax — never in localStorage)
        │
        ▼
middleware.ts reads session on every request
        │
        ▼
Server Components get user via auth() helper
Client Components get user via useSession()
```

---

## Install

```bash
npm install next-auth@beta   # NextAuth.js v5 (Auth.js)
```

---

## auth.ts — central config

```typescript
// src/auth.ts
import NextAuth from 'next-auth'
import Credentials from 'next-auth/providers/credentials'
import type { User } from 'next-auth'

const DJANGO_API_URL = process.env.DJANGO_API_URL

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Credentials({
      name: 'Staff Login',
      credentials: {
        email:     { label: 'Email',    type: 'email' },
        password:  { label: 'Password', type: 'password' },
        user_type: { label: 'Type',     type: 'text' },   // 'staff' or 'customer'
      },
      async authorize(credentials) {
        const userType = credentials?.user_type ?? 'staff'
        const endpoint = `${DJANGO_API_URL}/api/v1/auth/${userType}/login/`

        const res = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email:    credentials?.email,
            password: credentials?.password,
          }),
        })

        if (!res.ok) return null   // invalid credentials

        const data = await res.json()
        if (!data.success) return null

        return {
          id:           data.data.user.id,
          email:        data.data.user.email,
          name:         data.data.user.full_name,
          role:         data.data.user.role,
          user_type:    userType,
          access_token: data.data.access,
          refresh_token: data.data.refresh,
        } as User
      },
    }),
  ],

  callbacks: {
    async jwt({ token, user }) {
      // First login: user object available
      if (user) {
        token.access_token  = (user as any).access_token
        token.refresh_token = (user as any).refresh_token
        token.user_type     = (user as any).user_type
        token.role          = (user as any).role
      }

      // TODO: add token refresh logic here when access_token expires
      return token
    },

    async session({ session, token }) {
      // Expose safe fields to client via useSession()
      session.user.id        = token.sub!
      session.user.user_type = token.user_type as string
      session.user.role      = token.role as string
      // Never expose access_token or refresh_token to client session
      return session
    },
  },

  pages: {
    signIn: '/login',
    error:  '/login',
  },

  session: { strategy: 'jwt' },
  secret: process.env.AUTH_SECRET,
})
```

---

## app/api/auth/[...nextauth]/route.ts — API route handler

```typescript
// app/api/auth/[...nextauth]/route.ts
export { handlers as GET, handlers as POST } from '@/auth'
```

---

## types/next-auth.d.ts — extend session types

```typescript
// types/next-auth.d.ts
import 'next-auth'

declare module 'next-auth' {
  interface Session {
    user: {
      id:        string
      email:     string
      name:      string
      user_type: string
      role?:     string
    }
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    access_token:  string
    refresh_token: string
    user_type:     string
    role?:         string
  }
}
```

---

## Getting the session — Server Components

```typescript
// In Server Components — auth() from '@/auth'
import { auth } from '@/auth'
import { redirect } from 'next/navigation'

export default async function DashboardPage() {
  const session = await auth()
  if (!session) redirect('/login')

  return <div>Welcome {session.user.name}</div>
}
```

---

## Getting the session — Client Components

```tsx
'use client'
import { useSession } from 'next-auth/react'

export function UserAvatar() {
  const { data: session, status } = useSession()
  if (status === 'loading') return <Skeleton />
  if (!session) return null
  return <div>{session.user.name}</div>
}
```

---

## Getting Django access token in BFF Route Handlers

```typescript
// In Route Handlers — need the Django access token to proxy requests
import { auth } from '@/auth'

export async function GET() {
  const session = await auth()
  const token = (session as any)?.access_token   // from JWT callback

  const res = await fetch(`${process.env.DJANGO_API_URL}/api/v1/jobs/`, {
    headers: { 'Authorization': `Bearer ${token}` },
  })
  return Response.json(await res.json())
}
```

---

## Login form (Client Component)

```tsx
// app/(auth)/login/LoginForm.tsx
'use client'
import { signIn } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { useState } from 'react'

export function LoginForm() {
  const router = useRouter()
  const [error, setError] = useState<string | null>(null)

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const form = new FormData(e.currentTarget)

    const result = await signIn('credentials', {
      email:     form.get('email'),
      password:  form.get('password'),
      user_type: 'staff',
      redirect:  false,
    })

    if (result?.error) {
      setError('Invalid email or password')
    } else {
      router.push('/dashboard')
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <input name="email"    type="email"    required className="w-full border rounded p-2" />
      <input name="password" type="password" required className="w-full border rounded p-2" />
      {error && <p className="text-red-600 text-sm">{error}</p>}
      <button type="submit" className="w-full bg-blue-600 text-white py-2 rounded">
        Sign in
      </button>
    </form>
  )
}
```
