# Backend: Admin, Testing & Project Config

---

## Admin Pattern
Every model MUST be registered with full config. Never use bare `admin.site.register()`.

```python
from django.contrib import admin
from .models import Order, OrderItem

class OrderItemInline(admin.TabularInline):
    model = OrderItem
    extra = 0
    readonly_fields = ('id', 'created_at', 'updated_at', 'created_by', 'updated_by')
    fields = ('product', 'quantity', 'unit_price', 'is_active', 'is_deleted')

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'status', 'total_amount',
                    'is_active', 'is_deleted', 'created_at', 'created_by')
    list_filter = ('status', 'is_active', 'is_deleted', 'created_at')
    search_fields = ('id', 'customer__name', 'customer__email', 'notes')
    readonly_fields = ('id', 'created_at', 'updated_at', 'created_by', 'updated_by', 'deleted_at')
    fieldsets = (
        ('Details', {'fields': ('customer', 'status', 'total_amount', 'notes')}),
        ('Status', {'fields': ('is_active', 'is_deleted', 'deleted_at')}),
        ('Audit', {'classes': ('collapse',),
                   'fields': ('id', 'created_at', 'updated_at', 'created_by', 'updated_by')}),
    )
    inlines = [OrderItemInline]

    def delete_model(self, request, obj):
        from django.utils import timezone
        obj.is_deleted = True
        obj.is_active = False
        obj.deleted_at = timezone.now()
        obj.deleted_by = request.user    # ← set deleted_by on single record
        obj.save()

    def delete_queryset(self, request, queryset):
        """
        Bulk soft-delete from admin list view.
        NOTE: Django's .update() cannot set deleted_by (no access to request.user in ORM).
        Two options — choose based on whether deleted_by audit trail matters more than speed:

        Option A — Loop (slower, fills deleted_by correctly):
        """
        from django.utils import timezone
        for obj in queryset:
            obj.is_deleted = True
            obj.is_active = False
            obj.deleted_at = timezone.now()
            obj.deleted_by = request.user
            obj.save()

        # Option B — Bulk update (faster, deleted_by stays null):
        # queryset.update(is_deleted=True, is_active=False, deleted_at=timezone.now())
```

---
