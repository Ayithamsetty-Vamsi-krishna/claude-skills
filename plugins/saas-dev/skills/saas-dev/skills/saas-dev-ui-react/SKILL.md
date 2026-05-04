---
name: saas-dev-ui-react
description: "Premium React + Next.js UI/UX skill for saas-dev. Activates on every React/Next.js frontend task. Generates complete design system then builds futuristic, production-grade components — glassmorphism, aurora, neumorphism, bento grid, animated landing pages, dashboards, forms. Integrates ui-ux-pro-max if installed."
triggers:
  - "React component"
  - "Next.js page"
  - "landing page"
  - "dashboard"
  - "frontend"
  - "UI component"
  - "web UI"
---

# saas-dev UI: React + Next.js Design Engine

You are a world-class React/Next.js UI engineer. Every web frontend task in saas-dev runs through this skill.

---

## Step 1: Check for ui-ux-pro-max

```
IF ui-ux-pro-max installed AND design-system/MASTER.md exists:
  → Read MASTER.md — use as primary design source
  → Tell user: "Using ui-ux-pro-max design engine"

ELSE:
  → Use this skill's built-in design system (Step 2)
  → After completing the task, suggest:
    "Install ui-ux-pro-max for 67 styles + 161 palettes:
     /plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill"
```

---

## Step 2: Generate Design System (BEFORE writing any component)

Detect product type from CLAUDE.md + PRD, then select style:

| Product Type | Style | Color Direction |
|---|---|---|
| SaaS / B2B Dashboard | Neumorphism or Swiss Minimalism | Navy/Slate + accent |
| Fintech / Banking | Dark Glassmorphism | Deep navy + gold/green |
| Healthcare | Clean Minimalism | White + blue/teal |
| E-commerce | Bento Grid or Flat Modern | Brand color + neutral |
| Creative / Portfolio | Aurora or Glassmorphism | Bold gradient + dark bg |
| Landing Page | Futuristic Glassmorphism or Aurora | Vivid gradient + dark |
| Admin Panel | Compact Minimalism | Gray + accent |
| Consumer / Social | Claymorphism | Vibrant + rounded |

Output this before any code:

```
DESIGN SYSTEM: [Feature Name]
Style: [chosen style]
Primary: #[hex]    Secondary: #[hex]    Accent: #[hex]
Background: #[hex]  Surface: #[hex]     Text: #[hex]  Muted: #[hex]
Heading font: [Google Font] — 600, 700
Body font: [Google Font] — 400, 500
Spacing: 4 / 8 / 16 / 24 / 32 / 48 / 64px
Radius: 6 / 12 / 20 / 28 / 9999px
Animations: 150ms fast / 250ms normal / 400ms slow
Easing: cubic-bezier(0.4,0,0.2,1) smooth / cubic-bezier(0.34,1.56,0.64,1) bounce
```

---

## Step 3: Required Stack

Always use these — no exceptions:

```json
{
  "tailwindcss": "utility classes — no raw CSS unless unavoidable",
  "framer-motion": "ALL animations — never CSS keyframes for complex motion",
  "lucide-react": "icons — consistent, clean",
  "react-hook-form": "forms — already in saas-dev",
  "@hookform/resolvers/zod": "validation — already in saas-dev",
  "@reduxjs/toolkit": "state — already in saas-dev",
  "recharts": "charts — custom styled tooltips"
}
```

---

## Step 4: Premium UI Patterns

### Glassmorphism (use for cards, modals, hero sections)
```tsx
// Glass card
<div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl
                shadow-[0_8px_32px_rgba(0,0,0,0.12)]">

// Glass nav
<nav className="fixed top-0 w-full bg-black/20 backdrop-blur-2xl
                border-b border-white/10 z-50">
```

### Aurora Gradient (use for hero backgrounds, CTAs)
```tsx
// Aurora bg
<div className="bg-gradient-to-br from-[#0f0c29] via-[#302b63] to-[#24243e]
                relative overflow-hidden">
  {/* Orbs */}
  <div className="absolute top-1/4 left-1/4 w-96 h-96 rounded-full
                  bg-purple-500/20 blur-3xl animate-pulse" />
  <div className="absolute bottom-1/4 right-1/4 w-80 h-80 rounded-full
                  bg-blue-500/20 blur-3xl animate-pulse delay-1000" />
```

### Gradient Text (use for headings, hero titles)
```tsx
<h1 className="bg-gradient-to-r from-[primary] via-[accent] to-[secondary]
               bg-clip-text text-transparent font-bold">
```

### Animated Card (use for feature cards, pricing)
```tsx
<motion.div
  whileHover={{ scale: 1.02, y: -4 }}
  transition={{ type: "spring", stiffness: 400, damping: 17 }}
  className="cursor-pointer"
>
```

### Staggered List (use for feature lists, team grids)
```tsx
const container = { hidden: {}, show: { transition: { staggerChildren: 0.08 } } }
const item = { hidden: { opacity: 0, y: 20 }, show: { opacity: 1, y: 0 } }

<motion.ul variants={container} initial="hidden" animate="show">
  {items.map(i => <motion.li key={i.id} variants={item} />)}
</motion.ul>
```

### Skeleton Shimmer (use for ALL loading states)
```tsx
<div className="animate-pulse space-y-3">
  <div className="h-4 bg-white/10 rounded-full w-3/4" />
  <div className="h-4 bg-white/10 rounded-full w-1/2" />
</div>
```

---

## Step 5: Page-Type Rules

### Landing Page (always these sections unless PRD says otherwise)

1. **Hero** — full-viewport, aurora/glass bg, animated headline, orbs, CTA with glow
2. **Social proof** — logo strip or testimonial cards
3. **Features** — bento grid or 3-col card grid, icons, short descriptions
4. **How it works** — 3-step numbered process with connecting line
5. **Pricing** — 2-3 tier cards, highlight recommended, annual/monthly toggle
6. **FAQ** — accordion, 5-8 questions
7. **Final CTA** — bold section before footer
8. **Footer** — logo + tagline + organized link columns + social icons

**Hero must have:**
- Animated entrance: `initial={{ opacity:0, y:30 }} animate={{ opacity:1, y:0 }}`
- Staggered children: headline → subtitle → CTA (80ms apart)
- CTA button: glow shadow on hover `hover:shadow-[0_0_30px_rgba(primary,0.5)]`
- Visual element: screenshot with `perspective-1000 rotateX-6` tilt on hover

### Dashboard
- Sidebar: collapsible, `w-64` expanded / `w-16` collapsed, smooth width transition
- Active nav item: `bg-primary/10 text-primary border-r-2 border-primary`
- Stats row: metric cards with `TrendingUp/Down` icons, percentage change
- Charts: recharts with custom `<Tooltip>` styled with glass effect
- Tables: sticky header, row hover `hover:bg-white/5`, checkbox selection

### Forms
- Floating labels: animate up on focus with `framer-motion`
- Real-time Zod validation: show error after 500ms debounce
- Submit button: `disabled` + spinner while loading
- Success: green border transition + checkmark animation
- Error: red border + gentle `x: [0, -8, 8, -4, 4, 0]` shake animation

---

## Step 6: Every Component Must Have

```tsx
// 1. Loading state
if (isLoading) return <ComponentSkeleton />

// 2. Error state
if (error) return (
  <div className="...glass-card text-center p-8">
    <AlertCircle className="mx-auto mb-3 text-red-400" size={32} />
    <p className="text-muted">Something went wrong</p>
    <button onClick={refetch} className="...btn-secondary mt-4">Retry</button>
  </div>
)

// 3. Empty state
if (!data?.length) return (
  <div className="...glass-card text-center p-12">
    <InboxIcon className="mx-auto mb-3 text-muted/50" size={48} />
    <p className="text-muted">No [items] yet</p>
    <button onClick={onCreate} className="...btn-primary mt-4">Create first [item]</button>
  </div>
)

// 4. Accessible
aria-label="..." role="..." tabIndex={0} onKeyDown={...}

// 5. Responsive
className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"
```

---

## Step 7: Quality Gates

Before marking any frontend task DONE:

**Visual:**
- [ ] Matches design reference (if designs/ file provided)
- [ ] Uses design system colors/fonts/spacing (no hardcoded values)
- [ ] Loading state present
- [ ] Empty state present
- [ ] Error state present
- [ ] Responsive: 320px / 768px / 1024px / 1440px

**Animation:**
- [ ] All transitions use design system tokens
- [ ] No layout shift during load (skeletons reserve space)
- [ ] Hover states < 200ms

**Code:**
- [ ] No hardcoded colors — use design tokens or Tailwind config
- [ ] Components < 200 lines (split if larger)
- [ ] Tests: renders, loading, error, user interaction
- [ ] No `any` TypeScript types

---

## Integration with saas-dev

This skill loads for every React/Next.js frontend task during execution.
Subagent receives: this skill + design system output + design reference file (if exists in designs/).
Quality gates enforced before subagent marks task DONE.
