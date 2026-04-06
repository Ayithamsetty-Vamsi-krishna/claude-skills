# Frontend: Component Patterns & Memoization

## Component Rules
- `React.memo` on EVERY component
- `useCallback` on EVERY function passed as prop
- `useMemo` on EVERY expensive derived value
- `displayName` set on all memoized components
- No `any` TypeScript types
- Every component handles: loading state, error state, empty state
- ALWAYS use selectors from `selectors.ts` — never inline `state => state.x.y`
- ALWAYS return `promise.abort()` from data-fetching `useEffect`
- ALWAYS use `ApiError` type in catch blocks — never cast to `Record<string, string[]>`

---

## List Component Pattern — #B5 #B6 fixed

```tsx
import React, { useEffect, useMemo, useCallback } from 'react'
import { useAppDispatch, useAppSelector } from '@/app/hooks'
import { fetchOrders, setSelectedOrder } from '../ordersSlice'
import {
  selectOrders, selectOrdersLoading, selectOrdersError   // ← from selectors.ts, not inline
} from '../selectors'
import {
  DataTable, PageHeader, Button, EmptyState,
  TableSkeleton, ErrorBanner, StatusBadge              // ← TableSkeleton for list pages
} from '@/components/shared'
import type { Order } from '../types'
import type { ApiError } from '@/types'

export const OrderList = React.memo(() => {
  const dispatch = useAppDispatch()

  // ✅ Always from selectors.ts — never inline
  const orders = useAppSelector(selectOrders)
  const loading = useAppSelector(selectOrdersLoading)
  const error = useAppSelector(selectOrdersError)

  useEffect(() => {
    const promise = dispatch(fetchOrders())
    // ✅ Always abort on unmount — prevents stale state updates
    return () => { promise.abort() }
  }, [dispatch])

  const columns = useMemo(() => [
    { key: 'id', header: 'ID', render: (r: Order) => r.id.slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: Order) => <StatusBadge status={r.status} /> },
    { key: 'amount', header: 'Amount', render: (r: Order) => r.totalAmount },
  ], [])

  const handleSelect = useCallback((order: Order) => {
    dispatch(setSelectedOrder(order))
  }, [dispatch])

  if (loading) return <TableSkeleton columns={columns.length} />   // ← TableSkeleton for list/table pages
  if (error) return <ErrorBanner message={error} />

  return (
    <div>
      <PageHeader title="Orders" action={<Button>New Order</Button>} />
      <DataTable
        columns={columns}
        data={orders}
        keyExtractor={r => r.id}
        onRowClick={handleSelect}
        emptyTitle="No orders yet"
        emptyDescription="Create your first order to get started."
      />
    </div>
  )
})
OrderList.displayName = 'OrderList'
```

---

## Form Component Pattern — #B7 fixed

```tsx
import React, { useState, useCallback } from 'react'
import { useAppDispatch } from '@/app/hooks'
import { createOrder } from '../ordersSlice'
import { Button, FormField } from '@/components/shared'
import { useToast } from '@/components/ui/use-toast'
import { isApiError } from '@/types'    // ← type guard for ApiError
import type { CreateOrderPayload } from '../types'

interface Props { onSuccess?: () => void }

export const OrderForm = React.memo<Props>(({ onSuccess }) => {
  const dispatch = useAppDispatch()
  const { toast } = useToast()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const handleSubmit = useCallback(async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setIsSubmitting(true)
    setErrors({})
    const fd = new FormData(e.currentTarget)
    const payload: CreateOrderPayload = {
      customerId: fd.get('customerId') as string,
      status: 'pending',
      totalAmount: fd.get('totalAmount') as string,
      items: [],
    }
    try {
      await dispatch(createOrder(payload)).unwrap()
      toast({ title: 'Order created successfully' })
      onSuccess?.()
    } catch (err: unknown) {
      // ✅ Always use ApiError shape — { success, message, errors }
      if (isApiError(err)) {
        // Map field-level errors to form state
        const fieldErrors: Record<string, string> = {}
        Object.entries(err.errors).forEach(([field, messages]) => {
          fieldErrors[field] = Array.isArray(messages) ? messages[0] : String(messages)
        })
        setErrors(fieldErrors)
        toast({ title: err.message, variant: 'destructive' })
      } else {
        toast({ title: 'An unexpected error occurred', variant: 'destructive' })
      }
    } finally {
      setIsSubmitting(false)
    }
  }, [dispatch, onSuccess, toast])

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <FormField label="Customer" name="customerId" required error={errors.customerId} />
      <FormField label="Total Amount" name="totalAmount" type="number" error={errors.totalAmount} />
      <Button type="submit" loading={isSubmitting}>Create Order</Button>
    </form>
  )
})
OrderForm.displayName = 'OrderForm'
```

---

## Memoization Rules

```tsx
// ✅ Correct
const handleSubmit = useCallback(async () => {
  await dispatch(createOrder(payload))
}, [dispatch, payload])

const sorted = useMemo(
  () => [...orders].sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
  [orders]
)

// ❌ Wrong — creates new function reference every render
<Child onClick={() => dispatch(someAction())} />

// ❌ Wrong — inline selector causes unnecessary re-renders
const orders = useAppSelector(state => state.orders.orders)

// ✅ Correct — memoized selector from selectors.ts
const orders = useAppSelector(selectOrders)
```

---

## Error Boundary (graceful component failure)

```tsx
// src/components/shared/ErrorBoundary.tsx
import React from 'react'
import { ErrorBanner } from './ErrorBanner'

interface Props {
  children: React.ReactNode
  fallback?: React.ReactNode
  onError?: (error: Error, info: React.ErrorInfo) => void
}

interface State { hasError: boolean; error: Error | null }

export class ErrorBoundary extends React.Component<Props, State> {
  state: State = { hasError: false, error: null }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    // Log to Sentry
    import('sentry-sdk').then(Sentry => Sentry.captureException(error, { extra: info }))
    this.props.onError?.(error, info)
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <ErrorBanner message="Something went wrong. Please refresh the page." />
      )
    }
    return this.props.children
  }
}

// Usage — wrap every route-level page
<ErrorBoundary fallback={<div>Page failed to load</div>}>
  <OrderListPage />
</ErrorBoundary>
```

---

## Code splitting — lazy route loading

```tsx
// src/app/router.tsx — lazy load each page to reduce initial bundle
import { lazy, Suspense } from 'react'
import { LoadingSpinner } from '@/components/shared'

// Lazy imports — each page becomes its own chunk
const OrderList = lazy(() => import('@/features/orders/pages/OrderList'))
const InvoiceList = lazy(() => import('@/features/invoices/pages/InvoiceList'))
const Dashboard = lazy(() => import('@/features/dashboard/pages/Dashboard'))

// Wrap lazy routes in Suspense
const SuspenseWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <Suspense fallback={<LoadingSpinner fullPage />}>{children}</Suspense>
)

export const router = createBrowserRouter([
  {
    path: '/',
    element: <ProtectedRoute />,
    children: [
      { path: 'orders', element: <SuspenseWrapper><OrderList /></SuspenseWrapper> },
      { path: 'invoices', element: <SuspenseWrapper><InvoiceList /></SuspenseWrapper> },
      { path: 'dashboard', element: <SuspenseWrapper><Dashboard /></SuspenseWrapper> },
    ],
  },
])
```

**Rules:**
- Every route-level page component → lazy import
- Every page → wrapped in ErrorBoundary
- Shared components → NOT lazy (they're small and used everywhere)
- Add both to Phase 4 checklist for every new page task
