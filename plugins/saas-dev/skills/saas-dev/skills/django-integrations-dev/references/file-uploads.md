# Integrations: File Uploads

## Decision tree (ask per task — Q7)

```
What's the file type and size limit?
├── Large files (10MB+) or CDN delivery needed
│   → Pre-signed S3 URL (frontend uploads directly to S3)
├── User-generated content (avatars, attachments)
│   → Pre-signed S3 URL
├── Small files + strict validation (virus scan, content check)
│   → Through Django (server receives, validates, then stores)
└── Private files needing access control
    → Through Django + private S3 bucket + signed URL for access
```

---

## Pattern A — Pre-signed S3 URL (large files, user content)

```python
# settings/base.py
from decouple import config
DEFAULT_FILE_STORAGE = 'storages.backends.s3boto3.S3Boto3Storage'
AWS_ACCESS_KEY_ID = config('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = config('AWS_SECRET_ACCESS_KEY')
AWS_STORAGE_BUCKET_NAME = config('AWS_S3_BUCKET_NAME')
AWS_S3_REGION_NAME = config('AWS_S3_REGION', default='ap-south-1')
AWS_S3_FILE_OVERWRITE = False
AWS_DEFAULT_ACL = None   # private by default
AWS_QUERYSTRING_AUTH = True   # pre-signed URLs for access

# requirements.txt additions
# django-storages[s3]>=1.14
# boto3>=1.34
```

```python
# uploads/views.py
import boto3
import uuid
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from core.authentication import StaffJWTAuthentication
from core.permissions import IsStaffUser

ALLOWED_TYPES = {
    'image': ['image/jpeg', 'image/png', 'image/webp'],
    'document': ['application/pdf', 'application/msword',
                 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
}
MAX_FILE_SIZE_MB = 50


class GenerateUploadURLView(APIView):
    """
    Step 1: Frontend requests a pre-signed URL.
    Step 2: Frontend uploads directly to S3.
    Step 3: Frontend calls ConfirmUploadView with the S3 key.
    """
    authentication_classes = [StaffJWTAuthentication]
    permission_classes = [IsStaffUser]

    def post(self, request):
        file_name = request.data.get('file_name', '')
        file_type = request.data.get('file_type', '')
        file_size = request.data.get('file_size', 0)   # bytes, sent by frontend
        upload_type = request.data.get('upload_type', 'document')   # 'image' or 'document'

        # Validate file type
        allowed = ALLOWED_TYPES.get(upload_type, [])
        if file_type not in allowed:
            return Response({
                'success': False,
                'message': f'File type {file_type} not allowed.',
                'errors': {'file_type': [f'Allowed types: {", ".join(allowed)}']}
            }, status=status.HTTP_400_BAD_REQUEST)

        # Validate file size
        if file_size > MAX_FILE_SIZE_MB * 1024 * 1024:
            return Response({
                'success': False,
                'message': f'File size exceeds {MAX_FILE_SIZE_MB}MB limit.',
                'errors': {'file_size': [f'Maximum allowed: {MAX_FILE_SIZE_MB}MB']}
            }, status=status.HTTP_400_BAD_REQUEST)

        # Generate unique S3 key
        extension = file_name.rsplit('.', 1)[-1].lower() if '.' in file_name else ''
        s3_key = f"uploads/{upload_type}s/{uuid.uuid4()}.{extension}"

        # Generate pre-signed URL (expires in 15 minutes)
        s3 = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_S3_REGION_NAME,
        )
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': settings.AWS_STORAGE_BUCKET_NAME,
                'Key': s3_key,
                'ContentType': file_type,
            },
            ExpiresIn=900,   # 15 minutes
        )

        return Response({
            'success': True,
            'data': {
                'upload_url': presigned_url,
                's3_key': s3_key,
                'expires_in': 900,
            }
        })
```

```python
# Frontend flow (TypeScript)
// 1. Get pre-signed URL
const { data } = await api.post('/api/v1/uploads/generate-url/', {
  file_name: file.name,
  file_type: file.type,
  file_size: file.size,
  upload_type: 'document',
})

// 2. Upload directly to S3
await fetch(data.upload_url, {
  method: 'PUT',
  body: file,
  headers: { 'Content-Type': file.type },
})

// 3. Confirm upload with backend
await api.post('/api/v1/uploads/confirm/', { s3_key: data.s3_key, entity_id: orderId })
```

---

## Pattern B — Through Django (small files with strict validation)

```python
# uploads/views.py
from django.core.files.storage import default_storage
import magic   # python-magic — checks actual MIME type not just extension

class DirectUploadView(APIView):
    authentication_classes = [StaffJWTAuthentication]
    permission_classes = [IsStaffUser]

    def post(self, request):
        file = request.FILES.get('file')
        if not file:
            return Response({
                'success': False,
                'message': 'No file provided.',
                'errors': {'file': ['This field is required.']}
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check actual MIME type (not just extension)
        mime = magic.from_buffer(file.read(1024), mime=True)
        file.seek(0)

        allowed_mimes = ['image/jpeg', 'image/png', 'application/pdf']
        if mime not in allowed_mimes:
            return Response({
                'success': False,
                'message': f'File type {mime} is not allowed.',
                'errors': {'file': [f'Allowed types: {", ".join(allowed_mimes)}']}
            }, status=status.HTTP_400_BAD_REQUEST)

        if file.size > 5 * 1024 * 1024:  # 5MB limit for through-Django uploads
            return Response({
                'success': False,
                'message': 'File size exceeds 5MB limit.',
                'errors': {'file': ['Maximum 5MB for this upload type.']}
            }, status=status.HTTP_400_BAD_REQUEST)

        # Save to storage (goes to S3 via django-storages)
        path = default_storage.save(f'uploads/{uuid.uuid4()}_{file.name}', file)
        url = default_storage.url(path)

        return Response({'success': True, 'data': {'url': url, 'path': path}})
```

---

## FileField on models (for storing references)

```python
# orders/models.py
class OrderAttachment(BaseModel):
    order = models.ForeignKey('Order', on_delete=models.CASCADE, related_name='attachments')
    file_name = models.CharField(max_length=255)
    s3_key = models.CharField(max_length=500)   # store key, not full URL
    file_type = models.CharField(max_length=100)
    file_size = models.PositiveIntegerField()   # bytes

    def get_signed_url(self, expiry_seconds=3600):
        """Generate a fresh signed URL for accessing the file."""
        import boto3
        from django.conf import settings
        s3 = boto3.client('s3', ...)
        return s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': settings.AWS_STORAGE_BUCKET_NAME, 'Key': self.s3_key},
            ExpiresIn=expiry_seconds,
        )
```

---

## Virus scanning (when strict validation required)

```python
# Option A — ClamAV (self-hosted, free)
# Install: sudo apt install clamav && pip install pyclamd

import pyclamd

def scan_file_for_virus(file_data: bytes) -> bool:
    """Returns True if file is clean, False if infected."""
    try:
        cd = pyclamd.ClamdNetworkSocket(host='localhost', port=3310)
        result = cd.scan_stream(file_data)
        if result and 'stream' in result:
            return False  # Infected
        return True  # Clean
    except Exception:
        # If ClamAV is unavailable, log and allow (or block — your policy)
        import logging
        logging.getLogger(__name__).warning('ClamAV unavailable — skipping scan')
        return True  # Fail-open (change to False for fail-closed)


# Option B — VirusTotal API (cloud, requires API key)
# Research: web_fetch https://docs.virustotal.com/reference/overview before implementing
# Free tier: 4 requests/min, 500/day

import requests
from decouple import config

def scan_with_virustotal(file_data: bytes, filename: str) -> dict:
    """Returns scan result dict. Research VirusTotal docs before using."""
    api_key = config('VIRUSTOTAL_API_KEY')
    response = requests.post(
        'https://www.virustotal.com/api/v3/files',
        headers={'x-apikey': api_key},
        files={'file': (filename, file_data)},
        timeout=30,
    )
    return response.json()
```

**Recommendation:** For most SaaS, MIME type checking + file size limits is sufficient.
Add ClamAV only if regulatory compliance (HIPAA, SOC2) requires it.
Document your security policy in CLAUDE.md so future sessions know the choice.
