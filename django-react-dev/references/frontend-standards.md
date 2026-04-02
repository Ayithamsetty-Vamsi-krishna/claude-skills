# Frontend Standards — React + TypeScript

## Project Structure (Feature-based)

```
frontend/
├── src/
│   ├── app/
│   │   ├── store.ts                  # Redux store configuration
│   │   ├── hooks.ts                  # Typed useAppDispatch / useAppSelector
│   │   └── router.tsx                # React Router config
│   ├── features/
│   │   └── <feature_name>/           # One folder per feature domain
│   │       ├── components/           # Feature-specific UI components
│   │       │   ├── FeatureList.tsx
│   │       │   ├── FeatureForm.tsx
│   │       │   └── FeatureCard.tsx
│   │       ├── pages/                # Route-level page components
│   │       │   └── FeaturePage.tsx
│   │       ├── hooks/                # Feature-specific custom hooks
│   │       │   └── useFeature.ts
│   │       ├── services/             # API call functions for this feature
│   │       │   └── featureService.ts
│   │       ├── store/                # Redux slice for this feature
│   │       │   └── featureSlice.ts
│   │       ├── types/                # TypeScript interfaces for this feature
│   │       │   └── feature.types.ts
│   │       └── tests/
│   │           └── FeatureList.test.tsx
│   ├── shared/
│   │   ├── components/               # App-wide reusable components
│   │   ├── hooks/                    # App-wide custom hooks
│   │   └── utils/                    # Utility functions
│   ├── services/
│   │   └── api.ts                    # Centralized Axios instance
│   └── main.tsx
├── index.html
├── vite.config.ts
└── tsconfig.json
```

---

## TypeScript — Always Typed

Define interfaces for every API response shape in the feature's `types/` folder.

```typescript
// features/orders/types/order.types.ts

export interface Customer {
  id: number;
  name: string;
  email: string;
}

export interface OrderItem {
  id: number;
  productId: number;
  product: { id: number; name: string; price: string };
  quantity: number;
}

export interface Order {
  id: number;
  customerId: number;
  customer: Customer;
  status: "pending" | "confirmed" | "shipped" | "delivered" | "cancelled";
  items: OrderItem[];
  createdAt: string;
  updatedAt: string;
}

export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export interface CreateOrderPayload {
  customerId: number;
  items: { productId: number; quantity: number }[];
}
```

Naming: camelCase variables and interfaces, PascalCase components and type names.

---

## Axios — Centralized API Service

```typescript
// src/services/api.ts
import axios from "axios";

const api = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL,
  headers: { "Content-Type": "application/json" },
});

// Attach JWT access token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem("accessToken");
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Auto-refresh on 401
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const original = error.config;
    if (error.response?.status === 401 && !original._retry) {
      original._retry = true;
      try {
        const refreshToken = localStorage.getItem("refreshToken");
        const { data } = await axios.post("/api/v1/auth/token/refresh/", {
          refresh: refreshToken,
        });
        localStorage.setItem("accessToken", data.access);
        original.headers.Authorization = `Bearer ${data.access}`;
        return api(original);
      } catch {
        localStorage.clear();
        window.location.href = "/login";
      }
    }
    return Promise.reject(error);
  }
);

export default api;
```

---

## Feature Service Layer

Each feature has its own service file that wraps api.ts calls.

```typescript
// features/orders/services/orderService.ts
import api from "@/services/api";
import type { Order, PaginatedResponse, CreateOrderPayload } from "../types/order.types";

export const orderService = {
  list: (params?: Record<string, string>) =>
    api.get<PaginatedResponse<Order>>("/api/v1/orders/", { params }),

  detail: (id: number) =>
    api.get<Order>(`/api/v1/orders/${id}/`),

  create: (payload: CreateOrderPayload) =>
    api.post<Order>("/api/v1/orders/", payload),

  update: (id: number, payload: Partial<CreateOrderPayload>) =>
    api.patch<Order>(`/api/v1/orders/${id}/`, payload),

  remove: (id: number) =>
    api.delete(`/api/v1/orders/${id}/`),
};
```

---

## Redux Toolkit — Slice Pattern

```typescript
// features/orders/store/orderSlice.ts
import { createAsyncThunk, createSlice } from "@reduxjs/toolkit";
import { orderService } from "../services/orderService";
import type { Order, PaginatedResponse } from "../types/order.types";

export const fetchOrders = createAsyncThunk(
  "orders/fetchAll",
  async (params: Record<string, string> | undefined, { rejectWithValue }) => {
    try {
      const { data } = await orderService.list(params);
      return data;
    } catch (err: any) {
      return rejectWithValue(err.response?.data ?? "Failed to fetch orders");
    }
  }
);

interface OrderState {
  items: Order[];
  total: number;
  loading: boolean;
  error: string | null;
}

const initialState: OrderState = {
  items: [],
  total: 0,
  loading: false,
  error: null,
};

const orderSlice = createSlice({
  name: "orders",
  initialState,
  reducers: {
    clearOrders: (state) => { state.items = []; },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchOrders.pending, (state) => {
        state.loading = true;
        state.error = null;
      })
      .addCase(fetchOrders.fulfilled, (state, action) => {
        state.loading = false;
        state.items = action.payload.results;
        state.total = action.payload.count;
      })
      .addCase(fetchOrders.rejected, (state, action) => {
        state.loading = false;
        state.error = action.payload as string;
      });
  },
});

export const { clearOrders } = orderSlice.actions;
export default orderSlice.reducer;
```

---

## Components — shadcn/ui + Tailwind CSS

- Use shadcn/ui primitives (Button, Input, Dialog, Table, Select, etc.)
- Tailwind utility classes only — no inline styles
- Always handle loading and error states

```tsx
// features/orders/components/OrderList.tsx
import { useEffect } from "react";
import { useAppDispatch, useAppSelector } from "@/app/hooks";
import { fetchOrders } from "../store/orderSlice";
import { Skeleton } from "@/components/ui/skeleton";
import { Alert, AlertDescription } from "@/components/ui/alert";

export function OrderList() {
  const dispatch = useAppDispatch();
  const { items, loading, error } = useAppSelector((s) => s.orders);

  useEffect(() => {
    dispatch(fetchOrders());
  }, [dispatch]);

  if (loading) return <Skeleton className="h-64 w-full" />;
  if (error) return (
    <Alert variant="destructive">
      <AlertDescription>{error}</AlertDescription>
    </Alert>
  );
  if (!items.length) return (
    <p className="text-muted-foreground text-sm">No orders found.</p>
  );

  return (
    <ul className="space-y-2">
      {items.map((order) => (
        <li key={order.id} className="rounded-lg border p-4">
          <p className="font-medium">Order #{order.id}</p>
          <p className="text-sm text-muted-foreground">{order.customer.name}</p>
        </li>
      ))}
    </ul>
  );
}
```

---

## Naming Conventions

| Thing | Convention |
|---|---|
| Variables / functions | camelCase |
| Components | PascalCase |
| Files (components) | PascalCase.tsx |
| Files (services, hooks, utils) | camelCase.ts |
| TypeScript interfaces | PascalCase |
| Redux actions | `feature/actionName` |
| CSS | Tailwind classes only |
