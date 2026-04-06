// assets/templates/shared-components.tsx
// Load this file ONLY when scaffolding src/components/shared/ for the first time.

import React from 'react'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { cn } from '@/lib/utils'

// ─── LoadingSpinner ───────────────────────────────────────────────────────────
interface SpinnerProps { fullPage?: boolean; className?: string }
export const LoadingSpinner = React.memo<SpinnerProps>(({ fullPage, className }) => {
  const spinner = <div data-testid="loading-spinner"
    className={cn('animate-spin rounded-full h-8 w-8 border-b-2 border-primary', className)} />
  return fullPage
    ? <div className="flex items-center justify-center min-h-screen">{spinner}</div>
    : spinner
})
LoadingSpinner.displayName = 'LoadingSpinner'

// ─── ErrorBanner ──────────────────────────────────────────────────────────────
interface ErrorProps { message: string; inline?: boolean; className?: string }
export const ErrorBanner = React.memo<ErrorProps>(({ message, inline, className }) =>
  inline
    ? <p className={cn('text-sm text-destructive', className)}>{message}</p>
    : <Alert variant="destructive" className={className}>
        <AlertDescription>{message}</AlertDescription>
      </Alert>
)
ErrorBanner.displayName = 'ErrorBanner'

// ─── EmptyState ───────────────────────────────────────────────────────────────
interface EmptyProps { title: string; description?: string; actionLabel?: string; onAction?: () => void }
export const EmptyState = React.memo<EmptyProps>(({ title, description, actionLabel, onAction }) => (
  <div className="flex flex-col items-center justify-center py-16 gap-3 text-center">
    <p className="text-lg font-medium">{title}</p>
    {description && <p className="text-xs text-muted-foreground">{description}</p>}
    {actionLabel && onAction &&
      <button onClick={onAction} className="text-sm underline text-primary">{actionLabel}</button>}
  </div>
))
EmptyState.displayName = 'EmptyState'

// ─── PageHeader ───────────────────────────────────────────────────────────────
interface HeaderProps { title: string; subtitle?: string; action?: React.ReactNode }
export const PageHeader = React.memo<HeaderProps>(({ title, subtitle, action }) => (
  <div className="flex items-start justify-between mb-6">
    <div className="space-y-1">
      <h2 className="text-2xl font-semibold tracking-tight">{title}</h2>
      {subtitle && <p className="text-xs text-muted-foreground">{subtitle}</p>}
    </div>
    {action && <div>{action}</div>}
  </div>
))
PageHeader.displayName = 'PageHeader'

// ─── Modal ────────────────────────────────────────────────────────────────────
interface ModalProps { open: boolean; onClose: () => void; title: string; description?: string; children: React.ReactNode }
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

// ─── DataTable ────────────────────────────────────────────────────────────────
interface Column<T> { key: string; header: string; render: (row: T) => React.ReactNode }
interface TableProps<T> {
  columns: Column<T>[]; data: T[]; loading?: boolean
  emptyTitle?: string; emptyDescription?: string
  keyExtractor: (row: T) => string
}
export const DataTable = React.memo(<T,>({
  columns, data, loading, emptyTitle='No data', emptyDescription, keyExtractor
}: TableProps<T>) => {
  if (loading) return <LoadingSpinner />
  if (!data.length) return <EmptyState title={emptyTitle} description={emptyDescription} />
  return (
    <Table>
      <TableHeader>
        <TableRow>{columns.map(c => <TableHead key={c.key}>{c.header}</TableHead>)}</TableRow>
      </TableHeader>
      <TableBody>
        {data.map(row => (
          <TableRow key={keyExtractor(row)}>
            {columns.map(c => <TableCell key={c.key}>{c.render(row)}</TableCell>)}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}) as <T>(props: TableProps<T>) => JSX.Element
