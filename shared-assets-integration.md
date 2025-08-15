# iOS Shared Assets Integration

This document explains how the iOS app integrates with the monorepo's shared assets.

## Shared Asset Structure

The monorepo's `/shared` directory contains platform-agnostic assets:

```
shared/
├── css/           # Shared stylesheets (base.css, themes.css, etc.)
├── js/            # Shared JavaScript modules
├── assets/        # Shared resources (images, fonts, map data)
└── data/          # Shared configuration and data files
```

## Integration Approach

### 1. CSS Files
CSS files from `/shared/css/` should be bundled into the iOS app's WebView components.
These provide consistent styling across Android and iOS platforms.

### 2. JavaScript Modules  
JavaScript files from `/shared/js/` should be injected into WebView contexts.
These provide consistent wiki functionality (collapsible content, map interactions, etc.).

### 3. Assets
Static assets from `/shared/assets/` should be copied into the iOS app bundle during build.
This includes map data (mbtiles), fonts, and any shared images.

### 4. Data Files
Configuration files from `/shared/data/` should be bundled as app resources.

## Build Integration

The iOS Xcode project should include a build phase that:

1. Copies CSS files from `../../shared/css/` to the app bundle
2. Copies JavaScript files from `../../shared/js/` to the app bundle  
3. Copies assets from `../../shared/assets/` to the app bundle
4. Copies data files from `../../shared/data/` to the app bundle

### Adding Build Phase to Xcode

1. Open `OSRS Wiki.xcodeproj` in Xcode
2. Select the target "OSRS Wiki"
3. Go to "Build Phases" tab
4. Add a new "Run Script" phase with:

```bash
# Copy shared assets to app bundle
echo "Copying shared assets..."

# Create directories in app bundle
mkdir -p "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/shared"

# Copy CSS files
cp -r "${SRCROOT}/../../shared/css" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/shared/"

# Copy JavaScript files  
cp -r "${SRCROOT}/../../shared/js" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/shared/"

# Copy assets
cp -r "${SRCROOT}/../../shared/assets" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/shared/"

# Copy data files
cp -r "${SRCROOT}/../../shared/data" "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/shared/"

echo "Shared assets copied successfully"
```

## Swift Code Integration

iOS Swift code should reference these bundled assets:

```swift
// Load shared CSS
if let cssPath = Bundle.main.path(forResource: "base", ofType: "css") {
    let cssContent = try String(contentsOfFile: cssPath)
    // Inject into WebView
}

// Load shared JavaScript
if let jsPath = Bundle.main.path(forResource: "collapsible_content", ofType: "js") {
    let jsContent = try String(contentsOfFile: jsPath)
    // Inject into WebView
}
```

This ensures both Android and iOS apps use identical web assets for consistent user experience.