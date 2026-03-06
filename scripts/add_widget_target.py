#!/usr/bin/env python3
"""
Adds the Chess4UWidget extension target to Chess4U.xcodeproj/project.pbxproj.
Run from the repository root: python3 scripts/add_widget_target.py
"""
import re, sys

PROJECT = "Chess4U.xcodeproj/project.pbxproj"

# ── Stable UUIDs for every new object ────────────────────────────────────────
W = {
    # File references
    "widget_swift_ref":    "WD100001AA100001BB100001",
    "widget_infoplist_ref":"WD100002AA100002BB100002",
    "widget_appex_ref":    "WD100003AA100003BB100003",
    "widgetkit_ref":       "WD100004AA100004BB100004",
    # Build files
    "widget_swift_bf":     "WD100005AA100005BB100005",
    "widgetkit_bf":        "WD100006AA100006BB100006",
    "swiftui_bf":          "WD100007AA100007BB100007",
    "embed_ext_bf":        "WD100008AA100008BB100008",
    # Groups
    "widget_group":        "WD100009AA100009BB100009",
    # Build phases
    "widget_sources_bp":   "WD100010AA100010BB100010",
    "widget_frameworks_bp":"WD100011AA100011BB100011",
    "widget_resources_bp": "WD100012AA100012BB100012",
    "embed_extensions_bp": "WD100013AA100013BB100013",
    # Target + configs
    "widget_target":       "WD100014AA100014BB100014",
    "widget_cfg_list":     "WD100015AA100015BB100015",
    "widget_cfg_debug":    "WD100016AA100016BB100016",
    "widget_cfg_release":  "WD100017AA100017BB100017",
    # Target dependency inside main target
    "widget_dep":          "WD100018AA100018BB100018",
    "widget_dep_proxy":    "WD100019AA100019BB100019",
}

# ── Guard: skip if already patched ───────────────────────────────────────────
with open(PROJECT) as f:
    src = f.read()

if W["widget_target"] in src:
    print("Widget target already present — nothing to do.")
    sys.exit(0)

# ── Helpers ───────────────────────────────────────────────────────────────────
def insert_after(text, anchor, snippet):
    idx = text.find(anchor)
    if idx == -1:
        raise ValueError(f"Anchor not found: {repr(anchor[:80])}")
    insert_point = idx + len(anchor)
    return text[:insert_point] + snippet + text[insert_point:]

def replace_first(text, old, new):
    idx = text.find(old)
    if idx == -1:
        raise ValueError(f"Pattern not found: {repr(old[:80])}")
    return text[:idx] + new + text[idx + len(old):]

# ─────────────────────────────────────────────────────────────────────────────
# 1.  PBXBuildFile entries
# ─────────────────────────────────────────────────────────────────────────────
build_file_anchor = "/* Begin PBXBuildFile section */"
new_build_files = f"""
		{W['widget_swift_bf']} /* Chess4UWidget.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {W['widget_swift_ref']} /* Chess4UWidget.swift */; }};
		{W['widgetkit_bf']} /* WidgetKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {W['widgetkit_ref']} /* WidgetKit.framework */; }};
		{W['embed_ext_bf']} /* Chess4UWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {W['widget_appex_ref']} /* Chess4UWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
"""
src = insert_after(src, build_file_anchor, new_build_files)

# ─────────────────────────────────────────────────────────────────────────────
# 2.  PBXFileReference entries
# ─────────────────────────────────────────────────────────────────────────────
file_ref_anchor = "/* Begin PBXFileReference section */"
new_file_refs = f"""
		{W['widget_swift_ref']} /* Chess4UWidget.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Chess4UWidget.swift; sourceTree = "<group>"; }};
		{W['widget_infoplist_ref']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{W['widget_appex_ref']} /* Chess4UWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = Chess4UWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
		{W['widgetkit_ref']} /* WidgetKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = WidgetKit.framework; path = System/Library/Frameworks/WidgetKit.framework; sourceTree = SDKROOT; }};
"""
src = insert_after(src, file_ref_anchor, new_file_refs)

# ─────────────────────────────────────────────────────────────────────────────
# 3.  PBXGroup — Chess4UWidget group + add to root group + products group
# ─────────────────────────────────────────────────────────────────────────────
group_section_anchor = "/* Begin PBXGroup section */"
new_group = f"""
		{W['widget_group']} /* Chess4UWidget */ = {{
			isa = PBXGroup;
			children = (
				{W['widget_swift_ref']} /* Chess4UWidget.swift */,
				{W['widget_infoplist_ref']} /* Info.plist */,
			);
			path = Chess4UWidget;
			sourceTree = "<group>";
		}};
"""
src = insert_after(src, group_section_anchor, new_group)

# Add widget group to root group children
src = replace_first(
    src,
    "B11BA34D63C71E3E5D1803C0 /* Chess4U */,",
    f"B11BA34D63C71E3E5D1803C0 /* Chess4U */,\n\t\t\t\t{W['widget_group']} /* Chess4UWidget */,"
)

# Add appex to Products group
src = replace_first(
    src,
    "625ACE7FA04888266A8808AD /* Chess4U.app */,",
    f"625ACE7FA04888266A8808AD /* Chess4U.app */,\n\t\t\t\t{W['widget_appex_ref']} /* Chess4UWidget.appex */,"
)

# ─────────────────────────────────────────────────────────────────────────────
# 4.  Build phases for widget target
# ─────────────────────────────────────────────────────────────────────────────
sources_section_anchor = "/* Begin PBXSourcesBuildPhase section */"
new_sources_phase = f"""
		{W['widget_sources_bp']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{W['widget_swift_bf']} /* Chess4UWidget.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
src = insert_after(src, sources_section_anchor, new_sources_phase)

frameworks_section_anchor = "/* Begin PBXFrameworksBuildPhase section */"
new_frameworks_phase = f"""
		{W['widget_frameworks_bp']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{W['widgetkit_bf']} /* WidgetKit.framework in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
src = insert_after(src, frameworks_section_anchor, new_frameworks_phase)

resources_section_anchor = "/* Begin PBXResourcesBuildPhase section */"
new_resources_phase = f"""
		{W['widget_resources_bp']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
src = insert_after(src, resources_section_anchor, new_resources_phase)

# Embed Extensions copy-files phase (goes on the main app target)
embed_phase = f"""
		{W['embed_extensions_bp']} /* Embed Foundation Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				{W['embed_ext_bf']} /* Chess4UWidget.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
copy_files_anchor = "/* Begin PBXCopyFilesBuildPhase section */"
if copy_files_anchor in src:
    src = insert_after(src, copy_files_anchor, embed_phase)
else:
    # No existing copy-files section; insert before Resources section
    src = insert_after(
        src,
        "/* Begin PBXResourcesBuildPhase section */",
        f"/* Begin PBXCopyFilesBuildPhase section */{embed_phase}/* End PBXCopyFilesBuildPhase section */\n\n"
    )

# ─────────────────────────────────────────────────────────────────────────────
# 5.  PBXNativeTarget for widget
# ─────────────────────────────────────────────────────────────────────────────
native_target_section_anchor = "/* Begin PBXNativeTarget section */"
new_native_target = f"""
		{W['widget_target']} /* Chess4UWidget */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {W['widget_cfg_list']} /* Build configuration list for PBXNativeTarget "Chess4UWidget" */;
			buildPhases = (
				{W['widget_sources_bp']} /* Sources */,
				{W['widget_frameworks_bp']} /* Frameworks */,
				{W['widget_resources_bp']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Chess4UWidget;
			productName = Chess4UWidget;
			productReference = {W['widget_appex_ref']} /* Chess4UWidget.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
"""
src = insert_after(src, native_target_section_anchor, new_native_target)

# ─────────────────────────────────────────────────────────────────────────────
# 6.  Add widget target + embed phase to main app target
# ─────────────────────────────────────────────────────────────────────────────
src = replace_first(
    src,
    "BC01316BBCA63BD9F9542A7E /* Resources */,\n\t\t\t);",
    f"BC01316BBCA63BD9F9542A7E /* Resources */,\n\t\t\t\t{W['embed_extensions_bp']} /* Embed Foundation Extensions */,\n\t\t\t);"
)

# ─────────────────────────────────────────────────────────────────────────────
# 7.  PBXProject — add widget to targets list + TargetAttributes
# ─────────────────────────────────────────────────────────────────────────────
src = replace_first(
    src,
    "BB100010CC100010DD100010 /* Chess4UUITests */,\n\t\t\t);",
    f"BB100010CC100010DD100010 /* Chess4UUITests */,\n\t\t\t\t{W['widget_target']} /* Chess4UWidget */,\n\t\t\t);"
)

src = replace_first(
    src,
    "BB100010CC100010DD100010 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t\tTestTargetID = 42AEFBAE01D2DFD981F7DA7D;\n\t\t\t\t\t};",
    f"BB100010CC100010DD100010 = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t\tTestTargetID = 42AEFBAE01D2DFD981F7DA7D;\n\t\t\t\t\t}};\n\t\t\t\t\t{W['widget_target']} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t}};"
)

# ─────────────────────────────────────────────────────────────────────────────
# 8.  Build configurations for widget
# ─────────────────────────────────────────────────────────────────────────────
xcbuildconfig_anchor = "/* Begin XCBuildConfiguration section */"
new_build_configs = f"""
		{W['widget_cfg_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Chess4UWidget/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.chess4u.Chess4U.Widget";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{W['widget_cfg_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Chess4UWidget/Info.plist;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.chess4u.Chess4U.Widget";
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_VERSION = 5.9;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
"""
src = insert_after(src, xcbuildconfig_anchor, new_build_configs)

# ─────────────────────────────────────────────────────────────────────────────
# 9.  XCConfigurationList for widget
# ─────────────────────────────────────────────────────────────────────────────
cfg_list_anchor = "/* Begin XCConfigurationList section */"
new_cfg_list = f"""
		{W['widget_cfg_list']} /* Build configuration list for PBXNativeTarget "Chess4UWidget" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{W['widget_cfg_debug']} /* Debug */,
				{W['widget_cfg_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
"""
src = insert_after(src, cfg_list_anchor, new_cfg_list)

# ─────────────────────────────────────────────────────────────────────────────
# Write result
# ─────────────────────────────────────────────────────────────────────────────
with open(PROJECT, "w") as f:
    f.write(src)

print("✅ Chess4UWidget target added to project.pbxproj")
