# Backend: Service Layer (Cross-App Business Logic)

## Rule (locked)
- Same-app logic → stays in serializer create()/update()
- Cross-app logic (touches 2+ apps) → moves to services/

## When to create a service (decision tree)
```
Does this logic touch models from more than one Django app?
  YES → create a service class in the app that owns the operation
  NO  → keep in serializer

Examples that NEED a service:
  - Invoice approval → updates Invoice + Budget + PurchaseOrder (3 apps)
  - Order creation → creates Order + deducts Inventory + triggers Notification
  - User registration → creates UserProfile + sends welcome email + creates Subscription

Examples that DON'T need a service (keep in serializer):
  - Create OrderItem (same orders app) → stays in OrderSerializer.create()
  - Update invoice total (same invoices app) → stays in InvoiceSerializer.update()
```

---

## Service Pattern

```python
# invoices/services.py
from django.db import transaction
from django.utils import timezone
from django.core.exceptions import ValidationError


class InvoiceApprovalService:
    """
    Cross-app: Invoice (invoices) + Budget (budgets) + PurchaseOrder (procurement).
    Called by InvoiceSerializer, never by views directly.
    """

    @staticmethod
    @transaction.atomic
    def approve(invoice_id, approved_by):
        """
        Approves an invoice. Deducts from budget. Locks the purchase order.
        Returns the approved Invoice instance.
        Raises ValidationError with { success, message, errors } shape if invalid.
        """
        from invoices.models import Invoice
        from budgets.services import BudgetService
        from procurement.models import PurchaseOrder

        # Lock the invoice row for the duration of this transaction
        invoice = Invoice.objects.select_for_update().get(id=invoice_id)

        # Validate state
        if invoice.status != 'pending':
            raise ValidationError({
                'status': [f'Cannot approve an invoice with status "{invoice.status}".']
            })

        # Cross-app operation 1: deduct from budget
        BudgetService.deduct(
            budget_id=invoice.budget_id,
            amount=invoice.total_amount,
            reference_type='invoice',
            reference_id=str(invoice.id),
            deducted_by=approved_by,
        )

        # Cross-app operation 2: lock the purchase order
        PurchaseOrder.objects.filter(id=invoice.po_id).update(
            is_locked=True,
            updated_by=approved_by,
            updated_at=timezone.now(),
        )

        # Update invoice
        invoice.status = 'approved'
        invoice.approved_by = approved_by
        invoice.approved_at = timezone.now()
        invoice.save(update_fields=['status', 'approved_by', 'approved_at', 'updated_at'])

        return invoice

    @staticmethod
    @transaction.atomic
    def reject(invoice_id, rejected_by, reason):
        from invoices.models import Invoice
        invoice = Invoice.objects.select_for_update().get(id=invoice_id)
        if invoice.status != 'pending':
            raise ValidationError({
                'status': [f'Cannot reject an invoice with status "{invoice.status}".']
            })
        invoice.status = 'rejected'
        invoice.rejection_reason = reason
        invoice.rejected_by = rejected_by
        invoice.rejected_at = timezone.now()
        invoice.save(update_fields=[
            'status', 'rejection_reason', 'rejected_by', 'rejected_at', 'updated_at'
        ])
        return invoice
```

---

## How serializer calls service

```python
# invoices/serializers.py
from invoices.services import InvoiceApprovalService

class InvoiceApprovalSerializer(serializers.Serializer):
    invoice_id = serializers.UUIDField()
    action = serializers.ChoiceField(choices=['approve', 'reject'])
    reason = serializers.CharField(required=False, allow_blank=True)

    def validate(self, attrs):
        if attrs['action'] == 'reject' and not attrs.get('reason'):
            raise serializers.ValidationError({
                'reason': ['Reason is required when rejecting an invoice.']
            })
        return attrs

    def save(self, **kwargs):
        request = self.context['request']
        action = self.validated_data['action']
        invoice_id = self.validated_data['invoice_id']

        if action == 'approve':
            return InvoiceApprovalService.approve(
                invoice_id=invoice_id,
                approved_by=request.user,
            )
        elif action == 'reject':
            return InvoiceApprovalService.reject(
                invoice_id=invoice_id,
                rejected_by=request.user,
                reason=self.validated_data['reason'],
            )
```

---

## Testing services directly

```python
# invoices/tests/test_services.py
import pytest
from invoices.services import InvoiceApprovalService

@pytest.mark.django_db
class TestInvoiceApprovalService:

    def test_approve_updates_invoice_status(self, invoice, admin_staff_user):
        result = InvoiceApprovalService.approve(invoice.id, approved_by=admin_staff_user)
        assert result.status == 'approved'
        assert result.approved_by == admin_staff_user

    def test_approve_non_pending_raises_validation_error(self, approved_invoice, admin_staff_user):
        from django.core.exceptions import ValidationError
        with pytest.raises(ValidationError) as exc:
            InvoiceApprovalService.approve(approved_invoice.id, approved_by=admin_staff_user)
        assert 'status' in exc.value.message_dict

    def test_approve_is_atomic(self, invoice, admin_staff_user, mocker):
        # Simulate BudgetService failing mid-transaction
        mocker.patch('budgets.services.BudgetService.deduct', side_effect=Exception('Budget error'))
        with pytest.raises(Exception):
            InvoiceApprovalService.approve(invoice.id, approved_by=admin_staff_user)
        # Invoice should NOT be approved (transaction rolled back)
        invoice.refresh_from_db()
        assert invoice.status == 'pending'
```
