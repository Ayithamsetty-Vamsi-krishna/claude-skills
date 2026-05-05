# Frontend: Multi-Step Wizard Forms

---

## Pattern — React Hook Form + Zod per step

```typescript
// src/features/onboarding/types.ts
import { z } from 'zod'

// Each step has its own Zod schema
export const Step1Schema = z.object({
  companyName: z.string().min(2, 'Company name must be at least 2 characters'),
  industry: z.string().min(1, 'Please select an industry'),
})

export const Step2Schema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
  email: z.string().email('Please enter a valid email'),
  phone: z.string().regex(/^\+?[0-9]{10,15}$/, 'Please enter a valid phone number'),
})

export const Step3Schema = z.object({
  plan: z.enum(['starter', 'professional', 'enterprise']),
  billingCycle: z.enum(['monthly', 'annual']),
})

// Combined schema for final submission
export const OnboardingSchema = Step1Schema.merge(Step2Schema).merge(Step3Schema)
export type OnboardingData = z.infer<typeof OnboardingSchema>
```

```tsx
// src/features/onboarding/OnboardingWizard.tsx
import React, { useState, useCallback } from 'react'
import { useForm, FormProvider } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { Step1Schema, Step2Schema, Step3Schema, OnboardingData } from './types'

const STEPS = [
  { id: 1, title: 'Company', schema: Step1Schema },
  { id: 2, title: 'Contact', schema: Step2Schema },
  { id: 3, title: 'Plan', schema: Step3Schema },
]

export const OnboardingWizard = React.memo(() => {
  const [currentStep, setCurrentStep] = useState(0)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const dispatch = useAppDispatch()

  const methods = useForm<OnboardingData>({
    resolver: zodResolver(STEPS[currentStep].schema),
    mode: 'onTouched',
    defaultValues: {
      companyName: '', industry: '',
      firstName: '', lastName: '', email: '', phone: '',
      plan: 'starter', billingCycle: 'monthly',
    },
  })

  const { handleSubmit, trigger, getValues, setError, formState: { errors } } = methods

  const handleNext = useCallback(async () => {
    // Validate only current step fields
    const currentFields = Object.keys(STEPS[currentStep].schema.shape) as (keyof OnboardingData)[]
    const isValid = await trigger(currentFields)
    if (isValid) setCurrentStep(s => s + 1)
  }, [currentStep, trigger])

  const handleBack = useCallback(() => {
    setCurrentStep(s => s - 1)
  }, [])

  const onSubmit = useCallback(async (data: OnboardingData) => {
    setIsSubmitting(true)
    try {
      await dispatch(submitOnboarding(data)).unwrap()
    } catch (err: unknown) {
      if (isApiError(err)) {
        // Map server errors back to the right step's fields
        Object.entries(err.errors).forEach(([field, messages]) => {
          setError(field as keyof OnboardingData, { type: 'server', message: messages[0] })
        })
        // Navigate to the step that has the error
        const errorFields = Object.keys(err.errors)
        for (let i = 0; i < STEPS.length; i++) {
          const stepFields = Object.keys(STEPS[i].schema.shape)
          if (errorFields.some(f => stepFields.includes(f))) {
            setCurrentStep(i)
            break
          }
        }
      }
    } finally {
      setIsSubmitting(false)
    }
  }, [dispatch, setError])

  const isLastStep = currentStep === STEPS.length - 1

  return (
    <FormProvider {...methods}>
      <div className="max-w-xl mx-auto">
        {/* Step indicator */}
        <div className="flex items-center justify-between mb-8">
          {STEPS.map((step, idx) => (
            <div key={step.id} className="flex items-center">
              <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium
                ${idx < currentStep ? 'bg-green-600 text-white' :
                  idx === currentStep ? 'bg-blue-600 text-white' :
                  'bg-gray-200 text-gray-600'}`}>
                {idx < currentStep ? '✓' : step.id}
              </div>
              <span className="ml-2 text-sm text-gray-600">{step.title}</span>
              {idx < STEPS.length - 1 && <div className="w-16 h-px bg-gray-300 mx-4" />}
            </div>
          ))}
        </div>

        {/* Step content */}
        <form onSubmit={handleSubmit(onSubmit)}>
          {currentStep === 0 && <Step1Fields />}
          {currentStep === 1 && <Step2Fields />}
          {currentStep === 2 && <Step3Fields />}

          {/* Navigation */}
          <div className="flex justify-between mt-8">
            {currentStep > 0 && (
              <Button type="button" variant="outline" onClick={handleBack}>Back</Button>
            )}
            {isLastStep ? (
              <Button type="submit" loading={isSubmitting} className="ml-auto">
                Complete Setup
              </Button>
            ) : (
              <Button type="button" onClick={handleNext} className="ml-auto">
                Next
              </Button>
            )}
          </div>
        </form>
      </div>
    </FormProvider>
  )
})
OnboardingWizard.displayName = 'OnboardingWizard'
```

---

## Persisting wizard state (survive page refresh)

```typescript
// Store wizard progress in Redux — persisted via redux-persist if needed
// wizardSlice.ts
const wizardSlice = createSlice({
  name: 'wizard',
  initialState: { step: 0, data: {} as Partial<OnboardingData> },
  reducers: {
    saveStepData: (state, action) => {
      state.data = { ...state.data, ...action.payload }
    },
    setStep: (state, action) => { state.step = action.payload },
    resetWizard: () => ({ step: 0, data: {} }),
  },
})
```
