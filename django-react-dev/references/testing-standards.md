# Testing Standards

## Backend — pytest + DRF APIClient

### Setup

```python
# conftest.py (app-level)
import pytest
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

User = get_user_model()

@pytest.fixture
def api_client():
    return APIClient()

@pytest.fixture
def user(db):
    return User.objects.create_user(
        username="testuser", email="test@example.com", password="testpass123"
    )

@pytest.fixture
def auth_client(api_client, user):
    api_client.force_authenticate(user=user)
    return api_client
```

### Test File Structure

```python
# apps/orders/tests/test_orders.py
import pytest
from django.urls import reverse
from apps.orders.models import Order

LIST_URL = reverse("order-list")

def detail_url(pk):
    return reverse("order-detail", args=[pk])


class TestOrderList:
    """GET /api/v1/orders/"""

    def test_list_returns_paginated_orders(self, auth_client, order_factory):
        order_factory.create_batch(3)
        response = auth_client.get(LIST_URL)
        assert response.status_code == 200
        assert "results" in response.data
        assert response.data["count"] == 3

    def test_list_requires_authentication(self, api_client):
        response = api_client.get(LIST_URL)
        assert response.status_code == 401

    def test_list_filters_by_status(self, auth_client, order_factory):
        order_factory(status="pending")
        order_factory(status="shipped")
        response = auth_client.get(LIST_URL, {"status": "pending"})
        assert response.status_code == 200
        assert all(o["status"] == "pending" for o in response.data["results"])

    def test_list_empty_returns_empty_results(self, auth_client):
        response = auth_client.get(LIST_URL)
        assert response.status_code == 200
        assert response.data["results"] == []


class TestOrderCreate:
    """POST /api/v1/orders/"""

    def test_create_valid_order(self, auth_client, customer, product):
        payload = {
            "customer_id": customer.pk,
            "items": [{"product_id": product.pk, "quantity": 2}],
        }
        response = auth_client.post(LIST_URL, payload, format="json")
        assert response.status_code == 201
        assert Order.objects.count() == 1

    def test_create_missing_customer_returns_400(self, auth_client):
        response = auth_client.post(LIST_URL, {"items": []}, format="json")
        assert response.status_code == 400
        assert "customer_id" in response.data

    def test_create_invalid_customer_fk_returns_400(self, auth_client):
        payload = {"customer_id": 9999, "items": []}
        response = auth_client.post(LIST_URL, payload, format="json")
        assert response.status_code == 400

    def test_create_unauthenticated_returns_401(self, api_client, customer):
        payload = {"customer_id": customer.pk, "items": []}
        response = api_client.post(LIST_URL, payload, format="json")
        assert response.status_code == 401


class TestOrderDetail:
    """GET/PATCH/DELETE /api/v1/orders/{id}/"""

    def test_retrieve_order(self, auth_client, order):
        response = auth_client.get(detail_url(order.pk))
        assert response.status_code == 200
        assert response.data["id"] == order.pk
        assert "customer" in response.data        # nested read object present
        assert "customer_id" in response.data     # FK write field present

    def test_retrieve_nonexistent_returns_404(self, auth_client):
        response = auth_client.get(detail_url(9999))
        assert response.status_code == 404

    def test_patch_order_status(self, auth_client, order):
        response = auth_client.patch(
            detail_url(order.pk), {"status": "confirmed"}, format="json"
        )
        assert response.status_code == 200
        order.refresh_from_db()
        assert order.status == "confirmed"

    def test_delete_order(self, auth_client, order):
        response = auth_client.delete(detail_url(order.pk))
        assert response.status_code == 204
        assert not Order.objects.filter(pk=order.pk).exists()

    def test_other_user_cannot_access_order(self, api_client, order):
        """Permission: order belongs to different user"""
        from django.contrib.auth import get_user_model
        other = get_user_model().objects.create_user(
            username="other", password="pass"
        )
        api_client.force_authenticate(user=other)
        response = api_client.get(detail_url(order.pk))
        assert response.status_code in [403, 404]
```

### Rules
- Use `pytest.mark.django_db` or `db` fixture — never skip DB marking
- Use `APIClient.force_authenticate` — never manually set JWT tokens in tests
- Group tests by endpoint in classes with descriptive docstrings
- Every test must have a single, clear assertion focus
- Cover: happy path, 400 bad input, 401 unauthenticated, 403 forbidden, 404 not found

---

## Frontend — Vitest + React Testing Library

### Setup

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
export default defineConfig({
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
  },
});

// src/test/setup.ts
import "@testing-library/jest-dom";
```

### Test File Structure

```tsx
// features/orders/tests/OrderList.test.tsx
import { render, screen, waitFor } from "@testing-library/react";
import { Provider } from "react-redux";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { OrderList } from "../components/OrderList";
import { setupStore } from "@/app/store";
import { orderService } from "../services/orderService";

vi.mock("../services/orderService");

const mockOrders = [
  { id: 1, customerId: 1, customer: { id: 1, name: "Alice" }, status: "pending", items: [] },
];

function renderWithStore(component: React.ReactElement) {
  return render(<Provider store={setupStore()}>{component}</Provider>);
}

describe("OrderList", () => {
  beforeEach(() => vi.clearAllMocks());

  it("renders loading skeleton while fetching", () => {
    vi.mocked(orderService.list).mockReturnValue(new Promise(() => {}));
    renderWithStore(<OrderList />);
    expect(screen.getByTestId("skeleton")).toBeInTheDocument();
  });

  it("renders orders after successful fetch", async () => {
    vi.mocked(orderService.list).mockResolvedValue({
      data: { count: 1, next: null, previous: null, results: mockOrders },
    } as any);
    renderWithStore(<OrderList />);
    await waitFor(() => expect(screen.getByText("Order #1")).toBeInTheDocument());
    expect(screen.getByText("Alice")).toBeInTheDocument();
  });

  it("renders error alert on API failure", async () => {
    vi.mocked(orderService.list).mockRejectedValue(new Error("Server error"));
    renderWithStore(<OrderList />);
    await waitFor(() =>
      expect(screen.getByRole("alert")).toBeInTheDocument()
    );
  });

  it("renders empty state when no orders", async () => {
    vi.mocked(orderService.list).mockResolvedValue({
      data: { count: 0, next: null, previous: null, results: [] },
    } as any);
    renderWithStore(<OrderList />);
    await waitFor(() =>
      expect(screen.getByText(/no orders found/i)).toBeInTheDocument()
    );
  });
});
```

### Rules
- Always wrap components in `<Provider store={...}>` when they use Redux
- Mock service layer (`orderService`) — never mock the Axios instance directly
- Test user-visible outcomes (text, roles, aria) — not implementation details
- Always test: renders correctly, loading state, error state, empty state, success state
- Use `data-testid` sparingly — prefer accessible queries (role, label, text)
