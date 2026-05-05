# Next.js Pages Router: Auth — NextAuth.js v4

```typescript
// src/pages/api/auth/[...nextauth].ts
import NextAuth from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'

export default NextAuth({
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email:     { label: 'Email',     type: 'email' },
        password:  { label: 'Password',  type: 'password' },
        user_type: { label: 'User Type', type: 'text' },
      },
      async authorize(credentials) {
        const userType = credentials?.user_type ?? 'staff'
        const res = await fetch(
          `${process.env.DJANGO_API_URL}/api/v1/auth/${userType}/login/`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              email: credentials?.email,
              password: credentials?.password,
            }),
          }
        )
        if (!res.ok) return null
        const data = await res.json()
        if (!data.success) return null
        return {
          id:           data.data.user.id,
          email:        data.data.user.email,
          name:         data.data.user.full_name,
          user_type:    userType,
          access_token: data.data.access,
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.user_type    = (user as any).user_type
        token.access_token = (user as any).access_token
      }
      return token
    },
    async session({ session, token }) {
      session.user.user_type = token.user_type as string
      return session
    },
  },
  pages: { signIn: '/login' },
  secret: process.env.AUTH_SECRET,
})
```

---
---

## Reading session server-side — getServerSession

```typescript
// pages/jobs/index.tsx — get session in getServerSideProps
import { getServerSession } from 'next-auth'
import { authOptions } from '../api/auth/[...nextauth]'
import type { GetServerSideProps } from 'next'

export const getServerSideProps: GetServerSideProps = async (ctx) => {
  const session = await getServerSession(ctx.req, ctx.res, authOptions)

  if (!session) {
    return { redirect: { destination: '/login', permanent: false } }
  }

  // Use session.user fields set in callbacks above
  return { props: { userType: session.user.user_type } }
}
```

## Reading session client-side — useSession

```tsx
// components/Navbar.tsx
'use client is NOT needed in Pages Router — all components are client-side'
import { useSession, signOut } from 'next-auth/react'

export function Navbar() {
  const { data: session, status } = useSession()
  if (status === 'loading') return <Skeleton />
  if (!session) return null

  return (
    <nav>
      <span>{session.user.name}</span>
      <button onClick={() => signOut({ callbackUrl: '/login' })}>Sign out</button>
    </nav>
  )
}
```

## Export authOptions for reuse across API routes

```typescript
// pages/api/auth/[...nextauth].ts
import NextAuth, { type NextAuthOptions } from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'

// Export authOptions so getServerSession can import it
export const authOptions: NextAuthOptions = {
  providers: [ CredentialsProvider({ /* ...same as above */ }) ],
  callbacks: { /* ...same as above */ },
  pages: { signIn: '/login' },
  secret: process.env.AUTH_SECRET,
}

export default NextAuth(authOptions)
```
