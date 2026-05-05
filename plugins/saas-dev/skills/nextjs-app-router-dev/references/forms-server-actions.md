# Next.js App Router: Forms — Server Actions vs RHF+Zod

## Decision rule

```
Does the form need:
  - Real-time field validation as user types? → RHF + Zod (Client Component)
  - Complex multi-step logic?                 → RHF + Zod (Client Component)
  - Simple mutation (1-2 fields)?             → Server Action (simpler)
  - Progressive enhancement (works without JS)? → Server Action
```

For SaaS dashboards with complex forms: **RHF + Zod (Client Component)** is almost always correct.
Server Actions are good for simple settings toggles, quick status updates.

---

## Pattern A — RHF + Zod (recommended for complex forms)

```tsx
// components/jobs/CreateJobForm.tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { useCallback } from 'react'
import { apiClient, ApiError } from '@/lib/api-client'
import { useToastStore } from '@/stores/toastStore'

const schema = z.object({
  vehicle:      z.string().uuid('Please select a vehicle'),
  description:  z.string().min(10, 'Minimum 10 characters'),
  total_amount: z.string().refine(v => Number(v) > 0, { message: 'Must be positive' }),
})
type FormValues = z.infer<typeof schema>

interface Props { onSuccess: () => void }

export function CreateJobForm({ onSuccess }: Props) {
  const { addToast } = useToastStore()
  const {
    register, handleSubmit, setError, reset,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({ resolver: zodResolver(schema) })

  const onSubmit = useCallback(async (data: FormValues) => {
    try {
      await apiClient.post('/jobs', data)
      addToast('Job card created', 'success')
      reset()
      onSuccess()
    } catch (err) {
      if (err instanceof ApiError && err.errors) {
        Object.entries(err.errors).forEach(([field, msgs]: [string, any]) => {
          setError(field as keyof FormValues, { type: 'server', message: msgs[0] })
        })
      } else {
        addToast((err as ApiError)?.message ?? 'Failed to create job', 'error')
      }
    }
  }, [addToast, onSuccess, reset, setError])

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <input {...register('vehicle')} placeholder="Vehicle ID"
          className="w-full border rounded-lg p-2 text-sm" />
        {errors.vehicle && <p className="text-red-600 text-xs mt-1">{errors.vehicle.message}</p>}
      </div>
      <div>
        <textarea {...register('description')} rows={3}
          className="w-full border rounded-lg p-2 text-sm" />
        {errors.description && <p className="text-red-600 text-xs mt-1">{errors.description.message}</p>}
      </div>
      <div>
        <input {...register('total_amount')} type="number" step="0.01"
          className="w-full border rounded-lg p-2 text-sm" />
        {errors.total_amount && <p className="text-red-600 text-xs mt-1">{errors.total_amount.message}</p>}
      </div>
      <button type="submit" disabled={isSubmitting}
        className="w-full bg-blue-600 text-white rounded-lg py-2 text-sm disabled:opacity-50">
        {isSubmitting ? 'Creating…' : 'Create Job Card'}
      </button>
    </form>
  )
}
```

---

## Pattern B — Server Action (simple mutations only)

```typescript
// app/(dashboard)/jobs/[id]/actions.ts
'use server'
import { revalidatePath } from 'next/cache'
import { djangoFetch } from '@/lib/api'

export async function updateJobStatus(jobId: string, newStatus: string) {
  const res = await djangoFetch(`/api/v1/jobs/${jobId}/`, {
    method: 'PATCH',
    body:   JSON.stringify({ status: newStatus }),
  })

  if (!res.ok) {
    const data = await res.json()
    throw new Error(data.message ?? 'Status update failed')
  }

  // Revalidate the page to show updated data
  revalidatePath(`/jobs/${jobId}`)
}
```

```tsx
// Used in a Client Component
'use client'
import { updateJobStatus } from './actions'
import { useTransition } from 'react'

export function StatusButton({ jobId }: { jobId: string }) {
  const [isPending, startTransition] = useTransition()

  return (
    <button
      onClick={() => startTransition(() => updateJobStatus(jobId, 'in_progress'))}
      disabled={isPending}
    >
      {isPending ? 'Updating…' : 'Start Job'}
    </button>
  )
}
```
