# DevOps: GitHub Actions CI/CD

---

## CI — Test on every PR

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

jobs:
  test-backend:
    name: Backend Tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpassword
        ports: ['5432:5432']
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports: ['6379:6379']
        options: --health-cmd "redis-cli ping" --health-interval 10s

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
          cache-dependency-path: backend/requirements.txt

      - name: Install dependencies
        run: |
          cd backend
          pip install -r requirements.txt

      - name: Run tests with coverage
        env:
          DATABASE_URL: postgres://testuser:testpassword@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379/0
          DJANGO_SETTINGS_MODULE: config.settings.testing
          SECRET_KEY: ci-test-secret-key-not-for-production
        run: |
          cd backend
          pytest --cov=. --cov-report=xml --cov-fail-under=80

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: backend/coverage.xml
          fail_ci_if_error: false

  test-frontend:
    name: Frontend Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: cd frontend && npm ci

      - name: Run tests
        run: cd frontend && npm test -- --coverage --run

      - name: Build check
        run: cd frontend && npm run build
```

---

## CD — Deploy on merge to main

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]

jobs:
  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: []   # add CI job name here if you want CD to wait for CI
    environment: production

    steps:
      - uses: actions/checkout@v4

      # ── Render deployment example ──────────────────────────────────
      # For Render: trigger deploy via webhook
      - name: Deploy to Render
        if: vars.DEPLOY_TARGET == 'render'
        run: |
          curl -X POST ${{ secrets.RENDER_DEPLOY_HOOK_URL }}

      # ── Railway deployment example ─────────────────────────────────
      - name: Deploy to Railway
        if: vars.DEPLOY_TARGET == 'railway'
        uses: bervProject/railway-deploy@main
        with:
          railway_token: ${{ secrets.RAILWAY_TOKEN }}
          service: ${{ secrets.RAILWAY_SERVICE_NAME }}

      # ── DigitalOcean App Platform ──────────────────────────────────
      - name: Deploy to DigitalOcean
        if: vars.DEPLOY_TARGET == 'digitalocean'
        uses: digitalocean/app_action@v2
        with:
          token: ${{ secrets.DIGITALOCEAN_ACCESS_TOKEN }}
          app_name: ${{ secrets.DO_APP_NAME }}

      # ── Generic: push Docker image to registry ─────────────────────
      - name: Build and push Docker image
        if: vars.DEPLOY_TARGET == 'docker'
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: ${{ secrets.DOCKER_REGISTRY }}/backend:${{ github.sha }}
```

---

## Required GitHub Secrets

Add these in: Repository → Settings → Secrets and variables → Actions

```
# Required for all deployments:
SECRET_KEY              → Django secret key (generate: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
DATABASE_URL            → production PostgreSQL connection string
REDIS_URL               → production Redis URL

# Provider-specific (add only what you need):
RENDER_DEPLOY_HOOK_URL  → from Render dashboard
RAILWAY_TOKEN           → from Railway account settings
DIGITALOCEAN_ACCESS_TOKEN
DOCKER_REGISTRY         → if using custom registry

# Application secrets:
STRIPE_SECRET_KEY       → if using Stripe
AWS_ACCESS_KEY_ID       → if using S3
AWS_SECRET_ACCESS_KEY
SENTRY_DSN              → if using Sentry
```

---

## Frontend CI — Next.js (Vitest + Playwright)

```yaml
# .github/workflows/ci.yml — add this job alongside test-backend
  test-nextjs:
    name: Next.js Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        run: cd frontend && npm ci

      - name: Type check
        run: cd frontend && npx tsc --noEmit

      - name: Unit tests (Vitest)
        run: cd frontend && npm run test -- --run --coverage
        env:
          DJANGO_API_URL: http://localhost:8000
          AUTH_SECRET: ci-test-secret

      - name: Build check (catches Next.js compile errors)
        run: cd frontend && npm run build
        env:
          DJANGO_API_URL: http://localhost:8000
          AUTH_SECRET: ci-test-secret
          NEXT_PUBLIC_APP_NAME: CI

  test-e2e:
    name: Playwright E2E
    runs-on: ubuntu-latest
    needs: [test-backend, test-nextjs]   # run after unit tests pass
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - name: Install deps
        run: cd frontend && npm ci && npx playwright install --with-deps chromium

      - name: Start Django (background)
        run: |
          cd backend
          pip install -r requirements.txt
          python manage.py migrate --settings=config.settings.testing
          python manage.py runserver 8000 &
        env:
          DJANGO_SETTINGS_MODULE: config.settings.testing

      - name: Start Next.js (background)
        run: cd frontend && npm run build && npm start &
        env:
          DJANGO_API_URL: http://localhost:8000
          AUTH_SECRET: ci-secret

      - name: Wait for services
        run: npx wait-on http://localhost:3000 http://localhost:8000/health/

      - name: Run Playwright
        run: cd frontend && npx playwright test

      - name: Upload Playwright report
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: frontend/playwright-report/
```
