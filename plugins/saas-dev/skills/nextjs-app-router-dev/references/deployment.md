# Next.js App Router: Deployment — Vercel

## Vercel (recommended — zero config)

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy from frontend/ directory
cd frontend
vercel

# Link to existing project on re-deploy
vercel --prod
```

---

## Environment variables on Vercel

```
# Set in Vercel dashboard: Project → Settings → Environment Variables

# Server-only (not exposed to browser — NO NEXT_PUBLIC_ prefix)
DJANGO_API_URL         = https://api.yourapp.com
AUTH_SECRET            = <generated secret>

# Browser-safe (NEXT_PUBLIC_ prefix)
NEXT_PUBLIC_APP_NAME   = AutoServe
NEXT_PUBLIC_APP_URL    = https://yourapp.vercel.app

# Stripe (if used)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY = pk_live_...

# ⚠️ NEVER put Stripe secret key or Django secret key in NEXT_PUBLIC_ vars
```

---

## Django on separate service — CORS for production

```python
# settings/production.py
CORS_ALLOWED_ORIGINS = [
    'https://yourapp.vercel.app',       # Vercel production
    'https://yourapp-git-main.vercel.app',  # Vercel preview branches (optional)
]
# Browser never calls Django — only Vercel's serverless functions do
# So CORS origin is the Vercel deployment URL, not the user's browser
```

---

## vercel.json — optional configuration

```json
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "rewrites": [],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-store" }
      ]
    }
  ]
}
```

---

## GitHub Actions → Vercel (CI/CD)

```yaml
# .github/workflows/deploy.yml
name: Deploy to Vercel
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json
      - name: Install + Build check
        run: cd frontend && npm ci && npm run build
      - name: Deploy to Vercel
        run: npx vercel --prod --token=${{ secrets.VERCEL_TOKEN }}
        env:
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
```

---

# Next.js App Router: Deployment — Docker

## next.config.ts — enable standalone output

```typescript
// next.config.ts
const nextConfig: NextConfig = {
  output: 'standalone',   // ← produces minimal self-contained build
  // ...rest of config
}
```

---

## Dockerfile for Next.js (Node.js runtime — not static files)

```dockerfile
# frontend/Dockerfile
# ── Stage 1: Dependencies ──────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# ── Stage 2: Build ────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ── Stage 3: Runner ───────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser  --system --uid 1001 nextjs

# standalone output — only what's needed to run
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

---

## docker-compose.yml with Django + Next.js + Redis

```yaml
# docker-compose.yml
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    volumes: [postgres_data:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-autoserve}
      POSTGRES_USER: ${POSTGRES_USER:-appuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-apppassword}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-appuser}"]
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s

  backend:
    build: ./backend
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4
    environment:
      DJANGO_SETTINGS_MODULE: config.settings.production
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      # CORS: allow only nextjs service (internal Docker network)
      CORS_ALLOWED_ORIGINS: http://nextjs:3000
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }

  nextjs:
    build:
      context: ./frontend
      target: runner
    environment:
      NODE_ENV: production
      # Points to Django via internal Docker network — never exposed to browser
      DJANGO_API_URL: http://backend:8000
      AUTH_SECRET: ${AUTH_SECRET}
      NEXT_PUBLIC_APP_NAME: ${APP_NAME:-AutoServe}
    ports:
      - "3000:3000"
    depends_on:
      - backend

  worker:
    build: ./backend
    command: celery -A config worker --loglevel=info
    environment:
      DJANGO_SETTINGS_MODULE: config.settings.production
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
    depends_on:
      - backend
      - redis

volumes:
  postgres_data:
```

---

## Key Docker difference from static React/Vite

```
React/Vite build:
  → produces /dist/ (static HTML/JS/CSS)
  → served by Nginx (no Node.js needed)

Next.js build (standalone):
  → produces /server.js + /.next/
  → requires Node.js 20 runtime to serve
  → Nginx optional (as reverse proxy only)
```
