# DevOps: Zero-Downtime Migrations

## The problem
Running `python manage.py migrate` during deployment while the old code is still
serving requests can break things. New columns don't exist yet, old code reads
columns that are being dropped, etc.

---

## Safe migration patterns

### Adding a new column (safe)
```python
# Always nullable first or with a default — never NOT NULL without default
class Migration(migrations.Migration):
    operations = [
        migrations.AddField(
            model_name='order',
            name='priority',
            field=models.CharField(
                max_length=20,
                choices=[('low','Low'),('high','High')],
                default='low',   # ← required for zero-downtime
                blank=True,
            ),
        ),
    ]
# After migration is stable in production, you can make it NOT NULL in a second migration
```

### Renaming a column (3-step)
```python
# Step 1 (deploy 1): Add new column alongside old column
migrations.AddField(model_name='order', name='customer_name', ...)

# Step 2 (deploy 2): Write to both columns, read from new column
# (code change, no migration)

# Step 3 (deploy 3): Remove old column
migrations.RemoveField(model_name='order', name='client_name')
```

### Removing a column (2-step)
```python
# Step 1 (deploy 1): Remove all code references to the column
# Step 2 (deploy 2): Drop the column via migration
# NEVER drop a column and remove code references in the same deploy
```

### Adding an index (safe — non-blocking)
```python
# Use CONCURRENTLY to avoid table lock (PostgreSQL)
migrations.AddIndex(
    model_name='order',
    index=models.Index(
        fields=['status', 'created_at'],
        name='order_status_created_idx',
        db_tablespace='pg_default',
    ),
)
# Or with raw SQL for CONCURRENT index:
migrations.RunSQL(
    sql="CREATE INDEX CONCURRENTLY IF NOT EXISTS order_status_idx ON orders_order(status)",
    reverse_sql="DROP INDEX IF EXISTS order_status_idx",
    state_operations=[
        migrations.AddIndex(model_name='order',
                           index=models.Index(fields=['status'], name='order_status_idx'))
    ]
)
```

---

## Deployment sequence (zero-downtime)

```bash
# Zero-downtime deploy sequence:

# 1. Run migrations BEFORE deploying new code
#    (migrations must be backward-compatible with old code)
python manage.py migrate --no-input

# 2. Deploy new code after migrations complete
#    (new code must be backward-compatible with old schema too)
# [trigger Render/Railway/DO deploy]

# 3. Verify health check passes before routing traffic
curl https://yourapp.com/health/

# In GitHub Actions CD:
jobs:
  deploy:
    steps:
      - name: Run migrations
        run: |
          # SSH into server or use provider CLI to run migrate first
          railway run python manage.py migrate --no-input

      - name: Deploy new code
        # then trigger deployment
```

---

## Dangerous operations (never in zero-downtime)

```python
# NEVER do these in a single deployment:
# 1. Drop a column that current code still reads
# 2. Rename a column (use 3-step pattern above)
# 3. Change a column type (add new + copy data + drop old)
# 4. Add NOT NULL constraint without default on existing table with data

# Data migrations — always separate from schema migrations
class Migration(migrations.Migration):
    operations = [
        migrations.RunPython(
            code=populate_new_field,
            reverse_code=migrations.RunPython.noop,
        )
    ]
```

---

## Production migration checklist

Before running any migration in production:

- [ ] Migration tested on staging with production-size data
- [ ] Migration is backward-compatible with currently deployed code
- [ ] New columns have defaults or are nullable
- [ ] No column drops or renames in same migration as code changes
- [ ] Large table migrations use CONCURRENTLY index creation
- [ ] Backup taken before applying irreversible migrations
- [ ] Rollback plan documented (what to do if migration fails)

---

## Database backup before destructive migrations

```bash
# Always backup before any migration that drops columns, changes types, or modifies data

# PostgreSQL backup (before running migrate)
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# In GitHub Actions — backup before migration step
- name: Backup database
  run: |
    pg_dump ${{ secrets.DATABASE_URL }} > backup_${{ github.sha }}.sql
    # Store in S3 or artifact
    aws s3 cp backup_${{ github.sha }}.sql s3://your-backups/migrations/

- name: Run migrations
  run: python manage.py migrate --no-input
```

---

## Rollback procedure

```bash
# If deployment fails after migrations were applied:

# Step 1 — Roll back the code (revert to previous deploy)
# Render: redeploy previous commit
# Railway: railway rollback
# Manual: git revert + push

# Step 2 — Reverse the migration (only if backward-compatible steps were used)
python manage.py migrate <app_name> <previous_migration_name>
# Example: python manage.py migrate orders 0024_add_status_field
# ⚠️ Only works if the migration has a proper reverse operation
# ⚠️ Data migrations with RunPython need explicit reverse_code=

# Step 3 — Restore from backup (if migration cannot be reversed)
psql $DATABASE_URL < backup_20240101_120000.sql
```

### Making migrations reversible
```python
# Always provide reverse_code for data migrations
class Migration(migrations.Migration):
    operations = [
        migrations.RunPython(
            code=populate_priority_field,
            reverse_code=lambda apps, schema_editor: apps.get_model('orders', 'Order')
                .objects.all().update(priority=None)  # ← rollback: clear the field
        )
    ]
```

### SSL / HTTPS configuration
```python
# settings/production.py — enable only when SSL is confirmed working
SECURE_SSL_REDIRECT = True           # redirect HTTP → HTTPS
SECURE_HSTS_SECONDS = 31536000       # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
```
```yaml
# For Render/Railway/DO — SSL is handled at platform level (automatic)
# For VPS — use Nginx + Certbot (Let's Encrypt):
# sudo apt install certbot python3-certbot-nginx
# sudo certbot --nginx -d yourdomain.com
```
