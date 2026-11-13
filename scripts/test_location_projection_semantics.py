#!/usr/bin/env python3
"""Patch 6A: native circular geometry, direct surfaces and geocoder delegation."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
from test_runtime_identifier_writers import method
from test_profile_creation_flow import check_macro_arity

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text(encoding="utf-8")
HOOK = "TLinkIOSTweak/Tweak.x"
PROJECTION = "common/PXLocationProjection.m"
DIRECT = [("- (CLLocationDirection)headingAccuracy", "PXHookAccuracy", "CLLocationDirection", "PXNativeAccuracy(self, _cmd)", ""),
          ("- (CLLocationDirection)magneticHeading", "PXHookMagnetic", "CLLocationDirection", "PXNativeMagnetic(self, _cmd)", ""),
          ("- (CLLocationDirection)trueHeading", "PXHookTrue", "CLLocationDirection", "PXNativeTrue(self, _cmd)", ""),
          ("- (BOOL)isSimulatedBySoftware", "PXHookSimulated", "BOOL", "PXNativeSource(self, _cmd)", ""),
          ("- (BOOL)isProducedByAccessory", "PXHookAccessory", "BOOL", "PXNativeSource(self, _cmd)", "")]
GEO = ["- (void)reverseGeocodeLocation:(CLLocation *)location completionHandler:(void (^)(NSArray<CLPlacemark *> *placemarks, NSError *error))completionHandler",
       "- (void)geocodeAddressString:(NSString *)addressString completionHandler:(void (^)(NSArray<CLPlacemark *> *placemarks, NSError *error))completionHandler"]


def source_contracts():
    s = read(HOOK); p = read(PROJECTION); manager = read("common/LocationSpoofingManager.m")
    assert "%hook CLRegion" not in s and "PXP0LocationDirectSurface" not in s
    assert "%group CircularRegionProjection" in s and "%hook CLCircularRegion" in s
    assert 'if (PXLocationCircularRegionMethodsMatch(objc_getClass("CLCircularRegion")))' in s and "%init(CircularRegionProjection);" in s
    accuracy = method(s, DIRECT[0][0]); assert accuracy.count("%orig") == 1 and "PXActiveLocationSnapshot" not in accuracy and ".heading" not in accuracy
    circular = s.split("%group CircularRegionProjection", 1)[1].split("#pragma mark - Sensor transform pipeline", 1)[0]
    contains = method(circular, "- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate")
    assert contains.count("%orig") == 1 and "PXLocationProjectedCircularContains(self, snapshot.coordinate, coordinate, &contains)" in contains
    assert "? YES" not in contains and "return originalContains;" in contains
    assert "PXLocationProjectionBypassActive() || !PXLocationIsKnownCircularRegion(self)" in contains
    assert 'object_getClass(region) == objc_getClass("CLCircularRegion")' in p
    assert "method_getReturnType" in p and "method_getArgumentType" in p and "method_getNumberOfArguments" in p
    assert "@encode(CLLocationCoordinate2D)" in p and "@encode(BOOL)" in p
    assert "radius <= 0" in p and "isfinite(radius)" in p and p.count("CLLocationCoordinate2DIsValid") == 2
    assert 'initWithCenter:center radius:radius identifier:@"PXLocationProjection"' in p and "[evaluation containsCoordinate:query]" in p
    assert "if (entered) gPXLocationProjectionBypassDepth--;" in p and "evaluation = nil; region = nil;" in p
    assert "OBJC_ASSOCIATION_RETAIN_NONATOMIC" not in p and "OBJC_ASSOCIATION_RETAIN" in p
    assert "void PXAttachLocationSpoofSnapshot(" not in manager and "BOOL PXLocationProjectionBypassActive(" not in manager
    for signature, _, _, _, _ in DIRECT[1:]:
        assert "PXLocationProjectionBypassActive()" in method(s, signature)
    for signature in GEO:
        body = method(s, signature)
        assert body.count("%orig(") == 1 and "@finally" in body and "completionHandler = nil;" in body
        assert body.index("%orig(") > body.index("@catch")
    forward = method(s, GEO[1])
    assert "@finally { delivery = nil; placemarks = nil; error = nil; }" in forward
    assert "delivery = clientCompletion;" in forward and "delivery(placemarks, error);" in forward
    assert "effectiveCompletion = ^" in forward and "clientCompletion = nil; effectiveCompletion = nil;" in forward
    lines = forward.splitlines(); start = next(i for i,l in enumerate(lines) if 'effectiveCompletion = ^' in l)
    assert lines[start-1].strip() == '{'
    end = next(i for i in range(start+1,len(lines)) if lines[i].strip()=='};')
    assert lines[end+1].strip()=='}'
    assert "$(wildcard common/*.m)" in read("Makefile")
    assert "scripts/test_location_projection_semantics.py --native" in read(".github/workflows/build-ios-arm.yml")
    assert "scripts/test_location_projection_semantics.py" in read("scripts/release_hardening.py")
    for fixture in ("tests/PXLocationProjectionSemanticsTests.m", "tests/PXGeocoderDispatchTests.m"):
        check_macro_arity(read(fixture), fixture)
    print("PASS: Location projection/geocoder source contracts (native runtime not implied)")


def generate_native_fragments(folder):
    s = read(HOOK); manager = read("common/LocationSpoofingManager.m")
    snapshot = manager[manager.index("@interface PXLocationSpoofSnapshot ()"):manager.index("@interface LocationSpoofingManager ()")]
    (folder / "PXLocationSnapshotValue.inc").write_text(snapshot, encoding="utf-8")
    bodies=[]
    for signature,name,ret,original,args in DIRECT:
        body=method(s,signature); body=body[body.index('{'):].replace('%orig',original)
        bodies.append('static '+ret+' '+name+'(__unsafe_unretained id self, SEL _cmd'+args+') '+body)
    circular=s.split('%group CircularRegionProjection',1)[1]
    for signature,name,ret,original,args in (("- (CLLocationCoordinate2D)center","PXHookCenter","CLLocationCoordinate2D","PXNativeCenter(self, _cmd)",""),
            ("- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate","PXHookContains","BOOL","PXNativeContains(self, _cmd, coordinate)",", CLLocationCoordinate2D coordinate")):
        body=method(circular,signature); body=body[body.index('{'):].replace('%orig',original)
        bodies.append('static '+ret+' '+name+'(__unsafe_unretained id self, SEL _cmd'+args+') '+body)
    (folder / "PXLocationDirectBodies.inc").write_text('\n\n'.join(bodies),encoding='utf-8')
    methods=[method(s,sig) for sig in GEO]
    (folder / "PXGeocoderDeclarations.inc").write_text('\n'.join(body.split(' {',1)[0]+';' for body in methods),encoding='utf-8')
    adapted=[methods[0].replace('%orig(effectiveLocation, effectiveCompletion)','PXNativeReverse(effectiveLocation, effectiveCompletion)'),
             methods[1].replace('%orig(addressString, effectiveCompletion)','PXNativeForward(addressString, effectiveCompletion)')]
    (folder / "PXGeocoderBodies.inc").write_text('\n\n'.join(adapted),encoding='utf-8')


def native_tests():
    assert sys.platform=='darwin' and shutil.which('xcrun'), '--native requires macOS/xcrun; cannot silently skip'
    with tempfile.TemporaryDirectory(prefix='px-location-projection-') as temp:
        folder=Path(temp); generate_native_fragments(folder)
        for scheme,defines in (('rootful',[]),('roothide',['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])):
            for mode,flag in (('plain-arc','-fno-objc-arc-exceptions'),('arc-eh','-fobjc-arc-exceptions')):
                for label,fixture in (('geometry','tests/PXLocationProjectionSemanticsTests.m'),('geocoder','tests/PXGeocoderDispatchTests.m')):
                    binary=folder/(label+'-'+scheme+'-'+mode)
                    sources=([str(ROOT/'common/PXLocationProjection.m')] if label=='geometry' else [])
                    print('Location semantics native matrix:',label,scheme,mode,flush=True)
                    subprocess.run(['xcrun','clang','-O0','-fobjc-arc','-fblocks','-fexceptions','-fobjc-exceptions',flag,
                                    '-Wall','-Wextra','-Werror=implicit-function-declaration','-I',str(ROOT/'common'),'-I',str(folder),
                                    *defines,*sources,str(ROOT/fixture),'-framework','Foundation','-framework','CoreLocation','-o',str(binary)],cwd=ROOT,check=True,timeout=60)
                    subprocess.run([str(binary)],cwd=ROOT,check=True,timeout=60)


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--native',action='store_true');args=parser.parse_args()
    source_contracts()
    if args.native:native_tests()
