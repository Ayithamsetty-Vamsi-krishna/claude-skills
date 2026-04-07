# DevOps: Platform-Adaptive Deployment

## Decision flow (Q10 — ask user or search)

```
Step 1: Ask user which platform they're using (ask_user_input_v0)
Step 2: If "search for best option" → web_search "Django React deployment 2025 comparison"
         → present top 3 options with pros/cons
         → ask user to choose
Step 3: web_fetch the chosen platform's deployment docs
Step 4: Generate platform-specific config
```

---

## Render (simplest, good for SaaS MVPs)

```yaml
# render.yaml (Infrastructure as Code)
services:
  - type: web
    name: backend
    env: python
    buildCommand: pip install -r requirements.txt && python manage.py collectstatic --noinput
    startCommand: gunicorn config.wsgi:application --workers 4 --bind 0.0.0.0:$PORT
    envVars:
      - key: DJANGO_SETTINGS_MODULE
        value: config.settings.production
      - key: SECRET_KEY
        sync: false   # set in Render dashboard
      - key: DATABASE_URL
        fromDatabase:
          name: app-db
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: app-redis
          type: redis
          property: connectionString

  - type: web
    name: frontend
    env: static
    buildCommand: npm ci && npm run build
    staticPublishPath: dist
    routes:
      - type: rewrite
        source: /*
        destination: /index.html   # SPA routing

  - type: worker
    name: celery-worker
    env: python
    buildCommand: pip install -r requirements.txt
    startCommand: celery -A config worker --loglevel=info

databases:
  - name: app-db
    plan: free

  - name: app-redis
    plan: free
    ipAllowList: []
```

---

## Railway

```toml
# railway.toml
[build]
builder = "nixpacks"

[deploy]
startCommand = "gunicorn config.wsgi:application --workers 4 --bind 0.0.0.0:$PORT"
healthcheckPath = "/health/"
healthcheckTimeout = 300
restartPolicyType = "on-failure"
restartPolicyMaxRetries = 3
```

```bash
# Railway CLI deployment
railway login
railway link [project-id]
railway up

# Set env vars
railway variables set SECRET_KEY=your-secret-key
railway variables set DJANGO_SETTINGS_MODULE=config.settings.production
```

---

## DigitalOcean App Platform

```yaml
# .do/app.yaml
name: saas-app
region: blr   # Bangalore for India

services:
  - name: backend
    source_dir: backend
    github:
      repo: your-org/your-repo
      branch: main
      deploy_on_push: true
    run_command: gunicorn config.wsgi:application --workers 4 --bind 0.0.0.0:$PORT
    environment_slug: python
    envs:
      - key: DJANGO_SETTINGS_MODULE
        value: config.settings.production
      - key: SECRET_KEY
        type: SECRET
      - key: DATABASE_URL
        scope: RUN_TIME
        value: ${db.DATABASE_URL}
    health_check:
      http_path: /health/

  - name: frontend
    source_dir: frontend
    github:
      repo: your-org/your-repo
      branch: main
      deploy_on_push: true
    build_command: npm ci && npm run build
    environment_slug: node-js
    static_sites:
      - output_dir: dist
        index_document: index.html
        error_document: index.html  # SPA routing

  - name: celery-worker
    source_dir: backend
    run_command: celery -A config worker --loglevel=info
    instance_count: 1

databases:
  - name: db
    engine: PG
    production: true
```

---

## AWS ECS (production-grade, complex)

```bash
# Research before implementing:
# web_fetch https://docs.aws.amazon.com/AmazonECS/latest/developerguide/getting-started.html

# Key steps (generate after reading docs):
# 1. ECR — push Docker images
# 2. ECS Task Definition — container config
# 3. ECS Service — desired count, load balancer
# 4. RDS PostgreSQL — managed database
# 5. ElastiCache Redis — managed Redis
# 6. ALB — Application Load Balancer
# 7. Route53 — DNS
# 8. ACM — SSL certificate
```

---

## Production settings checklist

```python
# settings/production.py
from .base import *

DEBUG = False
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='').split(',')
CSRF_TRUSTED_ORIGINS = config('CSRF_TRUSTED_ORIGINS', default='').split(',')
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True

# Static files — use S3 or whitenoise
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Logging — JSON format for log aggregation
LOGGING = {
    'version': 1,
    'handlers': {
        'console': {'class': 'logging.StreamHandler',
                    'formatter': 'json'},
    },
    'formatters': {
        'json': {'()': 'pythonjsonlogger.jsonlogger.JsonFormatter',
                 'format': '%(asctime)s %(name)s %(levelname)s %(message)s'},
    },
    'root': {'handlers': ['console'], 'level': 'INFO'},
}
```

---

## Zero-downtime migration integration per platform

**Always run migrations BEFORE deploying new code.** See `references/migrations-prod.md` for rules.

### Render
```yaml
# In render.yaml — add migration as pre-deploy command
services:
  - type: web
    name: backend
    preDeployCommand: python manage.py migrate --no-input   # ← runs before new code serves traffic
    startCommand: gunicorn config.wsgi:application ...
```

### Railway
```bash
# In railway.toml or via CLI before deploy
railway run python manage.py migrate --no-input
railway up
```

### DigitalOcean App Platform
```yaml
# In .do/app.yaml — run-command before service starts
services:
  - name: backend
    run_command: python manage.py migrate --no-input && gunicorn config.wsgi:application
```

### GitHub Actions CD (universal)
```yaml
# Always migrate before triggering platform deploy
steps:
  - name: Run migrations
    run: |
      # Use your platform CLI to run migrate on the production container
      # Examples:
      # render: curl -X POST ${{ secrets.RENDER_MIGRATE_HOOK }}
      # railway: railway run python manage.py migrate
      # SSH: ssh ${{ secrets.PROD_HOST }} "cd /app && python manage.py migrate"
  
  - name: Deploy new code
    # trigger deploy AFTER migrations succeed
```

---

## Environment promotion (dev → staging → production)

### Settings structure
```python
config/settings/
├── base.py           # shared settings
├── development.py    # local dev (DEBUG=True, console email, etc.)
├── staging.py        # mirrors production but with test data
└── production.py     # production (DEBUG=False, real services)
```

```python
# settings/staging.py
from .base import *
from decouple import config

DEBUG = False
ALLOWED_HOSTS = config('ALLOWED_HOSTS').split(',')

# Use real external services but separate accounts/keys
DATABASES = {'default': dj_database_url.config(default=config('DATABASE_URL'))}
STRIPE_SECRET_KEY = config('STRIPE_TEST_KEY')  # test mode Stripe key
AWS_STORAGE_BUCKET_NAME = config('AWS_STAGING_BUCKET')
SENTRY_DSN = config('SENTRY_STAGING_DSN', default='')

# Email: send to a catch-all in staging
EMAIL_HOST_USER = config('STAGING_EMAIL_USER')
```

### Render: two services (staging + production)
```yaml
# render.yaml
services:
  - type: web
    name: backend-staging
    branch: develop          # auto-deploy develop branch
    envVars:
      - key: DJANGO_SETTINGS_MODULE
        value: config.settings.staging
      - key: DATABASE_URL
        fromDatabase:
          name: db-staging
          property: connectionString

  - type: web
    name: backend-production
    branch: main             # auto-deploy main branch
    envVars:
      - key: DJANGO_SETTINGS_MODULE
        value: config.settings.production
      - key: DATABASE_URL
        fromDatabase:
          name: db-production
          property: connectionString
```

### GitHub Actions: staging deploy on PR merge, production on tag
```yaml
# .github/workflows/cd.yml
on:
  push:
    branches: [develop]     # → staging
    tags: ['v*']             # → production

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to staging
        run: curl -X POST ${{ secrets.RENDER_STAGING_DEPLOY_HOOK }}

  deploy-production:
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    environment: production   # requires manual approval in GitHub
    steps:
      - name: Deploy to production
        run: curl -X POST ${{ secrets.RENDER_PROD_DEPLOY_HOOK }}
```

**Promotion flow:**
```
feature branch → PR → review → merge to develop → auto-deploy staging
staging testing OK → merge develop to main → tag release → manual approve → deploy production
```

---

## Next.js deployment considerations

When the frontend is Next.js (App Router or Pages Router), deployment differs
from a static React/Vite build. Always confirm with the user which applies.

### Key difference: Next.js requires Node.js runtime

```
React/Vite:  npm run build → static dist/ → served by Nginx (no Node.js)
Next.js:     npm run build → .next/ + server.js → requires Node.js 20 to run
```

### next.config.ts — required for self-hosted Docker

```typescript
// frontend/next.config.ts
const nextConfig = {
  output: 'standalone',  // ← produces minimal self-contained build for Docker
}
export default nextConfig
```

### Platform recommendations for Next.js frontend

| Platform | Django backend | Next.js frontend | Notes |
|---|---|---|---|
| Render | Render web service | Render web service (Node) | Simple, same platform |
| Railway | Railway service | Railway service (Node) | Good DX |
| Vercel + Render | Render | Vercel | Optimal — Vercel is built for Next.js |
| Self-hosted | Docker | Docker (Node container) | Use standalone output |
| AWS | ECS/EC2 | ECS/Vercel/Amplify | Most flexible |

### CORS reminder for Next.js BFF

```python
# Django settings — allow only the Next.js SERVER, not the browser
# Browser → Next.js Route Handler → Django (BFF pattern)
CORS_ALLOWED_ORIGINS = [
    'http://nextjs:3000',               # Docker internal
    'https://yourapp.vercel.app',       # Vercel
    'https://your-nextjs.onrender.com', # Render
]
# Never CORS_ALLOW_ALL_ORIGINS = True in production
```

### GitHub Actions — add Next.js build job alongside Django

```yaml
# .github/workflows/ci.yml addition for Next.js
  frontend:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm', cache-dependency-path: frontend/package-lock.json }
      - run: npm ci
      - run: npm run build
        env:
          DJANGO_API_URL: http://localhost:8000
          AUTH_SECRET: test-secret-for-build
          NEXT_PUBLIC_APP_NAME: AutoServe
```
