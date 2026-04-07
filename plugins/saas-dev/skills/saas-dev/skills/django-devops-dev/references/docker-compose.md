# DevOps: Docker + docker-compose

---

## Django Dockerfile (multi-stage)

```dockerfile
# Dockerfile
# ── Stage 1: Build ──────────────────────────────────────────────────
FROM python:3.12-slim AS builder
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --upgrade pip && pip install --no-cache-dir -r requirements.txt

# ── Stage 2: Runner ─────────────────────────────────────────────────
FROM python:3.12-slim AS runner
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev curl && rm -rf /var/lib/apt/lists/*
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .
# Collect static files for production
RUN python manage.py collectstatic --noinput --settings=config.settings.production
EXPOSE 8000
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

```dockerfile
# React Dockerfile (production build)
# frontend/Dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

---

## docker-compose.yml (local development)

```yaml
# docker-compose.yml
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-appdb}
      POSTGRES_USER: ${POSTGRES_USER:-appuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-apppassword}
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-appuser}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  backend:
    build:
      context: ./backend
      target: builder   # use builder stage for dev (has build tools)
    command: python manage.py runserver 0.0.0.0:8000
    volumes:
      - ./backend:/app   # hot reload for dev
    ports:
      - "8000:8000"
    env_file: ./backend/.env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy

  frontend:
    image: node:20-alpine
    working_dir: /app
    command: npm run dev -- --host 0.0.0.0
    volumes:
      - ./frontend:/app
      - /app/node_modules
    ports:
      - "5173:5173"
    environment:
      - VITE_API_BASE_URL=http://localhost:8000

  worker:
    build:
      context: ./backend
      target: builder
    command: celery -A config worker --loglevel=info
    volumes:
      - ./backend:/app
    env_file: ./backend/.env
    depends_on:
      - backend
      - redis

  # Uncomment if using Celery beat (periodic tasks):
  # beat:
  #   build:
  #     context: ./backend
  #     target: builder
  #   command: celery -A config beat --loglevel=info
  #   env_file: ./backend/.env
  #   depends_on:
  #     - worker

volumes:
  postgres_data:
```

---

## .dockerignore (backend)

```
# backend/.dockerignore
__pycache__/
*.py[cod]
*.pyc
*.pyo
.env
.env.*
!.env.example
.git
.gitignore
*.log
.pytest_cache/
htmlcov/
dist/
build/
*.egg-info/
venv/
.venv/
node_modules/
```

---

## Common docker-compose commands

```bash
# Start all services
docker-compose up -d

# Run Django migrations
docker-compose exec backend python manage.py migrate

# Create superuser
docker-compose exec backend python manage.py createsuperuser

# View logs
docker-compose logs -f backend
docker-compose logs -f worker

# Rebuild after requirements change
docker-compose build backend && docker-compose up -d backend

# Stop all
docker-compose down

# Stop and remove volumes (reset DB)
docker-compose down -v
```

---

## Next.js in docker-compose (requires Node.js container, not Nginx)

When the frontend is Next.js, replace the static Nginx frontend with a Node.js container.
Full docker-compose with Django + Next.js is in:
`skills/nextjs-app-router-dev/references/deployment.md`

Key differences from React/Vite:
```yaml
# React/Vite — static files served by Nginx
frontend:
  image: nginx:alpine
  # serves /app/dist as static files

# Next.js — requires Node.js runtime (output: 'standalone')
nextjs:
  build:
    context: ./frontend
    target: runner        # multi-stage: deps → builder → runner
  environment:
    DJANGO_API_URL: http://backend:8000   # internal Docker network
    AUTH_SECRET: ${AUTH_SECRET}
  ports:
    - "3000:3000"
  # No Nginx needed — Next.js serves itself
```

**Critical env var rule for Next.js in Docker:**
- `DJANGO_API_URL` — no `NEXT_PUBLIC_` prefix, server-only, points to Django container
- Never expose Django URL to browser — BFF handles all proxying
