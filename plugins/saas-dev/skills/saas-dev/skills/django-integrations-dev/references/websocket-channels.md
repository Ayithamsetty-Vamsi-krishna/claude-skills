# Integrations: Real-Time — WebSocket, SSE, Polling

## Decision tree (skill decides based on requirement — Q8)

```
Is communication bidirectional? (both client and server send messages)
  YES → WebSocket (Django Channels)
  NO  → Is it server push only?
          YES → Is it high frequency or need low latency?
                  YES → SSE (StreamingHttpResponse)
                  NO  → Polling (interval fetch)
          NO  → Polling

Examples:
  Chat, collaborative editing, multiplayer, live cursor → WebSocket
  Notifications, order status updates, live feeds → SSE
  Dashboard refresh, report progress, non-critical updates → Polling
```

---

## WebSocket — Django Channels

```python
# requirements.txt
# channels>=4.1
# channels-redis>=4.2

# settings/base.py
INSTALLED_APPS += ['channels']
ASGI_APPLICATION = 'config.asgi.application'
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {'hosts': [config('REDIS_URL', default='redis://localhost:6379/2')]},
    }
}

# config/asgi.py
import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from notifications.routing import websocket_urlpatterns

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.development')
application = ProtocolTypeRouter({
    'http': get_asgi_application(),
    'websocket': AuthMiddlewareStack(URLRouter(websocket_urlpatterns)),
})
```

```python
# notifications/consumers.py
import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import AccessToken


class NotificationConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time notifications.
    Each user gets their own group: notifications_<user_id>
    """
    async def connect(self):
        # Authenticate via JWT in query string
        token_str = self.scope['query_string'].decode().split('token=')[-1]
        try:
            token = AccessToken(token_str)
            user_type = token.get('user_type')
            user_id = token.get('user_id')
        except Exception:
            await self.close(code=4001)
            return

        self.group_name = f'notifications_{user_type}_{user_id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        # Handle messages FROM client (if bidirectional)
        data = json.loads(text_data)
        # Process client message here

    # Handler for messages sent TO this consumer's group
    async def notification_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'notification',
            'data': event['data'],
        }))
```

```python
# Sending to a user from anywhere in Django (e.g. from a task or service):
# notifications/services.py
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

def send_notification(user_type: str, user_id: str, notification_data: dict):
    channel_layer = get_channel_layer()
    group_name = f'notifications_{user_type}_{user_id}'
    async_to_sync(channel_layer.group_send)(
        group_name,
        {'type': 'notification.message', 'data': notification_data}
    )
```

```python
# notifications/routing.py
from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/notifications/$', consumers.NotificationConsumer.as_asgi()),
]
```

---

## SSE — Server-Sent Events (notifications, live feeds)

```python
# core/sse.py
import json
import time
from django.http import StreamingHttpResponse
from rest_framework.views import APIView


class SSEView(APIView):
    """
    Base class for SSE endpoints.
    Client connects once and receives events as they happen.
    """
    authentication_classes = []   # handle auth via query param token

    def get(self, request, *args, **kwargs):
        response = StreamingHttpResponse(
            self.event_stream(request),
            content_type='text/event-stream'
        )
        response['Cache-Control'] = 'no-cache'
        response['X-Accel-Buffering'] = 'no'   # disable nginx buffering
        return response

    def event_stream(self, request):
        """Override in subclass to yield events."""
        raise NotImplementedError


class OrderStatusSSEView(SSEView):
    def event_stream(self, request):
        order_id = request.GET.get('order_id')
        last_status = None
        for _ in range(60):   # max 60 polls (60 seconds)
            from orders.models import Order
            try:
                order = Order.objects.get(id=order_id)
                if order.status != last_status:
                    last_status = order.status
                    data = json.dumps({'status': order.status, 'updated_at': str(order.updated_at)})
                    yield f'data: {data}\n\n'
            except Order.DoesNotExist:
                yield f'data: {json.dumps({"error": "Order not found"})}\n\n'
                return
            time.sleep(1)
        yield f'data: {json.dumps({"type": "close"})}\n\n'
```

```typescript
// Frontend: SSE hook
export function useOrderStatus(orderId: string) {
  const [status, setStatus] = useState<string | null>(null)
  useEffect(() => {
    const es = new EventSource(`/api/v1/orders/${orderId}/status-stream/`)
    es.onmessage = (e) => {
      const data = JSON.parse(e.data)
      if (data.type === 'close') { es.close(); return }
      setStatus(data.status)
    }
    es.onerror = () => es.close()
    return () => es.close()
  }, [orderId])
  return status
}
```

---

## Polling (simplest — for non-critical updates)

```typescript
// Frontend: polling with RTK Query
// In Redux slice or component:
const { data, isLoading } = useGetOrderQuery(orderId, {
  pollingInterval: 5000,   // refetch every 5 seconds
  skip: order?.status === 'completed',  // stop polling when done
})

// Or with useEffect abort pattern (matches v1.5.2 patterns):
useEffect(() => {
  const interval = setInterval(() => {
    const promise = dispatch(fetchOrder(orderId))
    return () => promise.abort()
  }, 5000)
  return () => clearInterval(interval)
}, [orderId])
```
