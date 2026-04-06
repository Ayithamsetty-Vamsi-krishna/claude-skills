# Integrations: Mandatory Research Flow

## The rule
NEVER write integration code from memory. APIs change. SDKs get deprecated.
Always read the official docs for the current version before writing code.

---

## Research execution (every integration, every time)

```python
# Step 1: Check if docs provided in context
# User may have uploaded docs or pasted a URL.
# If yes → read it, skip to Step 4.

# Step 2: Web search — 2-3 targeted queries
queries = [
    f"{provider_name} python official documentation {current_year}",
    f"{provider_name} API authentication python",
    f"{provider_name} python SDK pip install",
]
# Pick the official docs URL from results (docs.stripe.com, not medium.com)

# Step 3: Fetch and extract
# web_fetch the official docs URL
# Focus sections: Authentication, Quickstart, Webhooks, Error Handling, Changelog

# Step 4: Build the integration contract
contract = {
    "provider": "Stripe",
    "api_version": "2024-12-18",   # from docs, not assumed
    "sdk": "stripe==11.x",         # pip package + version from docs
    "auth_method": "API key (Bearer)",
    "base_url": "https://api.stripe.com/v1",
    "key_endpoints": [
        "POST /payment_intents — create payment",
        "POST /payment_intents/{id}/confirm — confirm payment",
    ],
    "webhook_signature": "stripe.Webhook.construct_event() with STRIPE_WEBHOOK_SECRET",
    "error_handling": "stripe.error.StripeError hierarchy",
    "rate_limit": "100 req/s, retry on 429",
}
# THEN write code using this contract
```

---

## Red flags — stop and re-research if you see these

- You're writing raw `requests.post()` without knowing the current auth header format
- You're guessing an endpoint URL from memory
- You're using `v1` or `v2` in a URL without checking if it's current
- You don't know the webhook signature verification method
- The SDK import path seems uncertain

---

## How to present research findings to user

Before writing code, briefly confirm what you found:

```
Research complete — Stripe API:
- SDK: stripe==11.4.0 (latest as of docs)
- Auth: STRIPE_SECRET_KEY as Bearer token
- Webhook: stripe.Webhook.construct_event() with STRIPE_WEBHOOK_SECRET
- Payment flow: create PaymentIntent → confirm → handle webhook events

Starting implementation...
```
