# Backend: Field-Level Encryption (MultiFernet Rotating Keys)

## Purpose
Some fields carry sensitive data — government IDs, phone numbers, signing
secrets, API tokens — that must be encrypted at rest. Database-level
encryption (TDE on RDS, Postgres pgcrypto) covers disk theft but not database
leaks or SQL injection. **Application-level encryption** protects even when
the attacker reads the database directly.

This pattern uses Python `cryptography` library's `Fernet` + `MultiFernet`
for key rotation — no external service, no added infra. When enterprise needs
audit/compliance beyond this, upgrade to AWS KMS or HashiCorp Vault.

---

## When to use field encryption

Encrypt these field types:
- Government identifiers (SSN, Aadhaar, passport)
- Phone numbers (in some jurisdictions — PII)
- API tokens + webhook secrets (regenerable, but still sensitive)
- Full name + DOB combinations (re-identification risk)
- Medical record numbers
- Bank account details (or don't store at all — use Stripe)

**Do NOT encrypt:**
- Fields used in `WHERE` queries (encryption breaks indexing)
- Fields used in search (see `search-postgres.md`)
- Fields displayed in list views (repeated decryption is slow)

**Index workaround for searchable encrypted fields:** Store an SHA-256 hash
of the sensitive value in a separate `<field>_hash` column for exact-match
lookups. The hash is deterministic; the encrypted value is not.

---

## Why MultiFernet (not plain Fernet)

`Fernet` encrypts with one key. If the key leaks, you must re-encrypt every
row — outage-level work.

`MultiFernet` accepts a LIST of keys. It:
- **Decrypts** with any key in the list (tries each until one works)
- **Encrypts** with the FIRST key in the list
- You can **add a new key at position 0** and gradually re-encrypt old values

This enables zero-downtime key rotation. New writes use the new key; old
reads still work with old keys; a background job re-encrypts row by row.

---

## Install

```
# requirements.txt
cryptography>=42.0
```

No system deps; pure Python + OpenSSL (usually present).

---

## Key management

```python
# core/encryption/keys.py
from cryptography.fernet import Fernet, MultiFernet
from django.conf import settings


def generate_new_key() -> str:
    """Run once to create a key. Store the result as an env var."""
    return Fernet.generate_key().decode()


def get_fernet() -> MultiFernet:
    """
    Returns a MultiFernet built from settings.FERNET_KEYS.

    FERNET_KEYS is a list from env (comma-separated). Order matters:
      - Position 0: current key (used for ALL new encryption)
      - Position 1+: old keys (used for decryption only)

    Environment example:
      FERNET_KEYS=<key_2025_04>,<key_2024_10>,<key_2023_05>
    """
    keys = settings.FERNET_KEYS
    if not keys:
        raise RuntimeError(
            'FERNET_KEYS not set. Generate one with generate_new_key() and '
            'add to .env as a comma-separated list.'
        )

    fernets = [Fernet(key.encode() if isinstance(key, str) else key) for key in keys]
    return MultiFernet(fernets)


# Single shared instance per process — Fernet is cheap to instantiate but
# caching saves ~2ms per encryption
_cached_fernet = None

def get_cached_fernet() -> MultiFernet:
    global _cached_fernet
    if _cached_fernet is None:
        _cached_fernet = get_fernet()
    return _cached_fernet
```

---

## Settings

```python
# settings/base.py
import os
from decouple import config, Csv


FERNET_KEYS = config('FERNET_KEYS', default='', cast=Csv())

# Safety: fail loudly in production if not set
if not DEBUG and not FERNET_KEYS:
    raise ValueError(
        'FERNET_KEYS must be set in production. '
        'Generate one via: python -c "from cryptography.fernet import Fernet; '
        'print(Fernet.generate_key().decode())"'
    )
```

```bash
# .env (dev)
# Generate a key:  python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
FERNET_KEYS=AbCdEf123...
```

```bash
# .env.example (commit this)
FERNET_KEYS=  # Comma-separated list of Fernet keys. Position 0 is current.
```

---

## Custom field: `EncryptedCharField`

```python
# core/encryption/fields.py
from cryptography.fernet import InvalidToken
from django.core.exceptions import ValidationError
from django.db import models
from .keys import get_cached_fernet


class EncryptedCharField(models.CharField):
    """
    Encrypts / decrypts a short string transparently.

    Database column stores base64 ciphertext. Python code reads/writes plaintext.

    WARNING: Cannot be used in WHERE queries, filters, or full-text search.
             For searchable sensitive data, add a separate <field>_hash column.

    Implementation notes:
    - max_length is of the PLAINTEXT; DB column size is larger (ciphertext is
      ~1.5x longer due to base64 + IV). We default to 4× headroom.
    - Empty string is stored as empty; None is stored as None. Only non-empty
      values are encrypted.
    """

    description = "A char field, encrypted with MultiFernet"

    def __init__(self, *args, **kwargs):
        # DB column size: plaintext max × 4 (cipher overhead + b64)
        # This limits you to max 8KB plaintext, which is fine for
        # phone numbers, tokens, secrets.
        self._plaintext_max_length = kwargs.pop('max_length', 255)
        kwargs['max_length'] = self._plaintext_max_length * 4
        super().__init__(*args, **kwargs)

    def from_db_value(self, value, expression, connection):
        """Read path: DB ciphertext → Python plaintext."""
        if value is None or value == '':
            return value
        fernet = get_cached_fernet()
        try:
            return fernet.decrypt(value.encode('utf-8')).decode('utf-8')
        except InvalidToken:
            # Log but don't crash — legacy un-encrypted row, data corruption,
            # or key list doesn't contain the key this was encrypted with.
            import logging
            logging.getLogger('encryption').error(
                'Failed to decrypt field — possible missing rotation key'
            )
            return None

    def to_python(self, value):
        """Form / serializer → Python. Return value as-is (already plaintext)."""
        return value

    def get_prep_value(self, value):
        """Write path: Python plaintext → DB ciphertext."""
        if value is None or value == '':
            return value
        if not isinstance(value, str):
            value = str(value)
        if len(value) > self._plaintext_max_length:
            raise ValidationError(
                f'Plaintext too long: {len(value)} > {self._plaintext_max_length}'
            )
        fernet = get_cached_fernet()
        return fernet.encrypt(value.encode('utf-8')).decode('utf-8')

    def deconstruct(self):
        name, path, args, kwargs = super().deconstruct()
        # Emit max_length as the plaintext size, not the DB column size
        kwargs['max_length'] = self._plaintext_max_length
        return name, path, args, kwargs


class EncryptedTextField(EncryptedCharField):
    """Same as EncryptedCharField but maps to TEXT (no size limit in DB)."""

    def db_type(self, connection):
        return 'text'
```

---

## Searchable encrypted data — use a hash column

If you need to query for a record by its encrypted value, store a hash:

```python
import hashlib
from core.encryption.fields import EncryptedCharField


class CustomerUser(AbstractBaseUser, BaseModel):
    # Plain fields
    email = models.EmailField(unique=True)

    # Encrypted at rest, unsearchable
    phone = EncryptedCharField(max_length=20, blank=True)
    # Searchable hash — can look up "who has this phone number?"
    phone_hash = models.CharField(max_length=64, blank=True, db_index=True)

    def save(self, *args, **kwargs):
        # Keep phone_hash in sync with phone
        if self.phone:
            self.phone_hash = hashlib.sha256(
                self._normalize_phone(self.phone).encode()
            ).hexdigest()
        else:
            self.phone_hash = ''
        super().save(*args, **kwargs)

    @staticmethod
    def _normalize_phone(phone):
        """Strip non-digits to make hash consistent across formats."""
        return ''.join(c for c in phone if c.isdigit())


# Lookup:
phone_input = '+1 (555) 123-4567'
normalized = CustomerUser._normalize_phone(phone_input)
lookup_hash = hashlib.sha256(normalized.encode()).hexdigest()
customer = CustomerUser.objects.filter(phone_hash=lookup_hash).first()
```

---

## Example: applied to a model

```python
# customers/models.py
from core.models import BaseModel
from core.encryption.fields import EncryptedCharField, EncryptedTextField


class CustomerUser(AbstractBaseUser, BaseModel):
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=200)

    # Government ID — sensitive, never displayed, occasionally compared
    national_id        = EncryptedCharField(max_length=50, blank=True)
    national_id_hash   = models.CharField(max_length=64, blank=True, db_index=True)

    # Phone — displayed to customer themselves, searchable via hash
    phone      = EncryptedCharField(max_length=20, blank=True)
    phone_hash = models.CharField(max_length=64, blank=True, db_index=True)

    # Customer notes (staff-authored) — might contain PII
    notes = EncryptedTextField(blank=True)

    class Meta:
        # Useful indexes only on non-encrypted columns
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['phone_hash']),
            models.Index(fields=['national_id_hash']),
        ]
```

---

## Key rotation workflow

**Step 1: Generate a new key.**

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# Output: <new_key>
```

**Step 2: Update FERNET_KEYS — new key FIRST.**

```
# .env — before
FERNET_KEYS=old_key_1,old_key_2

# .env — after
FERNET_KEYS=new_key,old_key_1,old_key_2
```

Deploy. **All new writes** use the new key. **All reads** still work because
old keys remain in the list.

**Step 3: Re-encrypt existing rows.** Run in background:

```python
# core/encryption/management/commands/rotate_encryption.py
from django.core.management.base import BaseCommand
from django.db import transaction
from django.apps import apps
from core.encryption.fields import EncryptedCharField, EncryptedTextField


class Command(BaseCommand):
    help = 'Re-encrypt all EncryptedField values with the current key'

    def add_arguments(self, parser):
        parser.add_argument('--model', help='app.Model (default: all models with encrypted fields)')
        parser.add_argument('--batch-size', type=int, default=500)
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        models = self._models_with_encrypted_fields(options.get('model'))
        for model_cls, fields in models:
            self._rotate_model(model_cls, fields, options['batch_size'], options['dry_run'])

    def _models_with_encrypted_fields(self, target):
        results = []
        for m in apps.get_models():
            encrypted_fields = [
                f for f in m._meta.get_fields()
                if isinstance(f, (EncryptedCharField, EncryptedTextField))
            ]
            if encrypted_fields:
                if target and f'{m._meta.app_label}.{m.__name__}' != target:
                    continue
                results.append((m, encrypted_fields))
        return results

    def _rotate_model(self, model_cls, fields, batch_size, dry_run):
        total = model_cls.objects.count()
        self.stdout.write(f'{model_cls.__name__}: {total} rows, fields {[f.name for f in fields]}')

        if dry_run:
            return

        processed = 0
        for offset in range(0, total, batch_size):
            with transaction.atomic():
                ids = list(model_cls.objects.values_list('id', flat=True)[offset:offset+batch_size])
                for obj in model_cls.objects.filter(id__in=ids):
                    # Just saving re-encrypts with the current key (Position 0 of FERNET_KEYS)
                    obj.save(update_fields=[f.name for f in fields])
                processed += len(ids)
            self.stdout.write(f'  {processed}/{total}')
```

**Step 4: After all rows re-encrypted, remove the old key.**

```
# .env
FERNET_KEYS=new_key
```

Deploy. Old key is no longer needed for decryption. If you find orphan rows,
add the old key back temporarily.

---

## Testing

```python
# core/encryption/tests/test_fields.py
import pytest
from customers.models import CustomerUser


@pytest.mark.django_db
class TestEncryptedFields:
    def test_encrypted_round_trip(self):
        customer = CustomerUser.objects.create(
            email='test@example.com',
            full_name='Test User',
            phone='+15551234567',
        )
        customer.refresh_from_db()
        assert customer.phone == '+15551234567'   # decrypted successfully

    def test_database_stores_ciphertext(self, db):
        customer = CustomerUser.objects.create(
            email='test@example.com',
            full_name='Test User',
            phone='+15551234567',
        )
        # Query raw DB — ciphertext, not plaintext
        from django.db import connection
        with connection.cursor() as cursor:
            cursor.execute('SELECT phone FROM customers_customeruser WHERE id=%s', [customer.id])
            raw_value = cursor.fetchone()[0]
        assert raw_value != '+15551234567'
        assert len(raw_value) > 40   # base64 Fernet token is long
        assert raw_value.startswith('gAAAA')   # Fernet magic prefix

    def test_hash_enables_lookup(self):
        customer = CustomerUser.objects.create(
            email='test@example.com', full_name='Test', phone='+15551234567',
        )
        import hashlib
        lookup_hash = hashlib.sha256(b'15551234567').hexdigest()
        assert CustomerUser.objects.filter(phone_hash=lookup_hash).first() == customer

    def test_old_key_decrypts_after_rotation(self, settings):
        from cryptography.fernet import Fernet
        old_key = Fernet.generate_key().decode()
        new_key = Fernet.generate_key().decode()

        # 1. Write with only old key
        settings.FERNET_KEYS = [old_key]
        # Reset cached Fernet
        from core.encryption import keys
        keys._cached_fernet = None

        customer = CustomerUser.objects.create(
            email='test@example.com', full_name='Test', phone='+15551234567',
        )

        # 2. Add new key at position 0
        settings.FERNET_KEYS = [new_key, old_key]
        keys._cached_fernet = None

        # Old record still decrypts because old key is in the list
        customer.refresh_from_db()
        assert customer.phone == '+15551234567'

        # New update re-encrypts with new key
        customer.phone = '+15559999999'
        customer.save()
        customer.refresh_from_db()
        assert customer.phone == '+15559999999'

        # 3. Remove old key — previous UNTOUCHED rows would fail, but this row was
        # re-saved so it's encrypted with new key and still decrypts
        settings.FERNET_KEYS = [new_key]
        keys._cached_fernet = None
        customer.refresh_from_db()
        assert customer.phone == '+15559999999'
```

---

## Admin handling

Django admin calls `field.to_python()` on form submit — encryption happens
automatically. Displaying in list views is fine but **slow on many rows**
because each row decrypts. Avoid encrypted fields in `list_display` for
list pages with hundreds of rows.

```python
@admin.register(CustomerUser)
class CustomerUserAdmin(admin.ModelAdmin):
    # Don't put 'phone' in list_display — causes N decryptions per page load
    list_display = ('email', 'full_name', 'phone_hash', 'created_at')
    readonly_fields = ('phone_hash', 'national_id_hash')
    search_fields = ('email',)    # can't search 'phone' directly
```

---

## Alternatives + upgrade paths

When this simple pattern is not enough:

- **Need HSM / hardware keys** → AWS KMS, GCP KMS, Azure Key Vault
- **Need full audit trail of key use** → Vault with audit log enabled
- **Need per-tenant keys** → MultiFernet still works; store tenant-scoped keys
- **Need asymmetric crypto** (sign vs encrypt) → `cryptography.hazmat.primitives`
- **Regulated industry** (HIPAA, PCI) — field encryption is one requirement among
  many; dedicated compliance review needed.

Document the choice in CLAUDE.md §7 ADR.

---

## Security reminders

- **FERNET_KEYS is a secret.** Never commit. Never log. Rotate yearly minimum.
- **Keys in bytes, not base64** — Fernet library expects bytes. Our code
  handles `.encode()` / `.decode()` but double-check when debugging.
- **Don't use deterministic encryption** — MultiFernet uses a random IV per
  encryption, so the same plaintext produces different ciphertexts. That's
  why you can't search on encrypted fields; it's also why attackers can't
  learn patterns from ciphertext.
- **Assume the DB is compromised, not the app server.** Field encryption
  protects against DB leaks but NOT against an attacker with app server
  access (they have the keys).
