# Backend: Sequential Code Generation (ORD-0001)

## Rule
- Lives in core/utils.py — called from model save() ONLY
- NEVER call from serializer or view — model is responsible for its own code
- Always gap-free via select_for_update() — prevents race conditions
- Configurable: per-tenant OR global — skill asks user at task time

---

## core/utils.py

```python
# core/utils.py
from django.db import transaction


def generate_code(
    model_class,
    prefix: str,
    field: str = 'code',
    pad: int = 4,
    tenant_id=None,
) -> str:
    """
    Generates a unique sequential code like ORD-0001.

    Uses select_for_update() to lock the latest record, preventing race conditions
    when multiple requests generate codes simultaneously.

    Args:
        model_class: The Django model class (e.g. Order)
        prefix: Code prefix (e.g. 'ORD', 'INV', 'JC')
        field: The field name on the model that holds the code (default: 'code')
        pad: Zero-padding length (default: 4 → ORD-0001)
        tenant_id: If provided, generates per-tenant sequence (ORD-0001 per tenant)
                   If None, generates global sequence

    Returns:
        str: The next code (e.g. 'ORD-0001')
    """
    with transaction.atomic():
        # Build queryset — filter by prefix and optionally by tenant
        qs = model_class.objects.select_for_update().filter(
            **{f'{field}__startswith': prefix}
        )
        if tenant_id is not None:
            # Per-tenant: only look at this tenant's codes
            qs = qs.filter(tenant_id=tenant_id)

        # Find the last code in sequence
        last = qs.order_by(f'-{field}').first()

        if last:
            last_code = getattr(last, field)
            # Extract numeric part after the last dash
            try:
                last_num = int(last_code.rsplit('-', 1)[-1])
                new_num = last_num + 1
            except (ValueError, IndexError):
                new_num = 1
        else:
            new_num = 1

        return f"{prefix}-{str(new_num).zfill(pad)}"
```

---

## Model integration

```python
# orders/models.py
from core.models import BaseModel
from core.utils import generate_code
from django.db import models


class Order(BaseModel):
    code = models.CharField(max_length=20, unique=True, blank=True, editable=False)
    # ... other fields

    def save(self, *args, **kwargs):
        if not self.code:
            # Generate code on first save only
            self.code = generate_code(
                model_class=Order,
                prefix='ORD',
                field='code',
                pad=4,
                # tenant_id=self.tenant_id,  # uncomment for per-tenant sequences
            )
        super().save(*args, **kwargs)
```

---

## Per-tenant variant

```python
# When each tenant has their own ORD-0001 counter:
def save(self, *args, **kwargs):
    if not self.code:
        self.code = generate_code(
            model_class=Order,
            prefix='ORD',
            tenant_id=self.tenant_id,   # scopes sequence to this tenant
        )
    super().save(*args, **kwargs)
# Result: Tenant A → ORD-0001, ORD-0002 | Tenant B → ORD-0001, ORD-0002 (independent)
```

---

## Testing sequential codes

```python
@pytest.mark.django_db
class TestCodeGeneration:

    def test_first_code_is_0001(self, user):
        order = OrderFactory(created_by=user, updated_by=user, code='')
        order.save()  # triggers generate_code
        assert order.code == 'ORD-0001'

    def test_codes_increment_sequentially(self, user):
        order1 = Order.objects.create(created_by=user, updated_by=user, ...)
        order2 = Order.objects.create(created_by=user, updated_by=user, ...)
        assert order1.code == 'ORD-0001'
        assert order2.code == 'ORD-0002'

    def test_code_not_overwritten_on_update(self, order):
        original_code = order.code
        order.notes = 'updated'
        order.save()
        order.refresh_from_db()
        assert order.code == original_code   # code never changes after creation

    def test_concurrent_code_generation_no_duplicates(self, user):
        """Race condition test — multiple threads generating codes simultaneously."""
        import threading
        codes = []
        errors = []

        def create_order():
            try:
                order = Order.objects.create(created_by=user, updated_by=user, ...)
                codes.append(order.code)
            except Exception as e:
                errors.append(str(e))

        threads = [threading.Thread(target=create_order) for _ in range(10)]
        for t in threads: t.start()
        for t in threads: t.join()

        assert len(errors) == 0
        assert len(codes) == len(set(codes))   # all codes are unique
```

---

## Important: Never use bulk_create with sequential codes

```python
# WRONG — bulk_create bypasses save(), codes will be blank/null
Order.objects.bulk_create([Order(...) for i in range(10)])

# CORRECT — individual creates trigger save() → generate_code()
for data in order_data_list:
    Order.objects.create(**data)
```
