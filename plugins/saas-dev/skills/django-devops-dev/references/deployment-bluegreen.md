# DevOps: Blue/Green Deployment (Docker)

## Purpose
Zero-downtime deploys without Kubernetes. Two full environments ("blue" and
"green"). One serves production; the other is staging/standby. Deploy to
standby, test, then flip a load balancer (nginx) to route traffic to it.
Old environment stays running as instant-rollback fallback.

Use this when:
- You're on Docker Compose / plain VM, not K8s
- You need zero-downtime deploys but don't want the K8s complexity
- You want instant rollback (flip nginx config, 1 second)

---

## Architecture

```
                ┌──── nginx ────┐
                │  (port 80/443) │
                │   reads symlink│
                └───────┬────────┘
                        │
              ┌─────────┴─────────┐
              │                   │
    ┌─────────▼────────┐   ┌─────▼──────────┐
    │ BLUE environment │   │ GREEN env      │
    │ backend:8001     │   │ backend:8002   │
    │ celery:8011      │   │ celery:8012    │
    │ (currently live) │   │ (new release)  │
    └──────────────────┘   └────────────────┘

       Both share the same Postgres + Redis
```

---

## Directory structure

```
deploy/
├── docker-compose.blue.yml
├── docker-compose.green.yml
├── docker-compose.shared.yml    ← db, redis, nginx (always running)
├── nginx/
│   ├── nginx.conf               ← main config
│   ├── upstream-blue.conf       ← points at blue
│   └── upstream-green.conf      ← points at green
└── deploy.sh                    ← flip orchestration script
```

---

## Shared services (always running)

```yaml
# deploy/docker-compose.shared.yml
version: '3.9'
services:
  db:
    image: postgres:16-alpine
    volumes: [postgres_data:/var/lib/postgresql/data]
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    restart: always
    networks: [shared_net]

  redis:
    image: redis:7-alpine
    restart: always
    networks: [shared_net]

  nginx:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/upstream.conf:/etc/nginx/upstream.conf:ro   # ← symlink to blue or green
      - ./certs:/etc/nginx/certs:ro
    restart: always
    networks: [shared_net]

volumes: {postgres_data:}
networks: {shared_net: {driver: bridge}}
```

---

## Blue environment

```yaml
# deploy/docker-compose.blue.yml
version: '3.9'
services:
  backend-blue:
    image: ${REGISTRY}/backend:${BLUE_VERSION}
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4
    environment:
      DJANGO_SETTINGS_MODULE: config.settings.production
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://redis:6379/0
      APP_COLOR: blue
      APP_VERSION: ${BLUE_VERSION}
    ports:
      - "8001:8000"              # unique port per color
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/readyz/"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 30s
    restart: always
    networks: [shared_net]

  celery-blue:
    image: ${REGISTRY}/backend:${BLUE_VERSION}
    command: celery -A config worker --loglevel=info
    environment:
      DATABASE_URL: postgres://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://redis:6379/0
      APP_COLOR: blue
    restart: always
    networks: [shared_net]

networks:
  shared_net:
    external: true
    name: deploy_shared_net
```

Green file is identical with `blue` replaced by `green` and port `8001` → `8002`.

---

## nginx upstream (the flip target)

```nginx
# deploy/nginx/upstream-blue.conf
upstream backend {
    server backend-blue:8000 max_fails=3 fail_timeout=30s;
}
```

```nginx
# deploy/nginx/upstream-green.conf
upstream backend {
    server backend-green:8000 max_fails=3 fail_timeout=30s;
}
```

```nginx
# deploy/nginx/nginx.conf
events { worker_connections 1024; }

http {
    include /etc/nginx/upstream.conf;   # ← symlink to upstream-blue.conf or upstream-green.conf

    upstream health_both {
        server backend-blue:8000  backup;   # optional: allow health checks on both
        server backend-green:8000 backup;
    }

    server {
        listen 443 ssl http2;
        server_name api.yourapp.com;

        ssl_certificate     /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;

        location / {
            proxy_pass http://backend;   # ← routed to blue or green
            proxy_set_header Host              $host;
            proxy_set_header X-Real-IP         $remote_addr;
            proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Request-ID      $request_id;

            proxy_connect_timeout 5s;
            proxy_read_timeout    30s;
        }

        location = /healthz {
            proxy_pass http://backend;
            access_log off;
        }
    }

    server {
        listen 80;
        server_name api.yourapp.com;
        return 301 https://$server_name$request_uri;
    }
}
```

---

## Deploy orchestration script

```bash
#!/usr/bin/env bash
# deploy/deploy.sh
set -euo pipefail

NEW_VERSION="${1:?Usage: deploy.sh <version>}"
COMPOSE_DIR="$(dirname "$0")"
cd "$COMPOSE_DIR"

# 1. Read current live color from nginx symlink
CURRENT_COLOR=$(readlink nginx/upstream.conf | sed 's/upstream-\(.*\)\.conf/\1/')
NEW_COLOR=$([[ "$CURRENT_COLOR" == "blue" ]] && echo "green" || echo "blue")

echo "═══════════════════════════════════════"
echo "  Current live: $CURRENT_COLOR"
echo "  Deploying to: $NEW_COLOR (version $NEW_VERSION)"
echo "═══════════════════════════════════════"

# 2. Set version env for new color
if [ "$NEW_COLOR" == "blue" ]; then
    export BLUE_VERSION="$NEW_VERSION"
else
    export GREEN_VERSION="$NEW_VERSION"
fi

# 3. Pull new image + start new environment
docker-compose -f docker-compose.shared.yml -f "docker-compose.$NEW_COLOR.yml" pull
docker-compose -f docker-compose.shared.yml -f "docker-compose.$NEW_COLOR.yml" up -d backend-$NEW_COLOR celery-$NEW_COLOR

# 4. Wait for new environment to be healthy
echo "Waiting for $NEW_COLOR to pass health checks..."
for i in {1..30}; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "backend-$NEW_COLOR-1" 2>/dev/null || echo "starting")
    if [ "$status" == "healthy" ]; then
        echo "✓ $NEW_COLOR is healthy"
        break
    fi
    echo "  [$i/30] $NEW_COLOR status: $status"
    sleep 5
done

if [ "$status" != "healthy" ]; then
    echo "❌ New environment failed health checks. Aborting — $CURRENT_COLOR still live."
    exit 1
fi

# 5. Smoke test against new environment directly (bypass nginx)
echo "Running smoke tests against $NEW_COLOR..."
BACKEND_PORT=$([[ "$NEW_COLOR" == "blue" ]] && echo "8001" || echo "8002")
SMOKE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$BACKEND_PORT/readyz/")
if [ "$SMOKE_RESULT" != "200" ]; then
    echo "❌ Smoke test failed (HTTP $SMOKE_RESULT). Aborting."
    exit 1
fi

# 6. Flip nginx symlink + reload
echo "Flipping traffic to $NEW_COLOR..."
ln -sfn "upstream-$NEW_COLOR.conf" nginx/upstream.conf
docker-compose -f docker-compose.shared.yml exec nginx nginx -s reload

echo "✓ Traffic now served by $NEW_COLOR"

# 7. Wait briefly, then stop old color (gives in-flight requests time to finish)
echo "Waiting 30s for in-flight requests on $CURRENT_COLOR..."
sleep 30
echo "Stopping $CURRENT_COLOR environment..."
docker-compose -f docker-compose.shared.yml -f "docker-compose.$CURRENT_COLOR.yml" stop "backend-$CURRENT_COLOR" "celery-$CURRENT_COLOR"

echo "═══════════════════════════════════════"
echo "  ✓ Deploy complete"
echo "  Live: $NEW_COLOR (version $NEW_VERSION)"
echo "  Previous $CURRENT_COLOR stopped (not removed — rollback-ready)"
echo "═══════════════════════════════════════"
```

---

## Rollback (instant)

```bash
#!/usr/bin/env bash
# deploy/rollback.sh
# Flips back to the previous color. Assumes its containers are still present (stopped).

set -euo pipefail
cd "$(dirname "$0")"

CURRENT=$(readlink nginx/upstream.conf | sed 's/upstream-\(.*\)\.conf/\1/')
PREVIOUS=$([[ "$CURRENT" == "blue" ]] && echo "green" || echo "blue")

echo "Rolling back $CURRENT → $PREVIOUS"

# Start the previous environment (it's still configured, just stopped)
docker-compose -f docker-compose.shared.yml -f "docker-compose.$PREVIOUS.yml" start "backend-$PREVIOUS" "celery-$PREVIOUS"

# Wait for health
for i in {1..20}; do
    status=$(docker inspect --format='{{.State.Health.Status}}' "backend-$PREVIOUS-1" 2>/dev/null)
    [ "$status" == "healthy" ] && break
    sleep 3
done

# Flip
ln -sfn "upstream-$PREVIOUS.conf" nginx/upstream.conf
docker-compose -f docker-compose.shared.yml exec nginx nginx -s reload

echo "✓ Rolled back to $PREVIOUS"
```

---

## Database migrations — the tricky part

Blue/green assumes both environments run against the same DB. This means:

**Rule 1:** Migrations must be backward-compatible between versions.
Blue (old) and green (new) both hit the DB simultaneously during the flip.

**Rule 2:** Never drop columns in one release. Two-phase:
- **Release N**: stop writing to the column (code change only)
- **Release N+1**: drop the column (migration only, after Release N is deployed)

**Rule 3:** Run migrations BEFORE starting the new color:

```bash
# In deploy.sh — between steps 3 and 4
echo "Running migrations..."
docker-compose -f docker-compose.shared.yml -f "docker-compose.$NEW_COLOR.yml" \
    run --rm "backend-$NEW_COLOR" python manage.py migrate --no-input
```

**Rule 4:** If a migration breaks backward-compatibility, you cannot blue/green.
Schedule downtime or do a proper schema migration tool (Gh-ost, pt-online-schema-change
on MySQL; pg-online-schema-change on Postgres).

---

## GitHub Actions integration

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    tags: ['v*']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build + push image
        run: |
          docker build -t $REGISTRY/backend:${{ github.ref_name }} backend/
          docker push $REGISTRY/backend:${{ github.ref_name }}
        env:
          REGISTRY: ${{ secrets.REGISTRY }}

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: deploy
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          script: |
            cd /opt/app/deploy
            ./deploy.sh ${{ github.ref_name }}
```

---

## Monitoring during deploy

The deploy script already checks health. Watch these too:

- **Error rate** (Prometheus alert) — should not spike during flip
- **Response time** (p95) — should not regress
- **Connection count** (pg_stat_activity) — briefly 2× during overlap, recovers after old color stops

Watch for 5 minutes post-deploy. Auto-rollback if error rate > 1%:

```bash
# deploy.sh — add at end
echo "Monitoring for 5 minutes..."
for i in {1..10}; do
    sleep 30
    error_rate=$(curl -s "$PROMETHEUS/api/v1/query?query=rate(django_http_responses_total_by_status{status=~\"5..\"}[1m])" | jq .data.result[0].value[1] -r)
    if (( $(echo "$error_rate > 0.01" | bc -l) )); then
        echo "❌ Error rate spiked to $error_rate — auto-rolling back"
        ./rollback.sh
        exit 1
    fi
done
echo "✓ 5-min monitoring window clean"
```

---

## Pros + cons

**Pros:**
- Zero-downtime deploys without K8s
- Instant rollback (nginx symlink flip)
- Previous version stays available for 1 cycle
- Simple to reason about

**Cons:**
- Needs 2× server capacity for the overlap period
- Requires backward-compatible migrations
- Shared DB is a coupling point — blue + green both hit it
- Manual ops runbook for scenarios outside the script

---

## When to move to K8s instead

See `deployment-k8s.md`. Short version: migrate to K8s when:
- You need autoscaling based on load
- You run > 5 backend instances
- Multi-region deploys
- You want canary deploys (5% traffic to new version first)

Docker blue/green is simpler but ceiling is ~20 instances.
