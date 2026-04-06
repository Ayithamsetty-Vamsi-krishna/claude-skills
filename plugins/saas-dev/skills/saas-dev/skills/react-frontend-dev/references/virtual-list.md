# Frontend: Infinite Scroll + Virtual Lists

---

## When to use
- Lists with 100+ items → virtual list (renders only visible rows)
- Paginated data that grows → infinite scroll
- Both: infinite scroll loading + virtual rendering of loaded items

---

## Infinite scroll with Intersection Observer

```typescript
// src/hooks/useInfiniteScroll.ts
import { useEffect, useRef, useCallback } from 'react'

export function useInfiniteScroll(
  onLoadMore: () => void,
  hasMore: boolean,
  isLoading: boolean,
) {
  const observerRef = useRef<IntersectionObserver | null>(null)
  const sentinelRef = useRef<HTMLDivElement | null>(null)

  const setSentinelRef = useCallback((node: HTMLDivElement | null) => {
    if (observerRef.current) observerRef.current.disconnect()
    sentinelRef.current = node

    if (!node) return
    observerRef.current = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && hasMore && !isLoading) {
          onLoadMore()
        }
      },
      { threshold: 0.1 }
    )
    observerRef.current.observe(node)
  }, [onLoadMore, hasMore, isLoading])

  useEffect(() => () => observerRef.current?.disconnect(), [])

  return setSentinelRef
}

// Usage in a list component:
export const OrderList = React.memo(() => {
  const dispatch = useAppDispatch()
  const { items, hasMore, isLoading, page } = useAppSelector(selectOrders)

  const loadMore = useCallback(() => {
    if (!isLoading && hasMore) {
      dispatch(fetchOrdersPage(page + 1))
    }
  }, [dispatch, isLoading, hasMore, page])

  const sentinelRef = useInfiniteScroll(loadMore, hasMore, isLoading)

  return (
    <div>
      {items.map(order => <OrderRow key={order.id} order={order} />)}
      {isLoading && <TableSkeleton rows={3} />}
      {/* Sentinel — triggers load when visible */}
      <div ref={sentinelRef} className="h-4" />
      {!hasMore && items.length > 0 && (
        <p className="text-center text-gray-500 py-4">All orders loaded</p>
      )}
    </div>
  )
})
```

---

## Virtual list with @tanstack/virtual

```typescript
// Install: npm install @tanstack/react-virtual
// Use when rendering 1000+ items (avoids DOM overload)

import { useVirtualizer } from '@tanstack/react-virtual'

export const VirtualOrderList = React.memo<{ orders: Order[] }>(({ orders }) => {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: orders.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 64,   // estimated row height in px
    overscan: 5,              // render 5 items above/below visible area
  })

  return (
    <div ref={parentRef} className="h-[600px] overflow-auto">
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }}>
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <OrderRow order={orders[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  )
})
VirtualOrderList.displayName = 'VirtualOrderList'
```

---

## Redux slice for paginated + infinite scroll

```typescript
// ordersSlice.ts additions for infinite scroll
interface OrdersState {
  items: Order[]
  page: number
  hasMore: boolean
  isLoadingMore: boolean
  totalCount: number
}

// In extraReducers:
builder
  .addCase(fetchOrdersPage.pending, (state) => {
    state.isLoadingMore = true
  })
  .addCase(fetchOrdersPage.fulfilled, (state, action) => {
    state.isLoadingMore = false
    // Append new items (don't replace)
    state.items.push(...action.payload.results)
    state.page += 1
    state.totalCount = action.payload.count
    state.hasMore = action.payload.next !== null
  })
  .addCase(fetchOrdersPage.rejected, (state) => {
    state.isLoadingMore = false
  })
```
