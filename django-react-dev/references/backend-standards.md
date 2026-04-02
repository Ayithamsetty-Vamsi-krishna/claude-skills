# Backend Standards — Django REST Framework

## Project Structure (App-based)

```
backend/
├── config/
│   ├── settings/
│   │   ├── base.py
│   │   ├── development.py
│   │   └── production.py
│   ├── urls.py
│   └── wsgi.py
├── apps/
│   └── <feature_name>/          # One Django app per feature domain
│       ├── __init__.py
│       ├── admin.py
│       ├── apps.py
│       ├── filters.py            # FilterSet classes only
│       ├── models.py
│       ├── serializers.py
│       ├── views.py
│       ├── urls.py
│       ├── permissions.py        # Custom DRF permissions if needed
│       ├── managers.py           # Custom model managers
│       └── tests/
│           ├── __init__.py
│           └── test_<resource>.py
├── common/
│   ├── pagination.py             # Shared pagination classes
│   ├── permissions.py            # Shared permissions
│   └── mixins.py                 # Shared view/serializer mixins
└── manage.py
```

---

## Models

- snake_case field names always
- Always define `__str__`, `class Meta` with `ordering` and `verbose_name`
- Use `related_name` on every FK/M2M for reverse access clarity
- Use `on_delete=models.PROTECT` for FKs unless cascade is explicitly required
- No business logic in models — use model managers or serializer

```python
class Order(models.Model):
    customer = models.ForeignKey(
        Customer, on_delete=models.PROTECT, related_name="orders"
    )
    status = models.CharField(max_length=20, choices=StatusChoices.choices)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Order"
        verbose_name_plural = "Orders"

    def __str__(self):
        return f"Order #{self.pk} — {self.customer}"
```

---

## Views — DRF Generics Only

Always use the appropriate Generic view. Never use plain APIView unless no generic fits.

| Use case | Generic class |
|---|---|
| List + Create | `generics.ListCreateAPIView` |
| Retrieve + Update + Delete | `generics.RetrieveUpdateDestroyAPIView` |
| Retrieve only | `generics.RetrieveAPIView` |
| Create only | `generics.CreateAPIView` |
| List only | `generics.ListAPIView` |

```python
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from .models import Order
from .serializers import OrderSerializer
from .filters import OrderFilter

class OrderListCreateView(generics.ListCreateAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]
    filterset_class = OrderFilter

    def get_queryset(self):
        return (
            Order.objects
            .select_related("customer")
            .prefetch_related("items__product")
            .filter(customer__user=self.request.user)
        )


class OrderDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            Order.objects
            .select_related("customer")
            .prefetch_related("items__product")
            .filter(customer__user=self.request.user)
        )
```

**ORM Rules (strict — no exceptions):**
- Always `select_related` for FK/OneToOne accessed in serializer
- Always `prefetch_related` for reverse FK / M2M accessed in serializer
- Never call `.count()`, `.exists()`, or iterate related objects in Python — use `annotate()`
- No N+1: if in doubt, log queries in development with django-debug-toolbar or `django.db.connection.queries`

---

## URLs

Plural REST nouns. Always versioned under `/api/v1/`.

```python
# apps/orders/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path("", views.OrderListCreateView.as_view(), name="order-list"),
    path("<int:pk>/", views.OrderDetailView.as_view(), name="order-detail"),
]

# config/urls.py
urlpatterns = [
    path("api/v1/orders/", include("apps.orders.urls")),
]
```

---

## Serializers

### Dual FK Pattern (required on all FK fields)

For every FK field, expose TWO fields:
- `<field>_id` — writable integer field (PrimaryKeyRelatedField)
- `<field>` — read-only nested serializer (for GET responses)

```python
class OrderSerializer(serializers.ModelSerializer):
    # Write field
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source="customer", write_only=False
    )
    # Read field
    customer = CustomerSerializer(read_only=True)

    class Meta:
        model = Order
        fields = ["id", "customer_id", "customer", "status", "created_at"]
```

### Nested Children (One-to-Many) — custom create/update always

Never use drf-writable-nested. Always write explicit `create()` and `update()`.

```python
class OrderSerializer(serializers.ModelSerializer):
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source="customer"
    )
    customer = CustomerSerializer(read_only=True)
    items = OrderItemSerializer(many=True)  # nested list — read + write

    class Meta:
        model = Order
        fields = ["id", "customer_id", "customer", "status", "items"]

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])
        order = Order.objects.create(**validated_data)
        for item_data in items_data:
            OrderItem.objects.create(order=order, **item_data)
        return order

    def update(self, instance, validated_data):
        items_data = validated_data.pop("items", None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if items_data is not None:
            instance.items.all().delete()
            for item_data in items_data:
                OrderItem.objects.create(order=instance, **item_data)
        return instance
```

### SerializerMethodField for computed/annotated values

```python
total_amount = serializers.SerializerMethodField()

def get_total_amount(self, obj):
    return obj.total_amount  # must be annotated on queryset, not computed here
```

---

## Filters — FilterSet Classes Only

Never filter via raw `request.query_params`. Always use `django-filter` FilterSet.

```python
# apps/orders/filters.py
import django_filters
from .models import Order

class OrderFilter(django_filters.FilterSet):
    status = django_filters.CharFilter(lookup_expr="iexact")
    created_after = django_filters.DateFilter(field_name="created_at", lookup_expr="gte")
    created_before = django_filters.DateFilter(field_name="created_at", lookup_expr="lte")
    customer_name = django_filters.CharFilter(
        field_name="customer__name", lookup_expr="icontains"
    )

    class Meta:
        model = Order
        fields = ["status", "created_after", "created_before", "customer_name"]
```

---

## Pagination

Always paginate list endpoints. Define in `common/pagination.py`:

```python
from rest_framework.pagination import PageNumberPagination

class StandardPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
```

Set as default in settings:
```python
REST_FRAMEWORK = {
    "DEFAULT_PAGINATION_CLASS": "common.pagination.StandardPagination",
    "PAGE_SIZE": 20,
}
```

---

## Authentication — JWT (djangorestframework-simplejwt)

```python
# settings/base.py
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
}
```

Endpoints:
- `POST /api/v1/auth/token/` — obtain token pair
- `POST /api/v1/auth/token/refresh/` — refresh access token
