# Frontend: Feature Exports & Runtime Validation

## #7 — Feature index.ts Barrel Export

Every feature folder MUST end with an `index.ts` that barrel-exports everything.
This keeps imports clean across the app — one import path per feature.

```typescript
// src/features/orders/index.ts
// Public API of the orders feature — import from here everywhere

// Types
export type { Order, OrderItem, CreateOrderPayload, UpdateOrderPayload } from './types'

// Slice actions + thunks
export {
  fetchOrders,
  fetchOrderById,
  createOrder,
  updateOrder,
  deleteOrder,
  setSelectedOrder,
  clearError,
} from './ordersSlice'

// Selectors — from selectors.ts, NOT from ordersSlice — #B4 fix
export {
  selectOrders,
  selectSelectedOrder,
  selectOrdersLoading,
  selectOrdersError,
  selectTotalCount,
  selectOrderById,
  selectPendingOrders,
} from './selectors'

// Service
export { ordersService } from './ordersService'

// Components
export { OrderList } from './components/OrderList'
export { OrderForm } from './components/OrderForm'
export { OrderCard } from './components/OrderCard'
```

Usage across the app — clean single import:
```typescript
// ✅ Correct — import from feature index
import { OrderList, fetchOrders, type Order } from '@/features/orders'

// ❌ Wrong — importing from internal files directly
import { OrderList } from '@/features/orders/components/OrderList'
import { fetchOrders } from '@/features/orders/ordersSlice'
```

**Rule:** Add `index.ts` creation as the LAST sub-task of every frontend feature task.

---

## #8 — Zod Runtime Schema Validation

TypeScript types are compile-time only — they don't catch bad API responses at runtime.
Use `zod` to validate API responses at the service layer.

Install: `npm install zod`

```typescript
// src/features/orders/types.ts
import { z } from 'zod'

// Zod schema — source of truth
export const OrderItemSchema = z.object({
  id: z.string().uuid(),
  productId: z.string().uuid(),
  product: z.object({
    id: z.string().uuid(),
    name: z.string(),
  }),
  quantity: z.number().int().positive(),
  unitPrice: z.string(),
  createdAt: z.string(),
})

export const OrderSchema = z.object({
  id: z.string().uuid(),
  customerId: z.string().uuid(),
  customer: z.object({
    id: z.string().uuid(),
    name: z.string(),
    email: z.string().email(),
  }),
  status: z.enum(['pending', 'confirmed', 'cancelled']),
  totalAmount: z.string(),
  notes: z.string().optional(),
  items: z.array(OrderItemSchema),
  createdAt: z.string(),
  updatedAt: z.string(),
})

export const PaginatedOrdersSchema = z.object({
  count: z.number(),
  next: z.string().nullable(),
  previous: z.string().nullable(),
  results: z.array(OrderSchema),
})

// Infer TypeScript types from schemas — single source of truth
export type Order = z.infer<typeof OrderSchema>
export type OrderItem = z.infer<typeof OrderItemSchema>

// Write payloads (not from API — define separately)
export interface CreateOrderPayload {
  customerId: string
  status: string
  totalAmount: string
  items: { productId: string; quantity: number; unitPrice: string }[]
}
export type UpdateOrderPayload = Partial<CreateOrderPayload>
```

```typescript
// src/features/orders/ordersService.ts
import api from '@/services/api'
import { OrderSchema, PaginatedOrdersSchema } from './types'
import type { Order, CreateOrderPayload, UpdateOrderPayload } from './types'

export const ordersService = {
  getAll: async (params = {}) => {
    const response = await api.get('/orders/', { params })
    // Runtime validation — catches API shape mismatches immediately
    return PaginatedOrdersSchema.parse(response.data)
  },

  getById: async (id: string): Promise<Order> => {
    const response = await api.get(`/orders/${id}/`)
    return OrderSchema.parse(response.data)
  },

  create: async (payload: CreateOrderPayload): Promise<Order> => {
    const response = await api.post('/orders/', payload)
    return OrderSchema.parse(response.data)
  },

  update: async (id: string, payload: UpdateOrderPayload): Promise<Order> => {
    const response = await api.patch(`/orders/${id}/`, payload)
    return OrderSchema.parse(response.data)
  },

  delete: async (id: string): Promise<void> => {
    await api.delete(`/orders/${id}/`)
  },
}
```

**Rule:** Every service file MUST use Zod schemas for all GET responses.
POST/PATCH response validation is recommended but optional.
If Zod is not already in the project, add it as the first frontend sub-task.

---

## API Error Type & Type Guard (src/types/index.ts)

```typescript
// src/types/index.ts

export interface ApiError {
  success: false
  message: string
  errors: Record<string, string[]>
}

// Type guard — use in all catch blocks
export const isApiError = (error: unknown): error is ApiError =>
  typeof error === 'object' &&
  error !== null &&
  'success' in error &&
  (error as ApiError).success === false &&
  'message' in error &&
  'errors' in error

// Usage in components:
// } catch (err: unknown) {
//   if (isApiError(err)) {
//     setErrors(Object.fromEntries(
//       Object.entries(err.errors).map(([k, v]) => [k, v[0]])
//     ))
//     toast({ title: err.message, variant: 'destructive' })
//   }
// }
```
