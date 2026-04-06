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

## app/hooks.ts — Typed Redux Hooks
Every component uses these — never import raw `useDispatch`/`useSelector` directly.

```typescript
// src/app/hooks.ts
import { useDispatch, useSelector } from 'react-redux'
import type { RootState, AppDispatch } from './store'

// Typed versions — use these everywhere instead of plain useDispatch/useSelector
export const useAppDispatch = useDispatch.withTypes<AppDispatch>()
export const useAppSelector = useSelector.withTypes<RootState>()
```

```typescript
// src/app/store.ts
import { configureStore } from '@reduxjs/toolkit'
import { rootReducer } from './rootReducer'

export const store = configureStore({ reducer: rootReducer })

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch
```

---

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

---

## Frontend Environment Variables

```
# .env  ← never commit — add to .gitignore
VITE_API_BASE_URL=http://localhost:8000

# .env.example  ← always commit — shows required vars without values
VITE_API_BASE_URL=
```

**Rule:** Any `import.meta.env.VITE_*` variable used in code MUST have a corresponding entry in `.env.example`. Never hardcode URLs or keys.
