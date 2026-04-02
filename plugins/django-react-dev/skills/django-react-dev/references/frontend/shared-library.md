# Frontend: Shared Component Library

**Golden rule:** Use ONLY these components for UI. Never reimplement inline.
All live in `src/components/shared/`. Import from `@/components/shared`.

## index.ts (barrel export)
```typescript
export { Text } from './Text'
export { Button } from './Button'
export { FormField } from './FormField'
export { StatusBadge } from './StatusBadge'
export { DataTable } from './DataTable'
export { Modal } from './Modal'
export { PageHeader } from './PageHeader'
export { EmptyState } from './EmptyState'
export { LoadingSpinner } from './LoadingSpinner'
export { ErrorBanner } from './ErrorBanner'
```

## Text — Typography System
```tsx
import React from 'react'
import { cn } from '@/lib/utils'

type Variant = 'h1'|'h2'|'h3'|'h4'|'body'|'body-sm'|'caption'|'label'

const styles: Record<Variant,string> = {
  h1:'text-3xl font-bold tracking-tight', h2:'text-2xl font-semibold tracking-tight',
  h3:'text-xl font-semibold', h4:'text-lg font-medium',
  body:'text-sm text-foreground', 'body-sm':'text-xs text-foreground',
  caption:'text-xs text-muted-foreground', label:'text-sm font-medium',
}
const tag: Record<Variant,keyof JSX.IntrinsicElements> = {
  h1:'h1',h2:'h2',h3:'h3',h4:'h4',body:'p','body-sm':'p',caption:'span',label:'span'
}

interface TextProps { variant?:Variant; children:React.ReactNode; className?:string; as?:keyof JSX.IntrinsicElements }
export const Text = React.memo<TextProps>(({ variant='body', children, className, as }) => {
  const Tag = as ?? tag[variant]
  return <Tag className={cn(styles[variant], className)}>{children}</Tag>
})
Text.displayName = 'Text'
```

## Button — Wrapped with loading state
```tsx
import React from 'react'
import { Button as Shadcn, ButtonProps } from '@/components/ui/button'
import { LoadingSpinner } from './LoadingSpinner'

interface Props extends ButtonProps { loading?: boolean }
export const Button = React.memo<Props>(({ loading, children, disabled, ...p }) => (
  <Shadcn disabled={disabled || loading} {...p}>
    {loading && <LoadingSpinner className="h-4 w-4 mr-2" />}
    {children}
  </Shadcn>
))
Button.displayName = 'Button'
```

## FormField — Input + Label + Error
```tsx
import React from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { ErrorBanner } from './ErrorBanner'
import { cn } from '@/lib/utils'

interface Props extends React.InputHTMLAttributes<HTMLInputElement> { label:string; name:string; error?:string }
export const FormField = React.memo<Props>(({ label, name, error, className, ...p }) => (
  <div className={cn('space-y-1', className)}>
    <Label htmlFor={name}>{label}</Label>
    <Input id={name} name={name} aria-invalid={!!error} {...p} />
    {error && <ErrorBanner message={error} inline />}
  </div>
))
FormField.displayName = 'FormField'
```

## StatusBadge
```tsx
import React from 'react'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

const map: Record<string,string> = {
  active:'bg-green-100 text-green-800', inactive:'bg-gray-100 text-gray-600',
  pending:'bg-yellow-100 text-yellow-800', confirmed:'bg-blue-100 text-blue-800',
  cancelled:'bg-red-100 text-red-800', deleted:'bg-red-200 text-red-900',
}
export const StatusBadge = React.memo<{status:string; className?:string}>(({status,className}) => (
  <Badge className={cn(map[status]??'bg-gray-100 text-gray-600', className)}>
    {status.charAt(0).toUpperCase()+status.slice(1)}
  </Badge>
))
StatusBadge.displayName = 'StatusBadge'
```

## DataTable, Modal, PageHeader, EmptyState, LoadingSpinner, ErrorBanner
See `assets/templates/shared-components.tsx` for full implementations.
Load that file only when scaffolding the shared library for the first time.

---

## React Router — Protected Route Pattern

Install: `npm install react-router-dom`

Every new page feature needs a route registered here. Never add routes in feature folders.

```typescript
// src/app/router.tsx
import { createBrowserRouter, Navigate, Outlet } from 'react-router-dom'

// Protected wrapper — redirects to /login if no token
const ProtectedRoute: React.FC = () => {
  const token = localStorage.getItem('access_token')
  return token ? <Outlet /> : <Navigate to="/login" replace />
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: <ProtectedRoute />,
    children: [
      { index: true, element: <Navigate to="/dashboard" replace /> },
      { path: 'dashboard', element: <DashboardPage /> },
      { path: 'orders', element: <OrderList /> },
      { path: 'orders/:id', element: <OrderDetail /> },
      // ← Add new feature routes here
    ],
  },
  { path: '/login', element: <LoginPage /> },
  { path: '*', element: <Navigate to="/" replace /> },
])
```

**Rule:** When adding a new feature, always add the route to `router.tsx` as part of the feature task plan. This is a mandatory sub-task for any page-level component.

---

## TableSkeleton — Loading Skeleton Pattern

Use this instead of `<LoadingSpinner />` on list/table pages. Users see the layout before data arrives.

```tsx
// src/components/shared/TableSkeleton.tsx
import React from 'react'
import { Skeleton } from '@/components/ui/skeleton'

interface TableSkeletonProps {
  rows?: number
  columns?: number
}

export const TableSkeleton = React.memo<TableSkeletonProps>(({ rows = 5, columns = 4 }) => (
  <div className="space-y-3">
    {/* Header row */}
    <div className="flex gap-4">
      {Array.from({ length: columns }).map((_, i) => (
        <Skeleton key={i} className="h-4 flex-1 rounded" />
      ))}
    </div>
    {/* Data rows */}
    {Array.from({ length: rows }).map((_, i) => (
      <div key={i} className="flex gap-4">
        {Array.from({ length: columns }).map((_, j) => (
          <Skeleton key={j} className="h-10 flex-1 rounded" />
        ))}
      </div>
    ))}
  </div>
))
TableSkeleton.displayName = 'TableSkeleton'
```

Add to `DataTable` component — use `TableSkeleton` not `LoadingSpinner` for table loading states:
```tsx
if (loading) return <TableSkeleton rows={5} columns={columns.length} />
```

Add `TableSkeleton` to `shared/index.ts` barrel export.

**Rule:**
- List/table pages → `<TableSkeleton />` for loading state
- Full-page transitions → `<LoadingSpinner fullPage />` for loading state
- Inline/button loading → `<LoadingSpinner className="h-4 w-4" />` inside `<Button loading>`
