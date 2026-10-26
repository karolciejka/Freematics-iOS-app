# Regenerates OBDLive.xcodeproj/project.pbxproj from the source tree (deterministic object IDs).
# Usage: python3 scripts/gen-xcodeproj.py .   (run after adding or removing a source file)
import hashlib, os, sys
root = sys.argv[1]  # ios/
def oid(*k): return hashlib.md5('/'.join(k).encode()).hexdigest()[:24].upper()

app_src = sorted(f for f in os.listdir(f'{root}/OBDLive') if f.endswith('.swift'))
core_src = sorted(f for f in os.listdir(f'{root}/OBDCore/Sources/OBDCore') if f.endswith('.swift'))
fonts = sorted(f for f in os.listdir(f'{root}/OBDLive/Resources/Fonts') if f.endswith('.ttf'))

objs = {}
def add(section, id_, body): objs.setdefault(section, []).append((id_, body))

files = []  # (fileref id, path, name, type, group, buildphase)
for f in app_src: files.append((f'OBDLive/{f}', f, 'sourcecode.swift', 'app', 'src'))
for f in core_src: files.append((f'OBDCore/Sources/OBDCore/{f}', f, 'sourcecode.swift', 'core', 'src'))
for f in fonts: files.append((f'OBDLive/Resources/Fonts/{f}', f, 'file', 'fonts', 'res'))
files.append(('OBDLive/Resources/Assets.xcassets', 'Assets.xcassets', 'folder.assetcatalog', 'res', 'res'))
files.append(('OBDLive/Resources/Settings.bundle', 'Settings.bundle', 'wrapper.plug-in', 'res', 'res'))
files.append(('OBDLive/Resources/Info.plist', 'Info.plist', 'text.plist.xml', 'res', None))

groups = {'app': ('OBDLive', 'OBDLive'), 'core': ('OBDCore', 'OBDCore/Sources/OBDCore'), 'res': ('Resources', 'OBDLive/Resources'), 'fonts': ('Fonts', 'OBDLive/Resources/Fonts')}
P = lambda s: s if all(c.isalnum() or c in '._/' for c in s) else f'"{s}"'

for path, name, ftype, grp, phase in files:
    add('PBXFileReference', oid('ref', path), f'{{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {P(name)}; sourceTree = "<group>"; }};')
    if phase:
        add('PBXBuildFile', oid('build', path), f'{{isa = PBXBuildFile; fileRef = {oid("ref", path)} /* {name} */; }};')
product = oid('product')
add('PBXFileReference', product, '{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "OBD Live.app"; sourceTree = BUILT_PRODUCTS_DIR; };')

def children(grp): return [oid('ref', p) for p, n, t, g, ph in files if g == grp]
G = {k: oid('group', k) for k in groups}
add('PBXGroup', G['fonts'], '{isa = PBXGroup; children = (%s); path = Fonts; sourceTree = "<group>"; };' % ', '.join(children('fonts')))
add('PBXGroup', G['res'], '{isa = PBXGroup; children = (%s); path = Resources; sourceTree = "<group>"; };' % ', '.join([G['fonts']] + children('res')))
add('PBXGroup', G['app'], '{isa = PBXGroup; children = (%s); path = OBDLive; sourceTree = "<group>"; };' % ', '.join(children('app') + [G['res']]))
add('PBXGroup', G['core'], '{isa = PBXGroup; children = (%s); name = OBDCore; path = OBDCore/Sources/OBDCore; sourceTree = "<group>"; };' % ', '.join(children('core')))
prodgrp = oid('group', 'products')
add('PBXGroup', prodgrp, '{isa = PBXGroup; children = (%s); name = Products; sourceTree = "<group>"; };' % product)
maingrp = oid('group', 'main')
add('PBXGroup', maingrp, '{isa = PBXGroup; children = (%s, %s, %s); sourceTree = "<group>"; };' % (G['app'], G['core'], prodgrp))

srcphase, resphase, fwphase = oid('phase', 'src'), oid('phase', 'res'), oid('phase', 'fw')
add('PBXSourcesBuildPhase', srcphase, '{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (%s); runOnlyForDeploymentPostprocessing = 0; };' % ', '.join(oid('build', p) for p, n, t, g, ph in files if ph == 'src'))
add('PBXResourcesBuildPhase', resphase, '{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (%s); runOnlyForDeploymentPostprocessing = 0; };' % ', '.join(oid('build', p) for p, n, t, g, ph in files if ph == 'res'))
add('PBXFrameworksBuildPhase', fwphase, '{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0; };')

def settings(debug, target):
    s = {}
    if target:
        s.update({
            'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
            'CODE_SIGN_STYLE': 'Automatic',
            'CURRENT_PROJECT_VERSION': '1',
            'DEVELOPMENT_TEAM': '""',
            'INFOPLIST_FILE': 'OBDLive/Resources/Info.plist',
            'LD_RUNPATH_SEARCH_PATHS': '("$(inherited)", "@executable_path/Frameworks")',
            'MARKETING_VERSION': '1.0',
            'PRODUCT_BUNDLE_IDENTIFIER': 'com.karolciejka.obdlive',
            'PRODUCT_NAME': '"OBD Live"',
            'SWIFT_EMIT_LOC_STRINGS': 'YES',
            'TARGETED_DEVICE_FAMILY': '1',
        })
    else:
        s.update({
            'ALWAYS_SEARCH_USER_PATHS': 'NO', 'CLANG_ENABLE_MODULES': 'YES', 'CLANG_ENABLE_OBJC_ARC': 'YES',
            'COPY_PHASE_STRIP': 'NO', 'ENABLE_STRICT_OBJC_MSGSEND': 'YES', 'GCC_C_LANGUAGE_STANDARD': 'gnu17',
            'IPHONEOS_DEPLOYMENT_TARGET': '16.0', 'SDKROOT': 'iphoneos', 'SWIFT_VERSION': '5.0',
            'DEBUG_INFORMATION_FORMAT': 'dwarf' if debug else '"dwarf-with-dsym"',
            'ENABLE_TESTABILITY': 'YES' if debug else 'NO',
            'GCC_OPTIMIZATION_LEVEL': '0' if debug else 's',
            'SWIFT_OPTIMIZATION_LEVEL': '"-Onone"' if debug else '"-O"',
            'SWIFT_COMPILATION_MODE': 'singlefile' if debug else 'wholemodule',
            'ONLY_ACTIVE_ARCH': 'YES' if debug else 'NO',
            'VALIDATE_PRODUCT': 'NO' if debug else 'YES',
        })
        if debug:
            s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
            s['GCC_PREPROCESSOR_DEFINITIONS'] = '("DEBUG=1", "$(inherited)")'
    return '{isa = XCBuildConfiguration; buildSettings = {%s}; name = %s; };' % (' '.join(f'{k} = {v};' for k, v in sorted(s.items())), 'Debug' if debug else 'Release')

cfg = {}
for scope in ('project', 'target'):
    for debug in (True, False):
        i = oid('cfg', scope, str(debug)); cfg[(scope, debug)] = i
        add('XCBuildConfiguration', i, settings(debug, scope == 'target'))
pl, tl = oid('cfglist', 'project'), oid('cfglist', 'target')
add('XCConfigurationList', pl, '{isa = XCConfigurationList; buildConfigurations = (%s, %s); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };' % (cfg[('project', True)], cfg[('project', False)]))
add('XCConfigurationList', tl, '{isa = XCConfigurationList; buildConfigurations = (%s, %s); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; };' % (cfg[('target', True)], cfg[('target', False)]))

target = oid('target')
add('PBXNativeTarget', target, '{isa = PBXNativeTarget; buildConfigurationList = %s; buildPhases = (%s, %s, %s); buildRules = (); dependencies = (); name = OBDLive; productName = OBDLive; productReference = %s; productType = "com.apple.product-type.application"; };' % (tl, srcphase, fwphase, resphase, product))
proj = oid('project')
add('PBXProject', proj, '{isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1540; LastUpgradeCheck = 1540; TargetAttributes = {%s = {CreatedOnToolsVersion = 15.4; }; }; }; buildConfigurationList = %s; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = %s; productRefGroup = %s; projectDirPath = ""; projectRoot = ""; targets = (%s); };' % (target, pl, maingrp, prodgrp, target))

out = ['// !$*UTF8*$!', '{', '\tarchiveVersion = 1;', '\tclasses = {', '\t};', '\tobjectVersion = 56;', '\tobjects = {']
for section in sorted(objs):
    out.append(f'\n/* Begin {section} section */')
    for i, body in sorted(objs[section]):
        out.append(f'\t\t{i} = {body}')
    out.append(f'/* End {section} section */')
out += ['\t};', f'\trootObject = {proj} /* Project object */;', '}', '']
os.makedirs(f'{root}/OBDLive.xcodeproj', exist_ok=True)
open(f'{root}/OBDLive.xcodeproj/project.pbxproj', 'w').write('\n'.join(out))
print(len(files), 'files')
