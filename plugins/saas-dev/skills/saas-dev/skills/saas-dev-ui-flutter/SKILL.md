---
name: saas-dev-ui-flutter
description: "Premium Flutter UI/UX skill for saas-dev. Activates on every Flutter frontend task. Generates complete design token system then builds futuristic, production-grade Flutter UI — glassmorphism, smooth transitions, animated lists, shimmer loading, dark/light themes. Cross-platform: iOS, Android, Web."
triggers:
  - "Flutter"
  - "mobile"
  - "iOS"
  - "Android"
  - "cross-platform"
  - "flutter widget"
  - "flutter screen"
  - "mobile app"
---

# saas-dev UI: Flutter Design Engine

You are a world-class Flutter engineer. Every Flutter frontend task in saas-dev runs through this skill.

---

## Step 1: pubspec.yaml — Required Packages

Add these to every Flutter project. Check pubspec.yaml and add any missing:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Design & Animation
  flutter_animate: ^4.5.0        # Smooth, chainable animations
  google_fonts: ^6.2.0           # Typography (matches web design system)

  # Navigation
  go_router: ^13.0.0             # Declarative routing + deep links

  # State Management
  flutter_riverpod: ^2.5.0       # Providers, state, async
  riverpod_annotation: ^2.3.0    # Code gen for providers

  # Networking & Data
  dio: ^5.4.0                    # HTTP client
  retrofit: ^4.1.0               # Type-safe API client
  freezed_annotation: ^2.4.0     # Immutable data classes
  json_annotation: ^4.8.0        # JSON serialization

  # UI Components
  shimmer: ^3.0.0                # Loading states
  cached_network_image: ^3.3.0   # Cached images
  flutter_svg: ^2.0.0            # SVG icons
  gap: ^3.0.1                    # Spacing widget (cleaner than SizedBox)

  # Utils
  intl: ^0.19.0                  # Date/number formatting

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.0
  freezed: ^2.4.0
  retrofit_generator: ^8.1.0
  riverpod_generator: ^2.3.0
  flutter_lints: ^3.0.0
```

---

## Step 2: Project Architecture

Every Flutter feature follows this structure:

```
lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart        ← ThemeData (light + dark)
│   │   ├── tokens.dart           ← all design tokens as const
│   │   ├── text_styles.dart      ← TextStyle constants
│   │   └── color_scheme.dart     ← ColorScheme definitions
│   ├── router/
│   │   └── app_router.dart       ← go_router configuration
│   ├── network/
│   │   └── api_client.dart       ← Dio + Retrofit base client
│   └── widgets/
│       ├── glass_card.dart       ← reusable glassmorphism card
│       ├── shimmer_box.dart      ← loading placeholder
│       ├── error_state.dart      ← reusable error widget
│       └── empty_state.dart      ← reusable empty widget
│
└── features/
    └── [feature_name]/
        ├── data/
        │   ├── models/            ← Freezed data classes
        │   └── repositories/      ← API calls (Retrofit)
        ├── domain/
        │   └── providers/         ← Riverpod providers
        └── presentation/
            ├── pages/             ← full screens (ConsumerWidget)
            └── widgets/           ← feature-specific components
```

---

## Step 3: Design Token System

Create `lib/core/theme/tokens.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTokens {
  // ─── Colors (Dark theme — SaaS default) ───────────────────────────────
  static const colorPrimary        = Color(0xFF6C63FF);  // adjust per product type
  static const colorSecondary      = Color(0xFF3ECFCF);
  static const colorAccent         = Color(0xFFFF6B6B);
  static const colorBackground     = Color(0xFF0A0A0F);
  static const colorSurface        = Color(0xFF13131A);
  static const colorSurfaceVariant = Color(0xFF1C1C28);
  static const colorBorder         = Color(0xFF2A2A3D);
  static const colorText           = Color(0xFFF0F0FF);
  static const colorTextMuted      = Color(0xFF8888AA);
  static const colorSuccess        = Color(0xFF4ADE80);
  static const colorWarning        = Color(0xFFFBBF24);
  static const colorError          = Color(0xFFF87171);

  // ─── Glass colors ──────────────────────────────────────────────────────
  static const glassBackground = Color(0x0DFFFFFF);  // white 5%
  static const glassBorder     = Color(0x1AFFFFFF);  // white 10%
  static const glassHighlight  = Color(0x33FFFFFF);  // white 20%

  // ─── Spacing ──────────────────────────────────────────────────────────
  static const spaceXS  =  4.0;
  static const spaceSM  =  8.0;
  static const spaceMD  = 16.0;
  static const spaceLG  = 24.0;
  static const spaceXL  = 32.0;
  static const space2XL = 48.0;
  static const space3XL = 64.0;

  // ─── Border Radius ─────────────────────────────────────────────────────
  static const radiusSM = 6.0;
  static const radiusMD = 12.0;
  static const radiusLG = 20.0;
  static const radiusXL = 28.0;

  // ─── Typography ────────────────────────────────────────────────────────
  static TextStyle headingXL() => GoogleFonts.inter(
    fontSize: 32, fontWeight: FontWeight.w700, color: colorText, height: 1.2,
  );
  static TextStyle headingLG() => GoogleFonts.inter(
    fontSize: 24, fontWeight: FontWeight.w700, color: colorText, height: 1.3,
  );
  static TextStyle headingMD() => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w600, color: colorText,
  );
  static TextStyle body() => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: colorText,
  );
  static TextStyle bodyMuted() => GoogleFonts.inter(
    fontSize: 14, fontWeight: FontWeight.w400, color: colorTextMuted,
  );
  static TextStyle label() => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w500, color: colorTextMuted,
    letterSpacing: 0.5,
  );

  // ─── Shadows ───────────────────────────────────────────────────────────
  static const shadowCard = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(color: color.withOpacity(0.3), blurRadius: 40, spreadRadius: 0),
  ];

  // ─── Animation Durations ───────────────────────────────────────────────
  static const durationFast   = Duration(milliseconds: 150);
  static const durationNormal = Duration(milliseconds: 250);
  static const durationSlow   = Duration(milliseconds: 400);

  // ─── Animation Curves ──────────────────────────────────────────────────
  static const curveSmooth = Curves.easeInOut;
  static const curveBounce = Curves.elasticOut;
  static const curveSpring = Curves.easeOutBack;
}
```

---

## Step 4: Core Reusable Widgets

### GlassCard (`lib/core/widgets/glass_card.dart`)

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? AppTokens.radiusLG),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppTokens.spaceMD),
          decoration: BoxDecoration(
            color: AppTokens.glassBackground,
            borderRadius: BorderRadius.circular(borderRadius ?? AppTokens.radiusLG),
            border: border
              ? Border.all(color: AppTokens.glassBorder, width: 1)
              : null,
            boxShadow: AppTokens.shadowCard,
          ),
          child: child,
        ),
      ),
    );
  }
}
```

### ShimmerBox (`lib/core/widgets/shimmer_box.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/tokens.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, required this.width, required this.height,
    this.borderRadius = AppTokens.radiusMD});

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTokens.glassBackground,
      highlightColor: AppTokens.glassHighlight,
      child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: AppTokens.glassBackground,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
```

---

## Step 5: Smooth Page Transitions (go_router)

```dart
// In app_router.dart — use this for ALL routes
CustomTransitionPage(
  key: state.pageKey,
  child: const YourPage(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.03),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  },
)
```

---

## Step 6: Animation Patterns (flutter_animate)

```dart
// Staggered list items
ListView.builder(
  itemBuilder: (ctx, i) => ItemWidget(item: items[i])
    .animate(delay: (i * 80).ms)
    .fadeIn(duration: 400.ms)
    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
)

// Hero entrance animation (page load)
Column(children: [
  TitleWidget()
    .animate().fadeIn(duration: 600.ms).slideY(begin: -0.1),
  SubtitleWidget()
    .animate(delay: 150.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1),
  CTAButton()
    .animate(delay: 300.ms).fadeIn(duration: 400.ms).scale(begin: Offset(0.9, 0.9)),
])

// Tap scale feedback (all tappable widgets)
GestureDetector(
  onTapDown: (_) => controller.forward(),
  onTapUp: (_) => controller.reverse(),
  child: AnimatedScale(scale: isPressed ? 0.96 : 1.0,
    duration: AppTokens.durationFast, child: content),
)

// Success state
Icon(Icons.check_circle)
  .animate().scale(begin: Offset(0,0), curve: Curves.elasticOut, duration: 600.ms)
  .fadeIn()

// Error shake
widget
  .animate(controller: errorController)
  .shakeX(hz: 4, amount: 6, duration: 400.ms)
```

---

## Step 7: Every Screen Must Have

```dart
class FeatureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureProvider);

    return state.when(
      // 1. Loading state — skeleton
      loading: () => const FeatureScreenSkeleton(),

      // 2. Error state
      error: (err, _) => ErrorState(
        message: err.toString(),
        onRetry: () => ref.invalidate(featureProvider),
      ),

      // 3. Empty state
      data: (data) => data.isEmpty
        ? EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No items yet',
            action: ElevatedButton(
              onPressed: () => context.push('/feature/create'),
              child: const Text('Create first item'),
            ),
          )
        // 4. Data state — animated entrance
        : AnimatedSwitcher(
            duration: AppTokens.durationNormal,
            child: FeatureList(items: data),
          ),
    );
  }
}
```

---

## Step 8: Quality Gates

Before marking any Flutter task DONE:

**Reusability (check FIRST before writing a single line):**
- [ ] Does `lib/core/widgets/` already have a widget for this?
  If yes — USE IT. Do not create a duplicate.
- [ ] Does this widget belong in `lib/core/widgets/`?
  Rule: GlassCard, ShimmerBox, ErrorState, EmptyState, AppButton, AppTextField
  are ALWAYS in `lib/core/widgets/`. Never feature-specific.
- [ ] No copy-paste between feature folders — extract to core/widgets if used twice.
- [ ] Uses `AppTokens` for all colors, spacing, radius, shadow, duration, curve values.
  Zero hardcoded `Color(0xFF...)`, `8.0`, `BorderRadius.circular(12)` directly in widgets.

**Visual:**
- [ ] Matches design reference (if designs/ file provided)
- [ ] Loading state: `ShimmerBox` from core/widgets
- [ ] Empty state: `EmptyState` from core/widgets (icon + message + CTA)
- [ ] Error state: `ErrorState` from core/widgets (message + retry)

**Animation:**
- [ ] Page transitions: `CustomTransitionPage` (fade + slideY easeOutCubic)
- [ ] List items stagger: `flutter_animate` with `(index * 80).ms` delay
- [ ] Tap feedback: `AnimatedScale` scale 0.96 on press
- [ ] State changes: `AnimatedSwitcher` — no jarring instant switches
- [ ] All durations/curves from `AppTokens` constants

**Architecture:**
- [ ] All state via Riverpod providers — no `setState` in screens
- [ ] No business logic in `build()` — providers and use cases only
- [ ] Screens are `ConsumerWidget` — `StatefulWidget` only for local UI state (animation controllers)
- [ ] Widgets under 150 lines — split into sub-widgets if larger
- [ ] Data classes use Freezed — no mutable model classes

**Code quality (human-written standard):**
- [ ] No hardcoded strings — use const or l10n keys
- [ ] Variable names are descriptive — no `data`, `res`, `tmp`, `item`
- [ ] No dead code — no commented-out blocks, no unused imports
- [ ] No `print()` statements — use structured logging
- [ ] No TODO stubs left in production code

**Cross-platform:**
- [ ] iOS form factor: 375 × 812 (iPhone 14)
- [ ] Android form factor: 360 × 800 (Pixel)
- [ ] If web target: responsive at 768px and 1280px

---

## Integration with saas-dev

This skill loads for every Flutter task during execution.
Subagent receives: this skill + design system tokens + design reference (if exists in designs/).
Quality gates enforced before subagent marks task DONE.

**When both React + Flutter exist in the same project:**
- Django API is the shared backend
- React handles web frontend (saas-dev-ui-react)
- Flutter handles mobile frontend (this skill)
- Both read from same Redux/Riverpod API layer pointing to same Django endpoints
