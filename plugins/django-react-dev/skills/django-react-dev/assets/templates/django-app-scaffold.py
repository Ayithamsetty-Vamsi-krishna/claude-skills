# assets/templates/django-app-scaffold.py
# Load ONLY when scaffolding a brand new Django app from scratch.
# Copy-paste and replace <AppName>, <app_name>, <ModelName> as needed.

# ── core/models.py ────────────────────────────────────────────────────────────
CORE_MODELS = '''
import uuid
from django.db import models
from django.conf import settings

class BaseModel(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="%(app_label)s_%(class)s_created")
    updated_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
        on_delete=models.SET_NULL, related_name="%(app_label)s_%(class)s_updated")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False, db_index=True)
    is_active = models.BooleanField(default=True, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True
'''

# ── core/mixins.py ────────────────────────────────────────────────────────────
CORE_MIXINS = '''
from django.utils import timezone
from rest_framework.response import Response
from rest_framework import status

class SoftDeleteMixin:
    def perform_destroy(self, instance):
        instance.is_deleted = True
        instance.is_active = False
        instance.deleted_at = timezone.now()
        instance.save(update_fields=["is_deleted","is_active","deleted_at","updated_at"])
    def destroy(self, request, *args, **kwargs):
        self.perform_destroy(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)

class AuditMixin:
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user, updated_by=self.request.user)
    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)
'''

# ── core/pagination.py ────────────────────────────────────────────────────────
CORE_PAGINATION = '''
from rest_framework.pagination import PageNumberPagination

class DefaultPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100
'''

# ── <app>/models.py ───────────────────────────────────────────────────────────
APP_MODEL = '''
from django.db import models
from core.models import BaseModel

class <ModelName>(BaseModel):
    # Add your fields here
    name = models.CharField(max_length=255)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "<ModelName>"
        verbose_name_plural = "<ModelName>s"

    def __str__(self):
        return self.name
'''

# ── <app>/admin.py ────────────────────────────────────────────────────────────
APP_ADMIN = '''
from django.contrib import admin
from .models import <ModelName>

@admin.register(<ModelName>)
class <ModelName>Admin(admin.ModelAdmin):
    list_display = ("id", "name", "is_active", "is_deleted", "created_at", "created_by")
    list_filter = ("is_active", "is_deleted", "created_at")
    search_fields = ("id", "name")
    readonly_fields = ("id", "created_at", "updated_at", "created_by", "updated_by", "deleted_at")
    fieldsets = (
        ("Details", {"fields": ("name",)}),
        ("Status", {"fields": ("is_active", "is_deleted", "deleted_at")}),
        ("Audit", {"classes": ("collapse",),
                   "fields": ("id", "created_at", "updated_at", "created_by", "updated_by")}),
    )
    def delete_model(self, request, obj):
        from django.utils import timezone
        obj.is_deleted=True; obj.is_active=False; obj.deleted_at=timezone.now(); obj.save()
    def delete_queryset(self, request, qs):
        from django.utils import timezone
        qs.update(is_deleted=True, is_active=False, deleted_at=timezone.now())
'''
