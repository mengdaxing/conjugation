#!/usr/bin/env python3
"""Generate a dependency-free Xcode project from the checked-in sources."""
import hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
objects={}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(s): return '"'+str(s).replace('\\','\\\\').replace('"','\\"')+'"'
def arr(items): return '('+','.join(items)+')'
def add(key,isa,**attrs):
 ident=uid(key); objects[ident]='{isa = '+isa+';'+''.join(f'{k} = {v};' for k,v in attrs.items())+'}';return ident

def configs(name,settings):
 configs=[]
 for mode in ['Debug','Release']:
  cfg=dict(settings)
  cfg['SWIFT_OPTIMIZATION_LEVEL']=q('-Onone' if mode=='Debug' else '-O')
  cfg['SWIFT_ACTIVE_COMPILATION_CONDITIONS']=q('DEBUG' if mode=='Debug' else '')
  if mode=='Debug':
   cfg['GCC_PREPROCESSOR_DEFINITIONS']=arr([q('DEBUG=1'),q('$(inherited)')])
   cfg['ENABLE_TESTABILITY']='YES'
  configs.append(add(name+mode,'XCBuildConfiguration',buildSettings='{'+''.join(f'{k}={v};' for k,v in cfg.items())+'}',name=q(mode)))
 return add(name+'ConfigList','XCConfigurationList',buildConfigurations=arr(configs),defaultConfigurationIsVisible='0',defaultConfigurationName=q('Release'))

common={'IPHONEOS_DEPLOYMENT_TARGET':'16.0','SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','ENABLE_USER_SCRIPT_SANDBOXING':'YES','DEVELOPMENT_TEAM':q(''),'CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':q('1,2'),'MARKETING_VERSION':'1.0.0','CURRENT_PROJECT_VERSION':'7','DEBUG_INFORMATION_FORMAT':q('dwarf-with-dsym'),'SUPPORTED_PLATFORMS':q('iphoneos iphonesimulator')}
app_settings={**common,'PRODUCT_BUNDLE_IDENTIFIER':q('com.personal.frenchconjugation'),'PRODUCT_NAME':q('Conjugation'),'INFOPLIST_FILE':q('Conjugation/Info.plist'),'ASSETCATALOG_COMPILER_APPICON_NAME':q('AppIcon'),'ENABLE_PREVIEWS':'YES','LD_RUNPATH_SEARCH_PATHS':arr([q('$(inherited)'),q('@executable_path/Frameworks')])}
appfiles=[]; buildsource=[]; buildresource=[]
for p in sorted([*(ROOT/'Conjugation').rglob('*'), *(ROOT/'Sources'/'Conjugation').rglob('*')]):
 # The standalone IPA target does not depend on the separate Skip package.
 if not p.is_file() or any(part.endswith('.xcassets') for part in p.parts):continue
 if p.name in ('SkipApp.swift','AndroidSpeech.swift','AndroidVerification.swift'):continue
 if p.suffix not in ['.swift','.json','.txt','.plist']:continue
 relative=str(p.relative_to(ROOT));typ={'.swift':'sourcecode.swift','.json':'text.json','.txt':'text','.plist':'text.plist.xml'}[p.suffix]
 f=add(relative,'PBXFileReference',lastKnownFileType=q(typ),path=q(relative),sourceTree=q('<group>'));appfiles.append(f)
 if p.suffix=='.plist':continue
 b=add(relative+'Build','PBXBuildFile',fileRef=f)
 (buildsource if p.suffix=='.swift' else buildresource).append(b)
asset=add('Assets','PBXFileReference',lastKnownFileType=q('folder.assetcatalog'),path=q('Conjugation/Assets.xcassets'),sourceTree=q('<group>'));appfiles.append(asset)
buildresource.append(add('AssetsBuild','PBXBuildFile',fileRef=asset))
appgroup=add('AppGroup','PBXGroup',children=arr(appfiles),name=q('Conjugation'),sourceTree=q('<group>'))
product=add('AppProduct','PBXFileReference',explicitFileType=q('wrapper.application'),path=q('Conjugation.app'),sourceTree=q('BUILT_PRODUCTS_DIR'))
app=add('AppTarget','PBXNativeTarget',buildConfigurationList=configs('App',app_settings),buildPhases=arr([add('AppSources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=arr(buildsource),runOnlyForDeploymentPostprocessing='0'),add('AppFrameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files='()',runOnlyForDeploymentPostprocessing='0'),add('AppResources','PBXResourcesBuildPhase',buildActionMask='2147483647',files=arr(buildresource),runOnlyForDeploymentPostprocessing='0')]),buildRules='()',dependencies='()',name=q('Conjugation'),productName=q('Conjugation'),productReference=product,productType=q('com.apple.product-type.application'))
products=[product]; groups=[appgroup];targets=[app]
for name,folder,kind in [('ConjugationTests','Unit','unit-test'),('ConjugationUITests','UI','ui-testing')]:
 files=[];builds=[]
 for p in sorted((ROOT/'Tests'/folder).glob('*.swift')):
  r=str(p.relative_to(ROOT));f=add(r,'PBXFileReference',lastKnownFileType=q('sourcecode.swift'),path=q(r),sourceTree=q('<group>'));files.append(f);builds.append(add(r+'Build','PBXBuildFile',fileRef=f))
 groups.append(add(name+'Group','PBXGroup',children=arr(files),name=q(name),sourceTree=q('<group>')))
 prod=add(name+'Product','PBXFileReference',explicitFileType=q('wrapper.cfbundle'),path=q(name+'.xctest'),sourceTree=q('BUILT_PRODUCTS_DIR'));products.append(prod)
 proxy=add(name+'Proxy','PBXContainerItemProxy',containerPortal=uid('Project'),proxyType='1',remoteGlobalIDString=app,remoteInfo=q('Conjugation'))
 dep=add(name+'Dependency','PBXTargetDependency',target=app,targetProxy=proxy)
 settings={**common,'PRODUCT_BUNDLE_IDENTIFIER':q('com.personal.'+name),'PRODUCT_NAME':q('$(TARGET_NAME)'),'GENERATE_INFOPLIST_FILE':'YES','LD_RUNPATH_SEARCH_PATHS':arr([q('$(inherited)'),q('@executable_path/Frameworks'),q('@loader_path/Frameworks')])}
 if kind=='unit-test':settings.update({'TEST_HOST':q('$(BUILT_PRODUCTS_DIR)/Conjugation.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Conjugation'),'BUNDLE_LOADER':q('$(TEST_HOST)')})
 else:settings['TEST_TARGET_NAME']=q('Conjugation')
 target=add(name+'Target','PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=arr([add(name+'Sources','PBXSourcesBuildPhase',buildActionMask='2147483647',files=arr(builds),runOnlyForDeploymentPostprocessing='0'),add(name+'Frameworks','PBXFrameworksBuildPhase',buildActionMask='2147483647',files='()',runOnlyForDeploymentPostprocessing='0'),add(name+'Resources','PBXResourcesBuildPhase',buildActionMask='2147483647',files='()',runOnlyForDeploymentPostprocessing='0')]),buildRules='()',dependencies=arr([dep]),name=q(name),productName=q(name),productReference=prod,productType=q('com.apple.product-type.bundle.'+kind));targets.append(target)
productsGroup=add('ProductsGroup','PBXGroup',children=arr(products),name=q('Products'),sourceTree=q('<group>'));groups.append(productsGroup)
rootgroup=add('RootGroup','PBXGroup',children=arr(groups),sourceTree=q('<group>'))
project=add('Project','PBXProject',attributes='{BuildIndependentTargetsInParallel=YES;LastUpgradeCheck=2620;TargetAttributes={'+app+'={CreatedOnToolsVersion=26.2;};};}',buildConfigurationList=configs('Project',{}),compatibilityVersion=q('Xcode 14.0'),developmentRegion=q('zh_CN'),hasScannedForEncodings='0',knownRegions=arr([q('zh_CN'),q('fr'),q('en'),q('Base')]),mainGroup=rootgroup,productRefGroup=productsGroup,projectDirPath=q(''),projectRoot=q(''),targets=arr(targets))
p=ROOT/'Conjugation.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion=1;classes={};objectVersion=56;objects={\n'+''.join(f'{k} = {v};\n' for k,v in objects.items())+'};rootObject='+project+';}\n')
schemes=p/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(ident,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{name}" BlueprintName="{name.removesuffix(".app").removesuffix(".xctest")}" ReferencedContainer="container:Conjugation.xcodeproj"/>'
(schemes/'Conjugation.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2620" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+ref(app,'Conjugation.app')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables>'+''.join('<TestableReference skipped="NO">'+ref(target,name+'.xctest')+'</TestableReference>' for target,name in zip(targets[1:],['ConjugationTests','ConjugationUITests']))+'</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(app,'Conjugation.app')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(app,'Conjugation.app')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
print('Generated Conjugation.xcodeproj')
