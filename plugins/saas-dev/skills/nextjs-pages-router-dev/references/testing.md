# Next.js Pages Router: Testing

## Setup — Vitest + React Testing Library

```bash
npm install -D vitest @vitejs/plugin-react jsdom \
  @testing-library/react @testing-library/user-event @testing-library/jest-dom
```

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { resolve } from 'path'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles:  ['./src/test/setup.ts'],
    globals:     true,
    alias: { '@': resolve(__dirname, 'src') },
  },
})

// src/test/setup.ts
import '@testing-library/jest-dom'

// Pages Router mocks next/router (not the App Router router package)
vi.mock('next/router', () => ({
  useRouter: vi.fn(() => ({
    push:      vi.fn(),
    replace:   vi.fn(),
    query:     {},
    pathname:  '/',
    asPath:    '/',
    isReady:   true,
  })),
}))

// Mock next/head
vi.mock('next/head', () => ({
  default: ({ children }: any) => children,
}))
```

---

## Testing getServerSideProps

```typescript
// pages/jobs/index.test.ts
import { getServerSideProps } from '@/pages/jobs/index'

describe('getServerSideProps', () => {
  it('redirects unauthenticated users to login', async () => {
    const ctx = {
      req: { cookies: {} },
      res: { setHeader: vi.fn() },
    } as any

    const result = await getServerSideProps(ctx)
    expect(result).toMatchObject({
      redirect: { destination: expect.stringContaining('/login') },
    })
  })

  it('returns job data for authenticated user', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true, status: 200,
      json: () => Promise.resolve({
        results: [{ id: '1', code: 'JC-0001', status: 'pending', status_display: 'Pending',
          total_amount: '1500', vehicle: 'v1', description: 'Oil change',
          assigned_to: null, completed_at: null, stripe_payment_intent_id: '',
          created_at: new Date().toISOString(), updated_at: new Date().toISOString() }],
        count: 1,
      }),
    })

    const ctx = {
      req: { cookies: { access_token: 'valid-token' } },
      res: { setHeader: vi.fn() },
    } as any

    const result = await getServerSideProps(ctx)
    expect(result).toMatchObject({ props: { jobs: expect.arrayContaining([expect.objectContaining({ code: 'JC-0001' })]), count: 1 } })
  })

  it('redirects when Django returns 401', async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 401, json: () => ({}) })
    const ctx = { req: { cookies: { access_token: 'expired' } }, res: {} } as any
    const result = await getServerSideProps(ctx)
    expect(result).toMatchObject({ redirect: { destination: '/login' } })
  })
})
```

---

## Testing BFF API Route Handlers (pages/api/)

```typescript
// pages/api/jobs/index.test.ts
import handler from '@/pages/api/jobs/index'
import { createMocks } from 'node-mocks-http'

// npm install -D node-mocks-http

describe('GET /api/jobs', () => {
  it('proxies Django response to client', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      status: 200,
      json: () => Promise.resolve({ results: [{ id: '1', code: 'JC-0001' }], count: 1 }),
    })

    const { req, res } = createMocks({ method: 'GET', cookies: { access_token: 'tok' } })
    await handler(req as any, res as any)

    expect(res._getStatusCode()).toBe(200)
    const data = JSON.parse(res._getData())
    expect(data.results[0].code).toBe('JC-0001')
  })

  it('forwards Authorization header from cookie to Django', async () => {
    global.fetch = vi.fn().mockResolvedValue({ status: 200, json: () => ({}) })
    const { req, res } = createMocks({ method: 'GET', cookies: { access_token: 'my-token' } })
    await handler(req as any, res as any)

    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: 'Bearer my-token' }),
      })
    )
  })

  it('rejects unsupported HTTP methods', async () => {
    const { req, res } = createMocks({ method: 'PUT' })
    await handler(req as any, res as any)
    expect(res._getStatusCode()).toBe(405)
  })
})
```

---

## Testing RTK Query components

```typescript
// src/test/renderWithStore.tsx
import { configureStore } from '@reduxjs/toolkit'
import { render, type RenderOptions } from '@testing-library/react'
import { Provider } from 'react-redux'
import { api } from '@/store/api'

export function renderWithStore(
  ui: React.ReactElement,
  preloadedState: Record<string, unknown> = {},
  options?: RenderOptions
) {
  const store = configureStore({
    reducer: { api: api.reducer },
    middleware: (getDefault) => getDefault().concat(api.middleware),
    preloadedState,
  })
  return {
    ...render(<Provider store={store}>{ui}</Provider>, options),
    store,
  }
}
```

```tsx
// components/jobs/JobsView.test.tsx
import { renderWithStore } from '@/test/renderWithStore'
import { screen, waitFor } from '@testing-library/react'
import { server } from '@/test/msw-server'   // MSW for API mocking
import { http, HttpResponse } from 'msw'
import { JobsView } from './JobsView'

// npm install -D msw

describe('JobsView', () => {
  it('renders jobs from RTK Query', async () => {
    server.use(
      http.get('/api/jobs', () =>
        HttpResponse.json({ results: [{ id: '1', code: 'JC-0001', status: 'pending',
          status_display: 'Pending', total_amount: '1500', vehicle: 'v1',
          description: 'Oil', assigned_to: null, completed_at: null,
          stripe_payment_intent_id: '', created_at: '', updated_at: '' }], count: 1 })
      )
    )
    renderWithStore(<JobsView initialJobs={[]} totalCount={0} />)
    expect(await screen.findByText('JC-0001')).toBeInTheDocument()
  })

  it('shows empty state when no jobs', () => {
    renderWithStore(<JobsView initialJobs={[]} totalCount={0} />)
    expect(screen.getByText(/no job cards/i)).toBeInTheDocument()
  })
})
```

---

## MSW server setup (mock BFF API for tests)

```typescript
// src/test/msw-server.ts
import { setupServer } from 'msw/node'
export const server = setupServer()

// src/test/setup.ts (add to existing setup)
import { server } from './msw-server'
beforeAll(()  => server.listen({ onUnhandledRequest: 'error' }))
afterEach(()  => server.resetHandlers())
afterAll(()   => server.close())
```

---

## E2E with Playwright

```bash
npm install -D @playwright/test
npx playwright install
```

```typescript
// e2e/auth.spec.ts
import { test, expect } from '@playwright/test'

test('staff can log in', async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name=email]',    'staff@test.com')
  await page.fill('[name=password]', 'testpass123')
  await page.click('button[type=submit]')
  await expect(page).toHaveURL('/dashboard')
})

test('unauthenticated redirected to login', async ({ page }) => {
  await page.goto('/jobs')
  await expect(page).toHaveURL(/.*login/)
})

test('job list renders after login', async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name=email]', 'staff@test.com')
  await page.fill('[name=password]', 'testpass123')
  await page.click('button[type=submit]')
  await page.goto('/jobs')
  await expect(page.getByRole('table')).toBeVisible()
})
```
