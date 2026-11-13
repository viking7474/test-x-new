#import "LocationSpoofingManager.h"
#import <objc/runtime.h>
#import <math.h>
#import <string.h>

static const void *kPXLocationSpoofSnapshotAssociationKey = &kPXLocationSpoofSnapshotAssociationKey;
static __thread NSUInteger gPXLocationProjectionBypassDepth = 0;

void PXAttachLocationSpoofSnapshot(id object, PXLocationSpoofSnapshot *snapshot) {
    if (!object || !snapshot) return;
    objc_setAssociatedObject(object,
                             kPXLocationSpoofSnapshotAssociationKey,
                             snapshot,
                             OBJC_ASSOCIATION_RETAIN);
}

PXLocationSpoofSnapshot *PXLocationSpoofSnapshotForObject(id object) {
    if (!object) return nil;
    id value = objc_getAssociatedObject(object, kPXLocationSpoofSnapshotAssociationKey);
    return [value isKindOfClass:[PXLocationSpoofSnapshot class]] ? value : nil;
}

BOOL PXLocationProjectionBypassActive(void) {
    return gPXLocationProjectionBypassDepth > 0;
}

CLLocationCoordinate2D PXLocationOriginalCoordinate(CLLocation *location) {
    if (!location) return kCLLocationCoordinate2DInvalid;
    gPXLocationProjectionBypassDepth += 1;
    @try {
        return location.coordinate;
    } @finally {
        location = nil;
        gPXLocationProjectionBypassDepth -= 1;
    }
}

CLLocationSpeed PXLocationOriginalSpeed(CLLocation *location) {
    if (!location) return -1.0;
    gPXLocationProjectionBypassDepth += 1;
    @try {
        return location.speed;
    } @finally {
        location = nil;
        gPXLocationProjectionBypassDepth -= 1;
    }
}

CLLocationDirection PXLocationOriginalCourse(CLLocation *location) {
    if (!location) return -1.0;
    gPXLocationProjectionBypassDepth += 1;
    @try {
        return location.course;
    } @finally {
        location = nil;
        gPXLocationProjectionBypassDepth -= 1;
    }
}

// Do not project unknown subclasses or fabricate geometry on the CLRegion base.
BOOL PXLocationIsKnownCircularRegion(id region) {
    return region && object_getClass(region) == objc_getClass("CLCircularRegion");
}

static BOOL PXLocationRegionMethodMatches(Class cls, SEL selector, const char *result, const char *argument) {
    Method method = cls ? class_getInstanceMethod(cls, selector) : NULL;
    if (!method || method_getNumberOfArguments(method) != (argument ? 3u : 2u)) return NO;
    char type[128] = {0};
    method_getReturnType(method, type, sizeof(type) - 1);
    if (strcmp(type, result) != 0) return NO;
    method_getArgumentType(method, 0, type, sizeof(type) - 1);
    if (type[0] != '@' || (type[1] && type[1] != '"')) return NO;
    method_getArgumentType(method, 1, type, sizeof(type) - 1);
    if (strcmp(type, @encode(SEL)) != 0) return NO;
    if (argument) {
        method_getArgumentType(method, 2, type, sizeof(type) - 1);
        if (strcmp(type, argument) != 0) return NO;
    }
    return YES;
}

BOOL PXLocationCircularRegionMethodsMatch(Class cls) {
    if (!cls || class_isMetaClass(cls)) return NO;
    return PXLocationRegionMethodMatches(cls, @selector(center), @encode(CLLocationCoordinate2D), NULL) &&
           PXLocationRegionMethodMatches(cls, @selector(radius), @encode(CLLocationDistance), NULL) &&
           PXLocationRegionMethodMatches(cls, @selector(containsCoordinate:), @encode(BOOL), @encode(CLLocationCoordinate2D));
}

// Return YES only when a projected result was computed. Invalid/unsupported
// inputs leave *contains untouched so the caller preserves its native result.
BOOL PXLocationProjectedCircularContains(CLRegion *region, CLLocationCoordinate2D center,
                                        CLLocationCoordinate2D query, BOOL *contains) {
    CLCircularRegion *evaluation = nil;
    BOOL entered = NO;
    @try {
        if (!contains || !PXLocationIsKnownCircularRegion(region) ||
            !isfinite(center.latitude) || !isfinite(center.longitude) || !CLLocationCoordinate2DIsValid(center) ||
            !isfinite(query.latitude) || !isfinite(query.longitude) || !CLLocationCoordinate2DIsValid(query)) return NO;
        // Native geometry may read other hooked getters during construction or
        // hit testing. Keep canonical reads native and restore on every exit.
        gPXLocationProjectionBypassDepth++;
        entered = YES;
        CLLocationDistance radius = [(CLCircularRegion *)region radius];
        if (!isfinite(radius) || radius <= 0) return NO;
        evaluation = [[CLCircularRegion alloc] initWithCenter:center radius:radius identifier:@"PXLocationProjection"];
        if (!evaluation) return NO;
        BOOL result = [evaluation containsCoordinate:query];
        *contains = result;
        return YES;
    } @finally {
        evaluation = nil; region = nil;
        if (entered) gPXLocationProjectionBypassDepth--;
    }
}
