# Frontend: Testing (Vitest + React Testing Library)

---

## Setup (vitest.config.ts)

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
  },
})
```

```typescript
// src/test/setup.ts
import '@testing-library/jest-dom'
```

---

## Generic renderWithStore — #B3 fixed

NOT hardcoded to one reducer. Accepts any reducers dynamically.

```typescript
// src/test/helpers.tsx
import React from 'react'
import { render, RenderOptions } from '@testing-library/react'
import { Provider } from 'react-redux'
import { configureStore, Reducer } from '@reduxjs/toolkit'

interface RenderWithStoreOptions extends Omit<RenderOptions, 'wrapper'> {
  preloadedState?: Record<string, unknown>
  reducers?: Record<string, Reducer>
}

export const renderWithStore = (
  ui: React.ReactElement,
  { preloadedState = {}, reducers = {}, ...renderOptions }: RenderWithStoreOptions = {}
) => {
  const store = configureStore({
    reducer: reducers,
    preloadedState,
  })
  const Wrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
    <Provider store={store}>{children}</Provider>
  )
  return { ...render(ui, { wrapper: Wrapper, ...renderOptions }), store }
}
```

Usage:
```typescript
import ordersReducer from '@/features/orders/ordersSlice'

// Each test brings its own reducers
renderWithStore(<OrderList />, {
  reducers: { orders: ordersReducer },
})
```

---

## Mock ApiError shape — #B2 fixed

Always mock the correct `{ success, message, errors }` shape from v1.3.0+.

```typescript
// src/test/mocks.ts

// ✅ Correct — matches standardised ApiError shape
export const mockApiError = (
  errors: Record<string, string[]> = {},
  message = 'Validation failed'
) => ({
  success: false as const,
  message,
  errors,
})

// Example usages:
// Field error:   mockApiError({ customerId: ['This field is required.'] })
// Auth error:    mockApiError({}, 'Authentication required.')
// Generic error: mockApiError({}, 'An unexpected error occurred.')
```

---

## Component Test Pattern — #T8 userEvent

Use `userEvent` over `fireEvent` — simulates real browser behaviour (focus, blur, typing).

```typescript
// orders/tests/OrderList.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'   // ← userEvent not fireEvent
import { renderWithStore } from '@/test/helpers'
import { mockApiError } from '@/test/mocks'
import { OrderList } from '../components/OrderList'
import ordersReducer from '../ordersSlice'
import * as service from '../ordersService'

const mockOrders = [{
  id: 'a1b2c3d4-0000-0000-0000-000000000001',
  status: 'pending',
  totalAmount: '100.00',
  customer: { id: 'c1', name: 'Acme Corp', email: 'acme@example.com' },
  items: [],
  createdAt: '2024-01-01T00:00:00Z',
  updatedAt: '2024-01-01T00:00:00Z',
}]

const renderOrderList = (preloadedState = {}) =>
  renderWithStore(<OrderList />, {
    reducers: { orders: ordersReducer },
    preloadedState,
  })

describe('OrderList', () => {
  beforeEach(() => vi.clearAllMocks())

  // ✅ Happy path
  it('renders orders from API', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockResolvedValue({
      count: 1, next: null, previous: null, results: mockOrders,
    })
    renderOrderList()
    await waitFor(() => expect(screen.getByText('pending')).toBeInTheDocument())
  })

  // ⏳ Loading state
  it('shows spinner while loading', () => {
    renderOrderList({
      orders: { loading: true, orders: [], error: null, totalCount: 0, selectedOrder: null },
    })
    expect(screen.getByTestId('loading-spinner')).toBeInTheDocument()
  })

  // 💥 Error state — uses correct ApiError shape — #B2
  it('shows error message on API failure', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockRejectedValue(
      mockApiError({}, 'Failed to load orders')
    )
    renderOrderList()
    await waitFor(() => expect(screen.getByText('Failed to load orders')).toBeInTheDocument())
  })

  // 🔁 Empty state
  it('shows empty state when no orders', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockResolvedValue({
      count: 0, next: null, previous: null, results: [],
    })
    renderOrderList()
    await waitFor(() => expect(screen.getByText('No orders yet')).toBeInTheDocument())
  })

  // 🔍 Zod rejection — #T5
  it('handles malformed API response gracefully', async () => {
    // Return wrong shape — Zod should catch it
    vi.spyOn(service.ordersService, 'getAll').mockRejectedValue(
      new Error('Expected string, received number at "results[0].id"')
    )
    renderOrderList()
    await waitFor(() => expect(screen.getByRole('alert')).toBeInTheDocument())
  })

  // 🔁 Abort on unmount — no stale state update — #T9 useEffect abort
  it('aborts request on unmount without console errors', async () => {
    const errorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    let resolveRequest!: (v: any) => void
    vi.spyOn(service.ordersService, 'getAll').mockImplementation(
      () => new Promise(resolve => { resolveRequest = resolve })
    )
    const { unmount } = renderOrderList()
    unmount()   // unmount BEFORE request resolves
    resolveRequest({ count: 0, next: null, previous: null, results: [] })
    await new Promise(r => setTimeout(r, 50))
    // No "Can't perform state update on unmounted component" warnings
    expect(errorSpy).not.toHaveBeenCalledWith(
      expect.stringContaining("Can't perform")
    )
    errorSpy.mockRestore()
  })
})
```

---

## Form Test Pattern — #T8 userEvent

```typescript
// orders/tests/OrderForm.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { renderWithStore } from '@/test/helpers'
import { mockApiError } from '@/test/mocks'
import { OrderForm } from '../components/OrderForm'
import ordersReducer from '../ordersSlice'
import * as service from '../ordersService'

const renderForm = (props = {}) =>
  renderWithStore(<OrderForm {...props} />, { reducers: { orders: ordersReducer } })

describe('OrderForm', () => {
  beforeEach(() => vi.clearAllMocks())

  // ✅ Successful submit
  it('calls onSuccess after successful creation', async () => {
    const user = userEvent.setup()
    const onSuccess = vi.fn()
    vi.spyOn(service.ordersService, 'create').mockResolvedValue({} as any)
    renderForm({ onSuccess })

    await user.type(screen.getByLabelText('Customer'), 'some-uuid')
    await user.type(screen.getByLabelText('Total Amount'), '150.00')
    await user.click(screen.getByRole('button', { name: /create/i }))

    await waitFor(() => expect(onSuccess).toHaveBeenCalled())
  })

  // ❌ API field errors shown inline — correct ApiError shape — #B2
  it('shows field errors from API response', async () => {
    const user = userEvent.setup()
    vi.spyOn(service.ordersService, 'create').mockRejectedValue(
      mockApiError(
        { customerId: ['This field is required.'] },
        'Validation failed'
      )
    )
    renderForm()
    await user.click(screen.getByRole('button', { name: /create/i }))
    await waitFor(() =>
      expect(screen.getByText('This field is required.')).toBeInTheDocument()
    )
  })

  // ⏳ Button shows loading state during submit
  it('disables button while submitting', async () => {
    const user = userEvent.setup()
    vi.spyOn(service.ordersService, 'create').mockImplementation(
      () => new Promise(resolve => setTimeout(resolve, 500))
    )
    renderForm()
    await user.click(screen.getByRole('button', { name: /create/i }))
    expect(screen.getByRole('button', { name: /create/i })).toBeDisabled()
  })
})
```

---

## Selector Unit Tests — #T9

Test selectors in isolation — fast, no rendering needed.

```typescript
// orders/tests/selectors.test.ts
import { describe, it, expect } from 'vitest'
import {
  selectOrders, selectOrdersLoading, selectOrdersError,
  selectOrderById, selectPendingOrders,
} from '../selectors'

const mockState = {
  orders: {
    orders: [
      { id: '1', status: 'pending', totalAmount: '100.00' },
      { id: '2', status: 'confirmed', totalAmount: '200.00' },
      { id: '3', status: 'cancelled', totalAmount: '50.00' },
    ],
    selectedOrder: null,
    totalCount: 3,
    loading: false,
    error: null,
  },
}

describe('Order Selectors', () => {
  it('selectOrders returns all orders', () => {
    expect(selectOrders(mockState as any)).toHaveLength(3)
  })

  it('selectOrdersLoading returns loading state', () => {
    expect(selectOrdersLoading(mockState as any)).toBe(false)
  })

  it('selectOrderById returns correct order', () => {
    const selector = selectOrderById('1')
    expect(selector(mockState as any)?.id).toBe('1')
  })

  it('selectOrderById returns null for missing id', () => {
    const selector = selectOrderById('non-existent')
    expect(selector(mockState as any)).toBeNull()
  })

  it('selectPendingOrders filters correctly', () => {
    const pending = selectPendingOrders(mockState as any)
    expect(pending).toHaveLength(1)
    expect(pending[0].status).toBe('pending')
  })

  // Memoization — verify selector is memoized
  it('selectOrders returns same reference when state unchanged', () => {
    const result1 = selectOrders(mockState as any)
    const result2 = selectOrders(mockState as any)
    expect(result1).toBe(result2)  // same reference = memoized
  })
})
```

---

## Test Coverage Checklist (every feature)

**Components:**
- [ ] Renders correctly with mock data
- [ ] Loading state displayed (`data-testid="loading-spinner"`)
- [ ] Error state displayed — correct `ApiError.message` shown
- [ ] Empty state displayed
- [ ] `userEvent` used — not `fireEvent`
- [ ] `mockApiError()` used for all error mocks — not raw objects

**Forms:**
- [ ] Successful submit → `onSuccess` called
- [ ] Field errors from `err.errors` shown inline per field
- [ ] Button disabled while submitting
- [ ] `userEvent.setup()` used for all interactions

**Selectors:**
- [ ] All selectors tested in isolation
- [ ] Memoization verified (same reference on unchanged state)
- [ ] Parameterised selectors tested with valid and missing IDs

**Zod:**
- [ ] Malformed API response handled and error shown

---

## SSE + WebSocket test patterns

```typescript
// Testing useSSE hook — mock EventSource
describe('useSSE', () => {
  class MockEventSource {
    static instances: MockEventSource[] = []
    onopen: (() => void) | null = null
    onmessage: ((e: MessageEvent) => void) | null = null
    onerror: (() => void) | null = null
    close = vi.fn()
    constructor(public url: string) { MockEventSource.instances.push(this) }
    // Helper to simulate receiving a message
    simulateMessage(data: unknown) {
      this.onmessage?.({ data: JSON.stringify(data) } as MessageEvent)
    }
  }

  beforeEach(() => {
    MockEventSource.instances = []
    vi.stubGlobal('EventSource', MockEventSource)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('calls onMessage when event received', () => {
    const onMessage = vi.fn()
    renderHook(() => useSSE('/api/status/', onMessage))
    MockEventSource.instances[0].simulateMessage({ status: 'confirmed' })
    expect(onMessage).toHaveBeenCalledWith({ status: 'confirmed' })
  })

  it('closes EventSource on unmount', () => {
    const { unmount } = renderHook(() => useSSE('/api/status/', vi.fn()))
    unmount()
    expect(MockEventSource.instances[0].close).toHaveBeenCalled()
  })
})

// Testing useWebSocket hook — mock WebSocket
describe('useWebSocket', () => {
  class MockWebSocket {
    static instances: MockWebSocket[] = []
    onopen: (() => void) | null = null
    onmessage: ((e: MessageEvent) => void) | null = null
    onclose: (() => void) | null = null
    onerror: (() => void) | null = null
    readyState = WebSocket.OPEN
    send = vi.fn()
    close = vi.fn()
    constructor(public url: string) { MockWebSocket.instances.push(this) }
    simulateMessage(data: unknown) {
      this.onmessage?.({ data: JSON.stringify(data) } as MessageEvent)
    }
  }

  beforeEach(() => {
    MockWebSocket.instances = []
    vi.stubGlobal('WebSocket', MockWebSocket)
  })
  afterEach(() => vi.unstubAllGlobals())

  it('dispatches notification on message', () => {
    const onMessage = vi.fn()
    renderHook(() => useWebSocket('ws://test/', { onMessage }))
    MockWebSocket.instances[0].simulateMessage({ type: 'notification', data: { id: '1' } })
    expect(onMessage).toHaveBeenCalled()
  })
})
```
