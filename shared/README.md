# Shared Assets Directory

This directory contains truly platform-agnostic assets that are shared between Android and iOS platforms.

## Directory Structure

```
shared/
├── css/           # Cross-platform stylesheets
├── js/            # Platform-agnostic JavaScript modules  
├── assets/        # Shared resources (images, fonts, maps)
└── data/          # Configuration and data files
```

## Asset Categories

### CSS Files (`css/`)
- **Universal styling**: base.css, themes.css, layout.css
- **Component styles**: components.css, wiki-integration.css
- **MediaWiki modules**: modules/ subdirectory contains extracted CSS modules
- Used by WebView components in both Android and iOS apps

### JavaScript Modules (`js/`)
- **Interactive features**: collapsible_content.js, map_native_finder.js
- **UI enhancements**: infobox_switcher_bootstrap.js, responsive_videos.js
- **MediaWiki integration**: mediawiki/ subdirectory contains page loading modules
- **Third-party libraries**: highcharts-stock.js, tablesort.min.js

### Assets (`assets/`)
- **Map data**: .mbtiles files for offline map functionality
- **Fonts**: Shared typography resources
- **Images**: Icons and graphics used by both platforms

### Data (`data/`)
- **Configuration files**: App settings, API endpoints
- **Static data**: Reference tables, lookup data
- **Schemas**: API response formats, data structures

## Platform Integration

### Android
- Assets referenced via Gradle source sets in `platforms/android/app/build.gradle.kts`
- Automatically included in APK build process
- Accessible through standard Android asset loading

### iOS  
- Assets copied during Xcode build phase
- Bundled into iOS app for WebView injection
- Integration documented in `platforms/ios/shared-assets-integration.md`

## Migration from Previous Structure

Previous `/shared` directory contained Android-specific Kotlin files with imports like:
- `android.os.Parcelable`
- `android.content.Context` 
- `android.net.ConnectivityManager`

These have been moved to `platforms/android/app/src/main/java/com/omiyawaki/osrswiki/shared/` where they belong, as they cannot be shared with iOS.

## Benefits

1. **Single source of truth**: All web assets maintained in one location
2. **Consistency**: Identical styling and behavior across platforms
3. **Maintainability**: Updates to shared assets automatically affect both apps
4. **Efficiency**: No duplication of CSS, JS, and static assets