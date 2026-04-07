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