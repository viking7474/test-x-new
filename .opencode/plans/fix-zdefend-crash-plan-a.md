# Plan A: Atomic Snapshot for Dyld Hooks — Fix ZDefend Crash

## Problem
Race condition between `hook__dyld_image_count()` and `hook__dyld_get_image_header(idx)`: ZDefend calls count on a background thread, gets filtered count N, then calls get_image_header(idx) but the `gVisibleToReal` map has been rebuilt between the two calls, causing out-of-bounds access → SIGSEGV at `0x2057da180`.

## File: `ProjectXTweak/JailbreakBypassHooks.x`

---

## Edit 1: Replace state variables (lines 2171-2176)

### OLD:
```c
// Phase 3: dylib hiding (dyld enumeration + dladdr)
static pthread_mutex_t gDyldLock = PTHREAD_MUTEX_INITIALIZER;
static uint32_t *gVisibleToReal = NULL;
static uint32_t gVisibleCount = 0;
static uint32_t gRealCount = 0;
static uint64_t gDyldLastBuildNs = 0;
```

### NEW:
```c
// Phase 3: dylib hiding (dyld enumeration + dladdr)
// Atomic snapshot approach: an immutable snapshot is created on each rebuild
// and swapped in atomically. Threads that called _dyld_image_count keep a
// TLS-cached reference so that subsequent name/header/slide calls use the
// *same* map, eliminating the race window that caused ZDefend SIGSEGV.

typedef struct PXDyldSnapshot {
    _Atomic(int32_t) refCount;
    uint32_t *map;          // visibleIndex -> realIndex
    uint32_t visibleCount;
    uint32_t realCount;
    uint64_t buildNs;
} PXDyldSnapshot;

static _Atomic(PXDyldSnapshot *) gDyldCurrentSnapshot = NULL;
static pthread_mutex_t gDyldLock = PTHREAD_MUTEX_INITIALIZER;

// Thread-local cached snapshot: set by hook__dyld_image_count so that
// subsequent hook__dyld_get_image_name/header/slide on the same thread
// see a consistent view.
static __thread PXDyldSnapshot *tls_dyldSnapshot = NULL;

static PXDyldSnapshot *PXDyldSnapshotRetain(PXDyldSnapshot *snap) {
    if (snap) atomic_fetch_add_explicit(&snap->refCount, 1, memory_order_relaxed);
    return snap;
}

static void PXDyldSnapshotRelease(PXDyldSnapshot *snap) {
    if (!snap) return;
    if (atomic_fetch_sub_explicit(&snap->refCount, 1, memory_order_acq_rel) == 1) {
        free(snap->map);
        free(snap);
    }
}

static PXDyldSnapshot *PXDyldAcquireSnapshot(void) {
    PXDyldSnapshot *snap = atomic_load_explicit(&gDyldCurrentSnapshot, memory_order_acquire);
    return PXDyldSnapshotRetain(snap);
}
```

---

## Edit 2: Replace PXDyldRebuildVisibleMapLocked (lines 2515-2552)

### OLD:
```c
static void PXDyldRebuildVisibleMapLocked(void) {
    uint32_t count = PXDyldOriginalImageCount();
    if (count == 0) {
        free(gVisibleToReal);
        gVisibleToReal = NULL;
        gRealCount = 0;
        gVisibleCount = 0;
        gDyldLastBuildNs = PXJBMonotonicNanoseconds();
        return;
    }

    uint32_t *replacement = (uint32_t *)calloc(count, sizeof(uint32_t));
    if (!replacement) {
        // Fail open rather than expose a stale index map from another dyld
        // generation. The indexed wrappers call the original trampoline when
        // no visible map is available.
        free(gVisibleToReal);
        gVisibleToReal = NULL;
        gRealCount = count;
        gVisibleCount = 0;
        gDyldLastBuildNs = PXJBMonotonicNanoseconds();
        return;
    }

    uint32_t visible = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = PXDyldOriginalImageName(i);
        if (PXJBShouldHideImageName(name)) continue;
        replacement[visible++] = i;
    }

    uint32_t *oldMap = gVisibleToReal;
    gVisibleToReal = replacement;
    gRealCount = count;
    gVisibleCount = visible;
    gDyldLastBuildNs = PXJBMonotonicNanoseconds();
    free(oldMap);
}
```

### NEW:
```c
static void PXDyldRebuildVisibleMapLocked(void) {
    uint32_t count = PXDyldOriginalImageCount();
    if (count == 0) {
        PXDyldSnapshot *old = atomic_exchange_explicit(&gDyldCurrentSnapshot, NULL, memory_order_acq_rel);
        PXDyldSnapshotRelease(old);
        return;
    }

    PXDyldSnapshot *snap = (PXDyldSnapshot *)calloc(1, sizeof(PXDyldSnapshot));
    if (!snap) {
        // Fail open: drop the current snapshot so indexed wrappers fall
        // through to the original trampoline.
        PXDyldSnapshot *old = atomic_exchange_explicit(&gDyldCurrentSnapshot, NULL, memory_order_acq_rel);
        PXDyldSnapshotRelease(old);
        return;
    }

    snap->map = (uint32_t *)calloc(count, sizeof(uint32_t));
    if (!snap->map) {
        free(snap);
        PXDyldSnapshot *old = atomic_exchange_explicit(&gDyldCurrentSnapshot, NULL, memory_order_acq_rel);
        PXDyldSnapshotRelease(old);
        return;
    }

    uint32_t visible = 0;
    for (uint32_t i = 0; i < count; i++) {
        const char *name = PXDyldOriginalImageName(i);
        if (PXJBShouldHideImageName(name)) continue;
        snap->map[visible++] = i;
    }

    snap->visibleCount = visible;
    snap->realCount = count;
    snap->buildNs = PXJBMonotonicNanoseconds();
    // Start with refCount=1 for the global atomic pointer.
    atomic_store_explicit(&snap->refCount, 1, memory_order_relaxed);

    PXDyldSnapshot *old = atomic_exchange_explicit(&gDyldCurrentSnapshot, snap, memory_order_acq_rel);
    PXDyldSnapshotRelease(old);
}
```

---

## Edit 3: Replace PXDyldEnsureVisibleMap (lines 2554-2568)

### OLD:
```c
static void PXDyldEnsureVisibleMap(void) {
    if (!PXJBHideDylibsEnabled()) return;

    uint64_t nowNs = PXJBMonotonicNanoseconds();
    uint32_t countNow = PXDyldOriginalImageCount();

    pthread_mutex_lock(&gDyldLock);
    BOOL expired = (nowNs == 0 || gDyldLastBuildNs == 0 ||
                    nowNs - gDyldLastBuildNs > 1000000000ull);
    BOOL needsRebuild = (gVisibleToReal == NULL) ||
                        (gRealCount != countNow) ||
                        expired;
    if (needsRebuild) PXDyldRebuildVisibleMapLocked();
    pthread_mutex_unlock(&gDyldLock);
}
```

### NEW:
```c
static void PXDyldEnsureVisibleMap(void) {
    if (!PXJBHideDylibsEnabled()) return;

    uint64_t nowNs = PXJBMonotonicNanoseconds();
    uint32_t countNow = PXDyldOriginalImageCount();

    // Fast path: check without locking.
    PXDyldSnapshot *current = atomic_load_explicit(&gDyldCurrentSnapshot, memory_order_acquire);
    BOOL expired = (nowNs == 0 || !current || current->buildNs == 0 ||
                    nowNs - current->buildNs > 1000000000ull);
    BOOL needsRebuild = (!current) ||
                        (current->realCount != countNow) ||
                        expired;
    if (!needsRebuild) return;

    // Slow path: acquire lock, double-check, rebuild.
    pthread_mutex_lock(&gDyldLock);
    current = atomic_load_explicit(&gDyldCurrentSnapshot, memory_order_acquire);
    expired = (nowNs == 0 || !current || current->buildNs == 0 ||
              nowNs - current->buildNs > 1000000000ull);
    needsRebuild = (!current) ||
                   (current->realCount != countNow) ||
                   expired;
    if (needsRebuild) PXDyldRebuildVisibleMapLocked();
    pthread_mutex_unlock(&gDyldLock);
}
```

---

## Edit 4: Replace hook__dyld_image_count (lines 2570-2580)

### OLD:
```c
static uint32_t hook__dyld_image_count(void) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    uint32_t originalCount = PXDyldOriginalImageCount();
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) return originalCount;

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    uint32_t result = gVisibleToReal ? gVisibleCount : originalCount;
    pthread_mutex_unlock(&gDyldLock);
    return result;
}
```

### NEW:
```c
static uint32_t hook__dyld_image_count(void) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    uint32_t originalCount = PXDyldOriginalImageCount();
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) return originalCount;

    PXDyldEnsureVisibleMap();

    // Release any previously cached TLS snapshot, then acquire a fresh one.
    // This snapshot is cached so that subsequent name/header/slide calls on
    // the *same* thread see a consistent index mapping.
    PXDyldSnapshotRelease(tls_dyldSnapshot);
    tls_dyldSnapshot = PXDyldAcquireSnapshot();

    return tls_dyldSnapshot ? tls_dyldSnapshot->visibleCount : originalCount;
}
```

---

## Edit 5: Replace hook__dyld_get_image_name (lines 2582-2601)

### OLD:
```c
static const char *hook__dyld_get_image_name(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageName(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageName(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return NULL;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageName(realIndex);
}
```

### NEW:
```c
static const char *hook__dyld_get_image_name(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageName(image_index);
    }

    PXDyldEnsureVisibleMap();

    // Prefer the TLS-cached snapshot (pinned by hook__dyld_image_count).
    // Fall back to a fresh acquire if no cached snapshot exists.
    PXDyldSnapshot *snap = tls_dyldSnapshot;
    BOOL ownedSnap = NO;
    if (!snap) {
        snap = PXDyldAcquireSnapshot();
        ownedSnap = YES;
    }
    if (!snap || !snap->map) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return PXDyldOriginalImageName(image_index);
    }
    if (image_index >= snap->visibleCount) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return NULL;
    }
    uint32_t realIndex = snap->map[image_index];
    if (ownedSnap) PXDyldSnapshotRelease(snap);
    return PXDyldOriginalImageName(realIndex);
}
```

---

## Edit 6: Replace hook__dyld_get_image_header (lines 2603-2622)

### OLD:
```c
static const struct mach_header *hook__dyld_get_image_header(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageHeader(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageHeader(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return NULL;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageHeader(realIndex);
}
```

### NEW:
```c
static const struct mach_header *hook__dyld_get_image_header(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageHeader(image_index);
    }

    PXDyldEnsureVisibleMap();

    PXDyldSnapshot *snap = tls_dyldSnapshot;
    BOOL ownedSnap = NO;
    if (!snap) {
        snap = PXDyldAcquireSnapshot();
        ownedSnap = YES;
    }
    if (!snap || !snap->map) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return PXDyldOriginalImageHeader(image_index);
    }
    if (image_index >= snap->visibleCount) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return NULL;
    }
    uint32_t realIndex = snap->map[image_index];
    if (ownedSnap) PXDyldSnapshotRelease(snap);
    return PXDyldOriginalImageHeader(realIndex);
}
```

---

## Edit 7: Replace hook__dyld_get_image_vmaddr_slide (lines 2624-2643)

### OLD:
```c
static intptr_t hook__dyld_get_image_vmaddr_slide(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageSlide(image_index);
    }

    PXDyldEnsureVisibleMap();
    pthread_mutex_lock(&gDyldLock);
    if (!gVisibleToReal) {
        pthread_mutex_unlock(&gDyldLock);
        return PXDyldOriginalImageSlide(image_index);
    }
    if (image_index >= gVisibleCount) {
        pthread_mutex_unlock(&gDyldLock);
        return 0;
    }
    uint32_t realIndex = gVisibleToReal[image_index];
    pthread_mutex_unlock(&gDyldLock);
    return PXDyldOriginalImageSlide(realIndex);
}
```

### NEW:
```c
static intptr_t hook__dyld_get_image_vmaddr_slide(uint32_t image_index) {
    PXJB_REENTRY_SCOPE(dyldScope, kPXJBReentryDyldSnapshot);
    if (!dyldScope.entered || !PXJBHideDylibsEnabled()) {
        return PXDyldOriginalImageSlide(image_index);
    }

    PXDyldEnsureVisibleMap();

    PXDyldSnapshot *snap = tls_dyldSnapshot;
    BOOL ownedSnap = NO;
    if (!snap) {
        snap = PXDyldAcquireSnapshot();
        ownedSnap = YES;
    }
    if (!snap || !snap->map) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return PXDyldOriginalImageSlide(image_index);
    }
    if (image_index >= snap->visibleCount) {
        if (ownedSnap) PXDyldSnapshotRelease(snap);
        return 0;
    }
    uint32_t realIndex = snap->map[image_index];
    if (ownedSnap) PXDyldSnapshotRelease(snap);
    return PXDyldOriginalImageSlide(realIndex);
}
```

---

## Verification
After applying all 7 edits:
1. `grep -n 'gVisibleToReal\|gVisibleCount\|gRealCount\|gDyldLastBuildNs' ProjectXTweak/JailbreakBypassHooks.x`
   → Should return 0 matches (all references replaced).
2. Build the tweak and test on a device with ZDefend-protected app.
3. Confirm no SIGSEGV in ZDefend on background thread during dyld enumeration.
