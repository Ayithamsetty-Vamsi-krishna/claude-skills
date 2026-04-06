# Frontend: Real-Time UI Patterns

---

## WebSocket hook (Django Channels backend)

```typescript
// src/hooks/useWebSocket.ts
import { useEffect, useRef, useCallback, useState } from 'react'

interface WebSocketOptions {
  onMessage: (data: unknown) => void
  onConnect?: () => void
  onDisconnect?: () => void
  reconnectInterval?: number
  maxReconnectAttempts?: number
}

export function useWebSocket(url: string, options: WebSocketOptions) {
  const ws = useRef<WebSocket | null>(null)
  const reconnectCount = useRef(0)
  const reconnectTimer = useRef<ReturnType<typeof setTimeout>>()
  const [isConnected, setIsConnected] = useState(false)

  const connect = useCallback(() => {
    const token = localStorage.getItem('access_token')
    const wsUrl = `${url}?token=${token}`

    ws.current = new WebSocket(wsUrl)

    ws.current.onopen = () => {
      setIsConnected(true)
      reconnectCount.current = 0
      options.onConnect?.()
    }

    ws.current.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        options.onMessage(data)
      } catch { /* ignore non-JSON messages */ }
    }

    ws.current.onclose = () => {
      setIsConnected(false)
      options.onDisconnect?.()
      // Reconnect with exponential backoff
      const maxAttempts = options.maxReconnectAttempts ?? 5
      if (reconnectCount.current < maxAttempts) {
        const delay = Math.min(1000 * 2 ** reconnectCount.current, 30000)
        reconnectCount.current++
        reconnectTimer.current = setTimeout(connect, delay)
      }
    }

    ws.current.onerror = () => ws.current?.close()
  }, [url, options])

  useEffect(() => {
    connect()
    return () => {
      clearTimeout(reconnectTimer.current)
      ws.current?.close()
    }
  }, [connect])

  const sendMessage = useCallback((data: unknown) => {
    if (ws.current?.readyState === WebSocket.OPEN) {
      ws.current.send(JSON.stringify(data))
    }
  }, [])

  return { isConnected, sendMessage }
}

// Usage in component:
const { isConnected } = useWebSocket('ws://localhost:8000/ws/notifications/', {
  onMessage: (data) => dispatch(addNotification(data)),
  onConnect: () => console.log('WebSocket connected'),
})
```

---

## SSE hook (server-sent events)

```typescript
// src/hooks/useSSE.ts
import { useEffect, useState } from 'react'

export function useSSE<T>(url: string, onMessage: (data: T) => void) {
  const [isConnected, setIsConnected] = useState(false)

  useEffect(() => {
    const es = new EventSource(url)
    es.onopen = () => setIsConnected(true)
    es.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.type === 'close') { es.close(); return }
        onMessage(data)
      } catch { /* ignore */ }
    }
    es.onerror = () => { setIsConnected(false); es.close() }
    return () => es.close()
  }, [url])

  return isConnected
}

// Usage:
const isConnected = useSSE<OrderStatus>(
  `/api/v1/orders/${orderId}/status-stream/`,
  (data) => dispatch(updateOrderStatus(data))
)
```

---

## Live notification badge (combines WebSocket + Redux)

```tsx
// src/features/notifications/NotificationBell.tsx
import React from 'react'
import { useAppSelector, useAppDispatch } from '@/app/hooks'
import { selectUnreadCount, addNotification } from './notificationsSlice'
import { useWebSocket } from '@/hooks/useWebSocket'

export const NotificationBell = React.memo(() => {
  const dispatch = useAppDispatch()
  const unreadCount = useAppSelector(selectUnreadCount)

  useWebSocket('ws://localhost:8000/ws/notifications/', {
    onMessage: (data: any) => {
      if (data.type === 'notification') {
        dispatch(addNotification(data.data))
      }
    },
  })

  return (
    <div className="relative">
      <button className="p-2 rounded-full hover:bg-gray-100">
        <BellIcon className="w-5 h-5" />
        {unreadCount > 0 && (
          <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs
                           rounded-full w-5 h-5 flex items-center justify-center">
            {unreadCount > 99 ? '99+' : unreadCount}
          </span>
        )}
      </button>
    </div>
  )
})
NotificationBell.displayName = 'NotificationBell'
```
