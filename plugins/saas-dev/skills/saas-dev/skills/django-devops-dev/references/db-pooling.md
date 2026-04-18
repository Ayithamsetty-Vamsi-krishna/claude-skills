# DevOps: Database Connection Pooling

## The problem
Django opens a new Postgres connection per request by default. With N gunicorn
workers × M Celery workers × (concurrent requests), you can easily hit
Postgres's `max_connections` limit (typical default: 100).

**Symptoms:**
- `FATAL: sorry, too many clients already` errors in logs
- Occasional slow requests that hang on connection acquisition
- High CPU on Postgres even with moderate query load

**Three strategies**, trade-offs below. Ask user at devops Phase 0:

```
Database connection pooling strategy?
→ [PgBouncer in transaction mode — recommended for Django + workers]
→ [PgBouncer in session mode — safer (supports all Postgres features), less efficient]
→ [Built-in Django CONN_MAX_AGE only — simplest, low-traffic only]
→ [Document all three — decide based on observed load]
```

---

## Decision matrix

| Strategy                    | Concurrent reqs | Uses LISTEN/NOTIFY | Uses prepared stmts | Ops overhead |
|-----------------------------|-----------------|--------------------|-----------------------|------|
| CONN_MAX_AGE (built-in)     | < 50            | ✓                  | ✓                     | None |
| PgBouncer session mode      | 50 – 500        | ✓                  | ✓                     | Low  |
| PgBouncer transaction mode  | 500 – 5000      | ✗                  | ✗ (need config)       | Low  |

---

## Strategy A: Django CONN_MAX_AGE only (simplest)

Built into Django. Workers keep one persistent connection reused across requests:

```python
# config/settings/production.py
DATABASES = {
    'default': {
        'ENGINE':   'django.db.backends.postgresql',
        'NAME':     config('DB_NAME'),
        'USER':     config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST':     config('DB_HOST'),
        'PORT':     config('DB_PORT', default='5432'),

        # Keep connection open for 600s — saves reconnect overhead per request
        'CONN_MAX_AGE': 600,

        # Validate connection before using (Django 4.1+)
        'CONN_HEALTH_CHECKS': True,

        'OPTIONS': {
            'connect_timeout': 5,
        },
    },
}
```

**Math:** N workers × 1 connection each = N Postgres connections. Plus Celery
workers. If you run 10 gunicorn + 5 Celery, that's 15 connections — fits easily
in the default 100.

**When this stops working:**
- More than ~50 total workers
- Many short-lived processes (CI tasks, scripts)
- Bursty traffic creating temporary worker pools

---

## Strategy B: PgBouncer session mode

Add PgBouncer as a connection multiplexer. Django connects to PgBouncer; PgBouncer
manages a pool of real Postgres connections. Session mode = one Postgres
connection held for the full Django connection lifetime.

### docker-compose

```yaml
services:
  pgbouncer:
    image: edoburu/pgbouncer:1.22.0
    environment:
      DB_USER:     ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_HOST:     db
      DB_NAME:     ${DB_NAME}
      POOL_MODE:   session            # ← session mode
      MAX_CLIENT_CONN:   1000
      DEFAULT_POOL_SIZE: 25
      AUTH_TYPE:   scram-sha-256
    ports:
      - "6432:6432"
    depends_on:
      db: {condition: service_healthy}

  db:
    image: postgres:16-alpine
    # ... existing config ...
    command: >
      postgres
        -c max_connections=100
        -c shared_buffers=256MB
```

### Django config

```python
# config/settings/production.py
DATABASES = {
    'default': {
        'ENGINE':   'django.db.backends.postgresql',
        'NAME':     config('DB_NAME'),
        'USER':     config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST':     'pgbouncer',    # ← point at PgBouncer, not db
        'PORT':     '6432',
        'CONN_MAX_AGE': 0,           # ← PgBouncer handles pooling, Django shouldn't
        'OPTIONS': {'connect_timeout': 5},
    },
}
```

### What works in session mode
- All Django ORM features
- LISTEN/NOTIFY (WebSockets with Django Channels)
- Prepared statements
- Advisory locks (some limitations — see gotchas)

### What's different
- Connection stays dedicated to one Django worker for its lifetime
- If Django worker dies mid-query, PgBouncer closes the connection
- Pool sized by `DEFAULT_POOL_SIZE` — tune based on worker count

---

## Strategy C: PgBouncer transaction mode (max throughput)

Transaction mode = PgBouncer can reuse one Postgres connection across multiple
Django connections, BUT only between transactions. Much more efficient — but
has limitations.

### PgBouncer config

```yaml
services:
  pgbouncer:
    image: edoburu/pgbouncer:1.22.0
    environment:
      POOL_MODE:   transaction         # ← transaction mode
      MAX_CLIENT_CONN:   5000
      DEFAULT_POOL_SIZE: 25
      # ... other vars same as above
```

### Django config (CRITICAL — must disable server-side features)

```python
# config/settings/production.py
DATABASES = {
    'default': {
        'ENGINE':   'django.db.backends.postgresql',
        'NAME':     config('DB_NAME'),
        'USER':     config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST':     'pgbouncer',
        'PORT':     '6432',
        'CONN_MAX_AGE': 0,

        # CRITICAL for transaction mode
        'DISABLE_SERVER_SIDE_CURSORS': True,

        'OPTIONS': {
            'connect_timeout': 5,
            # Disable prepared statements OR use psycopg3 with prepare_threshold=None
            # Django 4.2+ uses psycopg3 by default
        },
    },
}
```

### What breaks in transaction mode

1. **Prepared statements** — server-side state lost between transactions
   - Fix: use psycopg3 with `prepare_threshold=None` or the `Hint: SET plan_cache_mode = force_custom_plan`

2. **Server-side cursors** (for large querysets) — must use `DISABLE_SERVER_SIDE_CURSORS = True`
   - Effect: `.iterator()` on huge querysets will use a client-side cursor (slower
     but compatible)

3. **LISTEN/NOTIFY** — server-side channel state lost
   - Fix: connect directly to Postgres (bypass PgBouncer) for Django Channels

4. **Advisory locks** via `pg_advisory_lock()` — held at session level
   - Fix: use `pg_advisory_xact_lock()` (transaction-scoped)

5. **SET** / `SET LOCAL` — session state doesn't persist
   - Usually fine since Django rarely uses SET; watch for custom SQL

### Sizing the pool

```
# For each Django worker running 1 transaction at a time:
pool_size = gunicorn_workers + celery_workers + 10% buffer

# Example: 20 gunicorn + 10 celery workers
pool_size = 20 + 10 + 3 = 33 → round to 40
MAX_CLIENT_CONN = 5000   (so Django/PgBouncer connection doesn't limit you)
```

---

## Monitoring PgBouncer

```sql
-- Connect to PgBouncer with psql:
psql postgres://pgbouncer_admin:password@pgbouncer:6432/pgbouncer

-- Pool stats
SHOW POOLS;
-- cl_active / cl_waiting / sv_active / sv_idle

-- Slow queries hitting the pool
SHOW STATS;

-- Current client connections
SHOW CLIENTS;

-- Running queries
SHOW ACTIVE_SOCKETS;
```

Key metrics to watch:
- `cl_waiting > 0` — clients queuing for a connection (pool too small)
- `sv_used / pool_size > 0.8` — pool near capacity
- `sv_idle == 0` — all connections busy

Prometheus exporter:
- `pgbouncer_exporter` (Docker image) scrapes PgBouncer stats and exposes
  them to Prometheus. Add to docker-compose alongside pgbouncer.

---

## Read replica routing (mentioned in monitoring.md)

For high-read workloads, add a read replica. Brief mention here — most projects
don't need it. Django supports it via `DATABASES` + a DB router:

```python
# config/settings/production.py
DATABASES = {
    'default': { ... 'HOST': 'primary.db' },
    'replica': { ... 'HOST': 'replica.db' },
}

DATABASE_ROUTERS = ['core.db_routers.ReplicaRouter']
```

```python
# core/db_routers.py
class ReplicaRouter:
    def db_for_read(self, model, **hints):
        if model._meta.app_label in ('reports', 'analytics'):
            return 'replica'
        return 'default'

    def db_for_write(self, model, **hints):
        return 'default'
```

Full pattern out of scope for Tier 3. Revisit when read traffic > 10× write.

---

## Cost-saving trick: `CONN_MAX_AGE` + PgBouncer together

If you use PgBouncer session mode, you can also enable Django's `CONN_MAX_AGE`
to save the small cost of creating the Django→PgBouncer connection. Don't
bother with transaction mode — the connection to PgBouncer is already cheap.

---

## Testing in local dev

```bash
# docker-compose up pgbouncer db
# Connect manually to test
psql postgres://user:pass@localhost:6432/dbname

# Confirm Django uses PgBouncer
python manage.py dbshell
# Check: is the connection to port 6432?
```

---

## Known gotchas

1. **Django 4.2+ uses psycopg3** — some prepared-statement issues with
   transaction-mode PgBouncer are fixed. Upgrade if on psycopg2.

2. **`ATOMIC_REQUESTS = True`** — wraps every request in a transaction.
   Works fine with transaction-mode PgBouncer, but you hold a connection
   for the entire request duration. Long-running views = connection starvation.

3. **Idle-in-transaction timeout** — set `idle_in_transaction_session_timeout`
   in Postgres to 60s so stuck Django processes don't hold connections forever.

4. **Migration connections** — `manage.py migrate` opens a new Django connection,
   which PgBouncer pools normally. Fine.

5. **Django Channels + PgBouncer transaction mode** — doesn't work (needs
   LISTEN/NOTIFY). Configure Channels to bypass PgBouncer:

   ```python
   DATABASES['channels'] = {
       **DATABASES['default'],
       'HOST': 'db',              # direct to Postgres
       'PORT': '5432',
       'DISABLE_SERVER_SIDE_CURSORS': False,
   }
   ```

6. **Bad `DEFAULT_POOL_SIZE`** — too small = connection starvation. Too large =
   Postgres CPU overload. Rule of thumb: `pool_size = cores × 2` per replica.

---

## Summary

| Traffic level                | Strategy                                    |
|------------------------------|---------------------------------------------|
| < 50 req/sec, small team     | CONN_MAX_AGE only                           |
| 50 – 500 req/sec             | PgBouncer session mode                      |
| 500 – 5,000 req/sec          | PgBouncer transaction mode + app changes    |
| 5,000+ req/sec, multi-region | PgBouncer + read replicas + sharding        |

Document the choice in CLAUDE.md §7 ADR.
