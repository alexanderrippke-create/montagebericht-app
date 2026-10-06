// Dependency-free Xcode project generator. Run with Node.js 18+ on any OS.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const id = value => crypto.createHash('sha256').update(value).digest('hex').slice(0,24).toUpperCase();
const quote = value => JSON.stringify(value);
const entries = [];
const object = (key, value) => { entries.push(`${id(key)} = { ${value} };`); return id(key); };
const list = values => `(${values.join(',')}${values.length ? ',' : ''})`;
function files(directory) {
  return fs.readdirSync(path.join(root, directory), {withFileTypes:true}).flatMap(entry => entry.isDirectory() ? files(`${directory}/${entry.name}`) : [`${directory}/${entry.name}`]);
}
const sourcePaths = files('Montagebericht').filter(name => name.endsWith('.swift'));
const testPaths = files('MontageberichtTests').filter(name => name.endsWith('.swift'));
const refs = (paths, type) => paths.map(name => object(`ref:${name}`, `isa = PBXFileReference; lastKnownFileType = ${type}; path = ${quote(name)}; sourceTree = SOURCE_ROOT;`));
const sourceRefs = refs(sourcePaths, 'sourcecode.swift');
const testRefs = refs(testPaths, 'sourcecode.swift');
const resources = ['Montagebericht/Assets/company-logo.png','Montagebericht/Assets/Assets.xcassets','Montagebericht/PrivacyInfo.xcprivacy'];
const resourceRefs = resources.map(name => object(`ref:${name}`, `isa = PBXFileReference; lastKnownFileType = ${name.endsWith('.xcassets') ? 'folder.assetcatalog' : name.endsWith('.png') ? 'image.png' : 'text.xml'}; path = ${quote(name)}; sourceTree = SOURCE_ROOT;`));
function phase(key, type, references) {
  const builds = references.map(ref => object(`build:${key}:${ref}`, `isa = PBXBuildFile; fileRef = ${ref};`));
  return object(key, `isa = ${type}; buildActionMask = 2147483647; files = ${list(builds)}; runOnlyForDeploymentPostprocessing = 0;`);
}
const appSources = phase('appSources','PBXSourcesBuildPhase',sourceRefs);
const appResources = phase('appResources','PBXResourcesBuildPhase',resourceRefs);
const appFrameworks = phase('appFrameworks','PBXFrameworksBuildPhase',[]);
const testSources = phase('testSources','PBXSourcesBuildPhase',testRefs);
const testFrameworks = phase('testFrameworks','PBXFrameworksBuildPhase',[]);
const appProduct = object('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = Montagebericht.app; sourceTree = BUILT_PRODUCTS_DIR;');
const testProduct = object('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = MontageberichtTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const products = object('products',`isa = PBXGroup; name = Products; children = ${list([appProduct,testProduct])}; sourceTree = "<group>";`);
const group = object('rootGroup',`isa = PBXGroup; children = ${list([...sourceRefs,...testRefs,...resourceRefs,products])}; sourceTree = "<group>";`);
const common = {IPHONEOS_DEPLOYMENT_TARGET:'17.0',SWIFT_VERSION:'5.0',CLANG_ENABLE_MODULES:'YES',CLANG_ENABLE_OBJC_ARC:'YES',GCC_C_LANGUAGE_STANDARD:'gnu17',SDKROOT:'iphoneos',ENABLE_USER_SCRIPT_SANDBOXING:'YES',SWIFT_STRICT_CONCURRENCY:'targeted',SWIFT_TREAT_WARNINGS_AS_ERRORS:'YES',COPY_PHASE_STRIP:'NO'};
const settings = data => Object.entries(data).map(([key,value]) => `${key} = ${quote(value)};`).join(' ');
function configurations(name, extra) {
  const configs = ['Debug','Release'].map(mode => object(`config:${name}:${mode}`,`isa = XCBuildConfiguration; name = ${mode}; buildSettings = { ${settings({...common, ...extra, SWIFT_OPTIMIZATION_LEVEL:mode === 'Debug' ? '-Onone':'-O', DEBUG_INFORMATION_FORMAT:mode === 'Debug' ? 'dwarf':'dwarf-with-dsym', ...(mode === 'Debug' ? {ENABLE_TESTABILITY:'YES',SWIFT_ACTIVE_COMPILATION_CONDITIONS:'DEBUG'}:{})})} };`));
  return object(`configs:${name}`,`isa = XCConfigurationList; buildConfigurations = ${list(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
}
const projectConfigs = configurations('project', {});
const appConfigs = configurations('app',{PRODUCT_BUNDLE_IDENTIFIER:'de.gustavschmidt.montagebericht',PRODUCT_NAME:'Montagebericht',INFOPLIST_FILE:'Montagebericht/Info.plist',GENERATE_INFOPLIST_FILE:'NO',TARGETED_DEVICE_FAMILY:'1,2',SUPPORTED_PLATFORMS:'iphoneos iphonesimulator',CODE_SIGN_STYLE:'Automatic',MARKETING_VERSION:'0.1.0',CURRENT_PROJECT_VERSION:'1',ASSETCATALOG_COMPILER_APPICON_NAME:'AppIcon',LD_RUNPATH_SEARCH_PATHS:'$(inherited) @executable_path/Frameworks'});
const testConfigs = configurations('tests',{PRODUCT_BUNDLE_IDENTIFIER:'de.gustavschmidt.montagebericht.tests',PRODUCT_NAME:'MontageberichtTests',GENERATE_INFOPLIST_FILE:'YES',TARGETED_DEVICE_FAMILY:'1,2',TEST_HOST:'$(BUILT_PRODUCTS_DIR)/Montagebericht.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Montagebericht',BUNDLE_LOADER:'$(TEST_HOST)',LD_RUNPATH_SEARCH_PATHS:'$(inherited) @executable_path/Frameworks @loader_path/Frameworks',CODE_SIGN_STYLE:'Automatic'});
object('appTarget',`isa = PBXNativeTarget; buildConfigurationList = ${appConfigs}; buildPhases = ${list([appSources,appFrameworks,appResources])}; buildRules = (); dependencies = (); name = Montagebericht; productName = Montagebericht; productReference = ${appProduct}; productType = "com.apple.product-type.application";`);
const proxy = object('proxy',`isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${id('appTarget')}; remoteInfo = Montagebericht;`);
const dependency = object('dependency',`isa = PBXTargetDependency; target = ${id('appTarget')}; targetProxy = ${proxy};`);
object('testTarget',`isa = PBXNativeTarget; buildConfigurationList = ${testConfigs}; buildPhases = ${list([testSources,testFrameworks])}; buildRules = (); dependencies = ${list([dependency])}; name = MontageberichtTests; productName = MontageberichtTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test";`);
object('project',`isa = PBXProject; attributes = { LastUpgradeCheck = 1600; TargetAttributes = { ${id('appTarget')} = { CreatedOnToolsVersion = 16.0; }; ${id('testTarget')} = { CreatedOnToolsVersion = 16.0; TestTargetID = ${id('appTarget')}; }; }; }; buildConfigurationList = ${projectConfigs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; hasScannedForEncodings = 0; knownRegions = (de,en,Base); mainGroup = ${group}; productRefGroup = ${products}; projectDirPath = ""; projectRoot = ""; targets = ${list([id('appTarget'),id('testTarget')])};`);
const projectDir = path.join(root,'Montagebericht.xcodeproj');
fs.mkdirSync(path.join(projectDir,'xcshareddata','xcschemes'),{recursive:true});
fs.writeFileSync(path.join(projectDir,'project.pbxproj'),`// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n${entries.join('\n')}\n}; rootObject = ${id('project')}; }\n`);
const ref = (target, name) => `<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${id(target)}" BuildableName="${name}" BlueprintName="${name.replace(/\.(app|xctest)$/,'')}" ReferencedContainer="container:Montagebericht.xcodeproj"/>`;
fs.writeFileSync(path.join(projectDir,'xcshareddata','xcschemes','Montagebericht.xcscheme'),`<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">${ref('appTarget','Montagebericht.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">${ref('testTarget','MontageberichtTests.xctest')}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('appTarget','Montagebericht.app')}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">${ref('appTarget','Montagebericht.app')}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>\n`);
console.log(`Generated Xcode project: ${sourcePaths.length} app files, ${testPaths.length} test files.`);
