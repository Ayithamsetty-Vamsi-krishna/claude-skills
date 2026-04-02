# Frontend Reference — React + TypeScript Standards

## Project Structure

```
frontend/
├── public/
├── src/
│   ├── app/
│   │   ├── store.ts               # Redux store config
│   │   ├── hooks.ts               # Typed useAppDispatch / useAppSelector
│   │   └── rootReducer.ts
│   ├── services/
│   │   └── api.ts                 # Axios instance + JWT interceptors (SINGLE source of truth)
│   ├── features/
│   │   └── <feature>/             # One folder per feature/domain
│   │       ├── index.ts           # Public exports
│   │       ├── types.ts           # TypeScript interfaces for this feature
│   │       ├── <feature>Slice.ts  # Redux slice (state + reducers + thunks)
│   │       ├── <feature>Service.ts # Axios API calls (uses api.ts)
│   │       ├── components/
│   │       │   ├── <Feature>List.tsx
│   │       │   ├── <Feature>Form.tsx
│   │       │   └── <Feature>Card.tsx
│   │       └── tests/
│   │           ├── <Feature>List.test.tsx
│   │           └── <Feature>Form.test.tsx
│   ├── components/
│   │   ├── ui/                    # shadcn/ui auto-generated primitives (do not edit)
│   │   └── shared/                # ← ALL custom shared components live here
│   │       ├── Text.tsx           # Typography system
│   │       ├── Button.tsx         # Wrapped Button with project defaults
│   │       ├── FormField.tsx      # Input + Label + error display
│   │       ├── StatusBadge.tsx    # Coloured badge for status fields
│   │       ├── DataTable.tsx      # Standard table with loading + empty states
│   │       ├── Modal.tsx          # Dialog wrapper
│   │       ├── PageHeader.tsx     # Page title + subtitle + action slot
│   │       ├── EmptyState.tsx     # Empty list illustration + CTA
│   │       ├── LoadingSpinner.tsx # Spinner + full-page loader variant
│   │       └── ErrorBanner.tsx    # Error display (banner + inline variants)
│   ├── lib/
│   │   └── utils.ts               # cn() helper + shared utilities
│   ├── constants/
│   │   └── index.ts               # App-wide constants (enums, config values)
│   ├── types/
│   │   └── index.ts               # Global shared TypeScript types
│   └── main.tsx
├── tailwind.config.ts
├── vite.config.ts
└── vitest.config.ts
```

---

## Axios API Service (src/services/api.ts)

Single Axios instance with JWT access + refresh token handling.

```typescript
import axios, { AxiosInstance, InternalAxiosRequestConfig, AxiosResponse } from 'axios'

const BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'

const api: AxiosInstance = axios.create({
  baseURL: `${BASE_URL}/api/v1`,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor — attach access token
api.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('access_token')
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => Promise.reject(error)
)

// Response interceptor — handle 401 + refresh
let isRefreshing = false
let failedQueue: Array<{ resolve: (token: string) => void; reject: (err: unknown) => void }> = []

const processQueue = (error: unknown, token: string | null = null) => {
  failedQueue.forEach(({ resolve, reject }) => {
    if (error) reject(error)
    else if (token) resolve(token)
  })
  failedQueue = []
}

api.interceptors.response.use(
  (response: AxiosResponse) => response,
  async (error) => {
    const originalRequest = error.config

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject })
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`
          return api(originalRequest)
        })
      }

      originalRequest._retry = true
      isRefreshing = true

      try {
        const refreshToken = localStorage.getItem('refresh_token')
        const response = await axios.post(`${BASE_URL}/api/v1/auth/token/refresh/`, {
          refresh: refreshToken,
        })
        const newAccessToken: string = response.data.access
        localStorage.setItem('access_token', newAccessToken)
        processQueue(null, newAccessToken)
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`
        return api(originalRequest)
      } catch (refreshError) {
        processQueue(refreshError, null)
        localStorage.removeItem('access_token')
        localStorage.removeItem('refresh_token')
        window.location.href = '/login'
        return Promise.reject(refreshError)
      } finally {
        isRefreshing = false
      }
    }

    return Promise.reject(error)
  }
)

export default api
```

---

## TypeScript Types Pattern (features/<feature>/types.ts)

Always type both the nested read shape AND the write payload shape separately.

```typescript
// Nested read object (what GET returns)
export interface Customer {
  id: string
  name: string
  email: string
}

export interface Product {
  id: string
  name: string
  price: string
}

export interface OrderItem {
  id: string
  productId: string        // camelCase FK ID
  product: Product         // nested read object
  quantity: number
  unitPrice: string
}

export interface Order {
  id: string
  customerId: string       // write FK ID
  customer: Customer       // nested read object
  status: 'pending' | 'confirmed' | 'cancelled'
  totalAmount: string
  notes: string
  items: OrderItem[]
  createdAt: string
  updatedAt: string
}

// Write payload shape (POST/PATCH)
export interface OrderItemPayload {
  productId: string
  quantity: number
  unitPrice: string
}

export interface CreateOrderPayload {
  customerId: string
  status: string
  totalAmount: string
  notes?: string
  items: OrderItemPayload[]
}

export type UpdateOrderPayload = Partial<CreateOrderPayload>

// Paginated API response wrapper
export interface PaginatedResponse<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}
```

---

## Redux Slice Pattern (features/<feature>/<feature>Slice.ts)

```typescript
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit'
import { Order, CreateOrderPayload, UpdateOrderPayload, PaginatedResponse } from './types'
import { ordersService } from './ordersService'

interface OrdersState {
  orders: Order[]
  selectedOrder: Order | null
  totalCount: number
  loading: boolean
  error: string | null
}

const initialState: OrdersState = {
  orders: [],
  selectedOrder: null,
  totalCount: 0,
  loading: false,
  error: null,
}

// Async thunks
export const fetchOrders = createAsyncThunk(
  'orders/fetchAll',
  async (params: Record<string, string> = {}, { rejectWithValue }) => {
    try {
      return await ordersService.getAll(params)
    } catch (error: unknown) {
      return rejectWithValue((error as Error).message)
    }
  }
)

export const createOrder = createAsyncThunk(
  'orders/create',
  async (payload: CreateOrderPayload, { rejectWithValue }) => {
    try {
      return await ordersService.create(payload)
    } catch (error: unknown) {
      return rejectWithValue((error as Error).message)
    }
  }
)

export const updateOrder = createAsyncThunk(
  'orders/update',
  async ({ id, payload }: { id: string; payload: UpdateOrderPayload }, { rejectWithValue }) => {
    try {
      return await ordersService.update(id, payload)
    } catch (error: unknown) {
      return rejectWithValue((error as Error).message)
    }
  }
)

export const deleteOrder = createAsyncThunk(
  'orders/delete',
  async (id: string, { rejectWithValue }) => {
    try {
      await ordersService.delete(id)
      return id
    } catch (error: unknown) {
      return rejectWithValue((error as Error).message)
    }
  }
)

const ordersSlice = createSlice({
  name: 'orders',
  initialState,
  reducers: {
    setSelectedOrder: (state, action: PayloadAction<Order | null>) => {
      state.selectedOrder = action.payload
    },
    clearError: (state) => {
      state.error = null
    },
  },
  extraReducers: (builder) => {
    builder
      // fetchOrders
      .addCase(fetchOrders.pending, (state) => {
        state.loading = true
        state.error = null
      })
      .addCase(fetchOrders.fulfilled, (state, action: PayloadAction<PaginatedResponse<Order>>) => {
        state.loading = false
        state.orders = action.payload.results
        state.totalCount = action.payload.count
      })
      .addCase(fetchOrders.rejected, (state, action) => {
        state.loading = false
        state.error = action.payload as string
      })
      // createOrder
      .addCase(createOrder.fulfilled, (state, action: PayloadAction<Order>) => {
        state.orders.unshift(action.payload)
        state.totalCount += 1
      })
      // updateOrder
      .addCase(updateOrder.fulfilled, (state, action: PayloadAction<Order>) => {
        const index = state.orders.findIndex((o) => o.id === action.payload.id)
        if (index !== -1) state.orders[index] = action.payload
      })
      // deleteOrder
      .addCase(deleteOrder.fulfilled, (state, action: PayloadAction<string>) => {
        state.orders = state.orders.filter((o) => o.id !== action.payload)
        state.totalCount -= 1
      })
  },
})

export const { setSelectedOrder, clearError } = ordersSlice.actions
export default ordersSlice.reducer
```

---

## Axios Service Pattern (features/<feature>/<feature>Service.ts)

```typescript
import api from '@/services/api'
import { Order, CreateOrderPayload, UpdateOrderPayload, PaginatedResponse } from './types'

// Centralise all API calls for this feature here
export const ordersService = {
  getAll: async (params: Record<string, string> = {}): Promise<PaginatedResponse<Order>> => {
    const response = await api.get('/orders/', { params })
    return response.data
  },

  getById: async (id: string): Promise<Order> => {
    const response = await api.get(`/orders/${id}/`)
    return response.data
  },

  create: async (payload: CreateOrderPayload): Promise<Order> => {
    const response = await api.post('/orders/', payload)
    return response.data
  },

  update: async (id: string, payload: UpdateOrderPayload): Promise<Order> => {
    const response = await api.patch(`/orders/${id}/`, payload)
    return response.data
  },

  delete: async (id: string): Promise<void> => {
    await api.delete(`/orders/${id}/`)
  },
}
```

---

## Component Pattern

### List Component
```tsx
import React, { useEffect } from 'react'
import { useAppDispatch, useAppSelector } from '@/app/hooks'
import { fetchOrders } from '../ordersSlice'
import { OrderCard } from './OrderCard'
import { Skeleton } from '@/components/ui/skeleton'
import { Alert, AlertDescription } from '@/components/ui/alert'

export const OrderList: React.FC = () => {
  const dispatch = useAppDispatch()
  const { orders, loading, error } = useAppSelector((state) => state.orders)

  useEffect(() => {
    dispatch(fetchOrders())
  }, [dispatch])

  // Loading state
  if (loading) {
    return (
      <div className="space-y-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <Skeleton key={i} className="h-24 w-full rounded-lg" />
        ))}
      </div>
    )
  }

  // Error state
  if (error) {
    return (
      <Alert variant="destructive">
        <AlertDescription>{error}</AlertDescription>
      </Alert>
    )
  }

  // Empty state
  if (orders.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-16 text-muted-foreground">
        <p className="text-lg font-medium">No orders yet</p>
        <p className="text-sm">Create your first order to get started.</p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {orders.map((order) => (
        <OrderCard key={order.id} order={order} />
      ))}
    </div>
  )
}
```

### Form Component
```tsx
import React, { useState } from 'react'
import { useAppDispatch } from '@/app/hooks'
import { createOrder } from '../ordersSlice'
import { CreateOrderPayload } from '../types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useToast } from '@/components/ui/use-toast'

interface OrderFormProps {
  onSuccess?: () => void
}

export const OrderForm: React.FC<OrderFormProps> = ({ onSuccess }) => {
  const dispatch = useAppDispatch()
  const { toast } = useToast()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault()
    setIsSubmitting(true)
    setErrors({})

    const formData = new FormData(e.currentTarget)
    const payload: CreateOrderPayload = {
      customerId: formData.get('customerId') as string,
      status: 'pending',
      totalAmount: formData.get('totalAmount') as string,
      items: [],
    }

    try {
      await dispatch(createOrder(payload)).unwrap()
      toast({ title: 'Order created successfully' })
      onSuccess?.()
    } catch (error: unknown) {
      const apiError = error as Record<string, string[]>
      // Map API field errors to form errors
      const fieldErrors: Record<string, string> = {}
      Object.entries(apiError).forEach(([field, messages]) => {
        fieldErrors[field] = Array.isArray(messages) ? messages[0] : String(messages)
      })
      setErrors(fieldErrors)
      toast({ title: 'Failed to create order', variant: 'destructive' })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-1">
        <Label htmlFor="customerId">Customer</Label>
        <Input id="customerId" name="customerId" required />
        {errors.customerId && (
          <p className="text-sm text-destructive">{errors.customerId}</p>
        )}
      </div>

      <Button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Creating...' : 'Create Order'}
      </Button>
    </form>
  )
}
```

---

## Testing Pattern (Vitest + React Testing Library)

```typescript
// tests/OrderList.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { Provider } from 'react-redux'
import { configureStore } from '@reduxjs/toolkit'
import { OrderList } from '../components/OrderList'
import ordersReducer from '../ordersSlice'
import * as ordersService from '../ordersService'

// Helper: render with Redux store
const renderWithStore = (preloadedState = {}) => {
  const store = configureStore({
    reducer: { orders: ordersReducer },
    preloadedState,
  })
  return render(
    <Provider store={store}>
      <OrderList />
    </Provider>
  )
}

describe('OrderList', () => {
  // ✅ Happy path
  it('renders orders when loaded', async () => {
    vi.spyOn(ordersService.ordersService, 'getAll').mockResolvedValue({
      count: 1,
      next: null,
      previous: null,
      results: [{ id: '1', status: 'pending', totalAmount: '100.00', /* ... */ }],
    })

    renderWithStore()
    await waitFor(() => {
      expect(screen.getByText('pending')).toBeInTheDocument()
    })
  })

  // 🔁 Empty state
  it('shows empty state when no orders', async () => {
    vi.spyOn(ordersService.ordersService, 'getAll').mockResolvedValue({
      count: 0, next: null, previous: null, results: [],
    })
    renderWithStore()
    await waitFor(() => {
      expect(screen.getByText('No orders yet')).toBeInTheDocument()
    })
  })

  // 💥 Error state
  it('shows error message on API failure', async () => {
    vi.spyOn(ordersService.ordersService, 'getAll').mockRejectedValue(
      new Error('Network error')
    )
    renderWithStore()
    await waitFor(() => {
      expect(screen.getByText('Network error')).toBeInTheDocument()
    })
  })

  // ⏳ Loading state
  it('shows skeletons while loading', () => {
    renderWithStore({ orders: { loading: true, orders: [], error: null, totalCount: 0, selectedOrder: null } })
    expect(screen.getAllByTestId('skeleton')).toHaveLength(3)
  })
})
```

---

---

## Shared Component Library (src/components/shared/)

**Golden rule:** Every component in this folder is the ONE canonical implementation. No feature folder may implement its own version of these. If it needs text, it uses `<Text>`. If it needs a button, it uses `<Button>`. Changes here propagate everywhere automatically.

### Text.tsx — Typography System
```tsx
import React from 'react'
import { cn } from '@/lib/utils'

type TextVariant = 'h1' | 'h2' | 'h3' | 'h4' | 'body' | 'body-sm' | 'caption' | 'label'

interface TextProps {
  variant?: TextVariant
  children: React.ReactNode
  className?: string
  as?: keyof JSX.IntrinsicElements
}

const variantStyles: Record<TextVariant, string> = {
  h1: 'text-3xl font-bold tracking-tight',
  h2: 'text-2xl font-semibold tracking-tight',
  h3: 'text-xl font-semibold',
  h4: 'text-lg font-medium',
  body: 'text-sm text-foreground',
  'body-sm': 'text-xs text-foreground',
  caption: 'text-xs text-muted-foreground',
  label: 'text-sm font-medium text-foreground',
}

const variantElement: Record<TextVariant, keyof JSX.IntrinsicElements> = {
  h1: 'h1', h2: 'h2', h3: 'h3', h4: 'h4',
  body: 'p', 'body-sm': 'p', caption: 'span', label: 'span',
}

export const Text = React.memo<TextProps>(({ variant = 'body', children, className, as }) => {
  const Tag = as ?? variantElement[variant]
  return <Tag className={cn(variantStyles[variant], className)}>{children}</Tag>
})
Text.displayName = 'Text'
```

### StatusBadge.tsx — Coloured Status Badges
```tsx
import React from 'react'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

interface StatusBadgeProps {
  status: string
  className?: string
}

const statusStyles: Record<string, string> = {
  active: 'bg-green-100 text-green-800',
  inactive: 'bg-gray-100 text-gray-600',
  pending: 'bg-yellow-100 text-yellow-800',
  confirmed: 'bg-blue-100 text-blue-800',
  cancelled: 'bg-red-100 text-red-800',
  deleted: 'bg-red-200 text-red-900',
}

export const StatusBadge = React.memo<StatusBadgeProps>(({ status, className }) => (
  <Badge className={cn(statusStyles[status] ?? 'bg-gray-100 text-gray-600', className)}>
    {status.charAt(0).toUpperCase() + status.slice(1)}
  </Badge>
))
StatusBadge.displayName = 'StatusBadge'
```

### PageHeader.tsx — Page Title + Action Slot
```tsx
import React from 'react'
import { Text } from './Text'

interface PageHeaderProps {
  title: string
  subtitle?: string
  action?: React.ReactNode   // e.g. a <Button> to open a create modal
}

export const PageHeader = React.memo<PageHeaderProps>(({ title, subtitle, action }) => (
  <div className="flex items-start justify-between mb-6">
    <div className="space-y-1">
      <Text variant="h2">{title}</Text>
      {subtitle && <Text variant="caption">{subtitle}</Text>}
    </div>
    {action && <div>{action}</div>}
  </div>
))
PageHeader.displayName = 'PageHeader'
```

### EmptyState.tsx
```tsx
import React from 'react'
import { Text } from './Text'
import { Button } from './Button'

interface EmptyStateProps {
  title: string
  description?: string
  actionLabel?: string
  onAction?: () => void
}

export const EmptyState = React.memo<EmptyStateProps>(({ title, description, actionLabel, onAction }) => (
  <div className="flex flex-col items-center justify-center py-16 gap-3 text-center">
    <Text variant="h4">{title}</Text>
    {description && <Text variant="caption">{description}</Text>}
    {actionLabel && onAction && (
      <Button variant="outline" onClick={onAction}>{actionLabel}</Button>
    )}
  </div>
))
EmptyState.displayName = 'EmptyState'
```

### LoadingSpinner.tsx
```tsx
import React from 'react'
import { cn } from '@/lib/utils'

interface LoadingSpinnerProps {
  fullPage?: boolean
  className?: string
}

export const LoadingSpinner = React.memo<LoadingSpinnerProps>(({ fullPage, className }) => {
  const spinner = (
    <div className={cn('animate-spin rounded-full h-8 w-8 border-b-2 border-primary', className)} />
  )
  if (fullPage) {
    return <div className="flex items-center justify-center min-h-screen">{spinner}</div>
  }
  return spinner
})
LoadingSpinner.displayName = 'LoadingSpinner'
```

### ErrorBanner.tsx
```tsx
import React from 'react'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { cn } from '@/lib/utils'

interface ErrorBannerProps {
  message: string
  inline?: boolean   // inline = small text, not full alert banner
  className?: string
}

export const ErrorBanner = React.memo<ErrorBannerProps>(({ message, inline, className }) => {
  if (inline) {
    return <p className={cn('text-sm text-destructive', className)}>{message}</p>
  }
  return (
    <Alert variant="destructive" className={className}>
      <AlertDescription>{message}</AlertDescription>
    </Alert>
  )
})
ErrorBanner.displayName = 'ErrorBanner'
```

### FormField.tsx — Input + Label + Inline Error
```tsx
import React from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ErrorBanner } from './ErrorBanner'
import { cn } from '@/lib/utils'

interface FormFieldProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label: string
  name: string
  error?: string
  className?: string
}

export const FormField = React.memo<FormFieldProps>(({ label, name, error, className, ...inputProps }) => (
  <div className={cn('space-y-1', className)}>
    <Label htmlFor={name}>{label}</Label>
    <Input id={name} name={name} aria-invalid={!!error} {...inputProps} />
    {error && <ErrorBanner message={error} inline />}
  </div>
))
FormField.displayName = 'FormField'
```

### Modal.tsx — Standard Dialog Wrapper
```tsx
import React from 'react'
import {
  Dialog, DialogContent, DialogHeader,
  DialogTitle, DialogDescription
} from '@/components/ui/dialog'

interface ModalProps {
  open: boolean
  onClose: () => void
  title: string
  description?: string
  children: React.ReactNode
}

export const Modal = React.memo<ModalProps>(({ open, onClose, title, description, children }) => (
  <Dialog open={open} onOpenChange={onClose}>
    <DialogContent>
      <DialogHeader>
        <DialogTitle>{title}</DialogTitle>
        {description && <DialogDescription>{description}</DialogDescription>}
      </DialogHeader>
      {children}
    </DialogContent>
  </Dialog>
))
Modal.displayName = 'Modal'
```

### Button.tsx — Wrapped shadcn Button with Project Defaults
```tsx
import React from 'react'
import { Button as ShadcnButton, ButtonProps as ShadcnButtonProps } from '@/components/ui/button'
import { LoadingSpinner } from './LoadingSpinner'
import { cn } from '@/lib/utils'

interface ButtonProps extends ShadcnButtonProps {
  loading?: boolean
}

export const Button = React.memo<ButtonProps>(({ loading, children, disabled, className, ...props }) => (
  <ShadcnButton disabled={disabled || loading} className={cn(className)} {...props}>
    {loading ? <LoadingSpinner className="h-4 w-4 mr-2" /> : null}
    {children}
  </ShadcnButton>
))
Button.displayName = 'Button'
```

### DataTable.tsx — Standard Table with Built-in States
```tsx
import React from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { LoadingSpinner } from './LoadingSpinner'
import { EmptyState } from './EmptyState'

interface Column<T> {
  key: string
  header: string
  render: (row: T) => React.ReactNode
}

interface DataTableProps<T> {
  columns: Column<T>[]
  data: T[]
  loading?: boolean
  emptyTitle?: string
  emptyDescription?: string
  keyExtractor: (row: T) => string
}

export const DataTable = React.memo(<T,>({
  columns, data, loading, emptyTitle = 'No data', emptyDescription, keyExtractor
}: DataTableProps<T>) => {
  if (loading) return <LoadingSpinner />

  if (data.length === 0) {
    return <EmptyState title={emptyTitle} description={emptyDescription} />
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          {columns.map((col) => (
            <TableHead key={col.key}>{col.header}</TableHead>
          ))}
        </TableRow>
      </TableHeader>
      <TableBody>
        {data.map((row) => (
          <TableRow key={keyExtractor(row)}>
            {columns.map((col) => (
              <TableCell key={col.key}>{col.render(row)}</TableCell>
            ))}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}) as <T>(props: DataTableProps<T>) => JSX.Element
```

---

## Memoization Rules (always applied)

- **`React.memo`** — wrap every shared component and every feature component that receives props
- **`useCallback`** — wrap every function passed as a prop (event handlers, callbacks to children)
- **`useMemo`** — wrap expensive derived values (filtered lists, computed totals, sorted arrays)
- **Always set `displayName`** on memoized components for React DevTools readability

```tsx
// ✅ Correct
const handleSubmit = useCallback(async () => {
  await dispatch(createOrder(payload))
}, [dispatch, payload])

const sortedOrders = useMemo(
  () => [...orders].sort((a, b) => a.createdAt.localeCompare(b.createdAt)),
  [orders]
)

// ❌ Wrong — new function reference on every render
<ChildComponent onClick={() => dispatch(someAction())} />
```

---


| Element | Convention | Example |
|---|---|---|
| Feature folders | camelCase | `orders/`, `orderItems/` |
| TS interfaces | PascalCase | `Order`, `OrderItem` |
| Redux slices | camelCase file, PascalCase state | `ordersSlice.ts` |
| Thunk actions | `verb + Noun` | `fetchOrders`, `createOrder` |
| Service files | `<feature>Service.ts` | `ordersService.ts` |
| Components | PascalCase | `OrderList.tsx`, `OrderForm.tsx` |
| Test files | `<Component>.test.tsx` | `OrderList.test.tsx` |
| CSS classes | Tailwind utility classes only | `className="flex items-center gap-4"` |
| API snake_case → TS camelCase | Always transform | `total_amount` → `totalAmount` |

## camelCase ↔ snake_case Transformation

Django returns snake_case. Always transform at the service layer or via Axios response interceptor.

Add to `api.ts` response interceptor (or use `axios-case-converter`):
```typescript
import { camelizeKeys, decamelizeKeys } from 'humps'

// In request interceptor — convert payload to snake_case
config.data = decamelizeKeys(config.data)

// In response interceptor — convert response to camelCase
response.data = camelizeKeys(response.data)
```
