# Frontend: Component Patterns & Memoization

## Component Rules
- `React.memo` on EVERY component
- `useCallback` on EVERY function passed as prop
- `useMemo` on EVERY expensive derived value
- `displayName` set on all memoized components
- No `any` TypeScript types
- Every component handles: loading state, error state, empty state

## List Component Pattern
```tsx
import React, { useEffect, useMemo, useCallback } from 'react'
import { useAppDispatch, useAppSelector } from '@/app/hooks'
import { fetchOrders, setSelectedOrder } from '../ordersSlice'
import { DataTable, PageHeader, Button, EmptyState, LoadingSpinner, ErrorBanner } from '@/components/shared'
import type { Order } from '../types'

export const OrderList = React.memo(() => {
  const dispatch = useAppDispatch()
  const { orders, loading, error } = useAppSelector(s => s.orders)

  useEffect(() => { dispatch(fetchOrders()) }, [dispatch])

  const columns = useMemo(() => [
    { key: 'id', header: 'ID', render: (r: Order) => r.id.slice(0,8) },
    { key: 'status', header: 'Status', render: (r: Order) => <StatusBadge status={r.status} /> },
    { key: 'amount', header: 'Amount', render: (r: Order) => r.totalAmount },
  ], [])

  const handleSelect = useCallback((order: Order) => {
    dispatch(setSelectedOrder(order))
  }, [dispatch])

  if (loading) return <LoadingSpinner />
  if (error) return <ErrorBanner message={error} />

  return (
    <div>
      <PageHeader title="Orders" action={<Button>New Order</Button>} />
      <DataTable
        columns={columns}
        data={orders}
        keyExtractor={r => r.id}
        emptyTitle="No orders yet"
        emptyDescription="Create your first order to get started."
      />
    </div>
  )
})
OrderList.displayName = 'OrderList'
```

## Form Component Pattern
```tsx
import React, { useState, useCallback } from 'react'
import { useAppDispatch } from '@/app/hooks'
import { createOrder } from '../ordersSlice'
import { Button, FormField, ErrorBanner } from '@/components/shared'
import { useToast } from '@/components/ui/use-toast'
import type { CreateOrderPayload } from '../types'

interface Props { onSuccess?: () => void }

export const OrderForm = React.memo<Props>(({ onSuccess }) => {
  const dispatch = useAppDispatch()
  const { toast } = useToast()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const handleSubmit = useCallback(async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setIsSubmitting(true); setErrors({})
    const fd = new FormData(e.currentTarget)
    const payload: CreateOrderPayload = {
      customerId: fd.get('customerId') as string,
      status: 'pending',
      totalAmount: fd.get('totalAmount') as string,
      items: [],
    }
    try {
      await dispatch(createOrder(payload)).unwrap()
      toast({ title: 'Order created' })
      onSuccess?.()
    } catch (err: unknown) {
      const apiErr = err as Record<string, string[]>
      setErrors(Object.fromEntries(
        Object.entries(apiErr).map(([k,v]) => [k, Array.isArray(v) ? v[0] : String(v)])))
      toast({ title: 'Failed to create order', variant: 'destructive' })
    } finally { setIsSubmitting(false) }
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

## Memoization Rules
```tsx
// ✅ Correct
const handleSubmit = useCallback(async () => {
  await dispatch(createOrder(payload))
}, [dispatch, payload])

const sorted = useMemo(
  () => [...orders].sort((a,b) => a.createdAt.localeCompare(b.createdAt)),
  [orders])

// ❌ Wrong — creates new function reference every render
<Child onClick={() => dispatch(someAction())} />
```
