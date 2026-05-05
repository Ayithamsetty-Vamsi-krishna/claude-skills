# Frontend: Selectors, Forms & Effect Cleanup

## Redux Selectors (features/<feature>/selectors.ts) (#7)

Every feature MUST have a dedicated `selectors.ts` using `createSelector` for memoization.
Never write inline selectors inside components.

```typescript
// src/features/orders/selectors.ts
import { createSelector } from '@reduxjs/toolkit'
import type { RootState } from '@/app/store'

// Base selectors — raw state access
const selectOrdersState = (state: RootState) => state.orders

// Memoized derived selectors
export const selectOrders = createSelector(
  selectOrdersState,
  (state) => state.orders
)

export const selectOrdersLoading = createSelector(
  selectOrdersState,
  (state) => state.loading
)

export const selectOrdersError = createSelector(
  selectOrdersState,
  (state) => state.error
)

export const selectTotalCount = createSelector(
  selectOrdersState,
  (state) => state.totalCount
)

export const selectSelectedOrder = createSelector(
  selectOrdersState,
  (state) => state.selectedOrder
)

// Parameterised selector — select by ID
export const selectOrderById = (id: string) =>
  createSelector(selectOrders, (orders) => orders.find((o) => o.id === id) ?? null)

// Derived selector — filter pending orders
export const selectPendingOrders = createSelector(
  selectOrders,
  (orders) => orders.filter((o) => o.status === 'pending')
)
```

Usage in components — always via selectors, never inline:
```typescript
// ✅ Correct — memoized, no unnecessary re-renders
const orders = useAppSelector(selectOrders)
const loading = useAppSelector(selectOrdersLoading)
const order = useAppSelector(selectOrderById(id))

// ❌ Wrong — new reference every render, causes re-renders
const orders = useAppSelector((state) => state.orders.orders)
```

**Rule:** Add `selectors.ts` creation as a mandatory sub-task in every frontend feature plan.
Export selectors from the feature `index.ts`.

---

## useEffect with dispatch().abort() Cleanup (#9)

Prevent stale state updates when a component unmounts before a request completes.
Always use the `.abort()` pattern for data-fetching `useEffect` hooks.

```typescript
import React, { useEffect } from 'react'
import { useAppDispatch, useAppSelector } from '@/app/hooks'
import { fetchOrders } from '../ordersSlice'
import { selectOrders, selectOrdersLoading, selectOrdersError } from '../selectors'

export const OrderList = React.memo(() => {
  const dispatch = useAppDispatch()
  const orders = useAppSelector(selectOrders)
  const loading = useAppSelector(selectOrdersLoading)
  const error = useAppSelector(selectOrdersError)

  useEffect(() => {
    // Dispatch returns a promise with .abort() method
    const promise = dispatch(fetchOrders())

    // Cleanup — abort the request if component unmounts before it completes
    return () => {
      promise.abort()
    }
  }, [dispatch])

  // ... render
})
OrderList.displayName = 'OrderList'
```

For effects with dependencies (e.g. filter params):
```typescript
useEffect(() => {
  const promise = dispatch(fetchOrders({ status: activeFilter }))
  return () => { promise.abort() }
}, [dispatch, activeFilter])
```

---

## Error Reset Before Re-fetch (#8)

Always reset error state to null before dispatching a new request.
The `pending` extraReducer already does `s.error = null` — this is enforced in the slice pattern above.
For manual re-fetch triggers (e.g. retry button), dispatch `clearError` first:

```typescript
const handleRetry = useCallback(() => {
  dispatch(clearError())          // reset error state
  dispatch(fetchOrders())         // re-fetch
}, [dispatch])
```

Add to the review checklist: every `pending` case in `extraReducers` sets `error: null`.

---

## React Hook Form + Zod for Forms

Install: `npm install react-hook-form @hookform/resolvers`

**Never use raw `FormData` for form input.** Connect Zod schemas (already in `types.ts`) directly to React Hook Form — single source of truth for validation.

```typescript
// src/features/orders/types.ts
// Write payload schema — used for BOTH API validation AND form validation
export const CreateOrderSchema = z.object({
  customerId: z.string().uuid({ message: 'Please select a valid customer' }),
  totalAmount: z.string().min(1, 'Amount is required').refine(
    val => !isNaN(parseFloat(val)) && parseFloat(val) > 0,
    { message: 'Amount must be greater than zero' }
  ),
  notes: z.string().optional(),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().int().positive(),
    unitPrice: z.string(),
  })).min(1, 'At least one item is required'),
})

// Infer TypeScript type from schema — no duplication
export type CreateOrderPayload = z.infer<typeof CreateOrderSchema>
```

```tsx
// Form component with React Hook Form + Zod
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { CreateOrderSchema } from '../types'
import type { CreateOrderPayload } from '../types'

export const OrderForm = React.memo<{ onSuccess?: () => void }>(({ onSuccess }) => {
  const dispatch = useAppDispatch()
  const { toast } = useToast()

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<CreateOrderPayload>({
    resolver: zodResolver(CreateOrderSchema),   // ← Zod schema drives validation
    defaultValues: { notes: '', items: [] },
  })

  const onSubmit = useCallback(async (data: CreateOrderPayload) => {
    try {
      await dispatch(createOrder(data)).unwrap()
      toast({ title: 'Order created successfully' })
      onSuccess?.()
    } catch (err: unknown) {
      if (isApiError(err)) {
        // Map API field errors back to React Hook Form
        Object.entries(err.errors).forEach(([field, messages]) => {
          setError(field as keyof CreateOrderPayload, {
            type: 'server',
            message: messages[0],
          })
        })
        toast({ title: err.message, variant: 'destructive' })
      }
    }
  }, [dispatch, onSuccess, toast, setError])

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <FormField
        label="Customer"
        {...register('customerId')}
        error={errors.customerId?.message}
      />
      <FormField
        label="Total Amount"
        type="number"
        {...register('totalAmount')}
        error={errors.totalAmount?.message}
      />
      <Button type="submit" loading={isSubmitting}>Create Order</Button>
    </form>
  )
})
OrderForm.displayName = 'OrderForm'
```

**Rules:**
- ALWAYS use `zodResolver` — never write manual validation logic
- Zod schema in `types.ts` is used for BOTH API response validation AND form validation
- Map server-side `ApiError.errors` back to form fields via `setError` after failed submit
- `isSubmitting` from `useForm` replaces manual `useState(false)` for loading state
