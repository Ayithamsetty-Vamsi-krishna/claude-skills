# Frontend: Testing (Vitest + React Testing Library)

## Setup (vitest.config.ts)
```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: { environment: 'jsdom', globals: true,
          setupFiles: ['./src/test/setup.ts'] },
})
```

## Test Helper — renderWithStore
```typescript
// src/test/helpers.tsx
import { render } from '@testing-library/react'
import { Provider } from 'react-redux'
import { configureStore } from '@reduxjs/toolkit'
import ordersReducer from '@/features/orders/ordersSlice'

export const renderWithStore = (ui: React.ReactElement, preloadedState = {}) => {
  const store = configureStore({
    reducer: { orders: ordersReducer },
    preloadedState,
  })
  return { ...render(<Provider store={store}>{ui}</Provider>), store }
}
```

## Component Test Pattern
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { screen, waitFor, fireEvent } from '@testing-library/react'
import { renderWithStore } from '@/test/helpers'
import { OrderList } from '../components/OrderList'
import * as service from '../ordersService'

const mockOrders = [
  { id: '1', status: 'pending', totalAmount: '100.00', customer: { id:'c1', name:'Acme' }, items: [] }
]

describe('OrderList', () => {
  beforeEach(() => vi.clearAllMocks())

  // ✅ Happy path
  it('renders orders', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockResolvedValue({
      count: 1, next: null, previous: null, results: mockOrders })
    renderWithStore(<OrderList />)
    await waitFor(() => expect(screen.getByText('pending')).toBeInTheDocument())
  })

  // 🔁 Empty state
  it('shows empty state when no orders', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockResolvedValue({
      count: 0, next: null, previous: null, results: [] })
    renderWithStore(<OrderList />)
    await waitFor(() => expect(screen.getByText('No orders yet')).toBeInTheDocument())
  })

  // 💥 Error state
  it('shows error on API failure', async () => {
    vi.spyOn(service.ordersService, 'getAll').mockRejectedValue(new Error('Network error'))
    renderWithStore(<OrderList />)
    await waitFor(() => expect(screen.getByText('Network error')).toBeInTheDocument())
  })

  // ⏳ Loading state
  it('shows spinner while loading', () => {
    renderWithStore(<OrderList />, {
      orders: { loading: true, orders: [], error: null, totalCount: 0, selectedOrder: null }
    })
    expect(screen.getByTestId('loading-spinner')).toBeInTheDocument()
  })
})

## Form Test Pattern
describe('OrderForm', () => {
  // ✅ Successful submit
  it('dispatches createOrder and calls onSuccess', async () => {
    const onSuccess = vi.fn()
    vi.spyOn(service.ordersService, 'create').mockResolvedValue(mockOrders[0])
    renderWithStore(<OrderForm onSuccess={onSuccess} />)
    fireEvent.change(screen.getByLabelText('Customer'), { target: { value: 'c1' } })
    fireEvent.submit(screen.getByRole('button', { name: /create/i }))
    await waitFor(() => expect(onSuccess).toHaveBeenCalled())
  })

  // ❌ Validation error from API
  it('shows field errors on API 400', async () => {
    vi.spyOn(service.ordersService, 'create').mockRejectedValue({ customerId: ['Required'] })
    renderWithStore(<OrderForm />)
    fireEvent.submit(screen.getByRole('button', { name: /create/i }))
    await waitFor(() => expect(screen.getByText('Required')).toBeInTheDocument())
  })
})
```

## Test Coverage Checklist (every component)
- [ ] Renders correctly with valid data
- [ ] Loading state displayed
- [ ] Error state displayed
- [ ] Empty state displayed
- [ ] Form: successful submit → store updated
- [ ] Form: API error → field errors shown
- [ ] Form: required validation before submit
