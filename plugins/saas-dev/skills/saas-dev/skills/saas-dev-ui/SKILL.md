---
name: saas-dev-ui
description: "Premium UI/UX design skill for saas-dev. Activates before any frontend task. Generates complete design system (style, colors, typography, spacing, animations) using ui-ux-pro-max patterns. Supports React/Next.js + Flutter. Produces futuristic, production-grade UI — glassmorphism, aurora, bento grid, neumorphism, brutalism and more. All frontend subagents load this skill."
triggers:
  - "landing page"
  - "frontend"
  - "UI"
  - "component"
  - "page design"
  - "Flutter"
  - "mobile"
  - "dashboard"
  - "design system"
---

# saas-dev UI/UX Design Engine

You are a world-class UI/UX engineer. Every frontend task in saas-dev runs through this skill first.

**Powered by:** ui-ux-pro-max design intelligence patterns
**Stacks supported:** React + Next.js (web) + Flutter (mobile/cross-platform)

---

## Step 1: Check for ui-ux-pro-max

Before generating any UI, check if the ui-ux-pro-max skill is installed:

```
IF ui-ux-pro-max is available in this project:
  → Load it: read design-system/MASTER.md if it exists
  → Use it as your design intelligence source
  → Tell user: "Using ui-ux-pro-max design engine for this feature"

IF ui-ux-pro-max is NOT installed:
  → Use this skill's built-in design system (below)
  → Recommend to user: "Install ui-ux-pro-max for 67 styles + 161 palettes:
    /plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill"
```

---

## Step 2: Generate Design System for This Feature

Before writing any component code, generate a design system tailored to the feature.
Use ask_user_input_v0 for design decisions you cannot infer from the PRD/designs.

### 2A — Detect Product Type (from PRD + CLAUDE.md)

Map the app to a product category to choose appropriate style:

| Product Type | Recommended Style | Color Direction |
|---|---|---|
| SaaS / B2B Dashboard | Neumorphism or Swiss Minimalism | Navy/Slate + accent |
| Fintech / Banking | Swiss Minimalism or Dark Glassmorphism | Deep navy + gold/green |
| Healthcare | Clean Minimalism | White + blue/teal |
| E-commerce | Bento Grid or Flat Modern | Brand color + neutral |
| Creative / Portfolio | Glassmorphism or Aurora | Gradient + dark bg |
| Landing Page | Futuristic Glassmorphism or Aurora | Bold gradient + dark |
| Admin Panel | Compact Minimalism | Gray + accent |
| Mobile App | Claymorphism or Neumorphism | Vibrant + clean |

### 2B — Design System Output (generate this BEFORE any component)

```markdown
# Design System: [Feature Name]

## Style
[Chosen style: e.g. Glassmorphism, Neumorphism, Aurora, Bento Grid, Swiss Minimalism]

## Color Palette
Primary:   #[hex]   — main brand/action color
Secondary: #[hex]   — supporting color
Accent:    #[hex]   — highlight / CTA color
Background:#[hex]   — page background
Surface:   #[hex]   — card/panel background
Text:      #[hex]   — primary text
Text Muted:#[hex]   — secondary text
Success:   #[hex]
Warning:   #[hex]
Error:     #[hex]

## Typography
Heading font: [Google Font name] — weights 600, 700
Body font:    [Google Font name] — weights 400, 500
Mono font:    [Google Font name] — weight 400

## Spacing Scale
xs: 4px  | sm: 8px | md: 16px | lg: 24px | xl: 32px | 2xl: 48px | 3xl: 64px

## Border Radius
sm: 6px | md: 12px | lg: 20px | xl: 28px | full: 9999px

## Shadows (style-specific)
[e.g. for Glassmorphism:]
card: 0 8px 32px rgba(0,0,0,0.12), 0 2px 8px rgba(0,0,0,0.08)
glow: 0 0 40px rgba([primary-rgb], 0.3)
inner: inset 0 1px 0 rgba(255,255,255,0.1)

## Blur / Glass Effects (if Glassmorphism)
backdrop-filter: blur(20px)
background: rgba(255,255,255,0.05)
border: 1px solid rgba(255,255,255,0.1)

## Animation Tokens
duration-fast:   150ms
duration-normal: 250ms
duration-slow:   400ms
easing-smooth:   cubic-bezier(0.4, 0, 0.2, 1)
easing-bounce:   cubic-bezier(0.34, 1.56, 0.64, 1)
easing-spring:   cubic-bezier(0.175, 0.885, 0.32, 1.275)

## Motion Principles
- All interactive elements: smooth transitions (250ms ease)
- Page transitions: fade + slide (400ms)
- Loading states: skeleton shimmer animation
- Hover states: subtle scale (1.02) + shadow elevation
- Focus states: colored ring (primary color, 2px offset)
- Error states: gentle shake animation
- Success states: pulse + checkmark animation
```

---

## Step 3: Stack-Specific Implementation

### React + Next.js Frontend

**Core libraries (always use these):**
- Tailwind CSS — utility classes, no custom CSS unless necessary
- Framer Motion — all animations (never CSS keyframes for complex motion)
- Lucide React — icons (consistent, clean)
- React Hook Form + Zod — forms (already in saas-dev)
- RTK Query — data fetching (already in saas-dev)

**Component architecture rules:**

```
Every component must have:
1. Loading state     → <ComponentSkeleton /> using TableSkeleton pattern
2. Empty state       → illustrated empty state with CTA
3. Error state       → friendly error with retry button
4. Responsive        → mobile-first, works at 320px → 1920px
5. Accessible        → ARIA labels, keyboard nav, focus rings
6. Animated          → Framer Motion for mount/unmount, hover, transitions
```

**Premium patterns to use:**

```typescript
// Glassmorphism card
className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-2xl shadow-glass"

// Aurora gradient background
className="bg-gradient-to-br from-[#0f0c29] via-[#302b63] to-[#24243e]"

// Animated gradient text
className="bg-gradient-to-r from-[primary] to-[accent] bg-clip-text text-transparent"

// Smooth hover card
whileHover={{ scale: 1.02, y: -4 }}
transition={{ type: "spring", stiffness: 400, damping: 17 }}

// Staggered list animation
variants={{ container: { staggerChildren: 0.08 } }}

// Skeleton shimmer
className="animate-pulse bg-gradient-to-r from-white/5 via-white/10 to-white/5"
```

**Page-level design rules:**

```
Landing page:
  - Hero: full-viewport, gradient/glass bg, animated headline, particle or gradient orb
  - Features: bento grid or card grid with icons
  - CTA: prominent button with glow effect
  - Pricing: clean cards with highlighted recommended tier
  - Footer: clean, links organized in columns

Dashboard:
  - Sidebar: collapsible, icon + label, active state with accent color
  - Top bar: search + notifications + user avatar
  - Stats row: metric cards with trend indicators
  - Charts: recharts with custom styled tooltips
  - Tables: sortable, filterable, row hover states

Forms:
  - Floating labels (animate on focus)
  - Real-time validation (Zod, no submit required)
  - Submit button: loading state with spinner
  - Error states: red ring + error message animate in
  - Success: green ring + smooth transition
```

---

### Flutter Frontend

**Use this when building mobile or cross-platform UI.**

**Core packages (add to pubspec.yaml):**
```yaml
flutter_animate: ^4.5.0        # Smooth animations
go_router: ^13.0.0             # Navigation
flutter_riverpod: ^2.5.0       # State management
cached_network_image: ^3.3.0   # Image caching
shimmer: ^3.0.0                # Loading states
flutter_svg: ^2.0.0            # SVG icons
google_fonts: ^6.2.0           # Typography
```

**Design token implementation (lib/theme/tokens.dart):**
```
Colors: ColorScheme with primary, secondary, surface, background, error
Typography: TextTheme from Google Fonts
Spacing: const values matching the design system scale
Radius: BorderRadius constants
Shadows: List<BoxShadow> for each elevation level
Animations: Duration + Curve constants
```

**Premium Flutter UI patterns:**

```dart
// Glassmorphism card
Container(
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.05),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 32)],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: child,
    ),
  ),
)

// Smooth page transitions (go_router)
CustomTransitionPage(
  transitionsBuilder: (context, animation, _, child) =>
    FadeTransition(opacity: animation, child: SlideTransition(
      position: Tween<Offset>(begin: Offset(0.0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    )),
)

// Animated list items
.animate(delay: (index * 80).ms)
.fadeIn(duration: 400.ms)
.slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic)

// Shimmer loading
Shimmer.fromColors(
  baseColor: Colors.white.withOpacity(0.05),
  highlightColor: Colors.white.withOpacity(0.1),
  child: placeholder,
)
```

**Flutter architecture rules:**
```
lib/
├── theme/
│   ├── tokens.dart          ← design tokens (colors, spacing, radius, shadows)
│   ├── app_theme.dart       ← ThemeData with all tokens applied
│   └── text_styles.dart     ← TextStyle constants
├── features/[feature]/
│   ├── presentation/
│   │   ├── pages/           ← full screens (StatelessWidget)
│   │   ├── widgets/         ← reusable UI components
│   │   └── state/           ← Riverpod providers
│   ├── domain/
│   │   └── models/          ← data classes (Freezed)
│   └── data/
│       └── repositories/    ← API calls (Dio + Retrofit)
```

---

## Step 4: Quality Gates (run before marking task DONE)

Every frontend task must pass these before marking complete:

**Visual quality:**
- [ ] Matches the design reference file (if provided)
- [ ] Uses design system tokens (colors, spacing, radius, typography)
- [ ] Has loading state (skeleton/shimmer)
- [ ] Has empty state (illustrated, with CTA)
- [ ] Has error state (friendly message + retry)
- [ ] Responsive: tested at 320px, 768px, 1024px, 1440px (web)
- [ ] Accessible: ARIA labels, keyboard navigation, focus visible

**Animation quality:**
- [ ] All transitions use design system duration + easing tokens
- [ ] No jarring instant state changes
- [ ] No layout shift during data load (skeletons reserve space)
- [ ] Hover states feel responsive (< 200ms)

**Code quality:**
- [ ] No hardcoded colors (use design tokens)
- [ ] No hardcoded spacing values (use spacing scale)
- [ ] Components are composable (no god components > 200 lines)
- [ ] Tests cover: renders correctly, loading state, error state, user interaction

---

## Step 5: Landing Page Specific Rules

When building a landing page, always include these sections (unless PRD says otherwise):

1. **Hero** — headline, sub-headline, CTA button, visual (illustration/screenshot/gradient)
2. **Social proof** — logos, testimonials, or stats
3. **Features** — 3-6 feature cards (icon + title + description)
4. **How it works** — 3-step process with numbered steps
5. **Pricing** — 2-3 tier cards, highlight recommended tier
6. **FAQ** — accordion component, 5-8 common questions
7. **CTA Section** — final push before footer
8. **Footer** — logo + tagline + organized links + social icons

**Landing page hero must have:**
- Animated gradient or glassmorphism background
- Headline with gradient text effect
- Smooth entrance animations (staggered, fade + slide up)
- CTA button with glow/shimmer hover effect
- Screenshot or UI preview (if available) with perspective tilt on hover

---

## Integration with saas-dev Orchestrator

When orchestrator reaches a frontend feature task:

1. **This skill loads automatically**
2. Generates design system for the feature (Step 2)
3. Identifies stack: React/Next.js or Flutter (from CLAUDE.md §2)
4. Applies premium patterns appropriate to the product type
5. Subagent receives: task + this skill + design reference file (if exists)
6. Subagent implements with quality gates enforced
7. After implementation: runs quality gate checklist before marking DONE

If designs/ folder has a mockup for this page → subagent must match it.
If no mockup → subagent generates using the design system in Step 2.
