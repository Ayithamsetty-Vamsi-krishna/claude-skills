# Frontend: State Management & API Layer

## Project Structure
```
src/
├── app/
│   ├── store.ts          # Redux store
│   ├── hooks.ts          # useAppDispatch, useAppSelector
│   └── rootReducer.ts
├── services/
│   └── api.ts            # Axios instance + JWT interceptors (single source)
├── features/<feature>/
│   ├── types.ts
│   ├── <feature>Slice.ts
│   ├── <feature>Service.ts
│   └── components/
├── components/shared/    # Canonical shared components (never reimplement)
├── lib/utils.ts          # cn() + shared utils
└── constants/index.ts
```

## api.ts — Axios with JWT Refresh
```typescript
import axios, { AxiosInstance, InternalAxiosRequestConfig } from 'axios'

const api: AxiosInstance = axios.create({
  baseURL: `${import.meta.env.VITE_API_BASE_URL}/api/v1`,
  headers: { 'Content-Type': 'application/json' },
})

// Attach token
api.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = localStorage.getItem('access_token')
  if (token && config.headers) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Refresh on 401
let isRefreshing = false
let queue: Array<{resolve:(t:string)=>void; reject:(e:unknown)=>void}> = []

const flush = (err: unknown, token: string | null = null) => {
  queue.forEach(({resolve, reject}) => err ? reject(err) : resolve(token!))
  queue = []
}

api.interceptors.response.use(r => r, async (error) => {
  const orig = error.config
  if (error.response?.status !== 401 || orig._retry) return Promise.reject(error)
  if (isRefreshing) return new Promise((resolve, reject) => {
    queue.push({resolve, reject})
  }).then(token => { orig.headers.Authorization = `Bearer ${token}`; return api(orig) })

  orig._retry = true; isRefreshing = true
  try {
    const { data } = await axios.post(
      `${import.meta.env.VITE_API_BASE_URL}/api/v1/auth/token/refresh/`,
      { refresh: localStorage.getItem('refresh_token') })
    localStorage.setItem('access_token', data.access)
    flush(null, data.access)
    orig.headers.Authorization = `Bearer ${data.access}`
    return api(orig)
  } catch (e) {
    flush(e); localStorage.clear(); window.location.href = '/login'
    return Promise.reject(e)
  } finally { isRefreshing = false }
})

export default api
```

## TypeScript Types (features/<feature>/types.ts)
```typescript
// Read shape (GET response)
export interface Order {
  id: string
  customerId: string       // FK write field
  customer: Customer       // nested read object
  status: 'pending' | 'confirmed' | 'cancelled'
  totalAmount: string
  items: OrderItem[]
  createdAt: string
  updatedAt: string
}

// Write payloads (POST/PATCH)
export interface CreateOrderPayload {
  customerId: string
  status: string
  totalAmount: string
  items: OrderItemPayload[]
}
export type UpdateOrderPayload = Partial<CreateOrderPayload>

export interface PaginatedResponse<T> {
  count: number; next: string | null; previous: string | null; results: T[]
}
```

## Redux Slice (features/<feature>/<feature>Slice.ts)
```typescript
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit'
import { Order, CreateOrderPayload, PaginatedResponse } from './types'
import { ordersService } from './ordersService'

interface OrdersState {
  orders: Order[]; selectedOrder: Order | null
  totalCount: number; loading: boolean; error: string | null
}

export const fetchOrders = createAsyncThunk('orders/fetchAll',
  async (params: Record<string,string> = {}, { rejectWithValue }) => {
    try { return await ordersService.getAll(params) }
    catch (e: unknown) { return rejectWithValue((e as Error).message) }
  })

export const createOrder = createAsyncThunk('orders/create',
  async (payload: CreateOrderPayload, { rejectWithValue }) => {
    try { return await ordersService.create(payload) }
    catch (e: unknown) { return rejectWithValue((e as Error).message) }
  })

const ordersSlice = createSlice({
  name: 'orders',
  initialState: { orders:[], selectedOrder:null, totalCount:0, loading:false, error:null } as OrdersState,
  reducers: {
    setSelectedOrder: (s, a: PayloadAction<Order|null>) => { s.selectedOrder = a.payload },
    clearError: (s) => { s.error = null },
  },
  extraReducers: b => b
    .addCase(fetchOrders.pending, s => { s.loading=true; s.error=null })
    .addCase(fetchOrders.fulfilled, (s, a: PayloadAction<PaginatedResponse<Order>>) => {
      s.loading=false; s.orders=a.payload.results; s.totalCount=a.payload.count })
    .addCase(fetchOrders.rejected, (s, a) => { s.loading=false; s.error=a.payload as string })
    .addCase(createOrder.fulfilled, (s, a: PayloadAction<Order>) => {
      s.orders.unshift(a.payload); s.totalCount++ }),
})

export const { setSelectedOrder, clearError } = ordersSlice.actions
export default ordersSlice.reducer
```

## Service Layer (features/<feature>/<feature>Service.ts)
```typescript
import api from '@/services/api'
import { Order, CreateOrderPayload, UpdateOrderPayload, PaginatedResponse } from './types'

export const ordersService = {
  getAll: async (params = {}): Promise<PaginatedResponse<Order>> =>
    (await api.get('/orders/', { params })).data,
  getById: async (id: string): Promise<Order> =>
    (await api.get(`/orders/${id}/`)).data,
  create: async (payload: CreateOrderPayload): Promise<Order> =>
    (await api.post('/orders/', payload)).data,
  update: async (id: string, payload: UpdateOrderPayload): Promise<Order> =>
    (await api.patch(`/orders/${id}/`, payload)).data,
  delete: async (id: string): Promise<void> =>
    void (await api.delete(`/orders/${id}/`)),
}
```

## camelCase ↔ snake_case
Add to api.ts interceptors using `humps`:
```typescript
import { camelizeKeys, decamelizeKeys } from 'humps'
// request: config.data = decamelizeKeys(config.data)
// response: response.data = camelizeKeys(response.data)
```

---

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
