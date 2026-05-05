# Integrations: PDF Generation — WeasyPrint (HTML/CSS → PDF)

## When to use WeasyPrint

Asked at Phase 0 of integrations when PDF is needed:

```
Which PDF generation library?
→ [WeasyPrint — HTML/CSS to PDF, pure Python]
→ [ReportLab — programmatic layout, more control]
→ [Both — ask per document type]
```

**WeasyPrint is the right choice when:**
- You can express the document as HTML + CSS (invoices, reports, letters)
- Designers can iterate on the layout without Python knowledge
- You want Django template inheritance (header, footer, styles reused)
- Output must match web styling closely

**Use ReportLab instead when:**
- Complex programmatic layouts (dynamic tables spanning pages with calculations)
- Precise typographic control (kerning, custom page flows)
- Existing team expertise in ReportLab
- No HTML/CSS skills in the team

---

## Install

```
# requirements.txt
weasyprint>=61.0
```

System dependencies — WeasyPrint needs Pango, Cairo, GDK-Pixbuf:

```bash
# Ubuntu / Debian
apt install -y libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libcairo2 \
               libgdk-pixbuf2.0-0

# Mac
brew install pango libffi

# Docker — add to Dockerfile
RUN apt-get update && apt-get install -y \
    libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz0b libcairo2 \
    && rm -rf /var/lib/apt/lists/*
```

---

## Directory structure

```
templates/
└── pdf/
    ├── base.html          ← shared layout (header, footer, styles)
    ├── invoice.html       ← inherits base, fills content
    ├── receipt.html
    └── report.html

static/
└── pdf/
    ├── logo.png
    ├── signature.svg
    └── fonts/
        ├── Inter-Regular.woff2
        └── Inter-Bold.woff2
```

---

## Base template

```html
{# templates/pdf/base.html #}
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{% block title %}Document{% endblock %}</title>
  <style>
    /* All CSS inline — WeasyPrint doesn't resolve relative stylesheet URLs the same way browsers do */

    @font-face {
      font-family: 'Inter';
      src: url('{% static "pdf/fonts/Inter-Regular.woff2" %}') format('woff2');
      font-weight: 400;
    }
    @font-face {
      font-family: 'Inter';
      src: url('{% static "pdf/fonts/Inter-Bold.woff2" %}') format('woff2');
      font-weight: 700;
    }

    /* Page size + margins */
    @page {
      size: A4;
      margin: 2cm 1.5cm 2.5cm 1.5cm;

      @top-center {
        content: element(page-header);
      }
      @bottom-center {
        content: "Page " counter(page) " of " counter(pages);
        font-size: 9pt;
        color: #888;
      }
    }

    body {
      font-family: 'Inter', sans-serif;
      font-size: 10pt;
      line-height: 1.5;
      color: #111;
    }

    /* Running header — repeats on every page */
    .page-header {
      position: running(page-header);
      font-size: 9pt;
      color: #555;
      border-bottom: 1px solid #ddd;
      padding-bottom: 4mm;
    }

    h1 { font-size: 20pt; margin: 0 0 8mm 0; color: #1a1a1a; }
    h2 { font-size: 14pt; margin-top: 8mm; }

    table { width: 100%; border-collapse: collapse; margin: 4mm 0; }
    th {
      background: #f5f5f5;
      text-align: left;
      padding: 3mm;
      font-weight: 700;
      border-bottom: 2px solid #333;
    }
    td {
      padding: 3mm;
      border-bottom: 1px solid #eee;
    }

    .text-right { text-align: right; }
    .muted      { color: #777; }
    .strong     { font-weight: 700; }

    /* Avoid breaking these across pages */
    .no-break   { page-break-inside: avoid; }
    .page-break { page-break-before: always; }

    {% block extra_styles %}{% endblock %}
  </style>
</head>
<body>

  <div class="page-header">
    <div style="display: flex; justify-content: space-between;">
      <span>{{ company.name }}</span>
      <span>{{ document_number }}</span>
    </div>
  </div>

  {% block content %}{% endblock %}

</body>
</html>
```

---

## Invoice template example

```html
{# templates/pdf/invoice.html #}
{% extends 'pdf/base.html' %}
{% load static humanize %}

{% block title %}Invoice {{ invoice.number }}{% endblock %}

{% block content %}
<div style="display: flex; justify-content: space-between; align-items: flex-start;">
  <div>
    <img src="{% static 'pdf/logo.png' %}" style="height: 40px;">
    <h1 style="margin-top: 6mm;">INVOICE</h1>
  </div>
  <div class="text-right muted">
    <div class="strong" style="color: #111;">{{ invoice.number }}</div>
    <div>Issued: {{ invoice.issue_date|date:"d M Y" }}</div>
    <div>Due: {{ invoice.due_date|date:"d M Y" }}</div>
  </div>
</div>

<hr style="border: none; border-top: 1px solid #ddd; margin: 6mm 0;">

<div style="display: flex; justify-content: space-between; gap: 20mm;">
  <div style="flex: 1;">
    <div class="muted">From</div>
    <div class="strong">{{ company.name }}</div>
    <div>{{ company.address|linebreaksbr }}</div>
    <div>{{ company.email }}</div>
  </div>
  <div style="flex: 1;">
    <div class="muted">Bill to</div>
    <div class="strong">{{ invoice.customer_name }}</div>
    <div>{{ invoice.customer_address|linebreaksbr }}</div>
    <div>{{ invoice.customer_email }}</div>
  </div>
</div>

<h2>Items</h2>
<table class="no-break">
  <thead>
    <tr>
      <th>Description</th>
      <th class="text-right" style="width: 20mm;">Qty</th>
      <th class="text-right" style="width: 30mm;">Unit price</th>
      <th class="text-right" style="width: 30mm;">Total</th>
    </tr>
  </thead>
  <tbody>
    {% for item in invoice.items.all %}
    <tr>
      <td>{{ item.description }}</td>
      <td class="text-right">{{ item.quantity }}</td>
      <td class="text-right">{{ item.unit_price|floatformat:2|intcomma }}</td>
      <td class="text-right">{{ item.line_total|floatformat:2|intcomma }}</td>
    </tr>
    {% endfor %}
  </tbody>
</table>

<div style="display: flex; justify-content: flex-end; margin-top: 6mm;">
  <table style="width: 80mm;">
    <tr>
      <td>Subtotal</td>
      <td class="text-right">{{ invoice.subtotal|floatformat:2|intcomma }}</td>
    </tr>
    <tr>
      <td>Tax ({{ invoice.tax_rate }}%)</td>
      <td class="text-right">{{ invoice.tax_amount|floatformat:2|intcomma }}</td>
    </tr>
    <tr class="strong" style="font-size: 12pt; border-top: 2px solid #333;">
      <td>Total due</td>
      <td class="text-right">{{ invoice.currency }} {{ invoice.total|floatformat:2|intcomma }}</td>
    </tr>
  </table>
</div>

{% if invoice.notes %}
<h2>Notes</h2>
<div>{{ invoice.notes|linebreaks }}</div>
{% endif %}

<div style="margin-top: 10mm; padding-top: 4mm; border-top: 1px solid #eee; font-size: 9pt;" class="muted">
  Thank you for your business. For questions about this invoice, contact {{ company.email }}.
</div>
{% endblock %}
```

---

## Generator function

```python
# core/pdf/generators.py
from django.template.loader import render_to_string
from weasyprint import HTML, CSS
from django.conf import settings


def render_pdf_from_template(template_name: str, context: dict, base_url=None) -> bytes:
    """
    Render a Django template to PDF bytes.

    Args:
        template_name: e.g. 'pdf/invoice.html'
        context: template context
        base_url: used to resolve relative URLs (images, fonts).
                  Defaults to STATIC_ROOT if not provided.

    Returns:
        PDF file contents as bytes — write to response or storage.
    """
    html_string = render_to_string(template_name, context)

    # base_url is critical — tells WeasyPrint where to find static assets
    resolved_base = base_url or settings.STATIC_ROOT or settings.BASE_DIR
    html = HTML(string=html_string, base_url=str(resolved_base))

    return html.write_pdf()
```

---

## Serving the PDF — two patterns

### Pattern A: Inline response (small, fast docs)

```python
# invoices/views.py
from django.http import HttpResponse
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from core.pdf.generators import render_pdf_from_template


class InvoicePDFView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        invoice = get_object_or_404(Invoice, pk=pk, tenant=request.tenant)

        pdf_bytes = render_pdf_from_template('pdf/invoice.html', {
            'invoice': invoice,
            'company': request.tenant.company_info,
            'document_number': invoice.number,
        })

        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="invoice-{invoice.number}.pdf"'

        # Audit log — record PDF download
        from core.audit.logger import log_action
        from core.audit.models import AuditAction
        log_action(AuditAction.EXPORT, content_object=invoice,
                   metadata={'format': 'pdf', 'document_type': 'invoice'})

        return response
```

### Pattern B: Celery task (large docs, reports)

For anything that takes > 2 seconds to render, offload to Celery:

```python
# invoices/tasks.py
from celery import shared_task
from django.core.files.base import ContentFile
from core.pdf.generators import render_pdf_from_template


@shared_task(bind=True, max_retries=3)
def generate_invoice_pdf(self, invoice_id: str):
    """Generate invoice PDF and store in S3. Returns the URL."""
    try:
        invoice = Invoice.objects.get(pk=invoice_id)

        pdf_bytes = render_pdf_from_template('pdf/invoice.html', {
            'invoice': invoice,
            'company': invoice.tenant.company_info,
            'document_number': invoice.number,
        })

        # Store in S3 (see file-uploads.md for setup)
        filename = f'invoices/{invoice.tenant_id}/{invoice.number}.pdf'
        invoice.pdf_file.save(filename, ContentFile(pdf_bytes), save=True)

        return invoice.pdf_file.url

    except Exception as exc:
        # Retry with exponential backoff
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)


# Calling the task:
task = generate_invoice_pdf.delay(str(invoice.pk))
# task.id → store in DB; poll status via Celery result backend OR signal on success
```

```python
# API endpoint for async PDF request
class InvoicePDFGenerateView(APIView):
    def post(self, request, pk):
        invoice = get_object_or_404(Invoice, pk=pk, tenant=request.tenant)
        task = generate_invoice_pdf.delay(str(invoice.pk))
        return Response({
            'success': True,
            'data': {
                'task_id': task.id,
                'status_url': f'/api/v1/tasks/{task.id}/status/',
            }
        })
```

---

## Email the PDF as an attachment

```python
# core/pdf/email.py
from django.core.mail import EmailMessage
from django.template.loader import render_to_string
from core.pdf.generators import render_pdf_from_template


def send_invoice_email(invoice):
    pdf_bytes = render_pdf_from_template('pdf/invoice.html', {
        'invoice': invoice,
        'company': invoice.tenant.company_info,
        'document_number': invoice.number,
    })

    html_body = render_to_string('email/invoice_email.html', {'invoice': invoice})

    email = EmailMessage(
        subject=f'Invoice {invoice.number}',
        body=html_body,
        from_email='billing@example.com',
        to=[invoice.customer_email],
    )
    email.content_subtype = 'html'
    email.attach(f'invoice-{invoice.number}.pdf', pdf_bytes, 'application/pdf')
    email.send()
```

---

## Common gotchas + fixes

### 1. Images don't appear
WeasyPrint requires absolute paths OR a valid `base_url`. Relative paths
without `base_url` will silently fail to load.

```python
# Wrong — relative path without base_url
html_string = '<img src="static/logo.png">'

# Right — use {% static %} template tag and pass base_url
html_string = render_to_string('pdf/invoice.html', context)
html = HTML(string=html_string, base_url=settings.STATIC_ROOT)
```

### 2. Fonts don't render
Self-hosted fonts with `@font-face` + `src: url(...)` work. Web fonts via CDN
often fail because WeasyPrint won't download them. Copy fonts into `static/pdf/fonts/`.

### 3. Page breaks in wrong places
Use `page-break-inside: avoid` for tables/sections that must stay together.
Use `page-break-before: always` to force a page break before a section.

```css
.invoice-items { page-break-inside: avoid; }
.terms-and-conditions { page-break-before: always; }
```

### 4. Slow generation for large tables
Long invoices with 1000+ line items take seconds. Solutions:
- Split into multiple PDFs (one per customer, one per period)
- Offload to Celery task (Pattern B above)
- Consider ReportLab for true streaming large-table generation

### 5. Unicode / emoji rendering
WeasyPrint uses Pango. Make sure system has Pango and emoji fonts:
```bash
apt install fonts-noto-color-emoji
```

---

## Testing

```python
# invoices/tests/test_pdf.py
import pytest
from core.pdf.generators import render_pdf_from_template
from invoices.tests.factories import InvoiceFactory


@pytest.mark.django_db
class TestInvoicePDF:
    def test_pdf_generates_without_error(self, tenant):
        invoice = InvoiceFactory(tenant=tenant)
        pdf_bytes = render_pdf_from_template('pdf/invoice.html', {
            'invoice':         invoice,
            'company':         tenant.company_info,
            'document_number': invoice.number,
        })
        # Basic sanity check — PDF starts with %PDF-
        assert pdf_bytes[:5] == b'%PDF-'
        assert len(pdf_bytes) > 1000  # not an empty doc

    def test_pdf_contains_invoice_number(self, tenant):
        """Check text content was actually rendered."""
        from pypdf import PdfReader
        from io import BytesIO

        invoice = InvoiceFactory(tenant=tenant, number='INV-TEST-001')
        pdf_bytes = render_pdf_from_template('pdf/invoice.html',
            {'invoice': invoice, 'company': tenant.company_info,
             'document_number': invoice.number})

        reader = PdfReader(BytesIO(pdf_bytes))
        text = ''.join(page.extract_text() for page in reader.pages)
        assert 'INV-TEST-001' in text

    def test_pdf_view_authorised_user(self, authenticated_client, invoice):
        r = authenticated_client.get(f'/api/v1/invoices/{invoice.pk}/pdf/')
        assert r.status_code == 200
        assert r['Content-Type'] == 'application/pdf'
        assert r.content[:5] == b'%PDF-'

    def test_pdf_tenant_isolation(self, authenticated_client, invoice_other_tenant):
        """User from tenant A cannot download tenant B's invoice PDF."""
        r = authenticated_client.get(f'/api/v1/invoices/{invoice_other_tenant.pk}/pdf/')
        assert r.status_code == 404
```

---

## Security considerations

- **Never render user-provided HTML** directly into templates — XSS to SSRF risk.
  WeasyPrint can follow `<img src>` URLs, which opens SSRF vectors.
  See `file-uploads.md` SSRF section — same rules apply here.

- **Always filter by tenant** on the invoice/document lookup — see the view
  example above.

- **Rate-limit PDF generation** — it's CPU-intensive. A malicious user hitting
  `/pdf/` repeatedly can DoS your app.

```python
# Use DRF throttling
from rest_framework.throttling import UserRateThrottle


class PDFThrottle(UserRateThrottle):
    rate = '30/minute'


class InvoicePDFView(APIView):
    throttle_classes = [PDFThrottle]
```

- **Audit log every PDF export** as `AuditAction.EXPORT` — compliance
  evidence of data access.
