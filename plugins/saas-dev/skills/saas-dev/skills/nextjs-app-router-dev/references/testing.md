# Next.js App Router: Testing

## Setup — Vitest (preferred over Jest for Next.js 15)

```bash
npm install -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom
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
    setupFiles: ['./src/test/setup.ts'],
    globals: true,
    alias: { '@': resolve(__dirname, 'src') },
  },
})

// src/test/setup.ts
import '@testing-library/jest-dom'

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter:    () => ({ push: vi.fn(), refresh: vi.fn() }),
  usePathname:  () => '/',
  useSearchParams: () => new URLSearchParams(),
  redirect:     vi.fn(),
}))

// Mock next/headers
vi.mock('next/headers', () => ({
  cookies: () => ({ get: vi.fn(), set: vi.fn(), delete: vi.fn() }),
  headers: () => ({ get: vi.fn() }),
}))
```

---

## Testing Server Components

```typescript
// Server Components are async functions — test by calling them directly
import { render, screen } from '@testing-library/react'
import { JobsPage } from '@/app/(dashboard)/jobs/page'

// Mock the data fetch
vi.mock('@/lib/api', () => ({
  djangoGet: vi.fn().mockResolvedValue({
    results: [
      { id: '1', code: 'JC-0001', status: 'pending', status_display: 'Pending',
        total_amount: '1500', vehicle: 'v1', description: 'Oil change',
        assigned_to: null, completed_at: null, stripe_payment_intent_id: '',
        created_at: new Date().toISOString(), updated_at: new Date().toISOString() }
    ],
    count: 1,
  }),
}))

it('renders job list from server', async () => {
  // Server Component returns a React element — await it
  const jsx = await JobsPage({ searchParams: Promise.resolve({}) })
  render(jsx)
  expect(screen.getByText('JC-0001')).toBeInTheDocument()
})
```

---

## Testing Client Components

```tsx
// components/jobs/CreateJobModal.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { CreateJobModal } from './CreateJobModal'

// Mock the BFF client
vi.mock('@/lib/api-client', () => ({
  apiClient: { post: vi.fn() },
  ApiError: class ApiError extends Error {
    constructor(public status: number, message: string, public errors = {}) {
      super(message)
    }
  },
}))

describe('CreateJobModal', () => {
  it('submits form and calls onSuccess', async () => {
    const { apiClient } = await import('@/lib/api-client')
    vi.mocked(apiClient.post).mockResolvedValue({ success: true })

    const onSuccess = vi.fn()
    render(<CreateJobModal isOpen onClose={() => {}} onSuccess={onSuccess} />)

    await userEvent.type(screen.getByPlaceholderText(/vehicle/i), '550e8400-e29b-41d4-a716-446655440000')
    await userEvent.type(screen.getByPlaceholderText(/description/i), 'Full service and oil change needed')
    await userEvent.type(screen.getByPlaceholderText(/amount/i), '1500')
    await userEvent.click(screen.getByRole('button', { name: /create/i }))

    expect(apiClient.post).toHaveBeenCalledWith('/jobs', expect.objectContaining({
      description: 'Full service and oil change needed',
    }))
    expect(onSuccess).toHaveBeenCalled()
  })

  it('maps server field errors to form fields', async () => {
    const { apiClient, ApiError } = await import('@/lib/api-client')
    vi.mocked(apiClient.post).mockRejectedValue(
      new ApiError(400, 'Validation error', { vehicle: ['Vehicle not found.'] })
    )

    render(<CreateJobModal isOpen onClose={() => {}} onSuccess={() => {}} />)
    await userEvent.type(screen.getByPlaceholderText(/vehicle/i), 'invalid-uuid')
    await userEvent.click(screen.getByRole('button', { name: /create/i }))

    expect(await screen.findByText('Vehicle not found.')).toBeInTheDocument()
  })
})
```

---

## Testing Route Handlers (BFF)

```typescript
// app/api/jobs/route.test.ts
import { GET, POST } from './route'
import { NextRequest } from 'next/server'

// Mock djangoFetch
vi.mock('@/lib/api', () => ({
  djangoFetch: vi.fn(),
}))

describe('GET /api/jobs/', () => {
  it('proxies response from Django', async () => {
    const { djangoFetch } = await import('@/lib/api')
    const mockJobs = { results: [{ id: '1', code: 'JC-0001' }], count: 1 }
    vi.mocked(djangoFetch).mockResolvedValue(
      new Response(JSON.stringify(mockJobs), { status: 200 })
    )

    const req = new NextRequest('http://localhost/api/jobs/')
    const res = await GET(req)
    const data = await res.json()

    expect(res.status).toBe(200)
    expect(data.results).toHaveLength(1)
    expect(data.results[0].code).toBe('JC-0001')
  })

  it('returns 401 when Django rejects token', async () => {
    const { djangoFetch } = await import('@/lib/api')
    vi.mocked(djangoFetch).mockResolvedValue(
      new Response(JSON.stringify({ detail: 'Not authenticated' }), { status: 401 })
    )

    const req = new NextRequest('http://localhost/api/jobs/')
    const res = await GET(req)
    expect(res.status).toBe(401)
  })
})
```

---

## E2E with Playwright (auth flows, critical paths)

```bash
npm install -D @playwright/test
npx playwright install
```

```typescript
// e2e/login.spec.ts
import { test, expect } from '@playwright/test'

test('staff can log in and see jobs', async ({ page }) => {
  await page.goto('/login')
  await page.fill('[name=email]', 'staff@test.com')
  await page.fill('[name=password]', 'testpass123')
  await page.click('button[type=submit]')

  await expect(page).toHaveURL('/dashboard')
  await expect(page.getByText('Job Cards')).toBeVisible()
})

test('unauthenticated user redirected to login', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page).toHaveURL('/login')
})
```
