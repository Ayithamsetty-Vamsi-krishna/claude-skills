# Frontend: Animation Patterns

## Rule: CSS-first, JS only when necessary
Most animations should use Tailwind + CSS transitions.
Use Framer Motion only for complex gestures, layout animations, or exit animations.

---

## Tailwind transition utilities (use first — no library needed)

```tsx
// Page/section fade in
<div className="animate-fade-in">...</div>

// Smooth button states
<Button className="transition-all duration-200 hover:scale-105 active:scale-95">
  Submit
</Button>

// Slide-in panel
<div className={`transform transition-transform duration-300
  ${isOpen ? 'translate-x-0' : 'translate-x-full'}`}>
  {/* Sidebar content */}
</div>

// Modal backdrop
<div className={`transition-opacity duration-200
  ${isOpen ? 'opacity-100' : 'opacity-0 pointer-events-none'}`}>
  <div className="bg-black/50 fixed inset-0" />
</div>
```

```css
/* src/styles/animations.css — custom Tailwind animations */
@keyframes fade-in {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}
@keyframes slide-in-right {
  from { transform: translateX(100%); }
  to   { transform: translateX(0); }
}
@keyframes pulse-subtle {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.7; }
}
```

---

## Framer Motion (complex animations only)

```typescript
// Install only when needed: npm install framer-motion
// Use for: layout animations, drag, complex entrance/exit
```

```tsx
// List item enter/exit animations
import { motion, AnimatePresence } from 'framer-motion'

export const AnimatedOrderList = React.memo<{ orders: Order[] }>(({ orders }) => (
  <AnimatePresence mode="popLayout">
    {orders.map(order => (
      <motion.div
        key={order.id}
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, x: -20 }}
        transition={{ duration: 0.2 }}
        layout   // smooth reordering
      >
        <OrderRow order={order} />
      </motion.div>
    ))}
  </AnimatePresence>
))

// Page transitions
const pageVariants = {
  initial: { opacity: 0, x: -20 },
  animate: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: 20 },
}
export const PageWrapper: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <motion.div variants={pageVariants} initial="initial" animate="animate" exit="exit"
              transition={{ duration: 0.2 }}>
    {children}
  </motion.div>
)
```

---

## Loading shimmer (beyond TableSkeleton)

```tsx
// For card/detail page loading — matches layout of the content
export const InvoiceDetailSkeleton = React.memo(() => (
  <div className="animate-pulse space-y-4">
    <div className="flex justify-between">
      <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-48" />
      <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-24" />
    </div>
    <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-full" />
    <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4" />
    <div className="h-32 bg-gray-200 dark:bg-gray-700 rounded" />
  </div>
))
InvoiceDetailSkeleton.displayName = 'InvoiceDetailSkeleton'
```

---

## Toast notifications (non-blocking)

```tsx
// Use shadcn/ui Toaster — already in shared library
// Pattern for consistent toast usage:
import { useToast } from '@/components/ui/use-toast'

const { toast } = useToast()

// Success
toast({ title: 'Invoice approved', description: `Invoice ${code} has been approved.` })

// Error (from API)
toast({ title: err.message, variant: 'destructive' })

// Loading state with update
const { id } = toast({ title: 'Uploading...', duration: Infinity })
// After upload:
toast({ id, title: 'Upload complete', duration: 3000 })
```

---

## Respect reduced motion

```css
/* Always wrap animations in this — accessibility requirement */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

```typescript
// In Framer Motion:
const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
const transition = prefersReducedMotion ? { duration: 0 } : { duration: 0.2 }
```
