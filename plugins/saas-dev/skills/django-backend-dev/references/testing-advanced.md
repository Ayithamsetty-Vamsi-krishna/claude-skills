# Backend: Advanced Tests — Services, Signals, Concurrency

> Requires setup from `testing-setup.md`. Uses patterns from `testing.md`.

## Service layer tests (cross-app services)

```python
# invoices/tests/test_services.py
@pytest.mark.django_db
class TestInvoiceApprovalService:

    def test_approve_succeeds_and_updates_all_apps(self, invoice, budget, admin_staff_user):
        """Cross-app service: invoice + budget + purchase order all updated atomically."""
        from invoices.services import InvoiceApprovalService
        result = InvoiceApprovalService.approve(invoice.id, approved_by=admin_staff_user)
        assert result.status == 'approved'
        assert result.approved_by == admin_staff_user
        # Budget deducted
        budget.refresh_from_db()
        assert budget.remaining < budget.total

    def test_approve_rolls_back_on_budget_failure(self, invoice, admin_staff_user, mocker):
        """If any cross-app step fails, entire transaction rolls back."""
        from invoices.services import InvoiceApprovalService
        from budgets.services import BudgetService
        mocker.patch.object(BudgetService, 'deduct', side_effect=Exception('Budget locked'))
        with pytest.raises(Exception):
            InvoiceApprovalService.approve(invoice.id, approved_by=admin_staff_user)
        invoice.refresh_from_db()
        assert invoice.status == 'pending'  # rolled back, not approved


## Signals tests

```python
# orders/tests/test_signals.py
@pytest.mark.django_db
class TestOrderSignals:

    def test_status_change_triggers_task(self, order, mocker):
        """post_save signal fires task when order status changes."""
        mock_task = mocker.patch('notifications.tasks.send_status_update_task.delay')
        order.status = 'confirmed'
        order.save(update_fields=['status'])
        mock_task.assert_called_once_with(str(order.id), 'pending', 'confirmed')

    def test_status_no_change_does_not_trigger_task(self, order, mocker):
        """No signal task if status didn't actually change."""
        mock_task = mocker.patch('notifications.tasks.send_status_update_task.delay')
        order.notes = 'updated'
        order.save(update_fields=['notes'])
        mock_task.assert_not_called()

    def test_signal_invalidates_cache(self, order):
        from django.core.cache import cache
        cache.set(f'orders:customer:{order.customer_id}', 'cached_data', timeout=300)
        order.status = 'confirmed'
        order.save()
        # Cache should be cleared after save
        assert cache.get(f'orders:customer:{order.customer_id}') is None
```

## Code generation concurrency test

```python
@pytest.mark.django_db(transaction=True)  # transaction=True required for threading
class TestCodeGenerationConcurrency:

    def test_no_duplicate_codes_under_concurrent_load(self, user):
        """
        10 concurrent threads creating orders simultaneously.
        All codes must be unique — select_for_update() prevents race conditions.
        """
        import threading
        codes = []
        errors = []

        def create_order():
            try:
                from django.db import connection
                connection.close()  # each thread needs own connection
                order = Order.objects.create(
                    customer_id=customer.id,
                    created_by=user, updated_by=user,
                    status='pending', total_amount='100.00'
                )
                codes.append(order.code)
            except Exception as e:
                errors.append(str(e))

        threads = [threading.Thread(target=create_order) for _ in range(10)]
        for t in threads: t.start()
        for t in threads: t.join()

        assert len(errors) == 0, f'Errors: {errors}'
        assert len(set(codes)) == len(codes), f'Duplicate codes found: {codes}'
        assert all(c.startswith('ORD-') for c in codes)
```
