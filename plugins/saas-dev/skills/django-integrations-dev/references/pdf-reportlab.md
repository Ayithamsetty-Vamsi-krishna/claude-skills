# Integrations: PDF Generation — ReportLab (Programmatic)

## When to use ReportLab

Use ReportLab instead of WeasyPrint when:
- **Complex dynamic tables** spanning pages with running totals
- **Precise typographic control** — kerning, custom line breaking, bleed marks
- **Programmatic calculations** — totals that update layout on the fly
- **Streaming generation** — writing the PDF incrementally for huge documents
- **Existing ReportLab knowledge** in the team

WeasyPrint wins for HTML/CSS-based documents (invoices, letters, basic reports).
ReportLab wins for precision layout and bulk generation. See `pdf-weasyprint.md`
for comparison table.

---

## Install

```
# requirements.txt
reportlab>=4.1.0
```

No system dependencies — pure Python (unlike WeasyPrint).

---

## Two ReportLab APIs — pick one per document

ReportLab exposes two layers; don't mix them within a single document.

### 1. `Canvas` — low-level drawing API

Think of it like drawing on a page: set cursor, draw text/line/shape, advance,
repeat. Good for: single-page docs with precise placement (tickets, badges,
certificates).

### 2. `Platypus` — document generation API

Higher-level. You build a list of flowables (Paragraph, Table, Image,
PageBreak) and ReportLab lays them out across pages automatically.
Good for: multi-page reports, invoices with variable-length line items.

**When in doubt, use Platypus.** Canvas is for layout work where you
personally want to decide every mm.

---

## Platypus: Invoice example

```python
# core/pdf/reportlab_generators.py
from io import BytesIO
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image, PageBreak, KeepTogether
)


def build_invoice_pdf(invoice) -> bytes:
    """
    Build an invoice PDF with ReportLab Platypus.
    Returns PDF bytes — matches the signature of render_pdf_from_template.
    """
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        topMargin=20*mm, bottomMargin=25*mm,
        leftMargin=15*mm, rightMargin=15*mm,
        title=f'Invoice {invoice.number}',
        author=invoice.tenant.name,
    )

    elements = []
    styles = _build_styles()

    # Header section
    elements.extend(_build_header(invoice, styles))
    elements.append(Spacer(1, 6*mm))

    # Parties (From / Bill to) as a 2-column table
    elements.append(_build_parties_table(invoice, styles))
    elements.append(Spacer(1, 8*mm))

    # Line items — the main table
    elements.append(Paragraph('Items', styles['section']))
    elements.append(Spacer(1, 2*mm))
    elements.append(_build_items_table(invoice, styles))
    elements.append(Spacer(1, 6*mm))

    # Totals (right-aligned)
    elements.append(_build_totals_table(invoice, styles))

    if invoice.notes:
        elements.append(Spacer(1, 6*mm))
        elements.append(Paragraph('Notes', styles['section']))
        elements.append(Paragraph(invoice.notes, styles['body']))

    # Page numbers via canvas hook
    doc.build(elements, onFirstPage=_add_page_number, onLaterPages=_add_page_number)

    buffer.seek(0)
    return buffer.read()


def _build_styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        name='h1_custom', parent=styles['Heading1'],
        fontName='Helvetica-Bold', fontSize=20, spaceAfter=8,
    ))
    styles.add(ParagraphStyle(
        name='section', parent=styles['Heading2'],
        fontName='Helvetica-Bold', fontSize=12, spaceAfter=4,
    ))
    styles.add(ParagraphStyle(
        name='body', parent=styles['BodyText'],
        fontName='Helvetica', fontSize=10, leading=14,
    ))
    styles.add(ParagraphStyle(
        name='muted', parent=styles['BodyText'],
        fontName='Helvetica', fontSize=9, textColor=colors.HexColor('#777'),
    ))
    return styles


def _build_header(invoice, styles):
    elements = []
    # Header table: logo on left, invoice number on right
    data = [[
        Paragraph('<b>INVOICE</b>', styles['h1_custom']),
        Paragraph(
            f'<b>{invoice.number}</b><br/>'
            f'Issued: {invoice.issue_date.strftime("%d %b %Y")}<br/>'
            f'Due: {invoice.due_date.strftime("%d %b %Y")}',
            styles['muted']
        ),
    ]]
    header = Table(data, colWidths=[100*mm, 80*mm])
    header.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('ALIGN',  (1, 0), (1, 0), 'RIGHT'),
        ('LINEBELOW', (0, 0), (-1, -1), 0.5, colors.HexColor('#ddd')),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4*mm),
    ]))
    elements.append(header)
    return elements


def _build_parties_table(invoice, styles):
    data = [[
        Paragraph(
            '<b>From</b><br/>'
            f'{invoice.tenant.name}<br/>'
            f'{invoice.tenant.address.replace(chr(10), "<br/>")}<br/>'
            f'{invoice.tenant.email}',
            styles['body']
        ),
        Paragraph(
            '<b>Bill to</b><br/>'
            f'{invoice.customer_name}<br/>'
            f'{invoice.customer_address.replace(chr(10), "<br/>")}<br/>'
            f'{invoice.customer_email}',
            styles['body']
        ),
    ]]
    table = Table(data, colWidths=[90*mm, 90*mm])
    table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
    ]))
    return table


def _build_items_table(invoice, styles):
    # Header row
    data = [['Description', 'Qty', 'Unit price', 'Total']]

    # Data rows
    for item in invoice.items.all():
        data.append([
            Paragraph(item.description, styles['body']),
            f'{item.quantity}',
            f'{item.unit_price:,.2f}',
            f'{item.line_total:,.2f}',
        ])

    table = Table(
        data,
        colWidths=[90*mm, 20*mm, 30*mm, 30*mm],
        repeatRows=1,  # header repeats on every page if table spans pages
    )
    table.setStyle(TableStyle([
        # Header row
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#f5f5f5')),
        ('FONTNAME',   (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('LINEBELOW',  (0, 0), (-1, 0), 1.5, colors.HexColor('#333')),
        ('FONTSIZE',   (0, 0), (-1, 0), 10),

        # Body
        ('FONTNAME',   (0, 1), (-1, -1), 'Helvetica'),
        ('FONTSIZE',   (0, 1), (-1, -1), 10),
        ('LINEBELOW',  (0, 1), (-1, -1), 0.25, colors.HexColor('#eee')),
        ('ALIGN',      (1, 1), (-1, -1), 'RIGHT'),
        ('VALIGN',     (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 3*mm),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3*mm),
    ]))
    return table


def _build_totals_table(invoice, styles):
    data = [
        ['Subtotal',                             f'{invoice.subtotal:,.2f}'],
        [f'Tax ({invoice.tax_rate}%)',            f'{invoice.tax_amount:,.2f}'],
        ['Total due',                             f'{invoice.currency} {invoice.total:,.2f}'],
    ]
    table = Table(data, colWidths=[50*mm, 30*mm])
    table.setStyle(TableStyle([
        ('ALIGN',     (0, 0), (-1, -1), 'RIGHT'),
        ('FONTSIZE',  (0, 0), (-1, -1), 10),
        ('LINEABOVE', (0, -1), (-1, -1), 1.5, colors.HexColor('#333')),
        ('FONTNAME',  (0, -1), (-1, -1), 'Helvetica-Bold'),
        ('FONTSIZE',  (0, -1), (-1, -1), 12),
        ('TOPPADDING', (0, -1), (-1, -1), 2*mm),
    ]))

    # Right-align the totals block on the page by wrapping it
    wrapper = Table([[table]], colWidths=[180*mm])
    wrapper.setStyle(TableStyle([('ALIGN', (0, 0), (-1, -1), 'RIGHT')]))
    return wrapper


def _add_page_number(canvas, doc):
    """Draw page number at the bottom. Runs for every page."""
    canvas.saveState()
    canvas.setFont('Helvetica', 9)
    canvas.setFillColor(colors.HexColor('#888'))
    page_text = f'Page {doc.page}'
    canvas.drawCentredString(A4[0] / 2, 10*mm, page_text)
    canvas.restoreState()
```

---

## Using it

```python
# invoices/views.py — same as WeasyPrint version, just different generator
from django.http import HttpResponse
from rest_framework.views import APIView
from core.pdf.reportlab_generators import build_invoice_pdf


class InvoicePDFView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        invoice = get_object_or_404(Invoice, pk=pk, tenant=request.tenant)
        pdf_bytes = build_invoice_pdf(invoice)

        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="invoice-{invoice.number}.pdf"'

        from core.audit.logger import log_action
        from core.audit.models import AuditAction
        log_action(AuditAction.EXPORT, content_object=invoice,
                   metadata={'format': 'pdf', 'engine': 'reportlab'})

        return response
```

---

## Canvas mode — when you need millimetre-precise control

```python
# core/pdf/reportlab_canvas.py — example: shipping label
from io import BytesIO
from reportlab.lib.pagesizes import A6
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas


def build_shipping_label(shipment) -> bytes:
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=A6)
    width, height = A6

    # "FROM" block
    c.setFont('Helvetica-Bold', 10)
    c.drawString(5*mm, height - 10*mm, 'FROM')
    c.setFont('Helvetica', 9)
    y = height - 14*mm
    for line in shipment.from_address.split('\n'):
        c.drawString(5*mm, y, line)
        y -= 4*mm

    # Horizontal line
    c.setLineWidth(0.5)
    c.line(5*mm, height/2 + 5*mm, width - 5*mm, height/2 + 5*mm)

    # "TO" block — larger, centered
    c.setFont('Helvetica-Bold', 14)
    c.drawString(5*mm, height/2, 'SHIP TO')
    c.setFont('Helvetica', 12)
    y = height/2 - 5*mm
    for line in shipment.to_address.split('\n'):
        c.drawString(5*mm, y, line)
        y -= 5*mm

    # Barcode (tracking number) — at the bottom
    c.setFont('Courier', 14)
    c.drawCentredString(width/2, 10*mm, shipment.tracking_number)

    c.showPage()   # finish page
    c.save()

    buffer.seek(0)
    return buffer.read()
```

---

## Custom fonts

```python
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont


# Register once at module load
pdfmetrics.registerFont(TTFont('Inter', 'static/pdf/fonts/Inter-Regular.ttf'))
pdfmetrics.registerFont(TTFont('Inter-Bold', 'static/pdf/fonts/Inter-Bold.ttf'))

# Then use in styles
styles.add(ParagraphStyle(
    name='body_inter', fontName='Inter', fontSize=10, leading=14,
))
```

ReportLab supports TTF natively. WOFF2 is not supported — convert to TTF first.

---

## Charts / graphs

```python
from reportlab.graphics.charts.barcharts import VerticalBarChart
from reportlab.graphics.shapes import Drawing
from reportlab.lib.colors import HexColor


def build_revenue_chart(monthly_revenue):
    """Returns a Drawing flowable to add to a Platypus document."""
    d = Drawing(400, 200)

    chart = VerticalBarChart()
    chart.x = 50
    chart.y = 50
    chart.height = 125
    chart.width = 300
    chart.data = [monthly_revenue]                      # single series
    chart.categoryAxis.categoryNames = [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ]
    chart.valueAxis.valueMin = 0
    chart.bars[0].fillColor = HexColor('#3b82f6')

    d.add(chart)
    return d


# In document:
elements.append(Paragraph('Monthly Revenue', styles['section']))
elements.append(build_revenue_chart([10_000, 12_500, 11_000, 14_000, 18_000, 22_000,
                                      24_500, 26_000, 28_500, 30_000, 32_500, 35_000]))
```

---

## Streaming large documents

For reports with thousands of rows, don't build the full element list in memory:

```python
# Wrong — all rows in memory
elements = [Table([[r.field] for r in Report.objects.all()])]  # huge list

# Better — split into chunks with KeepTogether
from reportlab.platypus import KeepTogether

elements = []
CHUNK_SIZE = 100
all_rows = list(Report.objects.iterator(chunk_size=CHUNK_SIZE))
for i in range(0, len(all_rows), CHUNK_SIZE):
    chunk = all_rows[i:i+CHUNK_SIZE]
    chunk_data = [[r.field for r in chunk]]
    elements.append(KeepTogether(Table(chunk_data)))
```

For truly huge documents (100k+ rows), consider streaming to a file rather
than building in memory:

```python
doc = SimpleDocTemplate('report.pdf', pagesize=A4)  # writes to disk as it goes
```

---

## Celery task (recommended for large/complex docs)

Same pattern as WeasyPrint — offload to Celery:

```python
# reports/tasks.py
from celery import shared_task
from django.core.files.base import ContentFile
from core.pdf.reportlab_generators import build_invoice_pdf


@shared_task(bind=True, max_retries=3)
def generate_large_report(self, report_id: str):
    try:
        report = Report.objects.get(pk=report_id)
        pdf_bytes = build_large_report_pdf(report)

        filename = f'reports/{report.tenant_id}/{report.id}.pdf'
        report.pdf_file.save(filename, ContentFile(pdf_bytes), save=True)
        return report.pdf_file.url
    except Exception as exc:
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)
```

---

## Testing

```python
# invoices/tests/test_reportlab_pdf.py
import pytest
from io import BytesIO
from pypdf import PdfReader
from core.pdf.reportlab_generators import build_invoice_pdf
from invoices.tests.factories import InvoiceFactory


@pytest.mark.django_db
class TestReportlabInvoicePDF:
    def test_generates_valid_pdf(self, tenant):
        invoice = InvoiceFactory(tenant=tenant)
        pdf_bytes = build_invoice_pdf(invoice)
        assert pdf_bytes[:5] == b'%PDF-'
        assert len(pdf_bytes) > 1000

    def test_contains_invoice_data(self, tenant):
        invoice = InvoiceFactory(tenant=tenant, number='INV-TEST-001',
                                 customer_name='Test Customer')
        pdf_bytes = build_invoice_pdf(invoice)
        reader = PdfReader(BytesIO(pdf_bytes))
        text = ''.join(page.extract_text() for page in reader.pages)
        assert 'INV-TEST-001'   in text
        assert 'Test Customer' in text
```

---

## ReportLab vs WeasyPrint — decision rules

Pick **ReportLab** when:
- You need deterministic, pixel-perfect layout (shipping labels, tickets)
- Document has programmatic content (computed tables, dynamic charts)
- Team has zero HTML/CSS familiarity
- You're generating 1000+ documents/hour (streaming wins on memory)
- Output must be archival-quality (PDF/A compliance — ReportLab has better support)

Pick **WeasyPrint** when:
- Designers can iterate on the layout
- Content mostly follows web conventions (headings, paragraphs, tables)
- You reuse CSS/styles across documents
- Time-to-first-prototype matters more than precision

**Asking per project:** both are documented in saas-dev. At integrations Phase 0:
```
→ [WeasyPrint — HTML/CSS to PDF, easier to iterate]
→ [ReportLab — programmatic layout, more control]
→ [Both — HTML for simple docs, ReportLab for precision docs]
```

---

## Known gotchas

1. **Complex HTML inside Paragraph tag** — ReportLab's Paragraph supports a
   limited HTML subset (`<b>`, `<i>`, `<br/>`, `<font>`). Complex markup
   (tables inside paragraphs, nested lists) won't work — build with nested tables.

2. **Unicode** — ReportLab has good unicode but you MUST register fonts that
   contain the glyphs you need. Default Helvetica doesn't cover CJK/Arabic.

3. **Memory** — building a huge `elements` list is the most common OOM cause.
   Use iterators + chunked tables.

4. **Line breaks in table cells** — Don't use `\n`. Use `<br/>` inside a
   Paragraph flowable, not a plain string.

5. **Images** — use absolute paths or `BytesIO`. Relative paths fail silently.

---

## Security

Same rules as WeasyPrint:
- Never render user-provided markup directly
- Always filter by tenant before lookup
- Rate-limit PDF endpoints
- Audit log every PDF export as `AuditAction.EXPORT`
