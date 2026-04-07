# Next.js Pages Router: Testing

## Setup — same as App Router (Vitest)

```typescript
// vitest.config.ts — same config, different mock for Pages Router
vi.mock('next/router', () => ({
  useRouter: () => ({ push: vi.fn(), query: {}, pathname: '/' }),
}))

// No need to mock next/headers or next/navigation (App Router specific)
```

## Testing pages with getServerSideProps

```typescript
// Directly test getServerSideProps — no render needed
import { getServerSideProps } from '@/pages/jobs/index'

it('redirects unauthenticated users to login', async () => {
  const ctx = {
    req: { cookies: {} },    // no token
    res: { setHeader: vi.fn() },
  } as any

  const result = await getServerSideProps(ctx)
  expect(result).toMatchObject({
    redirect: { destination: expect.stringContaining('/login') },
  })
})

it('returns jobs for authenticated users', async () => {
  global.fetch = vi.fn().mockResolvedValue({
    ok: true, status: 200,
    json: () => Promise.resolve({ results: [{ id: '1', code: 'JC-0001' }], count: 1 }),
  })

  const ctx = {
    req: { cookies: { access_token: 'valid-token' } },
    res: { setHeader: vi.fn() },
  } as any

  const result = await getServerSideProps(ctx)
  expect(result).toMatchObject({ props: { count: 1 } })
})
```

## Testing RTK Query components

```tsx
// Wrap in Redux Provider for testing
import { configureStore } from '@reduxjs/toolkit'
import { renderWithProviders } from '@/test/utils'  // custom render with store

function renderWithProviders(ui: React.ReactElement, preloadedState = {}) {
  const store = configureStore({
    reducer: { api: api.reducer, ...otherReducers },
    middleware: (getDefault) => getDefault().concat(api.middleware),
    preloadedState,
  })
  return render(<Provider store={store}>{ui}</Provider>)
}
```