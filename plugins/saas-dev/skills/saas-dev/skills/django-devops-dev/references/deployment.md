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
