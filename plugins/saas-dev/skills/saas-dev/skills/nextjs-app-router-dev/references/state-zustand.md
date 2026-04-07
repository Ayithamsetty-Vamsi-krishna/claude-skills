# Next.js App Router: State Management — Zustand

## Why Zustand, not Redux, for App Router

Redux requires wrapping the entire app in `<Provider>` which forces the root layout
to be a Client Component — this defeats Server Component benefits entirely.
Zustand stores are imported directly in Client Components with no Provider wrapper needed.

**Rule:** Zustand is for CLIENT-side UI state only.
Server data comes from Server Components via fetch() → props → Client Components.
Do not duplicate server data in Zustand — just use it as passed.

---

## Install

```bash
npm install zustand
```

---

## Store pattern — Client Component state

```typescript
// src/stores/jobsStore.ts
import { create } from 'zustand'
import type { JobCard } from '@/types'

interface JobsStore {
  // UI state only — not server data
  selectedJobId:   string | null
  isCreateModalOpen: boolean
  statusFilter:    string

  // Actions
  selectJob:       (id: string | null) => void
  openCreateModal: () => void
  closeCreateModal: () => void
  setStatusFilter: (status: string) => void
}

export const useJobsStore = create<JobsStore>((set) => ({
  selectedJobId:     null,
  isCreateModalOpen: false,
  statusFilter:      '',

  selectJob:       (id) => set({ selectedJobId: id }),
  openCreateModal: ()   => set({ isCreateModalOpen: true }),
  closeCreateModal: ()  => set({ isCreateModalOpen: false }),
  setStatusFilter: (status) => set({ statusFilter: status }),
}))
```

---

## Using Zustand in Client Components

```tsx
// components/jobs/JobsToolbar.tsx
'use client'
import { useJobsStore } from '@/stores/jobsStore'

export function JobsToolbar() {
  const { isCreateModalOpen, openCreateModal, statusFilter, setStatusFilter }
    = useJobsStore()

  return (
    <div className="flex items-center gap-4">
      <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)}>
        <option value="">All statuses</option>
        <option value="pending">Pending</option>
        <option value="in_progress">In Progress</option>
        <option value="completed">Completed</option>
      </select>
      <button onClick={openCreateModal}>+ New Job</button>
    </div>
  )
}
```

---

## Pattern: Server Component fetches, Client Component manages UI state

```tsx
// app/(dashboard)/jobs/page.tsx — Server Component
import { djangoGet } from '@/lib/api'
import { JobsView } from './JobsView'   // Client Component

export default async function JobsPage() {
  // Server-side fetch (cached for 0s — always fresh)
  const { results: jobs, count } = await djangoGet('/api/v1/jobs/')

  return <JobsView initialJobs={jobs} totalCount={count} />
}

// app/(dashboard)/jobs/JobsView.tsx — Client Component
'use client'
import { useJobsStore } from '@/stores/jobsStore'
import type { JobCard } from '@/types'

interface Props {
  initialJobs: JobCard[]
  totalCount:  number
}

export function JobsView({ initialJobs, totalCount }: Props) {
  const { statusFilter, isCreateModalOpen, closeCreateModal } = useJobsStore()

  // Client-side filter — no refetch needed for filter change
  const filtered = initialJobs.filter(
    j => !statusFilter || j.status === statusFilter
  )

  return (
    <div>
      {/* JobsToolbar updates Zustand store */}
      <JobsToolbar />
      {/* Table renders filtered subset */}
      <JobTable jobs={filtered} />
      {/* Modal controlled by Zustand */}
      {isCreateModalOpen && <CreateJobModal onClose={closeCreateModal} />}
    </div>
  )
}
```

---

## Auth store (minimal — most auth lives in cookies/NextAuth)

```typescript
// src/stores/authStore.ts
import { create } from 'zustand'

interface AuthStore {
  userType: string | null
  setUserType: (type: string) => void
  clearAuth:   () => void
}

export const useAuthStore = create<AuthStore>((set) => ({
  userType:    null,
  setUserType: (type) => set({ userType: type }),
  clearAuth:   ()     => set({ userType: null }),
}))
```

---

## What NOT to put in Zustand

```typescript
// ✗ Don't cache server data in Zustand — it goes stale
const useJobsStore = create(set => ({
  jobs: [],         // ← this is server data — don't cache here
  fetchJobs: async () => { ... }  // ← data fetching belongs in Server Components
}))

// ✓ Server data → fetched by Server Components → passed as props
// ✓ Zustand → UI state only (modals, filters, selections, toasts)
```

---

## Toast / notification store (global UI state)

```typescript
// src/stores/toastStore.ts
import { create } from 'zustand'
import { nanoid } from 'nanoid'

interface Toast {
  id:      string
  message: string
  type:    'success' | 'error' | 'info'
}

interface ToastStore {
  toasts:    Toast[]
  addToast:  (message: string, type?: Toast['type']) => void
  removeToast: (id: string) => void
}

export const useToastStore = create<ToastStore>((set) => ({
  toasts: [],
  addToast: (message, type = 'info') =>
    set(s => ({
      toasts: [...s.toasts, { id: nanoid(), message, type }]
    })),
  removeToast: (id) =>
    set(s => ({ toasts: s.toasts.filter(t => t.id !== id) })),
}))
```
