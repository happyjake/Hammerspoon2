// TypeScript definitions for Hammerspoon 2
// Auto-generated from API documentation
// DO NOT EDIT - Regenerate using: npm run docs:typescript

// ========================================
// Global Types
// ========================================

/**
 * Bridge type for working with colors in JavaScript
 */
declare class HSColor {
    /**
     * Create a color from RGB values
     * @param r Red component (0.0-1.0)
     * @param g Green component (0.0-1.0)
     * @param b Blue component (0.0-1.0)
     * @param a Alpha component (0.0-1.0)
     * @returns An HSColor object
     */
    static rgb(r: number, g: number, b: number, a: number): HSColor;

    /**
     * Create a color from a hex string
     * @param hex Hex string (e.g. "#FF0000" or "FF0000")
     * @returns An HSColor object
     */
    static hex(hex: string): HSColor;

    /**
     * Create a color from a named system color
     * @param name Name of the system color (e.g. "red", "blue", "systemBlue")
     * @returns An HSColor object
     */
    static named(name: string): HSColor;

    /**
     * Update this color's value.
If this color is bound to a UI element, the canvas re-renders automatically.
     * @param value A hex color string (e.g. "#FF0000") or another HSColor object
     */
    set(value: string | HSColor): void;

}

/**
 * This is a JavaScript object used to represent macOS fonts. It includes a variety of static methods that can instantiate the various font sizes commonly used with UI elements, and also includes static methods for instantiating the system font at various sizes/weights, or any custom font available on the system.
 */
declare class HSFont {
    /**
     * Body text style
     * @returns An HSFont object
     */
    static body(): HSFont;

    /**
     * Callout text style
     * @returns An HSFont object
     */
    static callout(): HSFont;

    /**
     * Caption text style
     * @returns An HSFont object
     */
    static caption(): HSFont;

    /**
     * Caption2 text style
     * @returns An HSFont object
     */
    static caption2(): HSFont;

    /**
     * Footnote text style
     * @returns An HSFont object
     */
    static footnote(): HSFont;

    /**
     * Headline text style
     * @returns An HSFont object
     */
    static headline(): HSFont;

    /**
     * Large Title text style
     * @returns An HSFont object
     */
    static largeTitle(): HSFont;

    /**
     * Sub-headline text style
     * @returns An HSFont object
     */
    static subheadline(): HSFont;

    /**
     * Title text style
     * @returns An HSFont object
     */
    static title(): HSFont;

    /**
     * Title2 text style
     * @returns An HSFont object
     */
    static title2(): HSFont;

    /**
     * Title3 text style
     * @returns An HSFont object
     */
    static title3(): HSFont;

    /**
     * The system font in a custom size
     * @param size The font size in points
     * @returns An HSFont object
     */
    static system(size: number): HSFont;

    /**
     * The system font in a custom size with a choice of weights
     * @param size The font size in points
     * @param weight The font weight as a string (e.g. "ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black")
     * @returns An HSFont object
     */
    static system(size: number, weight: string): HSFont;

    /**
     * A font present on the system at a given size
     * @param name A string containing the name of the font to instantiate
     * @param size The font size in points
     * @returns An HSFont object
     */
    static custom(name: string, size: number): HSFont;

}

/**
 * Bridge type for working with images in JavaScript
HSImage provides a comprehensive API for loading, manipulating, and saving images.
It supports various image sources including files, system icons, app bundles, and URLs.
## Loading Images
```javascript
// Load from file
const img = HSImage.fromPath("/path/to/image.png")

// Load system image
const icon = HSImage.fromName("NSComputer")

// Load app icon
const appIcon = HSImage.fromAppBundle("com.apple.Safari")

// Load from URL (asynchronous with Promise)
HSImage.fromURL("https://example.com/image.png")
    .then(image => console.log("Image loaded:", image.size))
    .catch(err => console.error("Failed to load image:", err))

// Or with async/await
const image = await HSImage.fromURL("https://example.com/image.png")
```
## Image Manipulation
```javascript
const img = HSImage.fromPath("/path/to/image.png")

// Get size
const size = img.size  // Returns HSSize

// Resize image (mutates in place)
img.size = HSSize(100, 100)

// Crop image
const cropped = img.croppedCopy(HSRect(10, 10, 50, 50))

// Save to file
img.saveToFile("/path/to/output.png")
```
 */
declare class HSImage {
    /**
     * Load an image from a file path
     * @param path Path to the image file
     * @returns An HSImage object, or null if the file couldn't be loaded
     */
    static fromPath(path: string): HSImage | null;

    /**
     * Load a system image by name
     * @param name Name of the system image (e.g., "NSComputer", "NSFolder")
     * @returns An HSImage object, or null if the image couldn't be found
     */
    static fromName(name: string): HSImage | null;

    /**
     * Load a system symbol by name
     * @param name Name of the symbol (e.g., "hammer", "questionmark.circle")
     * @returns An HSImage object, or null if the symbol couldn't be found
     */
    static fromSymbol(name: string): HSImage | null;

    /**
     * Load an app's icon by bundle identifier
     * @param bundleID Bundle identifier of the application
     * @param withFallbackSymbol The name of an SF Symbol to use if no bundle image could be loaded. Defaults to questionmark.circle
     * @returns An HSImage object, or null if the app couldn't be found
     */
    static fromAppBundle(bundleID: string, withFallbackSymbol?: string): HSImage | null;

    /**
     * Get the icon for a file
     * @param path Path to the file
     * @returns An HSImage object representing the file's icon
     */
    static iconForFile(path: string): HSImage | null;

    /**
     * Get the icon for a file type
     * @param fileType File extension or UTI (e.g., "png", "public.png")
     * @returns An HSImage object representing the file type's icon
     */
    static iconForFileType(fileType: string): HSImage | null;

    /**
     * Create an empty (fully transparent) image. Useful as a placeholder
for pre-allocated image slots that should render nothing when no
content is bound.
     * @returns An HSImage wrapping a 1×1 fully-transparent NSImage
     */
    static empty(): HSImage;

    /**
     * Load an image from a URL (asynchronous)
     * @param url URL string of the image
     * @returns A Promise that resolves to the loaded image, or rejects on error
     */
    static fromURL(url: string): Promise<HSImage>;

    /**
     * Create an image from base64-encoded image data (PNG, JPEG, TIFF, GIF, etc.).
This is the inverse of `encode()` — any base64 string produced by `encode()` round-trips.
Whitespace/newlines in the base64 input are ignored.
     * @param base64 Image file data encoded as a base64 string
     * @returns An HSImage object, or null if the data is not valid base64 or not a decodable image
     */
    static fromBase64(base64: string): HSImage | null;

    /**
     * Decode an image (from raw bytes or a file), optionally downscale it, and
re-encode it to a destination file — entirely off the main thread.
Use this instead of `saveToFile()` / `encode()` for any large or
untrusted image. Those run a **synchronous, full-bitmap** decode+encode on
the main thread: a single large photo can block the whole app for tens of
seconds and spike memory into the gigabytes. `transcodeToFileAsync` runs on
a background queue via ImageIO and, when `maxEdge` is set, **downsamples
during decode** — it never materialises the full-resolution bitmap.
     * @param options A configuration object:
     * @returns resolves to `{ path, width, height, bytes }`; rejects with an error string
     */
    static transcodeToFileAsync(options: any): Promise<Object>;

    /**
     * Decode an image (from raw bytes or a file), optionally downscale it, and
re-encode it to a **base64 string returned directly** — entirely off the
main thread, with no temp file.
This is the in-memory sibling of `transcodeToFileAsync`. Use it when the
caller needs the encoded bytes back as base64 (a webview `data:` URL, a
network payload) rather than on disk — it avoids the
transcode-to-file → read-back → delete round-trip. Same ImageIO core: with
`maxEdge` set it **downsamples during decode** and never materialises the
full-resolution bitmap, and the base64 encode also runs off-main.
     * @param options A configuration object:
     * @returns resolves to `{ b64, width, height, bytes }`; rejects with an error string
     */
    static transcodeToBase64Async(options: any): Promise<Object>;

    /**
     * Create a copy of the image
     * @returns A new HSImage copy
     */
    copyImage(): HSImage | null;

    /**
     * Create a cropped copy of the image
     * @param rect HSRect defining the crop area (x, y, w, h)
     * @returns A new cropped HSImage, or null if the rect falls outside the image bounds
     */
    croppedCopy(rect: HSRect): HSImage | null;

    /**
     * Save the image to a file
     * @param path Destination file path (extension determines format: png, jpg, tiff, bmp, gif)
     * @returns true if saved successfully, false otherwise
     */
    saveToFile(path: string): boolean;

    /**
     * Replace this image's content.
If this image is bound to a UI element, the canvas re-renders automatically.
     * @param value A file path string (`~` is expanded) or another HSImage object
     */
    set(value: string | HSImage): void;

    /**
     * Encode the image to a base64 string.
(maximum quality). Ignored when `format` is `"png"`.
     * @param format `"jpeg"` or `"png"` (case-insensitive). Any other value is treated as `"png"`.
     * @param quality JPEG compression quality in the range `0.0` (maximum compression) to `1.0`
     * @returns A base64-encoded string of the encoded image data, or `null` if encoding failed.
     */
    encode(format: string, quality: number): string | null;

    /**
     * The size of the image. Setting this resizes the image in place to the exact dimensions.
     */
    size: HSSize;

    /**
     * The name of the image, or null if not set.
     */
    name: string | null;

    /**
     * Whether the image is a template image.
Template images are tinted by the system to match the appearance context (e.g. menu bar icons).
     */
    template: boolean;

}

/**
 * This is a JavaScript object used to represent coordinates, or "points", as used in various places throughout Hammerspoon's API, particularly where dealing with positions on a screen. Behind the scenes it is a wrapper for the CGPoint type in Swift/ObjectiveC.
 */
declare class HSPoint {
    /**
     * Create a new HSPoint object
     * @param x A coordinate for this point on the x-axis
     * @param y A coordinate for this point on the y-axis
     */
    constructor(x: number, y: number);

    /**
     * A coordinate for the x-axis position of this point
     */
    x: number;

    /**
     * A coordinate for the y-axis position of this point
     */
    y: number;

}

/**
 * This is a JavaScript object used to represent a rectangle, as used in various places throughout Hammerspoon's API, particularly where dealing with portions of a display. Behind the scenes it is a wrapper for the CGRect type in Swift/ObjectiveC.
 */
declare class HSRect {
    /**
     * Create a new HSRect object
     * @param x The x-axis coordinate of the top-left corner
     * @param y The y-axis coordinate of the top-left corner
     * @param w The width of the rectangle
     * @param h The height of the rectangle
     */
    constructor(x: number, y: number, w: number, h: number);

    /**
     * An x-axis coordinate for the top-left point of the rectangle
     */
    x: number;

    /**
     * A y-axis coordinate for the top-left point of the rectangle
     */
    y: number;

    /**
     * The width of the rectangle
     */
    w: number;

    /**
     * The height of the rectangle
     */
    h: number;

    /**
     * The "origin" of the rectangle, ie the coordinates of its top left corner, as an HSPoint object
     */
    origin: HSPoint;

    /**
     * The size of the rectangle, ie its width and height, as an HSSize object
     */
    size: HSSize;

}

/**
 * This is a JavaScript object used to represent the size of a rectangle, as used in various places throughout Hammerspoon's API, particularly where dealing with portions of a display. Behind the scenes it is a wrapper for the CGSize type in Swift/ObjectiveC.
 */
declare class HSSize {
    /**
     * Create a new HSSize object
     * @param w The width of the rectangle
     * @param h The height of the rectangle
     */
    constructor(w: number, h: number);

    /**
     * The width of the rectangle
     */
    w: number;

    /**
     * The height of the rectangle
     */
    h: number;

}

/**
 * A reactive string container. Pass to `.text()` to get automatic
re-renders when `.set()` is called from JavaScript.
 */
declare class HSString {
    /**
     * Update the string value, triggering a re-render if bound to a UI element
     * @param newValue The new string
     */
    set(newValue: string): void;

    /**
     * The current string value
     */
    readonly value: string;

}

// ========================================
// Modules
// ========================================

/**
 * These functions are provided to maintain convenience with the console.log() function present in many JavaScript instances.
 */
declare namespace console {
    /**
     * Log a message to the Hammerspoon Log Window
     * @param message A message to log
     */
    function log(message: string): void;

    /**
     * Log an error to the Hammerspoon Log Window
     * @param message An error message
     */
    function error(message: string): void;

    /**
     * Log a warning to the Hammerspoon Log WIndow
     * @param message A warning message
     */
    function warn(message: string): void;

    /**
     * Log an informational message to the Hammerspoon Log Window
     * @param message An informational message
     */
    function info(message: string): void;

    /**
     * Log a debug message to the Hammerspoon Log Window
     * @param message A debug message
     */
    function debug(message: string): void;

}

/**
 * Root Hammerspoon namespace
 */
declare namespace hs {
    /**
     * Destroy the current JavaScript runtime and start a new one, loading all configuration from disk again
     */
    function reload(): void;

    /**
     * Force garbage collection of JavaScript objects that no longer have any references
     * @remarks This uses private macOS API
     */
    function collectGarbage(): void;

}

/**
 * Module for accessing information about the Hammerspoon application itself
 */
declare namespace hs.appinfo {
    /**
     * The application's internal name (e.g., "Hammerspoon 2")
     */
    const appName: string;

    /**
     * The application's display name shown to users
     */
    const displayName: string;

    /**
     * The application's version string (e.g., "2.0.0")
     */
    const version: string;

    /**
     * The application's build number
     */
    const build: string;

    /**
     * The minimum macOS version required to run this application
     */
    const minimumOSVersion: string;

    /**
     * The copyright notice for this application
     */
    const copyrightNotice: string;

    /**
     * The application's bundle identifier (e.g., "com.hammerspoon.Hammerspoon-2")
     */
    const bundleIdentifier: string;

    /**
     * The filesystem path to the application bundle
     */
    const bundlePath: string;

    /**
     * The filesystem path to the application's resource directory
     */
    const resourcePath: string;

    /**
     * The filesystem path to the main Hammerspoon 2 configuration file
     */
    const configPath: string;

    /**
     * The filesystem path to the directory Hammerspoon 2 loaded its config from
     */
    const configDir: string;

}

/**
 * Module for interacting with applications
 */
declare namespace hs.application {
    /**
     * Fetch all running applications
     * @returns An array of all currently running applications
     */
    function runningApplications(): HSApplication[];

    /**
     * Fetch the first running application that matches a name
     * @param name The applicaiton name to search for
     * @returns The first matching application, or nil if none matched
     */
    function matchingName(name: string): HSApplication | null;

    /**
     * Fetch the first running application that matches a Bundle ID
     * @param bundleID The identifier to search for
     * @returns The first matching application, or nil if none matched
     */
    function matchingBundleID(bundleID: string): HSApplication | null;

    /**
     * Fetch the running application that matches a POSIX PID
     * @param pid The PID to search for
     * @returns The matching application, or nil if none matched
     */
    function fromPID(pid: number): HSApplication | null;

    /**
     * Fetch the currently focused application
     * @returns The matching application, or nil if none matched
     */
    function frontmost(): HSApplication | null;

    /**
     * Fetch the application which currently owns the menu bar
     * @returns The matching application, or nil if none matched
     */
    function menuBarOwner(): HSApplication | null;

    /**
     * Fetch the filesystem path for an application
     * @param bundleID The application bundle identifier to search for (e.g. "com.apple.Safari")
     * @returns The application's filesystem path, or nil if it was not found
     */
    function pathForBundleID(bundleID: string): string | null;

    /**
     * Render the application's icon as a base64-encoded PNG string. Use the
returned string as the body of a `data:image/png;base64,…` URL to render
the icon in HTML/SwiftUI without exposing the underlying .icns path.
Falls back to NSWorkspace's generic icon if no application is found.
     * @param bundleID The application bundle identifier (e.g. "com.apple.Safari")
     * @returns The base64-encoded PNG bytes, or null if the bundle could not be located
     */
    function iconForBundleID(bundleID: string): string | null;

    /**
     * Fetch filesystem paths for an application
     * @param bundleID The application bundle identifier to search for (e.g. "com.apple.Safari")
     * @returns An array of strings containing any filesystem paths that were found
     */
    function pathsForBundleID(bundleID: string): string[];

    /**
     * Fetch filesystem path for an application able to open a given file type
     * @param fileType The file type to search for. This can be a UTType identifier, a MIME type, or a filename extension
     * @returns The path to an application for the given filetype, or il if none were found
     */
    function pathForFileType(fileType: string): string | null;

    /**
     * Fetch filesystem paths for applications able to open a given file type
     * @param fileType The file type to search for. This can be a UTType identifier, a MIME type, or a filename extension
     * @returns An array of strings containing the filesystem paths for any applications that were found
     */
    function pathsForFileType(fileType: string): string[];

    /**
     * Launch an application, or give it focus if it's already running
     * @param bundleID A bundle identifier for the app to launch/focus (e.g. "com.apple.Safari")
     * @returns A Promise that resolves to true if successful, false otherwise
     */
    function launchOrFocus(bundleID: string): Promise<boolean>;

    /**
     * Enumerate every `.app` bundle under the standard application roots,
plus any caller-supplied extra roots. Results are cached for 30 seconds
per unique `extraRoots` argument; the cache is dropped automatically
when the contents of any scanned root change (an app is installed or
deleted), so changes are visible on the next call. Call
`invalidateInstalledAppsCache()` to force a rescan by hand.
1. /Applications
2. ~/Applications
3. /System/Applications
4. /System/Applications/Utilities
5. /System/Cryptexes/App/System/Applications (Safari — its
/Applications symlink is flagged hidden, so it must be scanned
at its real cryptex location)
6. /System/Library/CoreServices/Applications (Keychain Access,
Archive Utility, Directory Utility, …)
7. /System/Library/CoreServices/Finder.app (Finder)
8. Any caller-supplied extra roots
A root may be a single `.app` bundle (like the Finder entry above), in
which case that bundle itself is the result — extra roots may use this
form too.
Both bundle layouts are understood: regular macOS bundles
(`Contents/Info.plist`) and the wrapper layout the App Store uses for
iPhone/iPad apps on Apple silicon (`Foo.app/Wrapper/<Inner>.app/`).
Wrapper apps report the inner bundle's metadata (that's where the
localized `displayName` lives) with `path` pointing at the outer
`.app` — the thing you launch or reveal in Finder.
Bundles with `LSBackgroundOnly = true` (true daemons with no UI) are
skipped. Menu-bar-only apps (`LSUIElement = true`, e.g. Hammerspoon 1,
Bartender, ClipMenu) are included because users still launch them.
`iconPath`, when non-null, points at the bundle's primary icon on disk
(`.icns` for macOS bundles, the app-icon `.png` for iOS wrapper apps).
     * @param extraRoots Optional array of additional directories to scan.
     * @returns Array of `{name, displayName, bundleID, path, iconPath, version}`
     */
    function installedApps(extraRoots: any): Record<string, any>[];

    /**
     * Force the next call to `installedApps()` to rescan from disk.
     */
    function invalidateInstalledAppsCache(): void;

    /**
     * Send SIGTERM (force=false) or SIGKILL (force=true) to an arbitrary PID.
Refuses to signal PID 0, 1, or this process. Returns true if the signal
was delivered, false on error (logged via AKError).
     * @param pid Target PID
     * @param force When true sends SIGKILL; otherwise SIGTERM.
     * @returns true on success
     */
    function killPid(pid: number, force: boolean): boolean;

    /**
     * Create a watcher for application events
     * @param listener A javascript function/lambda to call when any application event is received. The function will be called with two parameters: the name of the event, and the associated HSApplication object
     */
    function addWatcher(listener: (event: string, app: HSApplication | null) => void): void;

    /**
     * Remove a watcher for application events
     * @param listener The javascript function/lambda that was previously being used to handle events
     */
    function removeWatcher(listener: (...args: any[]) => any): void;

}

/**
 * Object representing an application. You should not instantiate this directly in JavaScript, but rather, use the methods from hs.application which will return appropriate HSApplication objects.
 */
declare class HSApplication {
    /**
     * Terminate the application
     * @returns True if the application was terminated, otherwise false
     */
    kill(): boolean;

    /**
     * Force-terminate the application
     * @returns True if the application was force-terminated, otherwise false
     */
    kill9(): boolean;

    /**
     * The application's HSAXElement object, for use with the hs.ax APIs
     * @returns An HSAXElement object, or nil if it could not be obtained
     */
    axElement(): HSAXElement | null;

    /**
     * Bring this application to the foreground
     * @param allWindows Pass true to raise all application windows. Defaults to false.
     */
    activate(allWindows?: boolean): void;

    /**
     * Hide this application and all its windows
     */
    hide(): void;

    /**
     * Unhide this application
     */
    unhide(): void;

    /**
     * Get the full menu structure of this application
     * @remarks This traverses the accessibility hierarchy and may be slow for apps with large menus.
     * @returns An array of top-level menu objects, each with title and items keys, or null if unavailable
     */
    getMenuItems(): Record<string, any>[] | null;

    /**
     * Find a menu item by searching all menus for a matching title (case-insensitive)
     * @param name The menu item title to search for
     * @returns An object with title and enabled keys, or null if not found
     */
    findMenuItemByName(name: string): Record<string, any> | null;

    /**
     * Find a menu item by following a hierarchical path of titles
     * @param path An array of menu titles forming a path from the top-level menu to the item, e.g. ["Edit", "Select All"]
     * @returns An object with title and enabled keys, or null if not found
     */
    findMenuItemByPath(path: string[]): Record<string, any> | null;

    /**
     * Click a menu item found by searching all menus for a matching title (case-insensitive)
     * @param name The menu item title to search for
     * @returns true if the menu item was found and clicked, false otherwise
     */
    selectMenuItemByName(name: string): boolean;

    /**
     * Click a menu item found by following a hierarchical path of titles
     * @param path An array of menu titles forming a path from the top-level menu to the item, e.g. ["File", "New Window"]
     * @returns true if the menu item was found and clicked, false otherwise
     */
    selectMenuItemByPath(path: string[]): boolean;

    /**
     * Find windows whose title contains the given string (case-insensitive)
     * @param pattern A string to search for in window titles
     * @returns An array of matching HSWindow objects
     */
    findWindow(pattern: string): HSWindow[];

    /**
     * Get the first window with exactly the given title
     * @param title The exact window title to search for
     * @returns The matching HSWindow, or null if not found
     */
    getWindow(title: string): HSWindow | null;

    /**
     * POSIX Process Identifier
     */
    readonly pid: number;

    /**
     * Bundle Identifier (e.g. com.apple.Safari)
     */
    readonly bundleID: string | null;

    /**
     * The application's title
     */
    readonly title: string | null;

    /**
     * Location of the application on disk
     */
    readonly bundlePath: string | null;

    /**
     * Is the application hidden
     */
    isHidden: boolean;

    /**
     * Is the application focused
     */
    readonly isActive: boolean;

    /**
     * The main window of this application, or nil if there is no main window
     */
    readonly mainWindow: HSWindow | null;

    /**
     * The focused window of this application, or nil if there is no focused window
     */
    readonly focusedWindow: HSWindow | null;

    /**
     * All windows of this application
     */
    readonly allWindows: HSWindow[];

    /**
     * All visible (ie non-hidden) windows of this application
     */
    readonly visibleWindows: HSWindow[];

    /**
     * Whether the application process is still running
     */
    readonly isRunning: boolean;

    /**
     * The kind of application: "standard" (regular dock app), "accessory" (no dock), or "background" (agent)
     */
    readonly kind: string;

}

/**
 * Module for discovering and controlling audio devices.
## Finding devices
```javascript
const all = hs.audiodevice.all();
const out = hs.audiodevice.defaultOutputDevice();
const mic = hs.audiodevice.defaultInputDevice();
```
## Selecting a device
```javascript
const usb = hs.audiodevice.findDeviceByName("USB Audio CODEC");
if (usb) usb.setDefaultOutputDevice();
```
## Watching for system-level changes
```javascript
var fn = function(event) {
    if (event === "dOut") console.log("Default output changed");
    if (event === "dev+") console.log("A device was added");
};
hs.audiodevice.addWatcher(fn);
// later…
hs.audiodevice.removeWatcher(fn);
```
 */
declare namespace hs.audiodevice {
    /**
     * All audio devices attached to the system.
     * @returns An array of HSAudioDevice objects
     */
    function all(): HSAudioDevice[];

    /**
     * All audio devices that have at least one output stream.
     * @returns An array of HSAudioDevice objects
     */
    function allOutputDevices(): HSAudioDevice[];

    /**
     * All audio devices that have at least one input stream.
     * @returns An array of HSAudioDevice objects
     */
    function allInputDevices(): HSAudioDevice[];

    /**
     * The current system default output device.
     * @returns An HSAudioDevice, or null if none is set
     */
    function defaultOutputDevice(): HSAudioDevice | null;

    /**
     * The current system default input device.
     * @returns An HSAudioDevice, or null if none is set
     */
    function defaultInputDevice(): HSAudioDevice | null;

    /**
     * The current system alert sound device.
     * @returns An HSAudioDevice, or null if none is set
     */
    function defaultEffectDevice(): HSAudioDevice | null;

    /**
     * Find the first audio device whose name matches the given string.
     * @param name The device name to search for
     * @returns An HSAudioDevice if found, null otherwise
     */
    function findDeviceByName(name: string): HSAudioDevice | null;

    /**
     * Find the audio device with the given unique identifier.
     * @param uid The device UID to search for
     * @returns An HSAudioDevice if found, null otherwise
     */
    function findDeviceByUID(uid: string): HSAudioDevice | null;

    /**
     * Register a listener for all system-level audio configuration events.
     * @param listener A JavaScript function that receives the event name string
     */
    function addWatcher(listener: (event: string) => void): void;

    /**
     * Remove a previously registered system-level listener.
     * @param listener The JavaScript function that was passed to ``addWatcher(_:)``
     */
    function removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * SKIP_DOCS
     */
    function _makeDeviceEmitter(): void;

}

/**
 * An audio device attached to the system.
Obtain instances via ``hs.audiodevice`` module methods — do not instantiate directly.
## Getting and setting volume
```javascript
const dev = hs.audiodevice.defaultOutputDevice();
if (dev) {
    console.log(dev.volume);    // 0.0 – 1.0, or null
    dev.volume = 0.5;
}
```
## Watching for changes
```javascript
const dev = hs.audiodevice.defaultOutputDevice();
if (dev) {
    var fn = function(event) { console.log("Device event:", event); };
    dev.addWatcher(fn);
    // later…
    dev.removeWatcher(fn);
}
```
 */
declare class HSAudioDevice {
    /**
     * The current output data source as `{ id, name }`, or `null` if unavailable.
     * @returns A dictionary containing the id and name of the current output data source
     */
    currentOutputDataSource(): Record<string, any> | null;

    /**
     * The current input data source as `{ id, name }`, or `null` if unavailable.
     * @returns A dictionary containing the id and name of the current input data source
     */
    currentInputDataSource(): Record<string, any> | null;

    /**
     * All available output data sources as an array of `{ id, name }` objects.
     * @returns A dictionary containing the ids and names of all available output data sources
     */
    outputDataSources(): Record<string, any>[];

    /**
     * All available input data sources as an array of `{ id, name }` objects.
     * @returns A dictionary containing the ids and names of all available input data sources
     */
    inputDataSources(): Record<string, any>[];

    /**
     * Select an output data source by its numeric ID.
     * @param sourceID The `id` value from ``outputDataSources()``
     * @returns `true` on success
     */
    setCurrentOutputDataSource(sourceID: number): boolean;

    /**
     * Select an input data source by its numeric ID.
     * @param sourceID The `id` value from ``inputDataSources()``
     * @returns `true` on success
     */
    setCurrentInputDataSource(sourceID: number): boolean;

    /**
     * Make this device the system default output device.
     * @returns `true` on success
     */
    setDefaultOutputDevice(): boolean;

    /**
     * Make this device the system default input device.
     * @returns `true` on success
     */
    setDefaultInputDevice(): boolean;

    /**
     * Make this device the system alert sound (effect) device.
     * @returns `true` on success
     */
    setDefaultEffectDevice(): boolean;

    /**
     * Register a listener for a per-device property-change event.
     * @param listener A JavaScript function that receives an event name string
     */
    addWatcher(listener: (event: string) => void): void;

    /**
     * Remove a previously registered per-device listener.
     * @param listener The JavaScript function that was passed to ``addWatcher(_:)``
     */
    removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * The CoreAudio object ID of this device.
     */
    readonly id: number;

    /**
     * The human-readable name of this device (e.g. `"Built-in Output"`).
     */
    readonly name: string;

    /**
     * The persistent unique identifier for this device.
     */
    readonly uid: string;

    /**
     * Whether this device has output streams (can play audio).
     */
    readonly isOutput: boolean;

    /**
     * Whether this device has input streams (can record audio).
     */
    readonly isInput: boolean;

    /**
     * The transport mechanism: `"built-in"`, `"usb"`, `"bluetooth"`, `"bluetooth-le"`,
`"hdmi"`, `"display-port"`, `"firewire"`, `"airplay"`, `"avb"`,
`"thunderbolt"`, `"virtual"`, `"aggregate"`, `"pci"`, or `"unknown"`.
     */
    readonly transportType: string;

    /**
     * Number of output channels, or 0 if the device has no output.
     */
    readonly outputChannels: number;

    /**
     * Number of input channels, or 0 if the device has no input.
     */
    readonly inputChannels: number;

    /**
     * Output volume scalar in the range `0.0`–`1.0`, or `null` if the device has
no controllable output volume. Setting `null` is a no-op.
     */
    volume: number | null;

    /**
     * Whether output is muted. Always `false` if the device has no mutable output.
     */
    muted: boolean;

    /**
     * Output stereo balance in the range `0.0` (full left)–`1.0` (full right),
or `null` if balance control is not available.
     */
    balance: number | null;

    /**
     * Input (microphone) volume scalar in the range `0.0`–`1.0`, or `null` if
the device has no controllable input volume.
     */
    inputVolume: number | null;

    /**
     * Whether input is muted. Always `false` if the device has no mutable input.
     */
    inputMuted: boolean;

    /**
     * The current nominal sample rate in Hz (e.g. `44100`), or `null` if unknown.
     */
    sampleRate: number | null;

    /**
     * All sample rates (in Hz) that this device supports.
For devices that support a range, both the minimum and maximum are included.
     */
    readonly availableSampleRates: number[];

}

/**
 * # Accessibility API Module
## Basic Usage
```js
// Get the focused UI element
const element = hs.ax.focusedElement();
console.log(element.role, element.title);

// Watch for window creation events
const app = hs.application.frontmost();
hs.ax.addWatcher(app, "AXWindowCreated", (notification, element) => {
    console.log("New window:", element.title);
});
```
**Note:** Requires accessibility permissions in System Preferences.
 */
declare namespace hs.ax {
    /**
     * Get the system-wide accessibility element
     * @returns The system-wide AXElement, or nil if accessibility is not available
     */
    function systemWideElement(): HSAXElement | null;

    /**
     * Get the accessibility element for an application
     * @param element An HSApplication object
     * @returns The AXElement for the application, or nil if accessibility is not available
     */
    function applicationElement(element: HSApplication): HSAXElement | null;

    /**
     * Get the accessibility element for a window
     * @param window An HSWindow  object
     * @returns The AXElement for the window, or nil if accessibility is not available
     */
    function windowElement(window: HSWindow): HSAXElement | null;

    /**
     * Get the accessibility element at the specific screen position
     * @param point An HSPoint object containing screen coordinates
     * @returns The AXElement at that position, or nil if none found
     */
    function elementAtPoint(point: HSPoint): HSAXElement | null;

    /**
     * Add a watcher for application AX events
     * @param application An HSApplication object
     * @param notification An event name
     * @param listener A function called with the notification name and the accessibility element it applies to
     */
    function addWatcher(application: HSApplication, notification: string, listener: (notification: string, element: HSAXElement) => void): void;

    /**
     * Remove a watcher for application AX events
     * @param application An HSApplication object
     * @param notification The event name to stop watching
     * @param listener The function/lambda provided when adding the watcher
     */
    function removeWatcher(application: HSApplication, notification: string, listener: (...args: any[]) => any): void;

    /**
     * Fetch the focused UI element
     * @returns An HSAXElement representing the focused UI element, or null if none was found
     */
    function focusedElement(): any;

    /**
     * Find AX elements for a given role
     * @param role The role name to search for
     * @param parent An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
     * @param options Optional object: { maxDepth: number, maxNodes: number }. maxDepth limits how many levels below the search root are visited (0 = the root only; unlimited when omitted). maxNodes caps the total number of elements visited (default 10000; pass 0 for unlimited). Every AX call is a synchronous IPC round-trip on the JS thread, so an uncapped walk of a large app (or the system-wide element) can freeze Hammerspoon for minutes — the default cap turns that into a bounded, warned-about truncation.
     * @returns An array of found elements
     */
    function findByRole(role: any, parent: any, options: any): any;

    /**
     * Find AX elements by title
     * @param title The name to search for
     * @param parent An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
     * @param options Optional object: { maxDepth: number, maxNodes: number }. maxDepth limits how many levels below the search root are visited (0 = the root only; unlimited when omitted). maxNodes caps the total number of elements visited (default 10000; pass 0 for unlimited). Every AX call is a synchronous IPC round-trip on the JS thread, so an uncapped walk of a large app (or the system-wide element) can freeze Hammerspoon for minutes — the default cap turns that into a bounded, warned-about truncation.
     * @returns An array of found elements
     */
    function findByTitle(title: any, parent: any, options: any): any;

    /**
     * SKIP_DOCS
     */
    function _boundedWalk(): void;

    /**
     * Prints the hierarchy of a given element to the Console
     * @param element An HSAXElement
     * @param depth This parameter should not be supplied
     */
    function printHierarchy(element: any, depth: any): void;

    /**
     * A dictionary containing all of the notification types that can be used with hs.ax.addWatcher()
     */
    const notificationTypes: Record<string, string>;

}

/**
 * Object representing an Accessibility element. You should not instantiate this directly, but rather, use the hs.ax methods to create these as required.
 */
declare class HSAXElement {
    /**
     * The element's children
     * @returns An array of HSAXElement objects
     */
    children(): HSAXElement[];

    /**
     * Get a specific child by index
     * @param index The index to fetch
     * @returns An HSAXElement object, if a child exists at the given index
     */
    childAtIndex(index: number): HSAXElement | null;

    /**
     * Get all available attribute names
     * @returns An array of attribute names
     */
    attributeNames(): string[];

    /**
     * Get the value of a specific attribute
     * @param attribute The attribute name to fetch the value for
     * @returns The requested value, or nil if none was found
     */
    attributeValue(attribute: string): any | null;

    /**
     * Set the value of a specific attribute
     * @param attribute The attribute name to set
     * @param value The value to set
     * @returns True if the operation succeeded, otherwise False
     */
    setAttributeValue(attribute: string, value: any): boolean;

    /**
     * Check if an attribute is settable
     * @param attribute An attribute name
     * @returns True if the attribute is settable, otherwise False
     */
    isAttributeSettable(attribute: string): boolean;

    /**
     * Get all available action names
     * @returns An array of available action names
     */
    actionNames(): string[];

    /**
     * Perform a specific action
     * @param action The action to perform
     * @returns True if the action succeeded, otherwise False
     */
    performAction(action: string): boolean;

    /**
     * The element's role (e.g., "AXWindow", "AXButton")
     */
    readonly role: string | null;

    /**
     * The element's subrole
     */
    readonly subrole: string | null;

    /**
     * The element's title
     */
    readonly title: string | null;

    /**
     * The element's value
     */
    readonly value: any | null;

    /**
     * The element's description
     */
    readonly elementDescription: string | null;

    /**
     * Whether the element is enabled
     */
    readonly isEnabled: boolean;

    /**
     * Whether the element is focused
     */
    isFocused: boolean;

    /**
     * The element's position on screen
     */
    position: HSPoint | null;

    /**
     * The element's size
     */
    size: HSSize | null;

    /**
     * The element's frame (position and size combined)
     */
    frame: HSRect | null;

    /**
     * The element's parent
     */
    readonly parent: HSAXElement | null;

    /**
     * Get the process ID of the application that owns this element
     */
    readonly pid: number;

}

/**
 * Module providing a single CoreBluetooth central for the CrossMac control relay.
On the **target** Mac, this module attaches to the ESP32 "VoiceKB" peripheral that
the OS is already BLE-bonded to for HID, discovers the custom relay GATT service,
subscribes its notify characteristic (controller → target) and writes its write
characteristic (target → controller). It never touches HID — the OS owns that.
This is deliberately *not* a general GATT stack: one service, one notify char, one
write char, on a device we are already bonded to.
 */
declare namespace hs.ble {
    /**
     * Create the BLE central used to attach to the bonded ESP32 relay service.
Each call returns a fresh `HSBLECentral`; in practice one central is enough.
All centrals are torn down when the module shuts down (JS reload).
     * @returns an `HSBLECentral`.
     */
    function central(): HSBLECentral;

}

/**
 * A CoreBluetooth central that attaches to the already-bonded ESP32 relay service.
Obtain via `hs.ble.central()`. Register `onState`, then `connect(...)` to attach
to the bonded peripheral and start the relay. The returned `HSBLEPeripheral`
reports connection and notify events.
 */
declare class HSBLECentral {
    /**
     * Register a callback for CoreBluetooth manager state changes.
Fires immediately with the current state if one is already known, then again
on every change. Use it to wait for `"poweredOn"` before calling `connect`,
and to surface `"unauthorized"` (missing Bluetooth permission) to the user.
`"unauthorized"`, `"unsupported"`, `"resetting"`, `"unknown"`.
     * @param cb `function(state)` — one of `"poweredOn"`, `"poweredOff"`,
     * @returns self, for chaining.
     */
    onState(cb: any): HSBLECentral;

    /**
     * Attach to the bonded ESP32 relay peripheral and bring up the relay channel.
Connection strategy (mirrors the proven helper): fast-attach via
`retrievePeripherals` when a `peerUUID` is known, else
`retrieveConnectedPeripherals`, else scan. Discovers the relay service,
subscribes the notify characteristic, and fires the peripheral's
`onConnect` once subscribed. Auto-reconnects on drop unless `autoReconnect`
is `false`.
`name` defaults to `"VoiceKB"`; the UUIDs default to the firmware relay
UUIDs; `autoReconnect` defaults to `true`. Pass `peerUUID` (from a prior
`peripheral.uuid`) for instant re-attach to the non-advertising bonded peer.
     * @param config `{ name?, peerUUID?, service?, notifyChar?, writeChar?, autoReconnect? }`.
     * @returns an `HSBLEPeripheral`.
     */
    connect(config: Record<string, any>): HSBLEPeripheral;

}

/**
 * A handle to the relay peripheral on the bonded ESP32.
Returned by `HSBLECentral.connect(...)`. Register `onConnect` / `onDisconnect` /
`onNotify`, and `write` lines to the controller. `onConnect` fires once the relay
notify characteristic is subscribed (the channel is live).
 */
declare class HSBLEPeripheral {
    /**
     * Register a callback fired when the relay channel becomes live (notify subscribed).
     * @param cb `function()`.
     * @returns self, for chaining.
     */
    onConnect(cb: any): HSBLEPeripheral;

    /**
     * Register a callback fired when the peripheral disconnects.
     * @param cb `function(reason)` — `reason` is the disconnect error text, or `"clean"`.
     * @returns self, for chaining.
     */
    onDisconnect(cb: any): HSBLEPeripheral;

    /**
     * Register a callback fired for each notify payload from the controller.
     * @param cb `function(line)` — `line` is the UTF-8 payload (a JSON string the relay layer parses).
     * @returns self, for chaining.
     */
    onNotify(cb: any): HSBLEPeripheral;

    /**
     * Write a line to the relay write characteristic (target → controller), `.withoutResponse`.
     * @param s the UTF-8 payload (caller-supplied JSON; keep it under the ATT MTU, ~240 B).
     * @returns `true` if queued; `false` if not connected or the payload exceeds the MTU.
     */
    write(s: string): boolean;

    /**
     * Disconnect the peripheral and stop auto-reconnect.
     */
    disconnect(): void;

    /**
     * The peripheral's system UUID. Persist this (e.g. in your config) and pass it
back as `connect({ peerUUID })` for instant re-attach to the non-advertising
bonded peer. Empty until first connected.
     */
    readonly uuid: string;

}

/**
 * Discover and publish Bonjour (mDNS / Zeroconf) network services.
Use `createSearch()` to search the network for services advertised by other
devices, and `advertise()` to advertise your own. The `networkServices()`
convenience function returns a snapshot of all service types currently
active on the local network.
## Common service type strings
The `hs.bonjour.serviceTypes` object maps short names to their mDNS strings,
e.g. `hs.bonjour.serviceTypes.ssh` → `"_ssh._tcp."`.
## Searching for a service
```js
// Find all SSH services on the local network and resolve each one
const search = hs.bonjour.createSearch()
search.findServices('_ssh._tcp.', 'local.', (event, svc, moreComing) => {
    if (event === 'serviceFound') {
        svc.resolve(5, ev => {
            if (ev === 'resolved') console.log(svc.hostname + ':' + svc.port)
        })
    }
})
```
## Advertising a service
```js
hs.bonjour.advertise('My Web Server', '_http._tcp.', 8080, ev => {
    if (ev === 'published') console.log('Now advertising!')
    else if (ev === 'error') console.error('Advertising failed')
})
// Later, to stop:
hs.bonjour.stopAdvertising('My Web Server', '_http._tcp.')
```
## Listing all active service types
```js
hs.bonjour.networkServices(5).then(types => {
    console.log('Active service types: ' + types.join(', '))
})
```
 */
declare namespace hs.bonjour {
    /**
     * Creates a new Bonjour search for discovering services or domains.
Call one of the `find…` methods on the returned search to start
discovering. Remove it with `removeSearch()` when finished.
     * @returns a new `HSBonjourSearch`
     */
    function createSearch(): HSBonjourSearch;

    /**
     * Stops and removes a previously created search.
     * @param search the search returned by `createSearch()`
     */
    function removeSearch(search: HSBonjourSearch): void;

    /**
     * Starts advertising a local service on the network.
If `domain` is omitted or not a string, it defaults to `"local."`.
If the 4th argument is a function, it is used as the callback and domain
defaults to `"local."`.
     * @param name human-readable name shown to browsers (e.g. `"My Web Server"`)
     * @param type service type in `"_proto._tcp."` or `"_proto._udp."` form
     * @param port port number the service listens on
     * @param domain mDNS domain; defaults to `"local."` if an empty string is passed
     * @param callback Optional function called on status changes with event name and optional error message
     */
    function advertise(name: string, type: string, port: number, domain: string, callback?: ((event: string, error?: string) => void) | null): void;

    /**
     * Stops advertising a service previously started with `advertise()`.
     * @param name the name passed to `advertise()`
     * @param type the type passed to `advertise()`
     */
    function stopAdvertising(name: string, type: string): void;

    /**
     * Returns a Promise that resolves to an array of service-type strings
currently advertised on the local network.
Internally searches for `_services._dns-sd._udp.` services, collects
results for up to `timeout` seconds (or until the browser signals no more
results), then resolves.
     * @param timeout maximum seconds to wait (pass `0` to use the default 5 s)
     * @returns a Promise resolving to an array of service-type strings such as `"_http._tcp."`
     */
    function networkServices(timeout: number): Promise<string[]>;

    /**
     * A frozen object mapping short service-type names to their mDNS strings.
Populated by the JavaScript enhancement layer.
     */
    const serviceTypes: Record<string, string>;

}

/**
 * Discovers Bonjour services and domains advertised on the local network.
Create via `hs.bonjour.newSearch()`, then call one of the `find…` methods.
Each search type uses its own underlying `NetServiceBrowser`, so service and
domain searches can run concurrently. Restarting any single search type stops
only that browser before beginning the new one.
## Service search callback events
| Event | Data | Description |
|-------|------|-------------|
| `"serviceFound"` | `HSBonjourService` | A matching service appeared |
| `"serviceRemoved"` | `HSBonjourService` | A previously found service disappeared |
| `"error"` | error string | The search failed |
## Domain search callback events
| Event | Data | Description |
|-------|------|-------------|
| `"domainFound"` | domain string | A domain was discovered |
| `"domainRemoved"` | domain string | A domain disappeared |
| `"error"` | error string | The search failed |
 */
declare class HSBonjourSearch {
    /**
     * Searches for services of the given type in the given domain.
If a service search is already active it is stopped before starting the
new one. Domain searches are unaffected. The callback receives
`(event, service, moreComing)` — see the type documentation for the
complete event table.
     * @param type service type string, e.g. `"_http._tcp."` or `"_ssh._tcp."`
     * @param domain mDNS domain; `"local."` for the local link, `""` for all domains
     * @param callback Called for each result with event name, service object, and whether more results are expected
     * @returns self, for chaining
     */
    findServices(type: string, domain: string, callback: (event: string, service: HSBonjourService, moreComing: boolean) => void): HSBonjourSearch;

    /**
     * Searches for domains visible to this machine (browsable domains).
If a browsable-domain search is already active it is stopped before
starting the new one. Service and registration-domain searches are
unaffected. The callback receives `(event, domain, moreComing)`.
     * @param callback Called for each result with event name, domain string, and whether more results are expected
     * @returns self, for chaining
     */
    findBrowsableDomains(callback: (event: string, domain: string, moreComing: boolean) => void): HSBonjourSearch;

    /**
     * Searches for domains on which this machine can register services.
If a registration-domain search is already active it is stopped before
starting the new one. Service and browsable-domain searches are
unaffected. The callback receives `(event, domain, moreComing)`.
     * @param callback Called for each result with event name, domain string, and whether more results are expected
     * @returns self, for chaining
     */
    findRegistrationDomains(callback: (event: string, domain: string, moreComing: boolean) => void): HSBonjourSearch;

    /**
     * Stops all active searches. Safe to call when no search is active.
     * @returns self, for chaining
     */
    stop(): HSBonjourSearch;

    /**
     * A unique identifier for this search object.
     */
    readonly identifier: string;

    /**
     * Whether to search over peer-to-peer Bluetooth/Wi-Fi in addition to
standard network interfaces. Defaults to `false`.
     */
    includesPeerToPeer: boolean;

}

/**
 * A discovered Bonjour service record. Call `resolve()` to look up its
hostname, port, and addresses.
Instances are delivered by an `HSBonjourSearch` callback. Call `resolve()`
to discover their hostname, port, and addresses, and optionally `monitor()`
to watch for TXT record changes.
## Callback events
| Method | Event | Extra data |
|--------|-------|------------|
| `resolve()` | `"resolved"` | _(none)_ |
| `resolve()` | `"stopped"` | _(none)_ |
| `resolve()` | `"error"` | error message string |
| `monitor()` | `"txtRecord"` | updated TXT record dict |
 */
declare class HSBonjourService {
    /**
     * Resolves the hostname, port, addresses, and TXT record of this service.
     * @param timeout seconds before giving up; pass `0` for no timeout
     * @param callback Called on status changes with event name and optional error message
     * @returns self, for chaining
     */
    resolve(timeout: number, callback: (event: string, error?: string) => void): HSBonjourService;

    /**
     * Starts monitoring the TXT record for changes. The callback fires whenever
the TXT record is updated.
Call `stopMonitoring()` to unsubscribe.
     * @param callback Called when TXT data changes with the updated record
     * @returns self, for chaining
     */
    monitor(callback: (txtRecord: Record<string, string>) => void): HSBonjourService;

    /**
     * Stops any active resolution.
     * @returns self, for chaining
     */
    stop(): HSBonjourService;

    /**
     * Stops TXT record monitoring started by `monitor()`.
     * @returns self, for chaining
     */
    stopMonitoring(): HSBonjourService;

    /**
     * A unique identifier assigned to this service object.
     */
    readonly identifier: string;

    /**
     * The service name (e.g. `"My Web Server"`).
     */
    readonly name: string;

    /**
     * The service type string (e.g. `"_http._tcp."`).
     */
    readonly type: string;

    /**
     * The mDNS domain (almost always `"local."`).
     */
    readonly domain: string;

    /**
     * The resolved hostname, or `null` before `resolve()` completes.
     */
    readonly hostname: string | null;

    /**
     * The service port. `-1` until `resolve()` completes.
     */
    readonly port: number;

    /**
     * IP address strings (IPv4 and/or IPv6) populated after `resolve()` completes.
     */
    readonly addresses: string[];

    /**
     * The TXT record as a `{key: value}` object, or `null` if none is available.
Populated after `resolve()` completes or when updated via `monitor()`.
     */
    readonly txtRecord: Record<string, string> | null;

    /**
     * Whether peer-to-peer Bluetooth/Wi-Fi is included in resolution.
     */
    includesPeerToPeer: boolean;

}

/**
 * Module for accessing Calendar Events.
 */
declare namespace hs.calendar {
    /**
     * Return the app's current Calendar authorization status.
     * @returns One of `fullAccess`, `writeOnly`, `denied`, `restricted`, or `notDetermined`
     */
    function authorizationStatus(): string;

    /**
     * List the Calendars available for Events.
     * @returns Calendar summaries containing `id`, `title`, `writable`, and `isDefault`
     */
    function listCalendars(): Record<string, any>[];

    /**
     * List Events from one Calendar that overlap a time window. The window may span at most four years.
     * @param calendar Calendar id or exact title
     * @param start Window start as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
     * @param end Window end as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
     * @returns Event objects containing `id`, `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, `attendees`, `organizer`, `status`, `availability`, `recurring`, and `occurrenceStart`. Timed values use UTC `Z`; all-day values are `YYYY-MM-DD`. Each attendee and organizer contains `name`, `url`, `status`, `role`, `type`, and `currentUser`. Non-recurring Events have a `null` `occurrenceStart`.
     */
    function listEvents(calendar: string, start: string, end: string): Record<string, any>[];

    /**
     * Search Event titles across all Calendars in a time window. The window may span at most four years.
     * @param query Case-insensitive text to find in Event titles
     * @param start Window start as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
     * @param end Window end as a valid ISO 8601 datetime with an explicit offset from `-14:00` through `+14:00`, or `Z`
     * @returns Matching Event objects in the same occurrence-aware shape as `listEvents`
     */
    function searchEvents(query: string, start: string, end: string): Record<string, any>[];

    /**
     * Create a single Event.
Timed `start`/`end` values require an explicit UTC offset or `Z`; all-day values must be `YYYY-MM-DD`.
`calendar` resolves by id first, then exact title, and defaults to the Calendar for new Events when omitted.
`alarms` contains non-negative minutes-before values. Recurring Event creation is unsupported.
     * @param options Event fields: `title`, `start`, `end`, optional `calendar`, `allDay`, `location`, `notes`, `url`, and `alarms`
     * @returns The created Event as a plain object; invalid input, unavailable targets, and save failures throw a JavaScript `Error`
     */
    function createEvent(options: any): Record<string, any> | null;

    /**
     * Update writable fields on one non-recurring Event.
Timed `start`/`end` values require an explicit UTC offset or `Z`; all-day values must be `YYYY-MM-DD`.
Changing `allDay` requires both `start` and `end`. Pass `null` to clear `location`, `notes`, or `url`.
`calendar` resolves by id first, then exact title. Recurring Event series editing is unsupported in v1.
     * @param id Event identifier returned by `createEvent`, `listEvents`, or `searchEvents`
     * @param fields One or more of `calendar`, `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, and `alarms`.
     * @returns The updated Event as a plain object; unknown ids, recurring series, invalid fields, and save failures throw a JavaScript `Error`
     */
    function updateEvent(id: string, fields: any): Record<string, any> | null;

    /**
     * Delete one non-recurring Event. Recurring Event series deletion is unsupported in v1.
     * @param id Event identifier returned by `createEvent`, `listEvents`, or `searchEvents`
     * @returns `true` after the Event is removed; unknown ids, recurring series, and removal failures throw a JavaScript `Error`
     */
    function deleteEvent(id: string): boolean;

}

/**
 * Module for discovering and interacting with camera devices.
This module lets you enumerate cameras, capture still images, and react to
device connect/disconnect events in real time.
Camera access requires user permission. Call `hs.permissions.requestCamera()`
before using ``captureImage()`` or reading ``isInUse``.
## Enumerating cameras
```javascript
const cameras = hs.camera.all()
cameras.forEach(cam => {
    console.log(cam.name + " — " + (cam.isInUse ? "in use" : "idle"))
})
```
## Finding a specific camera
```javascript
const cam = hs.camera.findByName("FaceTime HD Camera")
if (cam) {
    cam.captureImage()
        .then(img => img.saveToFile("/tmp/snapshot.png"))
        .catch(err => console.error("Capture error: " + err))
}
```
## Watching for connect / disconnect events
```javascript
const handler = (event, camera) => {
    if (event === "connected")    console.log("Camera connected: " + camera.name)
    if (event === "disconnected") console.log("Camera disconnected: " + camera.name)
}
hs.camera.addWatcher(handler)
// Later…
hs.camera.removeWatcher(handler)
```
## Watching a camera's in-use state
```javascript
const cam = hs.camera.all()[0]
cam.addWatcher((isInUse) => {
    console.log(cam.name + " is now " + (isInUse ? "in use" : "idle"))
})
```
 */
declare namespace hs.camera {
    /**
     * All video camera devices currently connected to the system.
     * @returns An array of `HSCamera` objects
     */
    function all(): HSCamera[];

    /**
     * Find the first camera whose name matches the given string.
     * @param name The device name to search for (exact match)
     * @returns An `HSCamera` if found, `null` otherwise
     */
    function findByName(name: string): HSCamera | null;

    /**
     * Find the camera with the given unique identifier.
     * @param uid The device UID to search for
     * @returns An `HSCamera` if found, `null` otherwise
     */
    function findByUID(uid: string): HSCamera | null;

    /**
     * Register a listener for camera device connect/disconnect events.
     * @param listener A JavaScript function called with the event name (`"connected"` or `"disconnected"`) and the affected camera
     */
    function addWatcher(listener: (event: string, camera: HSCamera) => void): void;

    /**
     * Remove a previously registered module-level event listener.
     * @param listener The function originally passed to ``addWatcher(_:)``
     */
    function removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * SKIP_DOCS
     */
    function _makeCameraEmitter(): void;

}

/**
 * A camera device attached to the system.
Obtain instances via the ``hs.camera`` module — do not instantiate directly.
## Reading camera properties
```javascript
const cam = hs.camera.all()[0]
console.log(cam.name + " uid=" + cam.uid + " inUse=" + cam.isInUse)
```
## Watching for in-use state changes
```javascript
const cam = hs.camera.all()[0]
const fn = (isInUse) => {
    console.log(cam.name + " is now " + (isInUse ? "in use" : "not in use"))
}
cam.addWatcher(fn)
// later…
cam.removeWatcher(fn)
```
## Capturing a still image
```javascript
const cam = hs.camera.all()[0]
cam.captureImage()
    .then(img => img.saveToFile("/tmp/shot.png"))
    .catch(err => console.error("Capture failed: " + err))
```
 */
declare class HSCamera {
    /**
     * Register a listener that fires whenever this camera's in-use state changes.
The listener receives one argument: a boolean that is `true` when the camera
starts being used and `false` when it is released.
     * @param listener A JavaScript function called with `true` when the camera starts being used and `false` when released
     */
    addWatcher(listener: (isInUse: boolean) => void): void;

    /**
     * Remove a previously registered per-camera in-use listener.
     * @param listener The function originally passed to ``addWatcher(_:)``
     */
    removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * Capture a still image from this camera.
Camera permission must be granted via `hs.permissions.requestCamera()` before calling
this method. The returned `HSImage` can be saved, displayed in a UI element, or
passed to other image-processing APIs.
     * @returns A Promise that resolves to an `HSImage`, or rejects on error
     */
    captureImage(): Promise<HSImage>;

    /**
     * The type name for JavaScript introspection. Always `"HSCamera"`.
     */
    readonly typeName: string;

    /**
     * The persistent unique identifier for this camera.
     */
    readonly uid: string;

    /**
     * The human-readable name of this camera (e.g. `"FaceTime HD Camera"`).
     */
    readonly name: string;

    /**
     * Whether this camera is currently being used by any application.
Queries the underlying CoreMediaIO device state each time it is read.
     */
    readonly isInUse: boolean;

}

/**
 * # hs.chooser
**A Spotlight-style chooser for presenting options to the user**
`hs.chooser` lets you show a floating search panel that users can type into to filter and
select from a list of items. It's ideal for launchers, emoji pickers, command palettes, and
any interface where you want fast, keyboard-driven selection.
## Quick Start
```javascript
const chooser = hs.chooser.create()

chooser.setChoices([
    { text: "Open Safari", subText: "Web browser", action: "safari" },
    { text: "Open Terminal", subText: "Command line", action: "terminal" }
])

chooser.onSelect = (item) => {
    if (item) console.log("Selected: " + item.text + " (" + item.action + ")")
}

chooser.show()
```
## Dynamic Choices
```javascript
const allApps = hs.application.runningApplications()

chooser.setChoices((query) => {
    const q = query.toLowerCase()
    return allApps
        .filter(a => a.title.toLowerCase().includes(q))
        .map(a => ({ text: a.title, subText: a.bundleID }))
})
```
## Async Choices (with debounce)
```javascript
let debounceTimer = null
let cachedResults = []

chooser.setChoices(() => cachedResults)

chooser.onQueryChange = (query) => {
    if (debounceTimer) debounceTimer.invalidate()
    debounceTimer = hs.timer.doAfter(0.05, () => {
        fetchFromAPI(query).then(results => {
            cachedResults = results
            chooser.refreshChoices()
        })
    })
}
```
 */
declare namespace hs.chooser {
    /**
     * Create a new chooser.
     * @returns A new `HSChooser` object ready for configuration
     */
    function create(): HSChooser;

}

/**
 * A keyboard-driven floating chooser panel.
Create via `hs.chooser.create()`. Configure choices, set callbacks, then call `.show()`.
## Choice format
Each choice is a plain object with required `text` and optional `subText`, `image`, `valid`,
and `contextMenu` fields. All other fields are passed through to the `onSelect` callback unchanged.
The `contextMenu` array defines per-row right-click menu entries. Each entry is either
```javascript
{
  text: "Open Safari", subText: "com.apple.Safari",
  image: HSImage.fromAppBundle("com.apple.Safari"), valid: true, myData: 42,
  contextMenu: [
    { title: "Open", action: () => hs.urlevent.openURL("https://apple.com") },
    { type: "divider" },
    { title: "Copy bundle ID", action: () => hs.pasteboard.writeString("com.apple.Safari") }
  ]
}
```
## Keyboard shortcuts
 */
declare class HSChooser {
    /**
     * on show. The function is responsible for filtering; the chooser displays all items it returns.
     * @param choices An array of choice objects, or a function `(query) => [...]`
     * @returns Self for chaining
     */
    setChoices(choices: Array<Record<string, any>> | ((query: string) => Array<Record<string, any>>)): HSChooser;

    /**
     * Re-apply filtering (static choices) or re-invoke the choices function (dynamic).
Call after updating an external data source in an async `onQueryChange` handler.
     * @returns Self for chaining
     */
    refreshChoices(): HSChooser;

    /**
     * Show the chooser.
     * @returns Self for chaining
     */
    show(): HSChooser;

    /**
     * Hide the chooser without making a selection. Restores focus to the previously active window.
     * @returns Self for chaining
     */
    hide(): HSChooser;

    /**
     * Programmatically confirm a selection.
Omit `row` to confirm the currently highlighted row. Fires `onSelect` (or `onInvalid`
for rows with `valid: false`) and hides the chooser.
     * @param row Zero-based row index, or omit to use the current selection.
     * @returns Self for chaining
     */
    select(row: number | null): HSChooser;

    /**
     * Returns the dict for the highlighted row, or for a specific row by index.
Returns `null` if the index is out of range or no choices are set.
     * @param row Zero-based row index, or omit to query the highlighted row.
     * @returns The row dict (`{ text, subText?, image?, valid, ...extras }`) or `null`.
     */
    selectedRowContents(row: number | null): Record<string, any> | null;

    /**
     * Read-only type identifier.
     */
    readonly typeName: string;

    /**
     * Stable UUID string for this chooser instance.
     */
    readonly identifier: string;

    /**
     * The current text in the search field. Setting this from JS updates the display but
does not invoke the `onQueryChange` callback.
     */
    query: string;

    /**
     * Placeholder text shown in the empty search field (default: `"Search..."`).
     */
    placeholder: string;

    /**
     * Whether searches match against `subText` in addition to `text` (default: `false`).
Only applies when a static choices array is provided.
     */
    searchSubText: boolean;

    /**
     * When `true` and the query is non-empty but there are no matching choices, `onSelect`
is called with `{ text: <query> }` instead of `null` (default: `false`).
     */
    enableDefaultForQuery: boolean;

    /**
     * The zero-based index of the currently highlighted row (-1 when empty).
     */
    selectedRow: number;

    /**
     * Width of the chooser as a fraction of the screen width (default: `0.5` = 50 %).
     */
    width: number;

    /**
     * Maximum number of rows visible at once without scrolling (default: `10`).
     */
    visibleRows: number;

    /**
     * `true` if the chooser panel is currently on screen.
     */
    readonly isVisible: boolean;

    /**
     * Called when the user confirms a selection, or null to remove the handler.
The argument is the chosen row object (the original dict you passed to `setChoices`,
with `text`, `subText`, `image`, `valid`, and any custom fields intact).
The argument is `null` when dismissed (Escape).
     */
    onSelect: ((item: Record<string, any> | null) => void) | null;

    /**
     * Called on every keystroke with the new query string, or null to remove the handler.
Use this to debounce expensive searches or trigger async data fetching.
     */
    onQueryChange: ((query: string) => void) | null;

    /**
     * Called after the panel becomes visible, or null to remove the handler.
     */
    onShow: (() => void) | null;

    /**
     * Called after the panel is hidden (for any reason: selection, Escape, or `hide()`), or null to remove the handler.
     */
    onHide: (() => void) | null;

    /**
     * Called when the user activates a row whose `valid` field is `false`, or null to remove the handler.
The chooser stays open; the argument is the row dict (same shape as `onSelect`).
If unset, activating an invalid row is silently ignored.
     */
    onInvalid: ((item: Record<string, any>) => void) | null;

}

/**
 */
declare namespace hs.crypto {
    /**
     * AES-256-GCM encrypt. Inputs and outputs are base64 strings.
     * @param opts `{ keyB64: string, nonceB64: string, plaintext: string }`
     * @returns `{ nonceB64, ciphertextB64 }` where ciphertextB64 includes the 16-byte tag at the end
     */
    function aesGcmEncryptB64(opts: any): Record<string, string> | null;

    /**
     * AES-256-GCM authenticate-and-decrypt. Returns the plaintext UTF-8 string,
or null on auth failure / bad input. Designed to round-trip with Android's
Cipher.getInstance("AES/GCM/NoPadding") output (ciphertext+tag concatenated).
     * @param opts `{ keyB64: string, nonceB64: string, ciphertextB64: string }`
     * @returns the decoded UTF-8 plaintext, or null if authentication failed
     */
    function aesGcmDecryptB64(opts: any): string | null;

    /**
     * SHA-256 of a UTF-8 string, returned as base64. Useful for PSK → key
derivation that matches Android's `MessageDigest.getInstance("SHA-256")
.digest(passphrase.toByteArray())` shape.
     * @param input a UTF-8 string
     * @returns base64-encoded 32-byte digest
     */
    function sha256B64(input: string): string;

}

/**
 * # hs.docs
**Offline API documentation browser**
Browse and query the Hammerspoon 2 API documentation from within the app.
`hs.docs.show()` opens an `hs.ui.webview` window with the JS or TypeScript docs.
`hs.docs.get()` returns formatted plain-text documentation from the bundled `api.json`.
 */
declare namespace hs.docs {
    /**
     * Open the Hammerspoon 2 API documentation in a new window
     * @param moduleName Optional module to navigate to directly (e.g. `"hs.application"`). Omit to open the index page.
     * @param showTS Pass `true` to show TypeScript docs instead of JS docs
     */
    function show(moduleName?: string | null, showTS?: boolean): void;

    /**
     * Return documentation for a module, method, or property
     * @param identifier Dot-separated path such as `"hs.camera"` or `"hs.camera.all"`
     * @returns A plain-text summary of the item, or `null` if not found
     */
    function get(identifier: string): string | null;

    /**
     * Return the filesystem path to the bundled JS documentation directory
     * @returns Absolute path to the JS docs folder inside the app bundle, or `null`
     */
    function jsDocsPath(): string | null;

    /**
     * Return the filesystem path to the bundled TypeScript documentation directory
     * @returns Absolute path to the TS docs folder inside the app bundle, or `null`
     */
    function tsDocsPath(): string | null;

    /**
     * Return the contents of the bundled `api.json` file
     * @returns JSON string containing the full API specification, or `null`
     */
    function apiJSON(): string | null;

}

/**
 * Module for creating CGEventTap-based global keyboard event monitors
 */
declare namespace hs.eventtap {
    /**
     * Create a new event tap for the specified event types.
Call .start() on the returned object to begin receiving events.
Requires Accessibility permission (active event taps; keyboard monitoring may also need Input Monitoring).
'systemDefined' delivers media-key events (brightness, volume, play/pause…): `{type, subtype, modifiers}` plus — for subtype 8 (aux control buttons) — `key` (e.g. 'BRIGHTNESS_UP'), `nxKeyCode`, `down`, `isRepeat`.
'gesture' delivers raw trackpad touch frames: `{type, modifiers, touchCount, touches: [{id, phase, x, y}]}` with x/y normalized to the pad (origin bottom-left).
'magnify' delivers trackpad pinch-zoom gestures: `{type, modifiers, magnification, phase}` where `magnification` is the incremental scale delta for the frame (positive = zoom in) and `phase` is 'began' | 'changed' | 'ended' | 'cancelled'.
     * @param eventTypes Array of event type strings: 'keyDown', 'keyUp', 'flagsChanged', 'mouseMoved', 'leftMouseDown', 'leftMouseUp', 'rightMouseDown', 'rightMouseUp', 'otherMouseDown', 'otherMouseUp', 'leftMouseDragged', 'rightMouseDragged', 'scrollWheel', 'systemDefined', 'gesture', 'magnify'.
     * @param callback Function called with an event object. Return true to consume (suppress) the event.
     * @returns An HSEventTap instance
     */
    function makeTap(eventTypes: string[], callback: any): HSEventTap;

    /**
     * Synthesise a key stroke: press the modifiers + key, hold, then release.
and keyUp. Defaults to 200000 (200 ms), matching upstream Hammerspoon's
`hs.eventtap.keyStroke`. A zero/too-short hold is frequently dropped by the target
app — the clipboard gets set but the paste never lands.
     * @param mods Array of modifier strings, e.g. ['cmd']
     * @param key Key name, e.g. 'v'
     * @param delay Optional number of microseconds the key is held between keyDown
     */
    function keyStroke(mods: string[], key: string, delay: any): void;

    /**
     * Synthesise a scroll-wheel event at the current mouse position.
The window server routes scroll events to the window under the cursor —
independent of keyboard focus — so this scrolls whatever the mouse is over.
     * @param dx Horizontal scroll amount (positive scrolls left, like a physical wheel tilt-left)
     * @param dy Vertical scroll amount (positive scrolls up, like a physical wheel-up)
     * @param unit Optional unit string: 'pixel' (default) or 'line'
     */
    function scrollWheel(dx: number, dy: number, unit: any): void;

    /**
     * Synthesise a left mouse click (press + release) at a point in global
top-left screen coordinates (the same space as `hs.mouse.position()` and
window frames). Does not move the visible cursor.
Defaults to 200000 (200 ms), matching upstream Hammerspoon's `hs.eventtap.leftClick`.
     * @param point A point object `{x, y}` to click at
     * @param delay Optional number of microseconds between mouseDown and mouseUp.
     */
    function leftClick(point: Record<string, number>, delay: any): void;

    /**
     * Type a string by synthesising key events (M1 stub — lands in M4).
     * @param text Text to type
     */
    function typeText(text: string): void;

}

/**
 * Object representing a CGEventTap-based global key event tap.
 */
declare class HSEventTap {
    /**
     * Start the event tap. Returns true on success.
Requires Accessibility permission (active event taps). Returns false if permission is missing.
     * @returns true if the tap was started successfully
     */
    start(): boolean;

    /**
     * Stop the event tap.
     */
    stop(): void;

    /**
     * Whether the tap is currently running.
     */
    readonly isRunning: boolean;

}

/**
 * Module for filesystem operations.
`hs.fs` provides a comprehensive set of filesystem operations covering file
I/O, directory management, path manipulation, metadata access, symbolic
links, Finder tags, and macOS-specific features like file bookmarks and
Uniform Type Identifiers.
It replaces both Hammerspoon v1's `hs.fs` module and the functionality that
was previously available through Lua's built-in `io` and `file` modules.
## Reading and writing files
```javascript
const contents = hs.fs.read("/etc/hosts");           // entire file
const chunk    = hs.fs.read("/etc/hosts", 100, 50);  // 50 bytes from offset 100

hs.fs.readLines("/etc/hosts", function(line) {
    console.log(line);
    return true; // return false to stop early
});

hs.fs.write("/tmp/hello.txt", "Hello, world!\n");
hs.fs.append("/tmp/hello.txt", "More content\n");
```
## Directory operations
```javascript
hs.fs.mkdir("~/Projects/new-thing");

const files = hs.fs.list("~/Documents");
const all   = hs.fs.listRecursive("~/Documents");
```
## Path utilities
```javascript
const abs  = hs.fs.pathToAbsolute("~/Library");
const tmp  = hs.fs.temporaryDirectory();
const home = hs.fs.homeDirectory();
```
## Metadata
```javascript
const info = hs.fs.attributes("/etc/hosts");
// { size: 1234, type: "file", permissions: 420,
//   ownerID: 0, groupID: 0,
//   creationDate: 1700000000.0, modificationDate: 1700001000.0 }
```
 */
declare namespace hs.fs {
    /**
     * Read part or all of a file as a UTF-8 string.
     * @param path Path to the file. `~` is expanded.
     * @param offset Byte offset to start reading from. Pass `0` (or omit) to read from the beginning.
     * @param length Maximum number of bytes to read. Pass `0` (or omit) to read to the end of the file.
     * @returns The file contents as a UTF-8 string, or `null` if the file cannot be read.
     */
    function read(path: string, offset: number, length: number): string | null;

    /**
     * Read a file line-by-line, invoking a callback for each line.
Lines are delivered with newline characters stripped. Both `\n` and `\r\n` line endings are handled.
     * @param path Path to the file. `~` is expanded.
     * @param callback Called once per line with the line text. Return `true` to continue reading, or `false` to stop early.
     * @returns `true` if the file was read successfully (including early stops requested by the callback), or `false` if the file could not be opened.
     */
    function readLines(path: string, callback: (line: string) => boolean): boolean;

    /**
     * Read a mozLz4 file and return its decompressed contents as a string.
mozLz4 is Mozilla's LZ4 container: an 8-byte `mozLz40\0` magic, a
little-endian uint32 decompressed size, then a raw LZ4 block. Firefox
uses it for the live session store
(`sessionstore-backups/recovery.jsonlz4` — every open window and tab)
and for `bookmarkbackups/*.jsonlz4`.
     * @param path Path to the `.jsonlz4`/`.baklz4` file. `~` is expanded.
     * @returns The decompressed UTF-8 contents, or `nil` if the file is
     */
    function readMozLz4(path: string): string | null;

    /**
     * Write a UTF-8 string to a file, creating it or overwriting any existing content.
Intermediate directories are not created automatically; use `mkdir` first if needed.
     * @param path Path to the file. `~` is expanded.
     * @param content String to write.
     * @param inPlace Whether to write the file in-place or atomically. Defaults to atomically (false).
     * @returns `true` on success, `false` on failure.
     */
    function write(path: string, content: string, inPlace?: boolean): boolean;

    /**
     * Append a UTF-8 string to a file, creating it if it does not exist.
     * @param path Path to the file. `~` is expanded.
     * @param content String to append.
     * @returns `true` on success, `false` on failure.
     */
    function append(path: string, content: string): boolean;

    /**
     * Determine if a filesystem object exists at the given path
Unlike `isFile` and `isDirectory`, this follows symlinks.
     * @param path Path to check. `~` is expanded.
     * @returns `true` if any filesystem entry (file, directory, symlink, etc.) exists at the path.
     */
    function exists(path: string): boolean;

    /**
     * Determine if a file exists at the given path
This does **not** follow symlinks; a symlink pointing at a file returns `false`.
     * @param path Path to check. `~` is expanded.
     * @returns `true` if a regular file (not a directory or symlink) exists at the path.
     */
    function isFile(path: string): boolean;

    /**
     * Determine if a directory exists at the given path
This does **not** follow symlinks; a symlink pointing at a directory returns `false`.
     * @param path Path to check. `~` is expanded.
     * @returns `true` if a directory exists at the path.
     */
    function isDirectory(path: string): boolean;

    /**
     * Determine if a symlink exists at the given path
     * @param path Path to check. `~` is expanded.
     * @returns `true` if the path is a symbolic link.
     */
    function isSymlink(path: string): boolean;

    /**
     * Determine if a given filesystem path is readable
     * @param path Path to check. `~` is expanded.
     * @returns `true` if the current process can read the file or directory at the path.
     */
    function isReadable(path: string): boolean;

    /**
     * Determine if a given filesystem path is writable
     * @param path Path to check. `~` is expanded.
     * @returns `true` if the current process can write to the file or directory at the path.
     */
    function isWritable(path: string): boolean;

    /**
     * Copy a file or directory to a new location.
The destination must not already exist. If `source` is a directory, its
entire contents are copied recursively.
Copying normally clones metadata too (permissions, extended
attributes). Some TCC-protected files (e.g. under `~/Library/Safari`
with Full Disk Access) allow reads but deny the metadata clone; for
files, `copy` then falls back to a contents-only stream copy, so the
result may lack the source's xattrs/ACLs.
     * @param source Path to the existing file or directory. `~` is expanded.
     * @param destination Path for the copy. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function copy(source: string, destination: string): boolean;

    /**
     * Move (rename) a file or directory.
The destination must not already exist.
     * @param source Path to the existing file or directory. `~` is expanded.
     * @param destination New path. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function move(source: string, destination: string): boolean;

    /**
     * Delete a file or directory at the given path.
Directories are removed recursively. To remove only an empty directory,
use `rmdir` instead.
     * @param path Path to delete. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function deletePath(path: string): boolean;

    /**
     * List the immediate contents of a directory.
Returns bare filenames (not full paths), sorted alphabetically.
The `.` and `..` entries are never included.
     * @param path Path to the directory. `~` is expanded.
     * @returns Sorted array of filenames, or `null` if the path cannot be read.
     */
    function list(path: string): string[] | null;

    /**
     * Recursively list all entries under a directory.
Returns paths relative to `path`, sorted alphabetically.
     * @param path Path to the root directory. `~` is expanded.
     * @returns Sorted array of relative paths, or `null` if the path cannot be read.
     */
    function listRecursive(path: string): string[] | null;

    /**
     * Create a directory, including all necessary intermediate directories.
Succeeds silently if the directory already exists.
     * @param path Path of the directory to create. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function mkdir(path: string): boolean;

    /**
     * Remove an empty directory.
Fails if the directory is not empty. Use `deletePath` to remove a non-empty
directory recursively.
     * @param path Path of the directory to remove. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function rmdir(path: string): boolean;

    /**
     * Returns the current working directory of the process.
     * @returns Current directory path, or `null` on error.
     */
    function currentDir(): string | null;

    /**
     * Change the current working directory of the process.
     * @param path New working directory path. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function chdir(path: string): boolean;

    /**
     * Resolve a path to its absolute, canonical form.
Expands `~`, resolves `.` and `..`, and follows all symbolic links.
Returns `null` if any component of the path does not exist.
     * @param path Path to resolve.
     * @returns Absolute canonical path, or `null` if it cannot be resolved.
     */
    function pathToAbsolute(path: string): string | null;

    /**
     * Return the localised display name for a file or directory as shown by Finder.
For example, `/Library` appears as `"Library"` in Finder even though its
on-disk name is the same.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Display name string, or `null` if the path does not exist.
     */
    function displayName(path: string): string | null;

    /**
     * Returns the temporary directory for the current user.
     * @returns Temporary directory path (always ends with `/`).
     */
    function temporaryDirectory(): string;

    /**
     * Returns the home directory for the current user.
     * @returns Home directory path string.
     */
    function homeDirectory(): string;

    /**
     * Returns a `file://` URL string for the given path.
     * @param path Filesystem path. `~` is expanded.
     * @returns URL string
     */
    function urlFromPath(path: string): string;

    /**
     * Get metadata attributes for a file or directory.
Does not follow symbolic links. Use `isSymlink` to detect links before calling this if needed.
     * @param path Path to inspect. `~` is expanded.
     * @returns Attributes object, or `null` if the path cannot be accessed.
     */
    function attributes(path: string): Record<string, any> | null;

    /**
     * Update the modification timestamp of a file to the current time.
Creates the file if it does not exist (equivalent to the POSIX `touch` command).
     * @param path Path to the file. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function touch(path: string): boolean;

    /**
     * Create a hard link at `destination` pointing at `source`.
Both paths must be on the same filesystem volume.
     * @param source Path of the existing file.
     * @param destination Path for the new hard link.
     * @returns `true` on success, `false` on failure.
     */
    function link(source: string, destination: string): boolean;

    /**
     * Create a symbolic link at `destination` pointing at `source`.
Unlike hard links, symlinks may cross filesystem boundaries and may
point to paths that do not yet exist.
     * @param source The path the symlink will point to.
     * @param destination The path where the symlink will be created.
     * @returns `true` on success, `false` on failure.
     */
    function symlink(source: string, destination: string): boolean;

    /**
     * Read the target of a symbolic link without resolving it.
     * @param path Path to the symbolic link.
     * @returns The raw path the link points to, or `null` if the path is not a symlink.
     */
    function readlink(path: string): string | null;

    /**
     * Get the Finder tags assigned to a file or directory.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Array of tag name strings, or `null` if no tags are set.
     */
    function tags(path: string): string[] | null;

    /**
     * Replace all Finder tags on a file or directory.
This function is only available on macOS Tahoe (26) or later.
     * @param path Path to the file.
     * @returns `true` on success, `false` on failure.
     */
    function fileUTI(path: string): string | null;

    /**
     * Encode a file path as a persistent bookmark that survives file moves and renames.
The returned string is base64-encoded bookmark data that can be stored and
later resolved with `pathFromBookmark`.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Base64-encoded bookmark string, or `null` on failure.
     */
    function pathToBookmark(path: string): string | null;

    /**
     * Resolve a base64-encoded bookmark back to a file path.
     * @param data Base64-encoded bookmark string produced by `pathToBookmark`.
     * @returns The current file path, or `null` if the bookmark cannot be resolved.
     */
    function pathFromBookmark(data: string): string | null;

}

/**
 * Module for hashing and encoding operations
 */
declare namespace hs.hash {
    /**
     * Encode a string to base64
     * @param data The string to encode
     * @returns Base64 encoded string
     */
    function base64Encode(data: string): string;

    /**
     * Decode a base64 string
     * @param data The base64 string to decode
     * @returns Decoded string, or nil if the input is invalid
     */
    function base64Decode(data: string): string | null;

    /**
     * Generate MD5 hash of a string
     * @param data The string to hash
     * @returns Hexadecimal MD5 hash
     */
    function md5(data: string): string;

    /**
     * Generate SHA1 hash of a string
     * @param data The string to hash
     * @returns Hexadecimal SHA1 hash
     */
    function sha1(data: string): string;

    /**
     * Generate SHA256 hash of a string
     * @param data The string to hash
     * @returns Hexadecimal SHA256 hash
     */
    function sha256(data: string): string;

    /**
     * Generate SHA512 hash of a string
     * @param data The string to hash
     * @returns Hexadecimal SHA512 hash
     */
    function sha512(data: string): string;

    /**
     * Generate HMAC-MD5 of a string with a key
     * @param key The secret key
     * @param data The data to authenticate
     * @returns Hexadecimal HMAC-MD5
     */
    function hmacMD5(key: string, data: string): string;

    /**
     * Generate HMAC-SHA1 of a string with a key
     * @param key The secret key
     * @param data The data to authenticate
     * @returns Hexadecimal HMAC-SHA1
     */
    function hmacSHA1(key: string, data: string): string;

    /**
     * Generate HMAC-SHA256 of a string with a key
     * @param key The secret key
     * @param data The data to authenticate
     * @returns Hexadecimal HMAC-SHA256
     */
    function hmacSHA256(key: string, data: string): string;

    /**
     * Generate HMAC-SHA512 of a string with a key
     * @param key The secret key
     * @param data The data to authenticate
     * @returns Hexadecimal HMAC-SHA512
     */
    function hmacSHA512(key: string, data: string): string;

}

/**
 * Module for creating and managing system-wide hotkeys
 */
declare namespace hs.hotkey {
    /**
     * Bind a hotkey
     * @param mods An array of modifier key strings (e.g., ["cmd", "shift"])
     * @param key The key name or character (e.g., "a", "space", "return")
     * @param callbackPressed A JavaScript function to call when the hotkey is pressed, or null for no callback
     * @param callbackReleased A JavaScript function to call when the hotkey is released, or null for no callback
     * @returns A hotkey object, or nil if binding failed
     */
    function bind(mods: string[], key: string, callbackPressed: (() => void) | null, callbackReleased: (() => void) | null): HSHotkey | null;

    /**
     * Bind a hotkey with a message description
     * @param mods An array of modifier key strings
     * @param key The key name or character
     * @param message A description of what this hotkey does (currently unused, for future features)
     * @param callbackPressed A JavaScript function to call when the hotkey is pressed, or null for no callback
     * @param callbackReleased A JavaScript function to call when the hotkey is released, or null for no callback
     * @returns A hotkey object, or nil if binding failed
     */
    function bindSpec(mods: string[], key: string, message: string | null, callbackPressed: (() => void) | null, callbackReleased: (() => void) | null): HSHotkey | null;

    /**
     * Get the system-wide mapping of key names to key codes
     * @returns A dictionary mapping key names to numeric key codes
     */
    function getKeyCodeMap(): Record<string, number>;

    /**
     * Drive a `DoubleTapDetector` through a synthetic event sequence and
report how many times the trigger fired. For testing only.
     * @param modifier 'shift', 'ctrl', 'cmd', or 'alt'.
     * @param sequence array of events, each `{type, mods, atMs}`.
     * @returns integer fire count.
     */
    function testDoubleTapSequence(modifier: string, sequence: any): number;

    /**
     * Get the mapping of modifier names to modifier flags
     * @returns A dictionary mapping modifier names to their numeric values
     */
    function getModifierMap(): Record<string, number>;

    /**
     * Bind a callback to a double-tap of a bare modifier key.
Detects modifier-down → all-up → modifier-down within 300ms, with no
intervening key press. Fires on the second release.
     * @param modifier One of 'shift', 'ctrl', 'cmd', 'opt'
     * @param callback Function to invoke
     * @returns An HSDoubleTapHotkey with .unbind()
     */
    function bindDoubleTap(modifier: string, callback: any): HSDoubleTapHotkey | null;

}

/**
 * Object representing a system-wide hotkey. You should not create these objects directly, but rather, use the methods in hs.hotkey to instantiate these.
 */
declare class HSHotkey {
    /**
     * Enable the hotkey
     * @returns True if the hotkey was enabled, otherwise False
     */
    enable(): boolean;

    /**
     * Disable the hotkey
     */
    disable(): void;

    /**
     * Check if the hotkey is currently enabled
     * @returns True if the hotkey is enabled, otherwise False
     */
    isEnabled(): boolean;

    /**
     * The callback function to be called when the hotkey is pressed, or null to remove it
     */
    callbackPressed: (() => void) | null;

    /**
     * The callback function to be called when the hotkey is released, or null to remove it
     */
    callbackReleased: (() => void) | null;

}

/**
 * Object representing a double-tap hotkey binding. Use .unbind() to remove it.
 */
declare class HSDoubleTapHotkey {
    /**
     * Remove the double-tap binding
     */
    unbind(): void;

}

/**
 * Module for making HTTP(S) requests.
 */
declare namespace hs.http {
    /**
     * Start an HTTP request. Returns immediately with a cancellable handle; the
result is delivered to `callback(err, res)`.
(default `'GET'`); `headers` (object); `timeout` (seconds, default 30); `body`
(string, for small payloads); `bodyFile` (path to stream the request body FROM —
large uploads; wins over `body`); `saveTo` (path to stream the response body TO —
large downloads; omits `res.body`); `directConnection` (bool — bypass any
system HTTP proxy, for talking to a loopback SSH tunnel).
`{ status, headers, bytes, body?, path? }` or null on error.
     * @param options An object with: `url` (absolute URL, required); `method`
     * @param callback `(err, res)` — `err` is a string or null; `res` is
     * @returns a request handle with `.cancel()` and `.isRunning`.
     */
    function request(options: any, callback: any | null): HSHttpClientRequest;

    /**
     * Promise sugar: `hs.http.fetch(options) -> Promise<res>`. Swift-retained storage for the JS implementation.
     */
    let fetch: any | null;

    /**
     * Promise sugar: `hs.http.get(url, options?) -> Promise<res>`. Swift-retained storage for the JS implementation.
     */
    let get: any | null;

    /**
     * Promise sugar: `hs.http.post(url, body, options?) -> Promise<res>`. Swift-retained storage for the JS implementation.
     */
    let post: any | null;

}

/**
 * A handle to an in-flight HTTP request.
 */
declare class HSHttpClientRequest {
    /**
     * Cancel the request. The callback (if any) fires with err `'cancelled'`.
     */
    cancel(): void;

    /**
     * Whether the request is still running.
     */
    readonly isRunning: boolean;

    /**
     * A unique identifier for this request.
     */
    readonly identifier: string;

}

/**
 * Multi-map of HTTP header name → value(s), with case-insensitive lookup
per RFC 7230 §3.2. Backs both incoming `HSHttpRequest.headers` and
outgoing `HSHttpResponse.headers`. Mirrors the WHATWG Fetch `Headers`
API: `get`, `set`, `append`, `delete`, `has`, iteration.
 */
declare namespace hs.httpserver {
    /**
     * Start an HTTP server.
     * @param opts `{ port, hostname?, maxBodyBytes?, fetch }`
     * @returns a server handle with `.hostname`, `.port`, `.url`, `.stop()`
     */
    function serve(opts: any): HSHttpServer | null;

}

/**
 * Multi-map of HTTP header name → value(s), with case-insensitive lookup
per RFC 7230 §3.2. Backs both incoming `HSHttpRequest.headers` and
outgoing `HSHttpResponse.headers`. Mirrors the WHATWG Fetch `Headers`
API: `get`, `set`, `append`, `delete`, `has`, iteration.
 */
declare class HSHttpHeaders {
    /**
     * Factory equivalent to `new Headers(init)`. The JS wrapper in
`hs.httpserver.js` delegates here.
     * @param init_ plain JS object `{name: value}` or another Headers
     * @returns a new Headers instance
     */
    static make(init_: any): HSHttpHeaders;

    /**
     * Get the combined value for a header name (case-insensitive). Multi-value
headers are joined with `, ` per RFC 7230 §3.2.2.
     * @param name the header name to look up (case-insensitive)
     * @returns the combined header value, or null if the header is not present
     */
    get(name: string): string | null;

    /**
     * Set a header to a single value, replacing any prior value(s).
     * @param name the header name (case-insensitive)
     * @param value the value to set
     */
    set(name: string, value: string): void;

    /**
     * True if the header is present.
     * @param name the header name to test (case-insensitive)
     * @returns true if the header is present
     */
    has(name: string): boolean;

    /**
     * Remove a header.
     * @param name the header name to remove (case-insensitive)
     */
    deleteHeader(name: string): void;

    /**
     * Append a value to a header; the prior value(s) are kept.
     * @param name the header name (case-insensitive)
     * @param value the value to append
     */
    append(name: string, value: string): void;

    /**
     * All header names (lower-cased).
     * @returns all header names, lower-cased
     */
    keys(): string[];

    /**
     * All header values, in the same order as `keys()`.
     * @returns all header values, in the same order as `keys()`
     */
    values(): string[];

    /**
     * `[[name, value], …]` pairs.
     * @returns `[[name, value], …]` pairs of every header
     */
    entries(): string[][];

}

/**
 * One incoming HTTP request as observed by `hs.httpserver`. Models the
WHATWG Fetch `Request` shape: `method`, `url`, `pathname`, `headers`,
and a body-as-string/json accessor. Passed to the user's `fetch`
handler to produce a Response.
 */
declare class HSHttpRequest {
    /**
     * Decode the request body as UTF-8 text.
     * @returns A Promise resolving to the body text. Rejects
     */
    text(): Promise<string>;

    /**
     * Decode and JSON.parse the request body.
     * @returns A Promise resolving to the parsed JSON value.
     */
    json(): Promise<any>;

    /**
     * HTTP method, upper-cased (e.g. `"GET"`, `"POST"`).
     */
    readonly method: string;

    /**
     * Absolute URL of the request (e.g. `"http://127.0.0.1:9876/path?q=1"`).
     */
    readonly url: string;

    /**
     * Path component of the URL, without query string (e.g. `"/path"`).
     */
    readonly pathname: string;

    /**
     * Request headers.
     */
    readonly headers: HSHttpHeaders;

    /**
     * Remote IP address of the client (e.g. `"127.0.0.1"`).
     */
    readonly remoteAddress: string;

    /**
     * True if the body has already been consumed by `text()` or `json()`.
     */
    readonly bodyUsed: boolean;

    /**
     * Raw query string from the URL (without leading `?`), or empty string.
The JS-side shim in `hs.httpserver.js` wraps this as `URLSearchParams`.
     */
    readonly search: string;

}

/**
 * `status`, `statusText`, `headers`, and a body-as-bytes accessor.
Returned by the user's `fetch` handler.
 */
declare class HSHttpResponse {
    /**
     * Factory equivalent to `new Response(body, init)`. The JS wrapper in
`hs.httpserver.js` delegates here so users can write the canonical
`new Response('hi', { status: 200 })` form.
     * @param body response body string (or null/undefined for an empty body)
     * @param init_ response init object with optional `status`, `statusText`, and `headers`
     * @returns a new HSHttpResponse
     */
    static make(body: any, init_: any): HSHttpResponse;

    /**
     * JSON convenience: `Response.json({ok: true})` → JSON-stringified body
with `Content-Type: application/json`.
     * @param value JS value to JSON-stringify as the response body
     * @param init_ optional response init object with `status`, `statusText`, and `headers`
     * @returns a new HSHttpResponse with JSON body and `Content-Type: application/json`
     */
    static json(value: any, init_: any | null): HSHttpResponse;

    /**
     * Redirect: sets `Location` header and a 3xx status (default 302).
     * @param url the URL to redirect to (set as the `Location` header)
     * @param status HTTP status code (default 302); must be a 3xx redirect code
     * @returns a new HSHttpResponse with the Location header set
     */
    static redirect(url: string, status: number | null): HSHttpResponse;

    /**
     * HTTP status code (e.g. 200, 404).
     */
    readonly status: number;

    /**
     * HTTP status text. Defaults from `status` per RFC 7231 if not provided.
     */
    readonly statusText: string;

    /**
     * Response headers.
     */
    readonly headers: HSHttpHeaders;

}

/**
 * A bound HTTP server listening on a configured hostname/port. Returned
by `hs.httpserver.serve(...)`. Lifecycle: `start` happens implicitly on
creation; call `stop()` to shut it down. Each accepted connection
dispatches to the user-supplied `fetch` handler.
 */
declare class HSHttpServer {
    /**
     * Stop the server. Idempotent.
     */
    stop(): void;

    /**
     * Hostname the server is bound to (e.g. `"127.0.0.1"` or `"0.0.0.0"`).
     */
    readonly hostname: string;

    /**
     * TCP port the server is listening on.
     */
    readonly port: number;

    /**
     * Base URL of the server (e.g. `"http://127.0.0.1:9876/"`).
     */
    readonly url: string;

}

/**
 */
declare namespace hs.keychain {
    /**
     * Store a value under the given account name in the Keychain.
     * @param account account name (user-facing key)
     * @param value secret string to store
     * @returns true if the item was saved successfully
     */
    function set(account: string, value: string): boolean;

    /**
     * Retrieve the value for an account name.
     * @param account account name
     * @returns the stored string, or null if the item does not exist
     */
    function get(account: string): string | null;

    /**
     * Check whether an item exists under the given account name.
     * @param account account name
     * @returns true if the item is present
     */
    function has(account: string): boolean;

    /**
     * Delete the item under the given account name.
     * @param account account name
     * @returns true if an item was deleted; false if no item existed
     */
    function deleteAccount(account: string): boolean;

    /**
     * List all account names belonging to this app's Keychain namespace.
     * @returns array of account names
     */
    function list(): string[];

}

/**
 * Access information about the current keyboard layout and input sources, and respond to changes.
## Reading the current layout
```js
console.log("Layout: " + hs.keycodes.currentLayout())
console.log("Source ID: " + hs.keycodes.currentSourceID())
```
## Key code mapping
```js
// Look up a keycode by name
const code = hs.keycodes.map["a"]    // e.g. 0 on ANSI US
// Look up a name by keycode
const name = hs.keycodes.map["0"]   // e.g. "a"
```
## Switching layouts
```js
hs.keycodes.setLayout("British")
```
## Watching for input source changes
```js
hs.keycodes.addWatcher(() => {
    console.log("Switched to: " + hs.keycodes.currentLayout())
})
```
 */
declare namespace hs.keycodes {
    /**
     * Returns the localized name of the current keyboard layout.
Uses the base keyboard layout, which is the underlying layout even when an input
method (such as a CJK input method) is also active.
     * @returns The display name of the active layout (e.g. `"U.S."`, `"British"`), or `null`.
     */
    function currentLayout(): string | null;

    /**
     * Returns the localized name of the active input method, or `null` if none is active.
Input methods are distinct from keyboard layouts. They provide complex character
composition such as CJK input. Returns `null` when using a plain keyboard layout
with no input method overlay.
     * @returns The display name of the active input method (e.g. `"Hiragana"`), or `null`.
     */
    function currentMethod(): string | null;

    /**
     * Returns the reverse-DNS identifier of the currently selected keyboard input source.
     * @returns A string such as `"com.apple.keylayout.US"`, or `null` if unavailable.
     */
    function currentSourceID(): string | null;

    /**
     * Returns the localized names of all currently enabled keyboard layouts.
     * @returns An array of layout name strings (e.g. `["U.S.", "British", "French"]`).
     */
    function layouts(): string[];

    /**
     * Returns the localized names of all currently enabled input methods.
     * @returns An array of input method name strings. May be empty if none are enabled.
     */
    function methods(): string[];

    /**
     * Switches the active keyboard layout to the one with the given localized name.
Use `layouts()` to enumerate valid names.
     * @param layoutName The localized name of the layout to activate (e.g. `"U.S."`).
     * @returns `true` if the layout was found and selected, `false` otherwise.
     */
    function setLayout(layoutName: string): boolean;

    /**
     * Switches the active input method to the one with the given localized name.
Use `methods()` to enumerate valid names.
     * @param methodName The localized name of the input method to activate.
     * @returns `true` if the method was found and selected, `false` otherwise.
     */
    function setMethod(methodName: string): boolean;

    /**
     * Switches the active input source to the one with the given reverse-DNS identifier.
Use `currentSourceID()` to see the current value.
     * @param sourceID The input source ID to activate (e.g. `"com.apple.keylayout.British"`).
     * @returns `true` if the source was found and selected, `false` otherwise.
     */
    function setSourceID(sourceID: string): boolean;

    /**
     * Registers a listener that fires whenever the keyboard input source changes.
The listener is called with no arguments. Read `currentLayout()`, `currentSourceID()`,
or `map` inside the callback to inspect the new state.
The OS subscription starts lazily on the first listener and is released automatically
when the last listener is removed via `removeWatcher`.
     * @param listener A function called when the input source changes.
     */
    function addWatcher(listener: () => void): void;

    /**
     * Removes a previously registered input source change listener.
     * @param listener The function originally passed to `addWatcher`.
     */
    function removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * A bidirectional mapping between key names and their macOS virtual key codes.
Entries exist for both directions: look up a name to get its integer keycode, or look
up a keycode (as a string) to get the key name. The map is rebuilt automatically
whenever the keyboard input source changes.
     */
    const map: Record<string, any>;

}

/**
 * Determine the Mac's location via macOS Location Services.
Location data is obtained through WiFi network scanning and, where available, GPS
hardware. User permission is required — call `hs.permissions.requestLocation()`
before using any tracking features.
The module exposes a `geocoder` sub-object for forward/reverse geocoding without
requiring Location Services.
## locationTable
| Key | Type | Description |
|-----|------|-------------|
| `latitude` | number | Degrees north (positive) or south (negative) |
| `longitude` | number | Degrees east (positive) or west (negative) |
| `altitude` | number | Metres above sea level (`0` if unknown) |
| `horizontalAccuracy` | number | Uncertainty radius in metres (`-1` if invalid) |
| `verticalAccuracy` | number | Altitude accuracy in metres (`-1` if invalid) |
| `course` | number | Direction of travel in degrees (`-1` if invalid) |
| `speed` | number | Metres per second (`-1` if invalid) |
| `timestamp` | number | Seconds since the Unix epoch |
 */
declare namespace hs.location {
    /**
     * Geocodes an address string into an array of placemarkTables.
Returns a Promise that resolves with an array of placemarkTable objects
(sorted by relevance) or rejects with an error message.
     * @param address a free-form address string in any locale
     * @returns a Promise resolving to an array of placemarkTables
     */
    function lookupAddress(address: string): Promise<Record<string, any>[]>;

    /**
     * Reverse-geocodes a locationTable into an array of placemarkTables.
Returns a Promise that resolves with matching placemarks or rejects with
an error.
     * @param locationTable an object with at least `latitude` and `longitude`
     * @returns a Promise resolving to an array of placemarkTables
     */
    function lookupLocation(locationTable: Record<string, number>): Promise<Record<string, any>[]>;

    /**
     * Returns true if Location Services are enabled system-wide.
     * @returns true if enabled, false otherwise
     */
    function servicesEnabled(): boolean;

    /**
     * Returns the app's current Location Services authorization status as a string.
     * @returns `"authorized"`, `"denied"`, `"restricted"`, or `"notDetermined"`
     */
    function authorizationStatus(): string;

    /**
     * Returns the most recently cached location as a locationTable, or null.
Activates Location Services if not already running. The cache is updated
periodically while any watcher is running.
     * @returns a locationTable, or null if no cached location is available
     */
    function get(): Record<string, any> | null;

    /**
     * Calculates the straight-line distance in metres between two locationTables.
Does not require Location Services.
     * @param from locationTable with at least `latitude` and `longitude`
     * @param to locationTable with at least `latitude` and `longitude`
     * @returns distance in metres, or `-1` if either table is invalid
     */
    function distance(from: Record<string, number>, to: Record<string, number>): number;

    /**
     * Returns the time of sunrise for the given coordinates and date, or null if the sun does not rise on that date (polar night).
     * @param latitude degrees north (positive) or south (negative)
     * @param longitude degrees east (positive) or west (negative)
     * @param date the date to calculate for; pass null or omit to use today
     * @returns A Date object representing the time of sunrise, or null
     */
    function sunrise(latitude: number, longitude: number, date: Date | null): Date | null;

    /**
     * Returns the time of sunset for the given coordinates and date, or null if the sun does not set on that date (midnight sun).
     * @param latitude degrees north (positive) or south (negative)
     * @param longitude degrees east (positive) or west (negative)
     * @param date the date to calculate for; pass null or omit to use today
     * @returns A Date object representing the time of sunset, or null
     */
    function sunset(latitude: number, longitude: number, date: Date | null): Date | null;

    /**
     * Creates a new location watcher object. Call `.start()` on it to begin
receiving updates. The watcher is automatically stopped when the module
shuts down.
     * @returns an HSLocationWatcher
     */
    function addWatcher(): HSLocationWatcher;

    /**
     * Removes a previously created watcher and stops it if running.
     * @param watcher the watcher returned by `addWatcher()`
     */
    function removeWatcher(watcher: HSLocationWatcher): void;

}

/**
 * An independent location tracking object.
Create via `hs.location.addWatcher()`. Call `start()` to begin receiving
updates, and set a callback to handle them.
| Event | Data |
|-------|------|
| `"location"` | a locationTable |
| `"error"` | an error message string |
| `"authorizationChanged"` | the new status string (`"authorized"`, `"denied"`, `"restricted"`, `"notDetermined"`) |
 */
declare class HSLocationWatcher {
    /**
     * Starts location updates. The callback must be set first.
     * @returns self, for chaining
     */
    start(): HSLocationWatcher;

    /**
     * Stops location updates.
     * @returns self, for chaining
     */
    stop(): HSLocationWatcher;

    /**
     * Sets the callback function invoked when location events occur.
     * @param fn Called with the event name and associated data; see type documentation for event names
     * @returns self, for chaining
     */
    setCallback(fn: (event: string, data: Record<string, any>) => void): HSLocationWatcher;

    /**
     * Returns the most recently received location, or null if none yet.
     * @returns a locationTable, or null
     */
    location(): Record<string, any> | null;

    /**
     * The unique identifier assigned to this watcher.
     */
    readonly identifier: string;

    /**
     * The minimum distance in metres the device must move before a new update
is delivered. Defaults to `kCLDistanceFilterNone` (all movements reported).
     */
    distanceFilter: number;

}

/**
 * A single status item in the macOS menu bar, created via `hs.menubar.create()`.
Provides a builder-style API for setting an icon, title, click callback, and
querying the on-screen frame so callers can anchor a popover beneath it.
 */
declare namespace hs.menubar {
    /**
     * Create a new status item in the macOS menu bar.
     * @returns an `HSMenubarItem`. Chain `.setIcon(...)`, `.setTitle(...)`,
     */
    function create(): HSMenubarItem;

}

/**
 * A single status item in the macOS menu bar, created via `hs.menubar.create()`.
Provides a builder-style API for setting an icon, title, click callback, and
querying the on-screen frame so callers can anchor a popover beneath it.
 */
declare class HSMenubarItem {
    /**
     * Set the status-item title (e.g. a `mm:ss` countdown). Empty string clears it.
     * @param text the string to display
     * @param opts `{ color?: hex string, monospaced?: bool }` — both optional
     * @returns self for chaining
     */
    setTitle(text: string, opts: any): HSMenubarItem;

    /**
     * Set the status-item icon from an SF Symbol name.
When `color` is omitted the icon is a template (adapts to the menu bar).
     * @param symbolName an SF Symbol name (e.g. `'eye'`, `'eye.slash'`)
     * @param opts `{ pointSize?: number, color?: hex string, accessibilityLabel?: string }` — all optional.
     * @returns self for chaining
     */
    setIcon(symbolName: string, opts: any): HSMenubarItem;

    /**
     * Set the status-item image from a base64-encoded PNG.
     * @param base64PNG PNG bytes, base64-encoded (a leading `data:image/png;base64,` is tolerated)
     * @param opts `{ template?: bool }` — template images adapt to light/dark menu bars (default true)
     * @returns self for chaining
     */
    setImage(base64PNG: string, opts: any): HSMenubarItem;

    /**
     * Set the status-item image from an SVG document string. Rendered as a
template by default so macOS draws it adaptively (white on the dark menu
bar, black on light). Ideal for a vector glyph you regenerate over time
(e.g. a progress ring).
     * @param svg an SVG document string (should include an `xmlns`)
     * @param opts `{ template?: bool, size?: number }` — template defaults true, size defaults 18 (pt)
     * @returns self for chaining
     */
    setSVG(svg: string, opts: any): HSMenubarItem;

    /**
     * Register a function called (with no arguments) when the item is clicked.
     * @param fn a JavaScript function
     * @returns self for chaining
     */
    setCallback(fn: any): HSMenubarItem;

    /**
     * Highlight (or un-highlight) the status-item button background.
     * @param on whether to draw the highlighted background
     * @returns self for chaining
     */
    highlight(on: boolean): HSMenubarItem;

    /**
     * The on-screen rect of the status-item button as `{x, y, w, h}`, in
NSWindow (bottom-left origin) coordinates — the same convention as
`hs.webview` `currentFrame()`/`setFrame()`, so a webview can be anchored
to it. Returns null if the item has no realized on-screen button.
     * @returns `{x, y, w, h}` or null
     */
    frame(): Record<string, number> | null;

    /**
     * Remove the status item from the menu bar.
     */
    remove(): void;

}

/**
 * Module for controlling the mouse cursor
 */
declare namespace hs.mouse {
    /**
     * The current mouse cursor position in global screen coordinates (top-left origin, points).
Coordinates match `hs.screen` convention: `(0,0)` is the top-left of the primary
display and `y` increases downward.
     * @returns An object `{ x, y }`.
     */
    function position(): Record<string, number>;

    /**
     * Move (warp) the cursor to a global screen position (top-left origin).
Coordinates use the same convention as `hs.screen`: `(0,0)` is the top-left of
the primary display.
     * @param point An object `{ x, y }`.
     * @returns true.
     */
    function setPosition(point: Record<string, number>): boolean;

    /**
     * Hide the system mouse cursor.
     * @returns true on success.
     */
    function hideCursor(): boolean;

    /**
     * Show the system mouse cursor.
     * @returns true on success.
     */
    function showCursor(): boolean;

    /**
     * Connect or disconnect physical mouse movement from the on-screen cursor.
Pass `false` to decouple movement from the cursor position (useful for
relative-delta capture, e.g. seamless hand-off to a remote machine).
     * @param connected false to decouple movement from the cursor.
     * @returns true.
     */
    function setAssociated(connected: boolean): boolean;

}

/**
 * Module providing a best-effort MultipeerConnectivity data link.
This is the CrossMac **data plane** (bulk clipboard / images) — the reliable
**control plane** rides the ESP32 relay (`hs.serial` / `hs.ble`), never this.
`MCSession` runs over AWDL / peer-to-peer Wi-Fi / infrastructure, so no shared
router is required. Discovery uses Bonjour, so `NSBonjourServices` and
`NSLocalNetworkUsageDescription` must be present in Info.plist.
Recovery *policy* (when to `reset()`) lives in JavaScript; this module only
exposes honest peer events plus `start` / `stop` / `reset`.
 */
declare namespace hs.multipeer {
    /**
     * Create a Multipeer session.
`serviceType` defaults to `"voicekb-cs"` (≤15 chars, `[a-z0-9-]`);
`displayName` defaults to this host's name; `context` (the shared invite
secret both peers must match) defaults to `"voicekb-mpc-v1"`;
`encryption` is `"required"` (default), `"optional"`, or `"none"`.
`allowPeers` (optional `[String]`) restricts pairing to peers whose displayName
begins with one of these prefixes — others sharing the service+context are ignored.
     * @param config `{ serviceType?, displayName?, context?, encryption?, allowPeers? }`.
     * @returns an `HSMPCSession` (call `start()` to begin advertising + browsing).
     */
    function session(config: Record<string, any>): HSMPCSession;

}

/**
 * A MultipeerConnectivity session — the CrossMac data plane.
Obtain via `hs.multipeer.session(...)`. Call `start()` to advertise + browse;
both peers advertise and browse, and whichever sees the other first invites,
authenticated by the shared `context` string. Payloads cross the JS bridge as
base64 strings (pairs with `HSImage.encode`).
 */
declare class HSMPCSession {
    /**
     * Start advertising and browsing for peers.
     */
    start(): void;

    /**
     * Stop advertising/browsing and disconnect the session.
     */
    stop(): void;

    /**
     * Tear down and recreate the underlying session/advertiser/browser, then
resume if it was started. The JS watchdog calls this to clear a wedged
AWDL/MPC state.
     */
    reset(): void;

    /**
     * Register a callback for peer connection-state changes.
     * @param cb `function(peerName, state)` — state is `"connected"`, `"connecting"`, or `"disconnected"`.
     * @returns self, for chaining.
     */
    onPeer(cb: any): HSMPCSession;

    /**
     * Register a callback for received payloads.
     * @param cb `function(base64, peerName)` — `base64` is the received bytes, base64-encoded.
     * @returns self, for chaining.
     */
    onReceive(cb: any): HSMPCSession;

    /**
     * Send a payload to all connected peers.
     * @param base64 the payload bytes, base64-encoded.
     * @param opts `{ reliable }` — `reliable` defaults to `true`.
     * @returns `true` if sent to at least one peer; `false` if there are no peers, the base64 is invalid, or send failed.
     */
    send(base64: string, opts: any): boolean;

    /**
     * The display names of all currently connected peers.
     */
    readonly peers: string[];

}

/**
 * Module for creating and displaying macOS system notifications.
macOS notifications require user permission before they will appear. Request it once
(typically at startup) via `hs.permissions.requestNotifications()` and it will be
```js
hs.permissions.requestNotifications().then(granted => {
    if (granted) hs.notify.show("Hammerspoon", "Notifications are enabled!")
})
```
## Quick notification
```js
// Fire and forget
hs.notify.show("Build complete", "Your project compiled successfully.")

// With a callback invoked when the user interacts
hs.notify.show("Build complete", "Click to view the log.", (response) => {
    console.log("User tapped:", response.actionIdentifier)
})
```
## Rich notification
```js
const n = hs.notify.create({
    title:    "New message",
    subtitle: "From Alice",
    body:     "Are you free tonight?",
    sound:    true,
    threadIdentifier: "messages-alice",
    actions: [
        { identifier: "REPLY", title: "Reply", textInput: true,
          textInputButtonTitle: "Send", textInputPlaceholder: "Type a reply…" },
        { identifier: "DISMISS", title: "Dismiss", destructive: true }
    ],
    callback: (response) => {
        if (response.actionIdentifier === "REPLY") {
            console.log("Reply text:", response.userText)
        }
    }
})
n.send()
// Later, if needed:
n.withdraw()
```
## Callback response object
| Property | Type | Description |
|----------|------|-------------|
| `actionIdentifier` | string | `"DEFAULT"` when the user tapped the notification body; `"DISMISS"` when dismissed (if `.customDismissAction` is set); otherwise the action's `identifier` string |
| `userText` | string? | Text entered in a `textInput` action; only present when applicable |
| `userInfo` | object | The `userInfo` object originally passed to `create()`, if any |
| `notificationId` | string | The notification's unique identifier |
## Options for `create()`
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `title` | string | *(required)* | The bold heading line |
| `subtitle` | string | — | A second line shown beneath the title |
| `body` | string | — | The main message body |
| `sound` | boolean \| string | `true` | `true` = default sound, `false` = no sound, string = named `.aiff` file |
| `badge` | number | — | Value to show on the app icon badge |
| `threadIdentifier` | string | — | Groups related notifications visually in Notification Center |
| `userInfo` | object | `{}` | Arbitrary payload passed back to the callback |
| `interruptionLevel` | string | `"active"` | `"passive"`, `"active"`, or `"timeSensitive"` — controls Focus/DND behaviour (macOS 12+) |
| `trigger` | object | — | When to deliver the notification (see below). Omit for immediate delivery. |
| `actions` | array | — | Action buttons (see below) |
| `callback` | function | — | Invoked when the user interacts with the notification |
## Triggers
Pass a `trigger` object in `create()`'s options to schedule the notification instead of delivering it
```js
trigger: { type: "timeInterval", interval: 300 }
```
**Calendar** — deliver at a specific date/time. Provide either a JS `Date` object or individual
```js
// At a specific moment
trigger: { type: "calendar", date: new Date("2026-06-01T09:00:00") }

// At 09:00 on the next day that matches (e.g. next Monday, weekday 2)
trigger: { type: "calendar", weekday: 2, hour: 9, minute: 0 }
```
Supported component keys: `year`, `month`, `day`, `hour`, `minute`, `second`, `weekday`.
## Action objects
| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `identifier` | string | *(required)* | Unique identifier passed to the callback |
| `title` | string | *(required)* | Button label |
| `destructive` | boolean | `false` | Renders the title in a destructive (red) style |
| `foreground` | boolean | `false` | Brings Hammerspoon to the foreground when tapped |
| `textInput` | boolean | `false` | Converts this action to an inline text-reply button |
| `textInputButtonTitle` | string | `"Send"` | Label on the reply send button (requires `textInput: true`) |
| `textInputPlaceholder` | string | `""` | Placeholder shown in the text field (requires `textInput: true`) |
 */
declare namespace hs.notify {
    /**
     * Display a notification immediately.
     * @param title The notification title
     * @param body The notification body text
     * @param callback Optional function called when the user taps the notification. Receives a response object (see module docs for shape).
     */
    function show(title: string, body: string, callback: (response: Record<string, any>) => void): void;

    /**
     * Create a richly configured notification without sending it yet.
     * @param options A JavaScript object — see module documentation for supported keys.
     * @returns An `HSNotification` object. Call `.send()` on it to deliver the notification.
     */
    function create(options: Record<string, any>): HSNotification | null;

    /**
     * Remove all delivered Hammerspoon notifications from Notification Center.
     */
    function removeAllDelivered(): void;

    /**
     * Cancel all pending (not yet delivered) Hammerspoon notifications.
     */
    function removeAllPending(): void;

}

/**
 * A notification created by `hs.notify.new()`.
Call `.send()` to deliver it to macOS Notification Center. You can hold a reference
to the object and call `.withdraw()` later to remove it.
 */
declare class HSNotification {
    /**
     * Deliver this notification immediately to Notification Center.
     * @returns self, for method chaining
     */
    send(): HSNotification;

    /**
     * Remove this notification from Notification Center (if delivered) or cancel it (if pending).
     */
    withdraw(): void;

    /**
     * The unique identifier assigned to this notification.
Use it to correlate with system notification APIs if needed.
     */
    readonly identifier: string;

}

/**
 * Recognize text in images using Apple's Vision framework.
`hs.ocr` provides access to on-device text recognition without requiring
network access or any third-party dependencies. Pass a file path to
`recognizeText()` and receive back an `HSOCRResult` containing the full
recognized text and individual per-region observations with confidence
scores and normalized bounding boxes.
 */
declare namespace hs.ocr {
    /**
     * Recognize text in the image at the given file path.
Returns a Promise that resolves with an `HSOCRResult` containing all
recognized text and per-region observations. The image must exist on
disk; URLs and data buffers are not supported.
Recognition is performed on a background thread; the main thread is
not blocked during the operation.
`"accurate"` uses a larger neural network for better results;
`"fast"` trades accuracy for speed.
Observations whose `confidence` is below this threshold are excluded
from `result.observations` (and therefore from `result.text`).
Hints Vision toward specific languages. Use `supportedLanguages()` to
enumerate the available codes for the current device.
When `true`, Vision selects recognition languages automatically.
Overrides `languages` when set.
     * @param path Absolute path to the image file.
     * @param options Optional configuration object (see description).
     * @returns Resolves with the recognition result.
     */
    function recognizeText(path: string, options: Record<string, any> | null): Promise<HSOCRResult>;

    /**
     * Returns the BCP-47 language codes supported by the Vision text recognizer
on this device.
The set of languages varies between macOS versions and hardware. Call
this at runtime to discover which codes are valid for the `languages`
option passed to `recognizeText()`.
     * @returns An array of BCP-47 language code strings (e.g. `["en-US", "fr-FR"]`).
     */
    function supportedLanguages(): string[];

}

/**
 * A single region of text recognized in an image.
Instances are delivered inside the `observations` array of an `HSOCRResult`.
Each observation represents a discrete text run found in the source image,
along with a confidence score and a normalized bounding box.
`(0, 0)` is the top-left corner of the image and `(1, 1)` is the bottom-right.
This matches the convention used by most image-processing tools and differs
from Vision's internal bottom-left-origin system (the conversion is automatic).
 */
declare class HSOCRObservation {
    /**
     * The Swift type name, for JavaScript introspection.
     */
    readonly typeName: string;

    /**
     * The recognized text string for this observation.
     */
    readonly text: string;

    /**
     * Recognition confidence in the range `0.0` (uncertain) to `1.0` (certain).
Use `minimumConfidence` in the options passed to `recognizeText()` to
pre-filter observations below a threshold rather than filtering here.
     */
    readonly confidence: number;

    /**
     * Normalized bounding box of this observation in the source image, as an `HSRect`.
All values are in the range 0–1 with **top-left origin**
(`(0, 0)` = top-left corner, `(1, 1)` = bottom-right corner).
Use `bounds.x`, `bounds.y`, `bounds.w`, and `bounds.h` to access the components.
     */
    readonly bounds: HSRect;

}

/**
 * The result of a text recognition operation on an image.
An `HSOCRResult` is returned by `hs.ocr.recognizeText()` and bundles the
full recognized text together with an array of per-region observations,
each carrying its own confidence score and bounding box.
 */
declare class HSOCRResult {
    /**
     * The Swift type name, for JavaScript introspection.
     */
    readonly typeName: string;

    /**
     * The full recognized text from the image, with each observation's text
joined by newlines in the order Vision returned them.
Use this when you only need the raw text and don't care about bounding
boxes or per-region confidence scores.
     */
    readonly text: string;

    /**
     * The individual text observations that make up this result.
Each entry in the array is an `HSOCRObservation` with its own `text`,
`confidence`, and `bounds` properties. Observations are returned in the
order Vision produced them (typically top-to-bottom, left-to-right, but
this is image-dependent).
     */
    readonly observations: HSOCRObservation[];

}

/**
 * Run AppleScript and OSA JavaScript from Hammerspoon scripts.
Script execution is isolated in a separate XPC helper process
(`HammerspoonOSAScriptHelper`). If a script crashes or deadlocks, only the
helper is affected — the main app remains stable and the next call
reconnects automatically.
## Async API (Promise-based)
Every async function returns a `Promise` that **always resolves** (never rejects)
| Field | Type | Description |
|-------|------|-------------|
| `success` | `Boolean` | `true` if the script ran without error |
| `result` | `any` | Parsed return value of the script, or `null` on failure |
| `raw` | `String` | Raw string representation of the result, or the error message on failure |
## Sync API
The `*Sync` variants block until the script completes and return the same
`{ success, result, raw }` object directly.  Use these only when a Promise
chain is impractical; they block the JS thread for the duration of the call.
The `result` field is typed based on what the script returned: strings,
numbers, booleans, lists, and records are all mapped to their JavaScript
equivalents. `null` is used for AppleScript's `missing value` and for any
failure case.
## Examples
**Return a string (async):**
```javascript
hs.osascript.applescript('return "hello"')
  .then(r => console.log(r.result));  // "hello"
```
**Return a string (sync):**
```javascript
const r = hs.osascript.applescriptSync('return "hello"');
console.log(r.result);  // "hello"
```
**Interact with an application:**
```javascript
hs.osascript.applescript('tell application "Finder" to get name of home')
  .then(r => console.log(r.result));  // e.g. "cmsj"
```
**Handle errors (the Promise never rejects — check `success`):**
```javascript
hs.osascript.applescript('this is not valid')
  .then(r => {
    if (!r.success) console.log("Error:", r.raw);
  });
```
**OSA JavaScript:**
```javascript
hs.osascript.javascript('Application("Finder").name()')
  .then(r => console.log(r.result));  // "Finder"
```
**Run a script from a file:**
```javascript
hs.osascript.applescriptFromFile('/Users/me/scripts/notify.applescript')
  .then(r => console.log(r.success));
```
 */
declare namespace hs.osascript {
    /**
     * Run an AppleScript source string.
     * @param source The AppleScript source code to compile and execute.
     * @returns A `Promise` resolving to `{ success, result, raw }`.
     */
    function applescript(source: string): Promise<any>;

    /**
     * Run an OSA JavaScript source string.
OSA JavaScript is Apple's Open Scripting Architecture dialect of
JavaScript, distinct from the JavaScriptCore engine that runs
Hammerspoon scripts themselves.
     * @param source The OSA JavaScript source code to compile and execute.
     * @returns A `Promise` resolving to `{ success, result, raw }`.
     */
    function javascript(source: string): Promise<any>;

    /**
     * Read a file from disk and execute its contents as AppleScript.
The file is read in the main process before being sent to the XPC
helper. If the file cannot be read the promise resolves immediately
with `{ success: false, result: null, raw: "Failed to read file: <path>" }`.
     * @param path Absolute path to the AppleScript source file.
     * @returns A `Promise` resolving to `{ success, result, raw }`.
     */
    function applescriptFromFile(path: string): Promise<any>;

    /**
     * Read a file from disk and execute its contents as OSA JavaScript.
The file is read in the main process before being sent to the XPC
helper. If the file cannot be read the promise resolves immediately
with `{ success: false, result: null, raw: "Failed to read file: <path>" }`.
     * @param path Absolute path to the OSA JavaScript source file.
     * @returns A `Promise` resolving to `{ success, result, raw }`.
     */
    function javascriptFromFile(path: string): Promise<any>;

    /**
     * Low-level execution entry point used by the higher-level helpers.
Prefer `applescript()` or `javascript()` over calling this directly.
     * @param source The script source code.
     * @param language The OSA language name — must be `"AppleScript"` or `"JavaScript"`.
     * @returns A `Promise` resolving to `{ success, result, raw }`.
     */
    function _execute(source: string, language: string): Promise<any>;

    /**
     * Run an AppleScript source string synchronously.
Blocks the JS thread until the script completes.
     * @param source The AppleScript source code to compile and execute.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function applescriptSync(source: string): Record<string, any> | null;

    /**
     * Run an OSA JavaScript source string synchronously.
Blocks the JS thread until the script completes.
     * @param source The OSA JavaScript source code to compile and execute.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function javascriptSync(source: string): Record<string, any> | null;

    /**
     * Read a file from disk and execute its contents as AppleScript synchronously.
     * @param path Absolute path to the AppleScript source file.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function applescriptSyncFromFile(path: string): Record<string, any> | null;

    /**
     * Read a file from disk and execute its contents as OSA JavaScript synchronously.
     * @param path Absolute path to the OSA JavaScript source file.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function javascriptSyncFromFile(path: string): Record<string, any> | null;

    /**
     * Low-level synchronous execution entry point.
Prefer `applescriptSync()` or `javascriptSync()` over calling this directly.
     * @param source The script source code.
     * @param language The OSA language name — must be `"AppleScript"` or `"JavaScript"`.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function _executeSync(source: string, language: string): Record<string, any> | null;

}

/**
 * Module for interacting with the macOS pasteboard (clipboard)
The macOS pasteboard is "rich" — a single clipboard operation can carry multiple representations
of the same content for different applications to consume. For example, text copied from a web
browser may carry plain text, HTML, and RTF representations simultaneously.
## Basic Usage
```js
// Read and write plain text
const text = hs.pasteboard.readString()
hs.pasteboard.writeString("Hello from Hammerspoon!")

// Check what types are currently on the pasteboard
const available = hs.pasteboard.types()

// Write multiple representations at once
hs.pasteboard.writeObjects({
    "public.utf8-plain-text": "Hello",
    "public.html": "<b>Hello</b>"
})

// Watch for pasteboard changes
const handler = (changeCount) => {
    console.log("Pasteboard changed, count:", changeCount)
    console.log("New text:", hs.pasteboard.readString())
}
hs.pasteboard.addWatcher(handler)
// Later: hs.pasteboard.removeWatcher(handler)
```
## Pasteboard Conventions (nspasteboard.org)
macOS has no built-in notification API for transient or confidential clipboard content, so a
community convention has emerged (see [nspasteboard.org](https://nspasteboard.org)) around four
`org.nspasteboard.*` UTI marker types. These markers carry no payload — their mere presence on
the pasteboard signals intent to other applications.
### Standard marker UTIs
| UTI | Meaning |
|-----|---------|
| `org.nspasteboard.TransientType` | Content is temporary; it will be removed or overwritten shortly. Clipboard historians should **not** record this change. |
| `org.nspasteboard.ConcealedType` | Content is sensitive (e.g. a password). Historians should obfuscate it if displayed and ideally encrypt it if stored. |
| `org.nspasteboard.AutoGeneratedType` | Content was placed by an application without any user Copy action. Historians should generally skip recording it. |
| `org.nspasteboard.source` | The bundle identifier of the application that placed the content. Use an empty string when the source is unknown. |
### Legacy proprietary markers
Several apps defined their own markers before the `org.nspasteboard.*` standard existed.
| UTI | Application |
|-----|-------------|
| `de.petermaurer.TransientPasteboardType` | TextExpander, Butler |
| `com.typeit4me.clipping` | TypeIt4Me |
| `Pasteboard generator type` | Typinator |
| `com.agilebits.onepassword` | 1Password (confidential) |
| `com.apple.is-remote-clipboard` | macOS (remote content) |
### For scripts that write to the pasteboard
If your script temporarily commandeers the pasteboard (e.g. to trigger a paste), add
```js
hs.pasteboard.writeObjects({
    "public.utf8-plain-text": "temporary value",
    "org.nspasteboard.TransientType": ""
})
```
```js
hs.pasteboard.writeObjects({
    "public.utf8-plain-text": "s3cr3t!",
    "org.nspasteboard.ConcealedType": ""
})
```
### For scripts that monitor the pasteboard
If you are building a clipboard history tool with `addWatcher`, skip or obfuscate entries that
```js
const SKIP_TYPES = [
    "org.nspasteboard.TransientType",
    "org.nspasteboard.AutoGeneratedType",
    "de.petermaurer.TransientPasteboardType",
    "com.typeit4me.clipping",
    "Pasteboard generator type",
]
const CONCEAL_TYPES = [
    "org.nspasteboard.ConcealedType",
    "com.agilebits.onepassword",
]

hs.pasteboard.addWatcher((changeCount) => {
    const types = hs.pasteboard.types()
    if (SKIP_TYPES.some(t => types.includes(t))) return        // ignore transient
    const conceal = CONCEAL_TYPES.some(t => types.includes(t)) // handle sensitively
    // … record or display the pasteboard contents …
})
```
 */
declare namespace hs.pasteboard {
    /**
     * Read plain text from the pasteboard
     * @returns The plain text string, or null if not available
     */
    function readString(): string | null;

    /**
     * Read HTML from the pasteboard
     * @returns The HTML string, or null if not available
     */
    function readHTML(): string | null;

    /**
     * Read RTF from the pasteboard
     * @returns The RTF string, or null if not available
     */
    function readRTF(): string | null;

    /**
     * Read a URL from the pasteboard
     * @returns The URL as a string, or null if not available
     */
    function readURL(): string | null;

    /**
     * Read an image from the pasteboard
     * @returns An HSImage, or null if not available
     */
    function readImage(): HSImage | null;

    /**
     * Read raw data for a specific UTI type, returned as a base64-encoded string.
Use this for types not covered by the convenience read methods.
     * @param uti A UTI type string (e.g. "com.adobe.pdf")
     * @returns A base64-encoded string, or null if the type is not available
     */
    function readData(uti: string): string | null;

    /**
     * Write plain text to the pasteboard, replacing all current contents
     * @param str The text string to write
     * @returns true if the write succeeded
     */
    function writeString(str: string): boolean;

    /**
     * Write HTML to the pasteboard, replacing all current contents
     * @param html The HTML string to write
     * @returns true if the write succeeded
     */
    function writeHTML(html: string): boolean;

    /**
     * Write RTF to the pasteboard, replacing all current contents
     * @param rtf The RTF string to write
     * @returns true if the write succeeded
     */
    function writeRTF(rtf: string): boolean;

    /**
     * Write a URL to the pasteboard, replacing all current contents
     * @param url The URL string to write
     * @returns true if the write succeeded
     */
    function writeURL(url: string): boolean;

    /**
     * Write an image to the pasteboard, replacing all current contents
     * @param image An HSImage to write
     * @returns true if the write succeeded
     */
    function writeImage(image: HSImage): boolean;

    /**
     * Write raw base64-encoded data for a specific UTI type, replacing all current contents.
Use this for types not covered by the convenience write methods.
     * @param base64 The data encoded as a base64 string
     * @param uti A UTI type string (e.g. "com.adobe.pdf")
     * @returns true if the write succeeded
     */
    function writeData(base64: string, uti: string): boolean;

    /**
     * Write multiple type representations to the pasteboard atomically, replacing all current contents.
Keys must be UTI type strings; values must be strings. This is how you provide both a plain-text
fallback and a richer representation (such as HTML) in a single clipboard operation.
     * @param representations A JavaScript object whose keys are UTI strings and values are strings
     * @returns true if the write succeeded
     */
    function writeObjects(representations: Record<string, any>): boolean;

    /**
     * Get all UTI type strings currently on the pasteboard, across all items
     * @returns An array of UTI strings (e.g. ["public.utf8-plain-text", "public.html"])
     */
    function types(): string[];

    /**
     * Check whether a specific UTI type is currently available on the pasteboard
     * @param uti A UTI type string to check for
     * @returns true if the type is available
     */
    function hasType(uti: string): boolean;

    /**
     * Clear all contents from the pasteboard
     */
    function clear(): void;

    /**
     * Add a watcher that is called whenever the pasteboard contents change.
Multiple watchers may be registered; they are each called independently.
Because macOS provides no pasteboard change notification API, this is implemented
by polling `changeCount` at the interval specified by `watcherInterval`.
     * @param listener A function called with the new `changeCount` integer whenever the pasteboard changes
     */
    function addWatcher(listener: (changeCount: number) => void): void;

    /**
     * Remove a previously registered pasteboard watcher
     * @param listener The function previously passed to `addWatcher`
     */
    function removeWatcher(listener: (...args: any[]) => any): void;

    /**
     * The pasteboard change count. Increments each time any application writes to the pasteboard.
Comparing a saved value to the current value is the standard way to detect external changes.
     */
    const changeCount: number;

    /**
     * The polling interval for the pasteboard watcher, in seconds. Defaults to 0.5.
Changes take effect the next time a watcher is started (i.e. after removing and re-adding).
     */
    let watcherInterval: number;

}

/**
 * Module for checking and requesting system permissions
 */
declare namespace hs.permissions {
    /**
     * Check if the app has Accessibility permission
     * @returns true if permission is granted, false otherwise
     */
    function checkAccessibility(): boolean;

    /**
     * Request Accessibility permission (shows system dialog if not granted)
     */
    function requestAccessibility(): void;

    /**
     * Check if the app has Screen Recording permission
     * @returns true if permission is granted, false otherwise
     */
    function checkScreenRecording(): boolean;

    /**
     * Request Screen Recording permission
     * @remarks This will trigger a screen capture which prompts the system dialog
     */
    function requestScreenRecording(): void;

    /**
     * Check if the app has Camera permission
     * @returns true if permission is granted, false otherwise
     */
    function checkCamera(): boolean;

    /**
     * Request Camera permission (shows system dialog if not granted)
     * @returns A Promise that resolves to true if granted, false if denied
     */
    function requestCamera(): Promise<boolean>;

    /**
     * Check if the app has Microphone permission
     * @returns true if permission is granted, false otherwise
     */
    function checkMicrophone(): boolean;

    /**
     * Request Microphone permission (shows system dialog if not granted)
     * @returns A Promise that resolves to true if granted, false if denied
     */
    function requestMicrophone(): Promise<boolean>;

    /**
     * Check if the app has permission to display notifications.
The result is cached from the last request or check; the cache is refreshed asynchronously,
so the very first call in a session may return `false` before the cached value is populated.
Use `requestNotifications()` on first launch to ensure the result is accurate.
     * @returns true if notification permission is granted
     */
    function checkNotifications(): boolean;

    /**
     * Request notification permission (shows the system dialog if the user has not yet decided).
It is safe to call this on every launch — the dialog only appears once; subsequent calls
resolve immediately with the previously granted or denied state.
     * @returns A Promise that resolves to true if granted, false if denied
     */
    function requestNotifications(): Promise<boolean>;

    /**
     * Check if the app has Location permission.
     * @returns true if permission is granted, false otherwise
     */
    function checkLocation(): boolean;

    /**
     * Request Location permission (shows the system dialog if the user has not yet decided).
     * @returns A Promise that resolves to true if granted, false if denied
     */
    function requestLocation(): Promise<boolean>;

    /**
     * Check whether the app has full Calendar access.
     * @returns true if full Calendar access is granted, false otherwise
     */
    function checkCalendar(): boolean;

    /**
     * Request full Calendar access (shows the system dialog if the user has not yet decided).
It is safe to call this on every launch — macOS only shows the dialog once for this scope;
subsequent calls resolve with the durable authorization state.
     * @returns A Promise that resolves to true if full access is granted, false otherwise
     */
    function requestCalendar(): Promise<boolean>;

    /**
     * Check whether the app has full Reminders access.
     * @returns true if full Reminders access is granted, false otherwise
     */
    function checkReminders(): boolean;

    /**
     * Request full Reminders access (shows its independent system dialog if the user has not yet decided).
It is safe to call this on every launch — macOS only shows the dialog once for this scope;
subsequent calls resolve with the durable authorization state.
     * @returns A Promise that resolves to true if full access is granted, false otherwise
     */
    function requestReminders(): Promise<boolean>;

    /**
     * Check whether the user has granted Input Monitoring access to this app.
Required for hs.eventtap to receive global key events.
     * @returns true if granted, false if denied or unknown
     */
    function checkInputMonitoring(): boolean;

    /**
     * Trigger the macOS Input Monitoring permission prompt.
     */
    function requestInputMonitoring(): void;

}

/**
 * Monitor and control system power: prevent sleep, read battery state, respond to
power events, and lock or sleep the machine.
## Preventing sleep
```js
// Prevent the display from sleeping while a task runs
hs.power.preventSleep("display")
// ... do work ...
hs.power.allowSleep("display")
```
## Watching for system events
```js
hs.power.addEventWatcher(event => {
    if (event === "screensDidLock") console.log("Screen locked!")
})
```
## Reading battery state
```js
const info = hs.power.batteryInfo()
if (info) {
    console.log(`Battery: ${info.percentage}%, ${info.timeRemaining} minutes remaining`)
}
```
 */
declare namespace hs.power {
    /**
     * Prevents the specified type of system sleep.
Creates an IOKit power assertion that stops macOS from allowing the specified
type of sleep. Call `allowSleep` with the same type to release the assertion.
idle sleep), `"systemIdle"` (prevent system idle sleep), `"system"` (prevent
all system sleep, including from power button or lid close).
     * @param type The sleep type to prevent. One of: `"display"` (prevent display
     * @returns `true` if the assertion was created successfully.
     */
    function preventSleep(type: string): boolean;

    /**
     * Releases a previously created sleep prevention assertion.
     * @param type The sleep type to allow again. One of: `"display"`, `"systemIdle"`, `"system"`.
     * @returns `true` if an assertion existed and was released, `false` if none was active.
     */
    function allowSleep(type: string): boolean;

    /**
     * Returns whether Hammerspoon is currently preventing the specified type of sleep.
     * @param type The sleep type to check. One of: `"display"`, `"systemIdle"`, `"system"`.
     * @returns `true` if this sleep type is currently being prevented.
     */
    function isSleepPrevented(type: string): boolean;

    /**
     * Simulates user activity, briefly resetting the display idle timer.
Equivalent to moving the mouse — does not create a persistent assertion.
     */
    function declareActivity(): void;

    /**
     * Returns the active power management assertions from all processes on the system.
     * @returns An array of objects with `pid` (number), `name` (string), and `type` (string) properties.
     */
    function currentAssertions(): Record<string, any>[];

    /**
     * Puts the system to sleep immediately.
Requires the Automation permission for System Events.
     */
    function systemSleep(): void;

    /**
     * Locks the screen immediately.
     */
    function lockScreen(): void;

    /**
     * Starts the screensaver immediately.
     */
    function startScreensaver(): void;

    /**
     * Returns a snapshot of all available battery information, or `null` if no battery is present.
     * @returns An object with battery fields, or `null` if no battery is present.
     */
    function batteryInfo(): Record<string, any> | null;

    /**
     * Registers a listener that fires when system power events occur.
`"screensDidSleep"`, `"screensDidWake"`, `"screensDidLock"`, `"screensDidUnlock"`,
`"screensaverDidStart"`, `"screensaverDidStop"`, `"screensaverWillStop"`,
`"systemWillSleep"`, `"systemDidWake"`, `"systemWillPowerOff"`,
`"sessionDidBecomeActive"`, `"sessionDidResignActive"`.
The OS notification subscription starts lazily on the first listener and
is released automatically when the last listener is removed.
     * @param listener A function called with the power event name string.
     */
    function addEventWatcher(listener: (eventName: string) => void): void;

    /**
     * Removes a previously registered power event listener.
     * @param listener The function originally passed to `addEventWatcher`.
     */
    function removeEventWatcher(listener: (...args: any[]) => any): void;

    /**
     * Registers a listener that fires whenever battery state changes.
The listener receives no arguments; call `batteryInfo()` or read individual
properties inside the callback to determine what changed.
The OS notification subscription starts lazily on the first listener and
is released automatically when the last listener is removed.
     * @param listener A function called with no arguments on battery state change.
     */
    function addBatteryWatcher(listener: () => void): void;

    /**
     * Removes a previously registered battery change listener.
     * @param listener The function originally passed to `addBatteryWatcher`.
     */
    function removeBatteryWatcher(listener: (...args: any[]) => any): void;

    /**
     * The current battery charge percentage (0–100), or `-1` if no battery is present.
     */
    const percentage: number;

    /**
     * Whether the battery is currently charging.
Returns `false` when no battery is present.
     */
    const isCharging: boolean;

    /**
     * The current power source.
Returns `"ac"` when plugged in, `"battery"` when on battery power, `"ups"` when
powered by a UPS, or `"unknown"` if the source cannot be determined.
     */
    const powerSource: string;

    /**
     * Whether Low Power Mode is currently active.
     */
    const isLowPowerMode: boolean;

    /**
     * The current thermal state of the system.
Returns one of: `"nominal"`, `"fair"`, `"serious"`, `"critical"`.
     */
    const thermalState: string;

}

/**
 * Module for accessing Reminders.
 */
declare namespace hs.reminders {
    /**
     * Return the app's current Reminders authorization status.
     * @returns One of `fullAccess`, `denied`, `restricted`, or `notDetermined`
     */
    function authorizationStatus(): string;

    /**
     * List the Reminder Lists available for Reminders.
     * @returns Reminder List summaries containing `id`, `title`, `writable`, and `isDefault`
     */
    function listReminderLists(): Record<string, any>[];

    /**
     * List Reminders in a Reminder List, filtered by completion state.
     * @param list A Reminder List id or exact title. Omit it to use the default Reminder List.
     * @param completed `true` for completed Reminders or `false` for incomplete Reminders. Defaults to `false`.
     * @returns A Promise resolving to Reminder summaries
     */
    function listReminders(list?: string, completed?: boolean): Promise<object[]>;

    /**
     * Create a Reminder.
     * @param options An object containing the Reminder fields
     * @returns The created Reminder summary, or `null` after throwing a JavaScript error
     */
    function createReminder(options: {list?: string; title: string; due?: string; priority?: 'none' | 'low' | 'medium' | 'high'; notes?: string}): Record<string, any> | null;

    /**
     * Mark a Reminder complete.
     * @param id The Reminder's stable identifier
     * @returns The completed Reminder summary, or `null` after throwing a JavaScript error
     */
    function completeReminder(id: string): Record<string, any> | null;

    /**
     * Delete a Reminder.
     * @param id The Reminder's stable identifier
     * @returns `true` when the Reminder was deleted, or `false` after throwing a JavaScript error
     */
    function deleteReminder(id: string): boolean;

}

/**
 * Inspect and control the displays attached to the system.
## Obtaining screens
```javascript
const all    = hs.screen.all();   // [HSScreen, ...]
const main   = hs.screen.main();   // screen containing the focused window
const primary = hs.screen.primary(); // screen with the global menu bar
```
## Navigation
```javascript
const right = hs.screen.main().toEast();
if (right) console.log("Screen to the right:", right.name);
```
## Display modes
```javascript
const s = hs.screen.primary();
console.log(s.mode);
// → { width: 1440, height: 900, scale: 2, frequency: 60 }

s.setMode(1920, 1080, 1, 60);
```
## Screenshots
```javascript
const img = await hs.screen.main().snapshot();
img.saveToFile("/tmp/screen.png");
```
 */
declare namespace hs.screen {
    /**
     * All connected screens.
     * @returns An array of HSScreen objects
     */
    function all(): HSScreen[];

    /**
     * The screen that currently contains the focused window, or the screen
with the keyboard focus if no window is focused.
     * @returns An HSScreen object or `null` if no main screen can be determined.
     */
    function main(): HSScreen | null;

    /**
     * The primary display — the one that contains the global menu bar.
     * @returns An HSScreen object or `null` if no primary screen can be determined.
     */
    function primary(): HSScreen | null;

}

/**
 * An object representing a single display attached to the system.
## Coordinate system
All geometry is returned in **Hammerspoon screen coordinates**: the origin `(0, 0)`
is at the top-left of the primary display, and `y` increases downward.
This matches Hammerspoon v1 and is the inverse of the raw macOS/CoreGraphics convention.
## Examples
```javascript
const s = hs.screen.main();
console.log(s.name);               // e.g. "Built-in Retina Display"
console.log(s.frame.w);            // usable width in points

console.log(s.mode.width, s.mode.scale); // e.g. 1440, 2

s.desktopImage = "/Users/me/wallpaper.jpg";
```
 */
declare class HSScreen {
    /**
     * Switch to the given display mode.
Pass `0` for `scale` or `frequency` to match any value.
     * @param width Horizontal resolution in pixels.
     * @param height Vertical resolution in pixels.
     * @param scale Backing scale factor (e.g. `2` for HiDPI, `1` for non-HiDPI). Pass `0` to ignore.
     * @param frequency Refresh rate in Hz. Pass `0` to ignore.
     * @returns `true` on success.
     */
    setMode(width: number, height: number, scale: number, frequency: number): boolean;

    /**
     * Capture the current contents of this screen as an image.
Requires **Screen Recording** permission.
     * @returns Resolves with the captured image, or rejects if the capture fails (e.g. permission denied).
     */
    snapshot(): Promise<HSImage>;

    /**
     * The next screen in `hs.screen.all()` order, wrapping around.
     * @returns An HSScreen object
     */
    next(): HSScreen;

    /**
     * The previous screen in `hs.screen.all()` order, wrapping around.
     * @returns An HSScreen object
     */
    previous(): HSScreen;

    /**
     * The nearest screen whose left edge is at or beyond this screen's right edge, or `null`.
     * @returns An HSScreen object
     */
    toEast(): HSScreen | null;

    /**
     * The nearest screen whose right edge is at or before this screen's left edge, or `null`.
     * @returns An HSScreen object
     */
    toWest(): HSScreen | null;

    /**
     * The nearest screen that is physically above this screen, or `null`.
     * @returns An HSScreen object
     */
    toNorth(): HSScreen | null;

    /**
     * The nearest screen that is physically below this screen, or `null`.
     * @returns An HSScreen object
     */
    toSouth(): HSScreen | null;

    /**
     * Move this screen so its top-left corner is at the given position in global Hammerspoon coordinates.
     * @param x The X coordinate to move to
     * @param y The Y coordinate to move to
     * @returns `true` on success.
     */
    setOrigin(x: number, y: number): boolean;

    /**
     * Designate this screen as the primary display (moves the menu bar here).
     * @returns `true` on success.
     */
    setPrimary(): boolean;

    /**
     * Configure this screen to mirror another screen.
     * @param screen The screen to mirror.
     * @returns `true` on success.
     */
    mirrorOf(screen: HSScreen): boolean;

    /**
     * Stop mirroring, restoring this screen to an independent display.
     * @returns `true` on success.
     */
    mirrorStop(): boolean;

    /**
     * Convert a rect in global Hammerspoon coordinates to coordinates local to this screen.
The result origin is relative to this screen's top-left corner.
     * @param rect An `HSRect` in global Hammerspoon coordinates.
     * @returns The rect offset to be relative to this screen's top-left, or `null` if the input is invalid.
     */
    absoluteToLocal(rect: HSRect): HSRect;

    /**
     * Convert a rect in local screen coordinates to global Hammerspoon coordinates.
     * @remarks This uses private macOS APIs to set rotation.
     * @param rect An `HSRect` relative to this screen's top-left corner.
     * @returns The rect in global Hammerspoon coordinates, or `null` if the input is invalid.
     */
    localToAbsolute(rect: HSRect): HSRect;

    /**
     * Unique display identifier (matches `CGDirectDisplayID`).
     */
    readonly id: number;

    /**
     * The manufacturer-assigned localized display name.
     */
    readonly name: string;

    /**
     * The display's UUID string.
     */
    readonly uuid: string;

    /**
     * The usable screen area in Hammerspoon coordinates, excluding the menu bar and Dock.
     */
    readonly frame: HSRect;

    /**
     * The full screen area in Hammerspoon coordinates, including menu bar and Dock regions.
     */
    readonly fullFrame: HSRect;

    /**
     * The screen's top-left corner in global Hammerspoon coordinates.
     */
    readonly position: HSPoint;

    /**
     * The currently active display mode.
An object with keys: `width`, `height`, `scale`, `frequency`.
     */
    readonly mode: Record<string, any>;

    /**
     * All display modes supported by this screen.
Each element has keys: `width`, `height`, `scale`, `frequency`.
     */
    readonly availableModes: Record<string, any>[];

    /**
     * The current screen rotation in degrees (0, 90, 180, or 270).
Assign one of `0`, `90`, `180`, or `270` to rotate the display.
     */
    rotation: number;

    /**
     * The URL string of the current desktop background image for this screen, or `null`.
Assign a new absolute file path or `file://` URL string to change the wallpaper.
     */
    desktopImage: string | null;

}

/**
 * Module for enumerating and opening serial ports (e.g. a USB-attached ESP32).
 */
declare namespace hs.serial {
    /**
     * List available serial ports (devices matching `/dev/cu.*`).
     * @returns An array of port objects (empty if none are present). Each object
     */
    function list(): Record<string, string>[];

    /**
     * Open a serial port by device path.
     * @param path The device path, e.g. `/dev/cu.usbmodem1`.
     * @returns An `HSSerialPort` object, or `null` if the port could not be opened.
     */
    function open(path: string): HSSerialPort | null;

    /**
     * Open the first serial port whose name, path, USB serial number, or USB
location contains the given string.
     * @param match A substring to search for in each port.
     * @returns An `HSSerialPort` object, or `null` if no matching port was found or could not be opened.
     */
    function openFirst(match: string): HSSerialPort | null;

    /**
     * Register a listener for serial device add/remove events.
The listener receives an event name string and a port object. The port object
always includes `path` and `name`; USB-backed devices may also include
`serialNumber`, `location`, `locationId`, `usbVendor`, `usbProduct`,
`vendorId`, and `productId`.
     * @param listener A JavaScript function called as `fn(event, port)`
     */
    function addWatcher(listener: any): void;

    /**
     * Remove a previously registered serial device listener.
     * @param listener The JavaScript function that was passed to ``addWatcher(_:)``
     */
    function removeWatcher(listener: any): void;

}

/**
 * An open serial port. Do not construct directly — use hs.serial.open().
 */
declare class HSSerialPort {
    /**
     * Close the port.
     */
    close(): void;

    /**
     * Write a string to the port (caller includes any trailing "\n").
     * @param s the bytes to write (UTF-8).
     * @returns true if all bytes were written.
     */
    write(s: string): boolean;

    /**
     * Register a callback invoked once per inbound line (newline/CR-delimited).
     * @param cb a function called with each line string.
     * @returns this port (chainable).
     */
    onLine(cb: any): HSSerialPort;

    /**
     * Register a callback invoked when the port closes.
     * @param cb a function called when the port closes.
     * @returns this port (chainable).
     */
    onClose(cb: any): HSSerialPort;

    /**
     * The device path this port was opened on.
     */
    readonly path: string;

    /**
     * Whether the port is currently open.
     */
    readonly isOpen: boolean;

}

/**
 * Query the macOS Spotlight metadata database.
`hs.spotlight` wraps `NSMetadataQuery` to let you search for files and other
metadata objects indexed by Spotlight. Queries use `NSPredicate` syntax with
`kMDItem*` attribute keys (see `hs.spotlight.attribute` for common shortcuts).
## Quick start
```js
// Find all PDFs in the home directory and log their paths
const q = hs.spotlight.create()
q.setQuery("kMDItemContentType == 'com.adobe.pdf'")
 .setScopes([hs.spotlight.scope.home])
 .setCallback((event) => {
     if (event === 'didFinish') {
         console.log('Found ' + q.count + ' PDFs')
         q.results().forEach(item =>
             console.log(item.valueForAttribute(hs.spotlight.attribute.path))
         )
         q.stop()
     }
 })
 .start()
```
## One-shot search convenience
```js
const q = hs.spotlight.search(
    "kMDItemDisplayName BEGINSWITH 'Invoice'",
    (event) => {
        if (event === 'didFinish') {
            console.log('Found ' + q.count + ' invoices')
            q.stop()
        }
    }
)
```
## Grouping results by attribute
```js
const q = hs.spotlight.create()
q.setQuery("kMDItemContentTypeTree == 'public.image'")
 .setScopes([hs.spotlight.scope.home])
 .setGroupingAttributes([hs.spotlight.attribute.kind])
 .setCallback((event) => {
     if (event === 'didFinish') {
         q.groups().forEach(g =>
             console.log(g.value() + ': ' + g.count + ' images')
         )
         q.stop()
     }
 })
 .start()
```
## Monitoring for live changes
```js
// Keep the query running to receive live-update events
const q = hs.spotlight.create()
q.setQuery("kMDItemContentType == 'com.apple.application-bundle'")
 .setScopes(['/Applications'])
 .setCallback((event, update) => {
     if (event === 'didFinish') {
         console.log('Initial scan: ' + q.count + ' apps')
     } else if (event === 'didUpdate') {
         console.log('App list changed — now ' + q.count + ' apps')
         if (update) console.log('Added: ' + update.added.length)
     }
 })
 .start()
// Call q.stop() when you no longer want live updates
```
 */
declare namespace hs.spotlight {
    /**
     * Creates and returns a new, unconfigured Spotlight query.
Configure it with `setQuery()`, `setScopes()`, and `setCallback()`, then call `start()`.
The query is automatically stopped and released when the module shuts down.
     * @returns A new `HSSpotlightQuery`
     */
    function create(): HSSpotlightQuery;

    /**
     * Convenience helper that creates, configures, and starts a query in one call.
Equivalent to `create().setQuery(predicate).setCallback(callback).start()`.
Call `q.stop()` from inside `callback` (when `event === 'didFinish'`) to end
the search once you have what you need.
     * @param predicate An NSPredicate-format query string
     * @param callback A function called with lifecycle event name and optional update data
     * @returns The `HSSpotlightQuery` object (use to stop the search early)
     */
    function search(predicate: string, callback: (event: string, update?: Record<string, any>) => void): HSSpotlightQuery;

    /**
     * Predefined search scope constants for use with `HSSpotlightQuery.setScopes()`.
| Key | Description |
|-----|-------------|
| `home` | The current user's home directory |
| `computer` | All locally mounted volumes |
| `network` | Network-mounted volumes |
| `applications` | Common locations for .app bundles |
| `icloud` | iCloud Documents |
| `icloudData` | iCloud Data (non-document ubiquitous files) |
     */
    const scope: Record<string, string[]>;

    /**
     * Common Spotlight metadata attribute key shortcuts.
These are plain `kMDItem*` string values — using them is equivalent to typing
the raw key name, but they provide autocomplete and avoid typos.
| Key | Attribute | Description |
|-----|-----------|-------------|
| `path` | `kMDItemPath` | Absolute filesystem path |
| `displayName` | `kMDItemDisplayName` | User-visible display name |
| `fsName` | `kMDItemFSName` | Filename on disk |
| `contentType` | `kMDItemContentType` | UTI content type |
| `contentTypeTree` | `kMDItemContentTypeTree` | Full UTI conformance tree |
| `kind` | `kMDItemKind` | Finder "Kind" string |
| `fileSize` | `kMDItemFSSize` | File size in bytes |
| `creationDate` | `kMDItemFSCreationDate` | Filesystem creation date |
| `modifiedDate` | `kMDItemFSContentChangeDate` | Last content modification date |
| `lastUsedDate` | `kMDItemLastUsedDate` | Last time the item was opened |
| `useCount` | `kMDItemUseCount` | Number of times opened |
| `authors` | `kMDItemAuthors` | Document authors |
| `title` | `kMDItemTitle` | Document title |
| `comment` | `kMDItemComment` | User comment |
| `keywords` | `kMDItemKeywords` | Tags/keywords |
| `durationSeconds` | `kMDItemDurationSeconds` | Media duration in seconds |
| `pixelWidth` | `kMDItemPixelWidth` | Image/video width in pixels |
| `pixelHeight` | `kMDItemPixelHeight` | Image/video height in pixels |
| `whereFroms` | `kMDItemWhereFroms` | Download source URLs |
| `bundleIdentifier` | `kMDItemCFBundleIdentifier` | App bundle identifier |
     */
    const attribute: Record<string, string>;

}

/**
 * A grouped set of Spotlight results that share a common metadata attribute value.
Groups are returned by `HSSpotlightQuery.groups()` when grouping attributes have been
configured with `setGroupingAttributes()`. Do not instantiate `HSSpotlightGroup` directly.
When multiple grouping attributes are specified, groups nest: each group has `subgroups()`
containing the next level of grouping.
 */
declare class HSSpotlightGroup {
    /**
     * The shared value of the grouping attribute for all results in this group.
Returns `null` only in the unlikely case that the underlying value cannot be bridged.
     * @returns The attribute value (string, number, Date, etc.) or null
     */
    value(): any | null;

    /**
     * Returns the items contained in this group as an array of `HSSpotlightItem` objects.
     * @returns An array of `HSSpotlightItem` objects
     */
    results(): HSSpotlightItem[];

    /**
     * Returns nested subgroups when multiple grouping attributes were specified.
Returns an empty array if no subgroups exist for this group.
     * @returns An array of `HSSpotlightGroup` objects
     */
    subgroups(): HSSpotlightGroup[];

    /**
     * A unique identifier for this group object (UUID string).
     */
    readonly identifier: string;

    /**
     * The metadata attribute name by which results in this group are clustered.
     */
    readonly attribute: string;

    /**
     * The number of results contained in this group.
     */
    readonly count: number;

}

/**
 * An individual result returned by a Spotlight query.
Instances are returned by `HSSpotlightQuery.results()` and related methods.
Do not instantiate `HSSpotlightItem` directly.
Metadata values are read via `valueForAttribute()` using standard `kMDItem*` keys.
Call `attributes()` to discover which keys are populated on a particular item.
Common attribute key shortcuts live in `hs.spotlight.attribute`.
 */
declare class HSSpotlightItem {
    /**
     * Returns the list of metadata attribute names present on this item.
The list is typically not exhaustive — some attributes (such as `kMDItemPath`)
may be readable via `valueForAttribute()` even when absent from this list.
     * @returns An array of attribute name strings
     */
    attributes(): string[];

    /**
     * Returns the value for a specific metadata attribute, or `null` if absent.
The return type depends on the attribute: common types include strings, numbers,
dates, and arrays of strings. `NSURL`-typed values are automatically converted
to their string representation.
     * @param key An attribute key such as `"kMDItemPath"` or `hs.spotlight.attribute.path`
     * @returns The attribute value, or null
     */
    valueForAttribute(key: string): any | null;

    /**
     * A unique identifier for this result object (UUID string).
     */
    readonly identifier: string;

}

/**
 * A configurable Spotlight search query that can be started, stopped, and queried for results.
Create instances via `hs.spotlight.create()` or the convenience helper `hs.spotlight.search()`.
Configure the query with chainable setter methods, register a callback, then call `start()`.
Results accumulate during the initial gathering phase (`"didStart"` → `"inProgress"` → `"didFinish"`)
and continue to update during the live-monitoring phase (`"didUpdate"`). Stop explicitly
with `stop()` when you no longer need live updates.
 */
declare class HSSpotlightQuery {
    /**
     * Sets the NSPredicate query string for this search.
The string must be a valid `NSPredicate` format expression using `kMDItem*` attribute
keys and MDQuery operators (`==`, `!=`, `<`, `>`, `BEGINSWITH`, `CONTAINS`, etc.).
If the query is already running when this is called, it is stopped and restarted
automatically.
     * @param predicate An NSPredicate-format query string
     * @returns this query, for chaining
     */
    setQuery(predicate: string): HSSpotlightQuery;

    /**
     * Sets the search scopes that restrict where Spotlight looks.
Pass an array of predefined scope strings from `hs.spotlight.scope`, absolute
directory paths, or a mix of both. Paths beginning with `~` are expanded to the
user's home directory.
When not set, the query defaults to `hs.spotlight.scope.computer`.
     * @param scopes An array of scope-constant strings or absolute directory paths
     * @returns this query, for chaining
     */
    setScopes(scopes: string[]): HSSpotlightQuery;

    /**
     * Sets sort descriptors that control the order of results.
     * @param descriptors An array of sort descriptor objects
     * @returns this query, for chaining
     */
    setSortDescriptors(descriptors: Record<string, any>[]): HSSpotlightQuery;

    /**
     * Sets the attributes by which results will be grouped.
When grouping attributes are set, use `groups()` to retrieve results organised into
`HSSpotlightGroup` objects. Specifying multiple attributes creates nested subgroups
accessible via `group.subgroups()`.
     * @param attrs An array of attribute name strings
     * @returns this query, for chaining
     */
    setGroupingAttributes(attrs: string[]): HSSpotlightQuery;

    /**
     * Sets the attributes for which aggregate value-list summaries are computed.
After the query finishes, `valueLists()` returns aggregate data for each specified
attribute: distinct values and the number of results carrying each value.
     * @param attrs An array of attribute name strings
     * @returns this query, for chaining
     */
    setValueListAttributes(attrs: string[]): HSSpotlightQuery;

    /**
     * Registers a callback that receives query lifecycle events.
of `HSSpotlightItem` objects describing what changed in this update cycle
     * @param fn Called with lifecycle event name and optional update data containing added/changed/removed item arrays
     * @returns this query, for chaining
     */
    setCallback(fn: (event: string, update?: Record<string, any>) => void): HSSpotlightQuery;

    /**
     * Starts the query.
The query must have a predicate set (via `setQuery()`) before calling `start()`.
Calling `start()` on an already-running query is a no-op.
     * @returns this query, for chaining
     */
    start(): HSSpotlightQuery;

    /**
     * Stops the query while preserving accumulated results.
After stopping, `results()`, `count`, `groups()`, and `valueLists()` continue to
return the last gathered data. Call `start()` again to resume.
     * @returns this query, for chaining
     */
    stop(): HSSpotlightQuery;

    /**
     * Returns the current results as an array of `HSSpotlightItem` objects.
The result set is briefly frozen during access to ensure consistency. Safe to call
from within a query callback.
     * @returns An array of `HSSpotlightItem` objects (may be empty if the query has not run)
     */
    results(): HSSpotlightItem[];

    /**
     * Returns grouped results when grouping attributes have been configured.
Returns an empty array if `setGroupingAttributes()` was not called.
     * @returns An array of `HSSpotlightGroup` objects
     */
    groups(): HSSpotlightGroup[];

    /**
     * Returns aggregate value-list summaries for attributes set via `setValueListAttributes()`.
Returns an empty array if `setValueListAttributes()` was not called.
     * @returns An array of summary objects
     */
    valueLists(): Record<string, any>[];

    /**
     * A unique identifier for this query object (UUID string).
     */
    readonly identifier: string;

    /**
     * The number of results gathered so far.
     */
    readonly count: number;

    /**
     * Whether the query is currently running (gathering or monitoring for live updates).
     */
    readonly isRunning: boolean;

    /**
     * Whether the query is in the initial gathering phase.
`true` from `"didStart"` until `"didFinish"`; `false` thereafter while live-monitoring.
     */
    readonly isGathering: boolean;

}

/**
 * A per-connection SQLite database object returned by `hs.sqlite.open()`.
Wraps a sqlite3 handle and exposes synchronous exec, parameterized run/query,
and transaction helpers to JavaScript.
 */
declare namespace hs.sqlite {
    /**
     * Open an SQLite database file. Returns an HSSqliteDB on success, null on failure.
`~` is expanded; parent directories must already exist.
     * @param path Filesystem path to the database file
     * @returns An open HSSqliteDB, or null if the open failed
     */
    function open(path: string): HSSqliteDB | null;

}

/**
 * A per-connection SQLite database object returned by `hs.sqlite.open()`.
Wraps a sqlite3 handle and exposes synchronous exec, parameterized run/query,
and transaction helpers to JavaScript.
 */
declare class HSSqliteDB {
    /**
     * Execute one or more SQL statements with no parameters. Returns true on
success, false on error (logged via AKError). Use this for DDL
(CREATE/DROP/PRAGMA) and other parameter-less statements.
     * @param sql SQL text, possibly containing multiple `;`-separated statements
     * @returns True on success
     */
    exec(sql: string): boolean;

    /**
     * Run a parameterized write. Returns an object `{ changes, lastInsertRowid }`
on success, or null on error.
     * @param sql Parameterized SQL with `?` placeholders
     * @param params Array of values to bind (or null/undefined for no params)
     * @returns `{ changes: number, lastInsertRowid: number }` or null
     */
    run(sql: string, params: any): any | null;

    /**
     * Run a parameterized read. Returns an array of plain JS objects keyed by
column name. Empty array if no rows.
     * @param sql Parameterized SELECT
     * @param params Array of values to bind
     * @returns An array of objects
     */
    query(sql: string, params: any): Record<string, any>[];

    /**
     * Run a JS function inside a BEGIN/COMMIT pair. If the function throws,
the transaction is rolled back and the exception is re-thrown to the
caller. Returns the function's return value on success.
Nested transactions throw — savepoints are not supported in v1.
     * @param fn A function with no arguments
     * @returns The function's return value, or null on rollback
     */
    transaction(fn: any): any | null;

    /**
     * Close the database. Idempotent — second call is a no-op. Throws if
called inside a transaction.
     */
    close(): void;

    /**
     * The filesystem path of the database.
     */
    readonly path: string;

    /**
     * Whether the database is currently open. Becomes false after `close()`.
     */
    readonly isOpen: boolean;

}

/**
 * Module for a cmd+Tab-replacement window/app switcher. Backed by the live
`HSWindowRegistry` (MRU observer cache) and Swift-owned eventtap, so
trigger latency and cycle latency stay sub-frame regardless of how many
apps are running.
 */
declare namespace hs.switcher {
    /**
     * Enable the switcher with the given configuration.
after which the highlighted selection is committed.
presses Tab while filtering. The picker closes and the typed filter
text is handed off so a host launcher can search installed (not just
running) apps — letting the user launch something that isn't open yet.
the picker opens; returns an array of `{ bundleID, title, url,
windowIndex, tabIndex }` browser tabs. Tabs are listed under their
browser's app (matched by bundleID) beneath its window rows, and
committing one fires `onCommit` with `kind: 'tab'` plus the tab's
coordinates — the host is expected to focus it (e.g. AppleScript);
the switcher does not raise anything itself for tab commits.
     * @param cfg Object with optional keys:
     * @returns `{ disable: function }` on success, or `{ error: string }`
     */
    function enable(cfg: any): Record<string, any>;

    /**
     * Open the picker right now, as if the user had triggered ctrl×2.
Uses the first active binding's config; no-op if `enable()` has not
been called. Intended for testing / custom hotkey wiring.
     * @returns true if the picker opened, false otherwise.
     */
    function show(): boolean;

    /**
     * Diagnostic snapshot of the live picker (if open) and the registry.
Returns null if no session is active.
     * @returns object with `windowFrame`, `screenVisibleFrame`,
     */
    function debugState(): Record<string, any> | null;

    /**
     * Programmatically move the current session's selection (no UI events).
     * @param axis `'app'` to move between apps, `'window'` to move between windows within an app, `'linear'` to move through the flat row list the way the ↑/↓ arrow keys do
     * @param delta direction to move — `+1` for forward, `-1` for backward
     * @returns true if a session was active to move.
     */
    function debugMove(axis: string, delta: number): boolean;

    /**
     * Programmatically set the current session's filter text — the same
path as typing while the picker is open, including the best-match
selection (tab → window → app). An empty string returns to cycle mode.
     * @param text The filter text to apply.
     * @returns true if a session was active to filter.
     */
    function debugFilter(text: string): boolean;

    /**
     * Replace the OPEN picker's browser-tab rows with a fresh inventory —
the second half of the `tabsProvider` contract: the provider returns
its cache instantly, kicks an async re-inventory, then calls this so
a just-closed tab vanishes from the visible list (and the first
trigger after a reload fills in from empty). Apps with no rows in the
push lose their tabs. The selection re-aims (filter best-match) or
clamps so it never points past the shrunken row list. No-op when the
picker isn't open.
     * @param rows Array of `{bundleID, title, url, windowIndex, tabIndex}`.
     * @returns true if an open session accepted the update.
     */
    function updateTabs(rows: any): boolean;

    /**
     * Programmatically commit the current selection (same path as Enter).
Returns a dict with `frontmostBefore`, `targetApp`, `targetPid`,
`committed` (bool), and the caller can poll `frontmostAfter` via
`hs.application.frontmost()` shortly after.
     * @returns `{ frontmostBefore, targetApp, targetPid, committed }` describing the commit outcome
     */
    function debugCommit(): Record<string, any>;

}

/**
 * Module for running external processes
 */
declare namespace hs.task {
    /**
     * Create a new task
     * @param launchPath The full path to the executable to run
     * @param arguments An array of arguments to pass to the executable
     * @param completionCallback Optional callback called when the task terminates with exit code and reason
     * @param environment Optional dictionary of environment variables for the task
     * @param streamingCallback Optional callback called when the task produces output; stream is "stdout" or "stderr"
     * @returns A task object. Call start() to begin execution.
     */
    function create(launchPath: string, arguments: string[], completionCallback: ((exitCode: number, exitReason: string) => void) | null, environment: Record<string, string> | null, streamingCallback: ((stream: string, data: string) => void) | null): HSTask;

    /**
     * Run a short-lived command synchronously and return its stdout as a
string. Use sparingly — this blocks the JS thread until the process
exits. Intended for fast utilities (`ps`, `whoami`, `uname`) where
awaiting a Promise would add UI flicker.
     * @param launchPath Absolute path to the executable
     * @param arguments Argument array
     * @returns Combined stdout as a string, or null on failure
     */
    function runSync(launchPath: string, arguments: string[]): string | null;

    /**
     * Create and run a task asynchronously
     * @param launchPath - Full path to the executable
     * @param args - Array of arguments
     * @param options - Options object or legacy callback
     * @param legacyStreamCallback - Legacy streaming callback (optional)
     * @returns {Promise<{exitCode: number, stdout: string, stderr: string}>}
     */
    function runAsync(launchPath: string, args: string[], options: Object|Function, legacyStreamCallback: Function): any;

    /**
     * Run a shell command asynchronously
     * @param command - Shell command to execute
     * @param options - Options (same as run)
     * @returns {Promise<{exitCode: number, stdout: string, stderr: string}>}
     */
    function shell(command: string, options: Object): any;

    /**
     * Run multiple tasks in parallel
     * @returns {Promise<Array<{exitCode: number, stdout: string, stderr: string}>>} Array of results
     */
    function parallel(): any;

    /**
     * Create a task builder for fluent API
     * @param launchPath - Full path to the executable
     * @returns {TaskBuilder}
     */
    function builder(launchPath: string): any;

    /**
     * Run multiple tasks in sequence. Swift-retained storage for the JS implementation.
     */
    let sequence: ((...args: any[]) => any) | null;

    /**
     * TaskBuilder class. Swift-retained storage for the JS implementation.
     */
    let TaskBuilder: ((...args: any[]) => any) | null;

}

/**
 * Object representing an external process task
 */
declare class HSTask {
    /**
     * Start the task
     * @returns The task object for chaining
     */
    start(): HSTask;

    /**
     * Terminate the task (send SIGTERM)
     */
    terminate(): void;

    /**
     * Terminate the task with extreme prejudice (send SIGKILL)
     */
    kill9(): void;

    /**
     * Interrupt the task (send SIGINT)
     */
    interrupt(): void;

    /**
     * Pause the task (send SIGSTOP)
     */
    pause(): void;

    /**
     * Resume the task (send SIGCONT)
     */
    resume(): void;

    /**
     * Wait for the task to complete (blocking)
     */
    waitUntilExit(): void;

    /**
     * Write data to the task's stdin
     * @param data The string data to write
     */
    sendInput(data: string): void;

    /**
     * Close the task's stdin
     */
    closeInput(): void;

    /**
     * Check if the task is currently running
     * @remarks true if the task is running, false otherwise
     */
    readonly isRunning: boolean;

    /**
     * The process ID of the running task
     * @remarks The value will be -1 if the task is not running
     */
    readonly pid: number;

    /**
     * The environment variables for the task
     * @remarks Can only be modified before calling start()
     */
    environment: Record<string, string>;

    /**
     * The working directory for the task
     * @remarks Can only be modified before calling start()
     */
    workingDirectory: string | null;

    /**
     * The termination status of the task
     * @remarks Returns the exit code, or nil if the task hasn't terminated
     */
    readonly terminationStatus: number | null;

    /**
     * The termination reason
     * @remarks Returns a string describing why the task terminated, or nil if still running
     */
    readonly terminationReason: string | null;

}

/**
 */
declare namespace hs.text {
    /**
     * Convert Mandarin characters in a string to lowercase pinyin, stripped
of tone diacritics and inter-syllable spaces. Non-CJK characters are
passed through (lowercased). Used by the launcher's fuzzy matcher
and the switcher's filter to match e.g. "weixin" against "微信".
     * @param s input string
     * @returns lowercase pinyin (no spaces, no diacritics)
     */
    function toPinyin(s: string): string;

    /**
     * Switch the system's current keyboard input source to an ASCII-capable
layout (e.g. "ABC" or "U.S."). The previously-selected ASCII source is
reused. No-op if already on an ASCII source.
Useful when opening a search field — the user can type Latin letters
even if they were last using a Chinese / Japanese / Korean IME.
     * @returns true if the switch succeeded (or the current source is
     */
    function useASCIIInput(): boolean;

}

/**
 * Module for creating and managing timers
 */
declare namespace hs.timer {
    /**
     * Create a new timer
     * @param interval The interval in seconds at which the timer should fire
     * @param callback A JavaScript function to call when the timer fires
     * @param continueOnError If true, the timer will continue running even if the callback throws an error
     * @returns A timer object. Call start() to begin the timer.
     */
    function create(interval: number, callback: () => void, continueOnError?: boolean): HSTimer;

    /**
     * Create and start a one-shot timer
     * @param seconds Number of seconds to wait before firing
     * @param callback A JavaScript function to call when the timer fires
     * @returns A timer object (already started)
     */
    function doAfter(seconds: number, callback: () => void): HSTimer;

    /**
     * Create and start a repeating timer
     * @param interval The interval in seconds at which the timer should fire
     * @param callback A JavaScript function to call when the timer fires
     * @returns A timer object (already started)
     */
    function doEvery(interval: number, callback: () => void): HSTimer;

    /**
     * Create and start a timer that fires at a specific time
     * @param time Seconds since midnight (local time) when the timer should first fire
     * @param repeatInterval If provided, the timer will repeat at this interval. Pass 0 for one-shot.
     * @param callback A JavaScript function to call when the timer fires
     * @param continueOnError If true, the timer will continue running even if the callback throws an error
     * @returns A timer object (already started)
     */
    function doAt(time: number, repeatInterval: number, callback: () => void, continueOnError?: boolean): HSTimer;

    /**
     * Block execution for a specified number of microseconds (strongly discouraged)
     * @remarks This blocks the entire application and should be avoided. Use timers instead.
     * @param microseconds Number of microseconds to sleep
     */
    function usleep(microseconds: number): void;

    /**
     * Get the current time as seconds since the UNIX epoch with sub-second precision
     * @returns Fractional seconds since midnight, January 1, 1970 UTC
     */
    function secondsSinceEpoch(): number;

    /**
     * Get the number of nanoseconds since the system was booted (excluding sleep time)
     * @returns Nanoseconds since boot
     */
    function absoluteTime(): number;

    /**
     * Get the number of seconds since local midnight
     * @returns Seconds since midnight in the local timezone
     */
    function localTime(): number;

    /**
     * Converts minutes to seconds
     * @param n A number of minutes
     * @returns The equivalent number of seconds
     */
    function minutes(n: number): number;

    /**
     * Converts hours to seconds
     * @param n A number of hours
     * @returns The equivalent number of seconds
     */
    function hours(n: number): number;

    /**
     * Converts days to seconds
     * @param n A number of days
     * @returns The equivalent number of seconds
     */
    function days(n: number): number;

    /**
     * Converts weeks to seconds
     * @param n A number of weeks
     * @returns The equivalent number of seconds
     */
    function weeks(n: number): number;

    /**
     * Repeat a function/lambda until a given predicate function/lambda returns true
     * @param predicateFn A function/lambda to test if the timer should continue. Return True to end the timer, False to continue it
     * @param actionFn A function/lambda to call until the predicateFn returns true
     * @param checkInterval How often, in seconds, to call actionFn
     */
    function doUntil(predicateFn: any, actionFn: any, checkInterval: any): void;

    /**
     * Repeat a function/lambda while a given predicate function/lambda returns true
     * @param predicateFn A function/lambda to test if the timer should continue. Return True to continue the timer, False to end it
     * @param actionFn A function/lambda to call while the predicateFn returns true
     * @param checkInterval How often, in seconds, to call actionFn
     */
    function doWhile(predicateFn: any, actionFn: any, checkInterval: any): void;

    /**
     * Wait to call a function/lambda until a given predicate function/lambda returns true
     * @param predicateFn A function/lambda to test if the actionFn should be called. Return True to call the actionFn, False to continue waiting
     * @param actionFn A function/lambda to call when the predicateFn returns true. This will only be called once and then the timer will stop.
     * @param checkInterval How often, in seconds, to call predicateFn
     */
    function waitUntil(predicateFn: any, actionFn: any, checkInterval: any): void;

    /**
     * Wait to call a function/lambda until a given predicate function/lambda returns false
     * @param predicateFn A function/lambda to test if the actionFn should be called. Return False to call the actionFn, True to continue waiting
     * @param actionFn A function/lambda to call when the predicateFn returns False. This will only be called once and then the timer will stop.
     * @param checkInterval How often, in seconds, to call predicateFn
     */
    function waitWhile(predicateFn: any, actionFn: any, checkInterval: any): void;

}

/**
 * Object representing a timer. You should not instantiate these yourself, but rather, use the methods in hs.timer to create them for you.
 */
declare class HSTimer {
    /**
     * Start the timer
     */
    start(): void;

    /**
     * Stop the timer
     */
    stop(): void;

    /**
     * Immediately fire the timer's callback
     */
    fire(): void;

    /**
     * Check if the timer is currently running
     * @returns true if the timer is running, false otherwise
     */
    running(): boolean;

    /**
     * Get the number of seconds until the timer next fires
     * @returns Seconds until next trigger, or a negative value if the timer is not running
     */
    nextTrigger(): number;

    /**
     * Set when the timer should next fire
     * @param seconds Number of seconds from now when the timer should fire
     */
    setNextTrigger(seconds: number): void;

    /**
     * The timer's interval in seconds
     */
    readonly interval: number;

    /**
     * Whether the timer repeats
     */
    readonly repeats: boolean;

}

/**
 * Translate text between languages using the macOS on-device Translation framework.
Language identifiers use BCP-47 format (e.g. `"en"`, `"fr"`, `"zh-Hans"`).
Call `hs.translation.supportedLanguages()` to list every language the framework
recognises, and `hs.translation.status()` to check whether a specific pair is
installed and ready for offline use.
Language packs are downloaded through
**System Settings → General → Language & Region → Translation Languages**.
`hs.translation` cannot trigger downloads programmatically; `session()` returns
`null` when the requested pair is not yet installed.
## Quick start
```js
hs.translation.status("en", "fr").then(s => {
    if (s === "installed") {
        const session = hs.translation.session("en", "fr")
        session.translate("Good morning").then(r => console.log(r))
    } else {
        console.log("Install en→fr in System Settings → Language & Region → Translation Languages")
    }
})
```
 */
declare namespace hs.translation {
    /**
     * All language codes supported by the on-device translation engine.
Resolves to an array of BCP-47 identifiers (e.g. `["ar", "de", "en", "es", "fr"]`).
This covers every language the framework knows about, regardless of whether
the packs are installed locally. Use `status()` to distinguish installed
pairs from merely supported ones.
     * @returns Resolves to an array of BCP-47 language code strings.
     */
    function supportedLanguages(): Promise<string[]>;

    /**
     * Check the installation status of a language pair.
     * @param sourceLanguage BCP-47 code of the source language (e.g. `"en"`).
     * @param targetLanguage BCP-47 code of the target language (e.g. `"fr"`).
     * @returns Resolves to `"installed"`, `"supported"`, or `"unsupported"`.
     */
    function status(sourceLanguage: string, targetLanguage: string): Promise<string>;

    /**
     * Create a translation session for a language pair.
Returns an `HSTranslationSession`, or `null` if the system is running macOS
older than 26.0.
     * @param sourceLanguage BCP-47 code of the source language (e.g. `"en"`).
     * @param targetLanguage BCP-47 code of the target language (e.g. `"fr"`).
     * @returns An `HSTranslationSession`, or `null` on unsupported versions of macOS.
     */
    function session(sourceLanguage: string, targetLanguage: string): HSTranslationSession | null;

}

/**
 * JavaScript-visible API for a translation session bound to a specific language pair.
 */
declare class HSTranslationSession {
    /**
     * Translate a string from the session's source language to its target language.
     * @param text The text to translate.
     * @returns A Promise resolving to the translated string,
     */
    translate(text: string): Promise<string>;

    /**
     * The Swift type name, for JavaScript introspection.
     */
    readonly typeName: string;

    /**
     * BCP-47 identifier of the source language (e.g. `"en"`).
     */
    readonly sourceLanguage: string;

    /**
     * BCP-47 identifier of the target language (e.g. `"fr"`).
     */
    readonly targetLanguage: string;

}

/**
 * # hs.ui
**Create custom user interfaces, alerts, dialogs, and file pickers**
The `hs.ui` module provides a set of tools for creating custom user interfaces
in Hammerspoon with SwiftUI-like declarative syntax.
## Key Features
then call `.replaceWithColor()` or `.replaceWithHex()` on it from any callback to re-render the canvas automatically
then call `.set()` on it to update the displayed content live
to swap the image without rebuilding the window
## Basic Examples
### Simple Alert
```javascript
hs.ui.alert("Task completed!")
    .duration(3)
    .show();
```
### Dialog with Buttons
```javascript
hs.ui.dialog("Save changes?")
    .informativeText("Your document has unsaved changes.")
    .buttons(["Save", "Don't Save", "Cancel"])
    .onButton((index) => {
        if (index === 0) console.log("Saving...");
    })
    .show();
```
### Text Input Prompt
```javascript
hs.ui.textPrompt("Enter your name")
    .defaultText("John Doe")
    .onButton((buttonIndex, text) => {
        console.log("User entered: " + text);
    })
    .show();
```
### File Picker
```javascript
hs.ui.filePicker()
    .message("Choose a file")
    .allowedFileTypes(["txt", "md"])
    .onSelection((path) => {
        if (path) console.log("Selected: " + path);
    })
    .show();
```
### Custom Window
```javascript
hs.ui.window({x: 100, y: 100, w: 300, h: 200})
    .vstack()
        .spacing(10)
        .padding(20)
        .text("Hello, World!")
            .font(HSFont.title())
            .foregroundColor("#FFFFFF")
        .rectangle()
            .fill("#4A90E2")
            .cornerRadius(10)
            .frame({w: "100%", h: 60})
    .end()
    .backgroundColor("#2C3E50")
    .show();
```
### Reactive Color on Hover
```javascript
// Create a mutable color, then mutate it inside the hover callback
const btnColor = HSColor.hex("#4A90E2");

hs.ui.window({x: 100, y: 100, w: 160, h: 60})
    .rectangle()
        .fill(btnColor)
        .cornerRadius(8)
        .frame({w: "100%", h: "100%"})
        .onHover((isHovered) => {
            btnColor.replaceWithHex(isHovered ? "#E24A4A" : "#4A90E2");
        })
    .show();
```
### Reactive Text on Hover
```javascript
// Create a mutable string, then mutate it inside the hover callback
const label = hs.ui.string("Move your mouse here");

hs.ui.window({x: 100, y: 200, w: 220, h: 50})
    .text(label)
        .font(HSFont.body())
        .foregroundColor("#FFFFFF")
        .onHover((isHovered) => {
            label.set(isHovered ? "You're hovering!" : "Move your mouse here");
        })
    .show();
```
### Reactive Image on Click
```javascript
// Toggle between two system icons on each click
const icon = HSImage.fromName("NSStatusAvailable");

hs.ui.window({x: 100, y: 300, w: 80, h: 80})
    .image(icon)
        .resizable()
        .aspectRatio("fit")
        .frame({w: 64, h: 64})
        .onClick(() => {
            const next = (icon.name === "NSStatusAvailable")
                ? HSImage.fromName("NSStatusUnavailable")
                : HSImage.fromName("NSStatusAvailable");
            icon.replaceWithImage(next);
        })
    .show();
```
## Complete Example: Status Dashboard
Here's a more complex example showing how to build an interactive status dashboard
```javascript
// Create a status dashboard window
const statusWindow = hs.ui.window({x: 100, y: 100, w: 400, h: 500})
    .vstack()
        .spacing(15)
        .padding(20)

        // Header
        .text("System Status Dashboard")
            .font(HSFont.largeTitle())
            .foregroundColor("#FFFFFF")

        // Status cards
        .hstack()
            .spacing(10)
            .vstack()
                .spacing(5)
                .rectangle()
                    .fill("#4CAF50")
                    .cornerRadius(8)
                    .frame({w: 180, h: 100})
                .text("CPU: 45%")
                    .font(HSFont.headline())
                    .foregroundColor("#FFFFFF")
            .end()
            .vstack()
                .spacing(5)
                .rectangle()
                    .fill("#2196F3")
                    .cornerRadius(8)
                    .frame({w: 180, h: 100})
                .text("Memory: 8.2GB")
                    .font(HSFont.headline())
                    .foregroundColor("#FFFFFF")
            .end()
        .end()

        // Activity indicator with image
        .hstack()
            .spacing(10)
            .image(HSImage.fromName("NSComputer"))
                .resizable()
                .aspectRatio("fit")
                .frame({w: 64, h: 64})
            .vstack()
                .text("System Running")
                    .font(HSFont.title())
                .text("All services operational")
                    .font(HSFont.caption())
                    .foregroundColor("#A0A0A0")
            .end()
        .end()

        // Circle status indicators
        .hstack()
            .spacing(20)
            .circle()
                .fill("#4CAF50")
                .frame({w: 30, h: 30})
            .circle()
                .fill("#FFC107")
                .frame({w: 30, h: 30})
            .circle()
                .fill("#F44336")
                .frame({w: 30, h: 30})
        .end()
    .end()
    .backgroundColor("#2C3E50");

// Show the dashboard
statusWindow.show();

// Later, interact with dialogs
hs.ui.dialog("Shutdown system?")
    .informativeText("This will close all applications.")
    .buttons(["Shutdown", "Cancel"])
    .onButton((index) => {
        if (index === 0) {
            hs.ui.alert("Shutting down...")
                .duration(3)
                .show();
        }
    })
    .show();
```
## Complete Example: Reactive Hover Card
Demonstrates reactive colors and reactive text together — a single `.onHover()`
```javascript
const cardColor = HSColor.hex("#3498DB");
const cardLabel = hs.ui.string("Hover the card");

hs.ui.window({x: 100, y: 100, w: 220, h: 120})
    .vstack()
        .spacing(12)
        .padding(16)
        .rectangle()
            .fill(cardColor)
            .cornerRadius(10)
            .frame({w: "100%", h: 60})
            .onHover((isHovered) => {
                cardColor.replaceWithHex(isHovered ? "#E74C3C" : "#3498DB");
                cardLabel.set(isHovered ? "You found it!" : "Hover the card");
            })
        .text(cardLabel)
            .font(HSFont.headline())
            .foregroundColor("#FFFFFF")
    .end()
    .backgroundColor("#1A252F")
    .show();
```
 */
declare namespace hs.ui {
    /**
     * Create a custom UI window
Creates a borderless window that can contain custom UI elements built using a declarative,
SwiftUI-like syntax with shapes, text, and layout containers.
     * @param dict Dictionary with keys: `x`, `y`, `w`, `h` (all numbers)
     * @returns An `HSUIWindow` object for chaining
     */
    function window(dict: Record<string, any>): HSUIWindow;

    /**
     * Create a temporary on-screen alert
Displays a temporary notification that automatically dismisses after the specified duration.
Similar to the old `hs.alert` module but with more features.
     * @param message The message text to display
     * @returns An `HSUIAlert` object for chaining
     */
    function alert(message: string): HSUIAlert;

    /**
     * Create a modal dialog with buttons
Shows a blocking dialog with customizable message, informative text, and buttons.
Use the callback to handle button presses.
     * @param message The main message text
     * @returns An `HSUIDialog` object for chaining
     */
    function dialog(message: string): HSUIDialog;

    /**
     * Create a text input prompt
Shows a modal dialog with a text input field. The callback receives the button index
and the entered text.
     * @param message The prompt message
     * @returns An `HSUITextPrompt` object for chaining
     */
    function textPrompt(message: string): HSUITextPrompt;

    /**
     * Create a reactive string for binding text element content to a dynamic value
An `HSString` is a reactive value container. When passed to `.text()`,
the canvas automatically re-renders whenever `.set()` is called from JavaScript.
     * @param initialValue The starting string value
     * @returns An `HSString` object whose value can be updated with `.set()`
     */
    function string(initialValue: string): HSString;

    /**
     * Create a file or directory picker
Shows a standard macOS file picker dialog. Can be configured to select files,
directories, or both, with support for file type filtering and multiple selection.
     * @returns An `HSUIFilePicker` object for chaining
     */
    function filePicker(): HSUIFilePicker;

    /**
     * Create a web browser element for embedding in `hs.ui.window` (macOS 26+)
Returns a `UIWebView` element that you configure and then embed in any `hs.ui.window`
via `.webview(element)`. The element fills the available space inside the window layout.
Keep a reference to call navigation methods after the window is shown.
     * @returns A `UIWebView` element for configuration and embedding
     */
    function webview(): UIWebView;

}

/**
 * # HSUIWindow
**A custom window with declarative UI building**
`HSUIWindow` allows you to create custom windows with a SwiftUI-like
declarative syntax. Build interfaces using shapes, text, images, and layout containers.
## Building UI Elements
## Modifying Elements
## Examples
**Simple window with text and shapes:**
```javascript
hs.ui.window({x: 100, y: 100, w: 300, h: 200})
    .vstack()
        .spacing(10)
        .padding(20)
        .text("Dashboard")
            .font(HSFont.largeTitle())
            .foregroundColor("#FFFFFF")
        .rectangle()
            .fill("#4A90E2")
            .cornerRadius(10)
            .frame({w: "90%", h: 80})
    .end()
    .backgroundColor("#2C3E50")
    .show();
```
**Window with image:**
```javascript
const img = HSImage.fromPath("~/Pictures/photo.jpg")
hs.ui.window({x: 100, y: 100, w: 400, h: 300})
    .vstack()
        .padding(20)
        .image(img)
            .resizable()
            .aspectRatio("fit")
            .frame({w: 360, h: 240})
    .end()
    .show();
```
 */
declare class HSUIWindow {
    /**
     * Show the window
     * @returns Self for chaining
     */
    show(): HSUIWindow;

    /**
     * Hide the window (keeps it in memory)
     */
    hide(): void;

    /**
     * Close and destroy the window
     */
    close(): void;

    /**
     * Return the window's actual on-screen frame after show(), as
`{x, y, w, h}` in bottom-origin (NSWindow) coordinates. Returns null
if the window has not been shown. For debugging/testing only.
     * @returns `{x, y, w, h}` on-screen frame in NSWindow coordinates, or null if not shown
     */
    currentFrame(): Record<string, number> | null;

    /**
     * Render this window's content view to a PNG file at the given path.
Uses NSView.cacheDisplay — this does NOT capture the screen, only
re-renders this view's own drawing, so no Screen Recording permission
is required and only this window's pixels are produced.
     * @param path absolute filesystem path to write
     * @returns true on success
     */
    snapshotToPNG(path: string): boolean;

    /**
     * Show or hide the window's title bar
By default windows have a title bar. Pass `false` to create a borderless window.
`.closable()`, `.miniaturizable()`, and `.allowResize()` only take visual effect
when the window is titled.
     * @param show Pass `false` to make the window borderless
     * @returns Self for chaining
     */
    titled(show: boolean): HSUIWindow;

    /**
     * Show or hide the close button on the window
Requires `.titled(true)` to be visible. Enabled by default.
     * @param show Pass `false` to hide the close button
     * @returns Self for chaining
     */
    closable(show: boolean): HSUIWindow;

    /**
     * Show or hide the miniaturize (yellow) button on the window
Requires `.titled(true)` to be visible. Enabled by default.
     * @param show Pass `false` to hide the miniaturize button
     * @returns Self for chaining
     */
    miniaturizable(show: boolean): HSUIWindow;

    /**
     * Allow or prevent the user from resizing the window
Enabled by default. Only has a visual effect when `.titled(true)` is also set.
     * @param enable Pass `false` to prevent the user from resizing the window
     * @returns Self for chaining
     */
    allowResize(enable: boolean): HSUIWindow;

    /**
     * Set the text shown in the window's title bar
Only visible when `.titled(true)` is set (the default).
     * @param text The title bar text
     * @returns Self for chaining
     */
    windowTitle(text: string): HSUIWindow;

    /**
     * Set the window stacking level
Controls where this window sits in the macOS window hierarchy.
     * @param name The level name
     * @returns Self for chaining
     */
    level(name: '"normal"' | '"floating"' | '"screenSaver"' | '"dock"' | '"status"' | '"popUpMenu"'): HSUIWindow;

    /**
     * Set the window's background color
     * @param colorValue Color as an HSColor object
     * @returns Self for chaining
     */
    backgroundColor(colorValue: HSColor): HSUIWindow;

    /**
     * Add a rectangle shape
     * @returns Self for chaining (apply modifiers like `fill()`, `frame()`)
     */
    rectangle(): HSUIWindow;

    /**
     * Add a circle shape
     * @returns Self for chaining (apply modifiers like `fill()`, `frame()`)
     */
    circle(): HSUIWindow;

    /**
     * Add a text element
or an `HSString` object (from `hs.ui.string()`) for reactive text
     * @param content The text to display — a plain JS string for static text,
     * @returns Self for chaining (apply modifiers like `font()`, `foregroundColor()`)
     */
    text(content: string | HSString): HSUIWindow;

    /**
     * Add an inline multi-color text element. The content is an `HSString`
whose value is a JSON-encoded array of `{ text, accent }` segments;
segments render as one concatenated SwiftUI Text with per-segment
color. Use for per-character match highlighting where some letters
(the matched query chars) get the accent color.
JSON segments. The segment shape is `[{ text: string, accent: bool }, …]`.
     * @param content A plain JS string OR an `HSString` carrying the
     * @returns Self for chaining (apply `.font()`, `.foregroundColor()` for
     */
    attributedText(content: any): HSUIWindow;

    /**
     * Set the accent color used for `accent: true` segments inside an
`attributedText()` element. No effect on other elements.
     * @param colorValue Color as hex string or HSColor
     * @returns Self for chaining
     */
    accentColor(colorValue: any): HSUIWindow;

    /**
     * Add an image element
     * @param imageValue Image as HSImage object
     * @returns Self for chaining (apply modifiers like `resizable()`, `aspectRatio()`, `frame()`)
     */
    image(imageValue: HSImage): HSUIWindow;

    /**
     * Add a button element
or an `HSString` object (from `hs.ui.string()`) for reactive text
     * @param label The button label — a plain JS string for static text,
     * @returns Self for chaining (apply `.fill()`, `.cornerRadius()`, `.font()`,
     */
    button(label: string | HSString): HSUIWindow;

    /**
     * Add a single-line text input field
(from `hs.ui.string()`). When you pass an HSString, the field is two-way
bound: typing updates the HSString and `hsString.set(...)` updates the field.
     * @param initial The initial value — a plain JS string OR an `HSString`
     * @returns Self for chaining (apply `.placeholder()`, `.focused()`,
     */
    textField(initial: any): HSUIWindow;

    /**
     * Set placeholder text for the current text field (greyed-out hint when empty)
     * @param text The placeholder string
     * @returns Self for chaining
     */
    placeholder(text: string): HSUIWindow;

    /**
     * Control whether the current text field grabs first-responder when shown.
Default is true.
     * @param enabled true to autofocus
     * @returns Self for chaining
     */
    focused(enabled: boolean): HSUIWindow;

    /**
     * Register a callback that fires whenever the current text field's value changes.
Called with the new string.
     * @param callback `(value: string) => void`
     * @returns Self for chaining
     */
    onChange(callback: any): HSUIWindow;

    /**
     * Register a callback that fires when the current text field submits (Enter pressed
and not consumed by `onKey`). Called with the current value.
     * @param callback `(value: string) => void`
     * @returns Self for chaining
     */
    onSubmit(callback: any): HSUIWindow;

    /**
     * Begin a vertical stack (elements arranged top to bottom)
     * @returns Self for chaining (call `end()` when done)
     */
    vstack(): HSUIWindow;

    /**
     * Begin a horizontal stack (elements arranged left to right)
     * @returns Self for chaining (call `end()` when done)
     */
    hstack(): HSUIWindow;

    /**
     * Begin a z-stack (overlapping elements)
     * @returns Self for chaining (call `end()` when done)
     */
    zstack(): HSUIWindow;

    /**
     * Add flexible spacing that expands to fill available space
     * @returns Self for chaining
     */
    spacer(): HSUIWindow;

    /**
     * Embed a web browser element created with `hs.ui.webview()` (macOS 26+)
The element fills the available space in the window layout.
Keep a reference to the element to call navigation methods after the window is shown.
     * @param element A `UIWebView` created via `hs.ui.webview()`
     * @returns Self for chaining
     */
    webview(element: UIWebView): HSUIWindow;

    /**
     * End the current layout container
     * @returns Self for chaining
     */
    end(): HSUIWindow;

    /**
     * Fill a shape with a color
     * @param colorValue Color as an HSColor
     * @returns Self for chaining
     */
    fill(colorValue: HSColor): HSUIWindow;

    /**
     * Add a stroke (border) to a shape
     * @param colorValue Color as an HSColor
     * @returns Self for chaining
     */
    stroke(colorValue: HSColor): HSUIWindow;

    /**
     * Set the stroke width
     * @param width Width in points
     * @returns Self for chaining
     */
    strokeWidth(width: number): HSUIWindow;

    /**
     * Round the corners of a shape
     * @param radius Corner radius in points
     * @returns Self for chaining
     */
    cornerRadius(radius: number): HSUIWindow;

    /**
     * Set the frame (size) of an element
     * @param dict Dictionary with `w` and/or `h` (can be numbers or percentage strings like "50%")
     * @returns Self for chaining
     */
    frame(dict: Record<string, any>): HSUIWindow;

    /**
     * Set the opacity of an element
     * @param value Opacity from 0.0 (transparent) to 1.0 (opaque)
     * @returns Self for chaining
     */
    opacity(value: number): HSUIWindow;

    /**
     * Set the font for a text element
     * @param font An HSFont object (e.g., `HSFont.title()`)
     * @returns Self for chaining
     */
    font(font: HSFont): HSUIWindow;

    /**
     * Set the text color
     * @param colorValue Color as HSColor
     * @returns Self for chaining
     */
    foregroundColor(colorValue: HSColor): HSUIWindow;

    /**
     * Make an image resizable (allows it to scale with frame size)
     * @returns Self for chaining
     */
    resizable(): HSUIWindow;

    /**
     * Set the aspect ratio mode for an image
     * @param mode "fit" (scales to fit within frame) or "fill" (scales to fill frame)
     * @returns Self for chaining
     */
    aspectRatio(mode: string): HSUIWindow;

    /**
     * Add padding around a layout container
     * @param value Padding in points
     * @returns Self for chaining
     */
    padding(value: number): HSUIWindow;

    /**
     * Set spacing between elements in a stack
     * @param value Spacing in points
     * @returns Self for chaining
     */
    spacing(value: number): HSUIWindow;

    /**
     * Set a callback to fire when the element is clicked
     * @param callback A JavaScript function to call on click
     * @returns Self for chaining
     */
    onClick(callback: () => void): HSUIWindow;

    /**
     * Set a callback to fire when the cursor enters or leaves the element
     * @param callback A JavaScript function called with `true` when the cursor enters and `false` when it leaves
     * @returns Self for chaining
     */
    onHover(callback: (isHovering: boolean) => void): HSUIWindow;

    /**
     * Remove the window's title bar and chrome, making it completely borderless.
     * @returns Self for chaining
     */
    borderless(): HSUIWindow;

    /**
     * Center the window on the main screen when shown.
     * @returns Self for chaining
     */
    center(): HSUIWindow;

    /**
     * Anchor the window to an edge of the active screen's *visible* area —
the region excluding the menu bar and Dock — centered on the cross axis.
Use this instead of `center()` for status/HUD strips that should sit out
of the way at the bottom (or top) rather than over your content.
     * @param edge 'bottom', 'top', or 'center'
     * @returns Self for chaining
     */
    anchor(edge: string): HSUIWindow;

    /**
     * Control whether the window can become the key window (receive keyboard events).
     * @param enabled true to allow the window to become key
     * @returns Self for chaining
     */
    canBecomeKey(enabled: boolean): HSUIWindow;

    /**
     * Make the window click-through: mouse events pass straight to whatever is beneath it.
Essential for a transparent full-screen overlay (otherwise it would swallow every click).
     * @param enabled true to ignore mouse events (overlay/HUD); false for a normal window
     * @returns Self for chaining
     */
    ignoresMouseEvents(enabled: boolean): HSUIWindow;

    /**
     * Register a callback that fires on local key events while this window is key.
and modifiers is an array of strings like 'shift', 'cmd', etc.
     * @param callback Function called with (key, modifiers) where key is a character string
     * @returns Self for chaining
     */
    onKey(callback: any): HSUIWindow;

    /**
     * Register a callback that fires when the window loses key status (blurs).
     * @param callback Function to invoke when the window resigns key
     * @returns Self for chaining
     */
    onBlur(callback: any): HSUIWindow;

    /**
     * Round the window's outer corners (Spotlight/Raycast popup look).
Applies layer cornerRadius + masksToBounds to the window's content view
and makes the NSWindow background fully transparent so the corners
outside the rounded shape are see-through.
     * @param radius Corner radius in points. 0 disables rounding.
     * @returns Self for chaining
     */
    windowCornerRadius(radius: number): HSUIWindow;

}

/**
 * # HSUIAlert
**A temporary on-screen notification**
Displays a message that automatically fades out after a specified duration.
Positioned in the center of the screen with a semi-transparent background.
## Example
```javascript
hs.ui.alert("Task completed!")
    .font(HSFont.headline())
    .duration(5)
    .padding(30)
    .show();
```
 */
declare class HSUIAlert {
    /**
     * Set the font for the alert text
     * @param font An HSFont object (e.g., `HSFont.headline()`)
     * @returns Self for chaining
     */
    font(font: HSFont): HSUIAlert;

    /**
     * Set how long the alert is displayed
     * @param seconds Duration in seconds (default: 5.0)
     * @returns Self for chaining
     */
    duration(seconds: number): HSUIAlert;

    /**
     * Set the padding around the alert text
     * @param points Padding in points (default: 20)
     * @returns Self for chaining
     */
    padding(points: number): HSUIAlert;

    /**
     * Set a custom position for the alert
     * @param dict Dictionary with `x` and `y` coordinates
     * @returns Self for chaining
     */
    position(dict: Record<string, any>): HSUIAlert;

    /**
     * Show the alert
     * @returns Self for chaining (can store reference to close manually)
     */
    show(): HSUIAlert;

    /**
     * Close the alert immediately
     */
    close(): void;

}

/**
 * # HSUIDialog
**A modal dialog with customizable buttons**
Shows a blocking dialog with a message, optional informative text, and custom buttons.
Use the callback to respond to button presses.
## Example
```javascript
hs.ui.dialog("Save changes?")
    .informativeText("Your document has unsaved changes.")
    .buttons(["Save", "Don't Save", "Cancel"])
    .onButton((index) => {
        if (index === 0) {
            console.log("Saving...");
        } else if (index === 1) {
            console.log("Discarding changes...");
        }
    })
    .show();
```
 */
declare class HSUIDialog {
    /**
     * Set additional informative text below the main message
     * @param text The informative text
     * @returns Self for chaining
     */
    informativeText(text: string): HSUIDialog;

    /**
     * Set custom button labels
     * @param labels Array of button labels (default: ["OK"])
     * @returns Self for chaining
     */
    buttons(labels: string[]): HSUIDialog;

    /**
     * Set the dialog style
     * @param style Style name (e.g., "informational", "warning", "critical")
     * @returns Self for chaining
     */
    style(style: string): HSUIDialog;

    /**
     * Set the callback for button presses
     * @param callback Function receiving the 0-based index of the button the user pressed
     * @returns Self for chaining
     */
    onButton(callback: (buttonIndex: number) => void): HSUIDialog;

    /**
     * Show the dialog
     * @returns Self for chaining
     */
    show(): HSUIDialog;

    /**
     * Close the dialog programmatically
     */
    close(): void;

}

/**
 * # HSUIFilePicker
**A file or directory selection dialog**
Shows a standard macOS open panel for selecting files or directories. Supports
multiple selection, file type filtering, and more.
## Examples
### File Picker
```javascript
hs.ui.filePicker()
    .message("Choose a file to open")
    .allowedFileTypes(["txt", "md", "js"])
    .onSelection((path) => {
        if (path) {
            console.log("Selected: " + path);
        } else {
            console.log("User cancelled");
        }
    })
    .show();
```
### Directory Picker with Multiple Selection
```javascript
hs.ui.filePicker()
    .message("Choose directories to backup")
    .canChooseFiles(false)
    .canChooseDirectories(true)
    .allowsMultipleSelection(true)
    .onSelection((paths) => {
        if (paths) {
            paths.forEach(p => console.log("Dir: " + p));
        }
    })
    .show();
```
 */
declare class HSUIFilePicker {
    /**
     * Set the message displayed in the picker
     * @param text The message text
     * @returns Self for chaining
     */
    message(text: string): HSUIFilePicker;

    /**
     * Set the starting directory
     * @param path Path to directory (supports `~` for home)
     * @returns Self for chaining
     */
    defaultPath(path: string): HSUIFilePicker;

    /**
     * Set whether files can be selected
     * @param value true to allow file selection (default: true)
     * @returns Self for chaining
     */
    canChooseFiles(value: boolean): HSUIFilePicker;

    /**
     * Set whether directories can be selected
     * @param value true to allow directory selection (default: false)
     * @returns Self for chaining
     */
    canChooseDirectories(value: boolean): HSUIFilePicker;

    /**
     * Set whether multiple items can be selected
     * @param value true to allow multiple selection (default: false)
     * @returns Self for chaining
     */
    allowsMultipleSelection(value: boolean): HSUIFilePicker;

    /**
     * Restrict to specific file types
     * @param types Array of file extensions (e.g., ["txt", "md"])
     * @returns Self for chaining
     */
    allowedFileTypes(types: string[]): HSUIFilePicker;

    /**
     * Set whether to resolve symbolic links
     * @param value true to resolve aliases (default: true)
     * @returns Self for chaining
     */
    resolvesAliases(value: boolean): HSUIFilePicker;

    /**
     * Set the callback for file selection
     * @param callback Function receiving the selected path(s) or null if cancelled. Single selection receives a string; multiple selection receives an array of strings.
     * @returns Self for chaining
     */
    onSelection(callback: (paths: string | string[] | null) => void): HSUIFilePicker;

    /**
     * Show the file picker dialog
     */
    show(): void;

}

/**
 * # HSUITextPrompt
**A modal dialog with text input**
Shows a blocking dialog with a text input field. The callback receives both the
button index and the entered text.
## Example
```javascript
hs.ui.textPrompt("Enter your name")
    .informativeText("Please provide your full name")
    .defaultText("John Doe")
    .buttons(["OK", "Cancel"])
    .onButton((buttonIndex, text) => {
        if (buttonIndex === 0) {
            console.log("User entered: " + text);
        }
    })
    .show();
```
 */
declare class HSUITextPrompt {
    /**
     * Set additional informative text below the main message
     * @param text The informative text
     * @returns Self for chaining
     */
    informativeText(text: string): HSUITextPrompt;

    /**
     * Set the default text in the input field
     * @param text Default text value
     * @returns Self for chaining
     */
    defaultText(text: string): HSUITextPrompt;

    /**
     * Set custom button labels
     * @param labels Array of button labels (default: ["OK", "Cancel"])
     * @returns Self for chaining
     */
    buttons(labels: string[]): HSUITextPrompt;

    /**
     * Set the callback for button presses
     * @param callback Function receiving the 0-based button index and the text the user entered
     * @returns Self for chaining
     */
    onButton(callback: (buttonIndex: number, inputText: string) => void): HSUITextPrompt;

    /**
     * Show the prompt dialog
     */
    show(): void;

}

/**
 * # hs.ui.webview
**A web browser element for embedding in `hs.ui.window` layouts**
Available on macOS 26.0 or later, `hs.ui.webview()` creates a web browser element backed
by a SwiftUI `WebView` and `WebPage`. Embed it in any `hs.ui.window` using
`.webview(element)` — it fills the available space and can sit alongside other elements in
stacks.
```javascript
const wv = hs.ui.webview()
    .toolbar(["back", "forward", "reload", "url"])
    .loadURL("https://apple.com")

hs.ui.window({x: 100, y: 100, w: 1024, h: 768})
    .titled(true)
    .closable(true)
    .allowResize(true)
    .level("normal")
    .webview(wv)
    .show()
```
Because `wv` is a regular JavaScript object you can keep a reference and call navigation
```javascript
wv.loadURL("https://google.com")
wv.goBack()
```
## Custom Toolbar Example
```javascript
const wv = hs.ui.webview()
    .toolbar([
        "back", "forward", "reload", "url",
        {title: "Home", systemImage: "house", callback: () => wv.loadURL("https://apple.com")},
        {title: "Reload HS", callback: () => hs.reload()}
    ])
    .loadURL("https://apple.com")

hs.ui.window({x: 100, y: 100, w: 1024, h: 768})
    .webview(wv)
    .show()
```
## Full Example with Callbacks
```javascript
const wv = hs.ui.webview()
    .toolbar(["back", "forward", "reload", "url"])
    .inspectable(true)
    .onNavigate((url) => console.log("Navigated to: " + url))
    .onTitleChange((title) => console.log("Title: " + title))
    .onLoadChange((loading, url, title, progress) => {
        if (!loading) console.log("Page ready: " + url)
    })
    .loadURL("https://apple.com")

hs.ui.window({x: 100, y: 100, w: 1024, h: 768})
    .webview(wv)
    .show()
```
## Navigation Policy Example
```javascript
const wv = hs.ui.webview()
    .toolbar(["back", "forward", "reload", "url"])
    .onNavigationDecision((url) => {
        return !url.includes("evil.com")
    })
    .loadURL("https://apple.com")

hs.ui.window({x: 100, y: 100, w: 1024, h: 768})
    .webview(wv)
    .show()
```
## JavaScript Evaluation Example
```javascript
const wv = hs.ui.webview().loadURL("https://apple.com")
hs.ui.window({x: 100, y: 100, w: 1024, h: 768}).webview(wv).show()

// Fire and forget
wv.execJS("document.body.style.backgroundColor = 'lightyellow'")

// With result (note the JS method name is evalJSResult)
wv.evalJSResult("document.title", (result, error) => {
    if (error) { console.log("Error: " + error) }
    else { console.log("Title: " + result) }
})
```
 */
declare class UIWebView {
    /**
     * Load a URL in the web view
     * @param urlString The URL to load (e.g. "https://apple.com")
     * @returns Self for chaining
     */
    loadURL(urlString: string): UIWebView;

    /**
     * Load an HTML string directly into the web view
     * @param html The HTML content to display
     * @returns Self for chaining
     */
    loadHTML(html: string): UIWebView;

    /**
     * Navigate back in the browser history
     * @returns Self for chaining
     */
    goBack(): UIWebView;

    /**
     * Navigate forward in the browser history
     * @returns Self for chaining
     */
    goForward(): UIWebView;

    /**
     * Reload the current page
     * @returns Self for chaining
     */
    reload(): UIWebView;

    /**
     * Stop loading the current page
     * @returns Self for chaining
     */
    stopLoading(): UIWebView;

    /**
     * Set a custom User-Agent string for HTTP requests
     * @param ua The User-Agent string
     * @returns Self for chaining
     */
    userAgent(ua: string): UIWebView;

    /**
     * Enable or disable the Safari Web Inspector for this web view
When enabled, the web view appears in Safari → Develop menu.
     * @param value Pass `true` to enable the Web Inspector
     * @returns Self for chaining
     */
    inspectable(value: boolean): UIWebView;

    /**
     * Configure the toolbar with a list of standard and custom items
The toolbar renders above the web view. Each element of the array is either a string
naming a standard control or a dictionary describing a custom button.
An empty array (or omitting this call) hides the toolbar.
Standard string items: `"back"`, `"forward"`, `"reload"`, `"url"`, `"spacer"`.
     * @remarks The toolbar will not be shown if the web view is in a borderless window
     * @param items Toolbar items in display order
     * @returns Self for chaining
     */
    toolbar(items: Array<string | {title?: string, systemImage?: string, callback: () => void}>): UIWebView;

    /**
     * Enable or disable the macOS back/forward trackpad swipe gestures
Gestures are enabled by default. Pass `false` to disable them.
     * @param enabled Pass `false` to disable back/forward swipe gestures
     * @returns Self for chaining
     */
    backForwardGestures(enabled: boolean): UIWebView;

    /**
     * Enable or disable the trackpad pinch-to-zoom magnification gesture
The gesture is enabled by default. Pass `false` to disable it.
     * @param enabled Pass `false` to disable pinch-to-zoom
     * @returns Self for chaining
     */
    magnificationGestures(enabled: boolean): UIWebView;

    /**
     * Enable or disable link preview popovers shown on force-click
Link previews are enabled by default. Pass `false` to disable them.
     * @param enabled Pass `false` to disable link previews
     * @returns Self for chaining
     */
    linkPreviews(enabled: boolean): UIWebView;

    /**
     * Control whether the web page background is visible
Pass `false` to make the web view background transparent. Enabled (visible) by default.
     * @param visible Pass `false` to hide the web content background
     * @returns Self for chaining
     */
    contentBackground(visible: boolean): UIWebView;

    /**
     * Register a callback that fires when loading state or progress changes
Called whenever `isLoading`, `url`, `title`, or `estimatedProgress` changes.
     * @param callback Called with current loading state
     * @returns Self for chaining
     */
    onLoadChange(callback: (isLoading: boolean, url: string | null, title: string, progress: number) => void): UIWebView;

    /**
     * Register a callback that fires when navigation to a new page completes
     * @param callback Called with the final URL
     * @returns Self for chaining
     */
    onNavigate(callback: (url: string) => void): UIWebView;

    /**
     * Register a callback that fires when the page title changes
     * @param callback Called with the new title
     * @returns Self for chaining
     */
    onTitleChange(callback: (title: string) => void): UIWebView;

    /**
     * Register a callback that controls whether navigation is allowed
Called before each navigation. Return `true` to allow or `false` to block.
     * @param callback Return `true` to allow, `false` to block
     * @returns Self for chaining
     */
    onNavigationDecision(callback: (url: string) => boolean): UIWebView;

    /**
     * Execute JavaScript in the web page without capturing the result
     * @param script The JavaScript code to execute
     * @returns Self for chaining
     */
    execJS(script: string): UIWebView;

    /**
     * Execute JavaScript in the web page and deliver the result to a callback
The JavaScript method name is `evalJSResult` — it derives from the internal
Objective-C selector `evalJS:result:`.
     * @param script The JavaScript expression to evaluate
     * @param callback Called with the result or an error message
     * @returns Self for chaining
     */
    evalJSResult(script: string, callback: (result: any, error: string | null) => void): UIWebView;

    /**
     * The URL of the current page, or `null` if no page is loaded
     */
    readonly url: string | null;

    /**
     * The title of the current page
     */
    readonly title: string;

    /**
     * Whether the web view is currently loading a page
     */
    readonly isLoading: boolean;

    /**
     * The estimated loading progress from 0.0 to 1.0
     */
    readonly estimatedProgress: number;

    /**
     * Whether the web view can navigate back in history
     */
    readonly canGoBack: boolean;

    /**
     * Whether the web view can navigate forward in history
     */
    readonly canGoForward: boolean;

}

/**
 * Handle URL events received by Hammerspoon 2.
The module responds to `hammerspoon2://` URLs and, when Hammerspoon 2 is
configured as the system default handler, also to `http://`, `https://`,
and `mailto:` URLs.
## Responding to custom hammerspoon2:// events
URLs take the form `hammerspoon2://eventName?key=value&key2=value2`.
The host component (`eventName`) selects the registered callback.
```js
hs.urlevent.bind("myEvent", (eventName, params, pid, url) => {
    console.log("param foo = " + params["foo"])
})

// Remove a binding
hs.urlevent.bind("myEvent", null)
```
## Intercepting http / https / mailto URLs
Set `hs.urlevent.httpCallback` (or `mailtoCallback`) to a function.
You must also set Hammerspoon 2 as the system default handler for the
relevant scheme — see `setDefaultHandler(_:_:)`.
```js
hs.urlevent.httpCallback = (scheme, host, params, fullURL, pid) => {
    // Forward to a real browser rather than swallowing the link
    hs.urlevent.openURLWithBundle(fullURL, "com.apple.safari")
}
```
## Querying and changing default handlers
```js
const current = hs.urlevent.getDefaultHandler("https")
console.log("Current HTTPS handler: " + current)

const all = hs.urlevent.getAllHandlersForScheme("https")
console.log("Available: " + all.join(", "))

hs.urlevent.setDefaultHandler("https", "com.apple.safari")
```
 */
declare namespace hs.urlevent {
    /**
     * Register or remove a callback for a named `hammerspoon2://` URL event.
The URL format is `hammerspoon2://eventName?key=value`. The host
component (`eventName`) selects the callback to invoke.
     * @param eventName The URL host component identifying the event.
     * @param callback A function receiving `(eventName, params, senderPID, fullURL)`, or `null` to remove any existing binding.
     */
    function bind(eventName: string, callback: ((eventName: string, params: Record<string, string>, senderPID: number, fullURL: string) => void) | null): void;

    /**
     * Open a URL using the system default application for its scheme.
     * @param urlString The URL to open.
     * @returns `true` if the URL was successfully dispatched.
     */
    function openURL(urlString: string): boolean;

    /**
     * Open a URL with a specific application identified by bundle ID.
     * @param urlString The URL to open.
     * @param bundleID Bundle identifier of the application to use.
     * @returns `true` if the URL was dispatched to the application.
     */
    function openURLWithBundle(urlString: string, bundleID: string): boolean;

    /**
     * Returns the bundle identifier of the default application for a URL scheme.
     * @param scheme The scheme to query, without `://` (e.g. `"https"`, `"mailto"`).
     * @returns The bundle identifier string, or `null` if none is registered.
     */
    function getDefaultHandler(scheme: string): string | null;

    /**
     * Returns all bundle identifiers capable of handling a URL scheme.
     * @param scheme The scheme to query, without `://` (e.g. `"https"`, `"mailto"`).
     * @returns An array of bundle identifier strings.
     */
    function getAllHandlersForScheme(scheme: string): string[];

    /**
     * Set the default application for a URL scheme.
macOS may display a confirmation dialog for sensitive schemes such as
`http` and `https`. For custom schemes (`hammerspoon2`) no dialog is shown.
     * @param scheme The scheme to configure, without `://` (e.g. `"https"`, `"mailto"`).
     * @param bundleID Bundle identifier of the application to set as default.
     * @returns `true` if the change was accepted by the system.
     */
    function setDefaultHandler(scheme: string, bundleID: string): boolean;

    /**
     * Callback invoked when Hammerspoon 2 receives an `http://` or `https://` URL.
Fires only when Hammerspoon 2 is the system default handler for `http`/`https`.
Assign `null` to remove the callback.
     */
    let httpCallback: ((scheme: string, host: string, params: Record<string, string>, fullURL: string, senderPID: number) => void) | null;

    /**
     * Callback invoked when Hammerspoon 2 receives a `mailto:` URL.
Fires only when Hammerspoon 2 is the system default handler for `mailto`.
Assign `null` to remove the callback.
     */
    let mailtoCallback: ((scheme: string, host: string, params: Record<string, string>, fullURL: string, senderPID: number) => void) | null;

}

/**
 */
declare namespace hs.vision {
    /**
     * Recognize text in an image (OCR), returning each detected line of text with its
position inside the image.
The position of each line is reported as percentages of the image's size with a
top-left origin — i.e. `x`/`y`/`w`/`h` can be used directly as CSS
`left`/`top`/`width`/`height` percentage values for a Live Text-style overlay.
`x`/`y`/`w`/`h` is only the axis-aligned bounding box, while `quad` carries the
rotated corner points (`tl`/`tr`/`br`/`bl`, each `{x, y}` in the same percent space,
with `tl→tr` running along the reading direction) and `angle` is the text's rotation
in degrees (clockwise, `0` = horizontal, `90` = reading top-to-bottom).
or an `HSImage` object
When omitted, the language is detected automatically.
     * @param image The image to analyse — either a file path string (`~` is expanded)
     * @param options Optional settings object:
     * @returns A Promise resolving to
     */
    function recognizeText(image: any, options: any): Promise<object>;

    /**
     * List the languages the text recognizer supports on this system.
`"accurate"` (default) or `"fast"` (the fast path supports fewer languages)
     * @param level Optional recognition level the query applies to —
     * @returns An array of language identifiers (e.g. `["en-US", "zh-Hans", ...]`)
     */
    function supportedTextLanguages(level: any): string[];

}

/**
 * A WKWebView hosted inside a borderless NSWindow, created via `hs.webview.create()`.
Provides a builder-style API for loading URLs or HTML, styling the window,
registering JS message handlers, evaluating JavaScript, and managing the window lifecycle.
 */
declare namespace hs.webview {
    /**
     * Create a new webview hosted in a borderless NSWindow.
     * @param rect `{ x, y, w, h }` in NSWindow coordinates
     * @returns an `HSWebview` configured to host a WKWebView. Chain
     */
    function create(rect: any): HSWebview | null;

}

/**
 * A WKWebView hosted inside a borderless NSWindow, created via `hs.webview.create()`.
Provides a builder-style API for loading URLs or HTML, styling the window,
registering JS message handlers, evaluating JavaScript, and managing the window lifecycle.
 */
declare class HSWebview {
    /**
     * Load a URL into the webview. Accepts `https://`, `http://`, and `file://` URLs.
File URLs must be absolute paths; tilde is expanded.
     * @param urlString the URL to load
     * @returns self for chaining
     */
    url(urlString: string): HSWebview;

    /**
     * Load HTML source directly into the webview.
     * @param html HTML source string
     * @param baseURL optional base URL (string) for resolving relative refs; null to use about:blank
     * @returns self for chaining
     */
    html(html: string, baseURL: any): HSWebview;

    /**
     * Reload the currently-loaded content.
     * @returns self for chaining
     */
    reload(): HSWebview;

    /**
     * Configure window chrome.
`transparent: true` makes the NSWindow opaque-bg false so the page's own background shows through.
     * @param opts `{ titled?, closable?, resizable?, miniaturizable?, transparent? }` — all optional booleans.
     * @returns self for chaining
     */
    windowStyle(opts: any): HSWebview;

    /**
     * Set the window level by name. Same vocabulary as `hs.ui.window.level()`.
     * @param name `'normal' | 'floating' | 'modal' | 'popup' | 'screensaver' | 'mainmenu' | 'status'`
     * @returns self for chaining
     */
    level(name: string): HSWebview;

    /**
     * Allow this window to become key (capture keyboard focus). Default true for webviews.
     * @param value whether the window can become key
     * @returns self for chaining
     */
    canBecomeKey(value: boolean): HSWebview;

    /**
     * Never activate Hammerspoon 2 when this window is shown or clicked. The
webview is hosted in a non-activating panel: the page still gets clicks
and drags but the frontmost app keeps focus throughout — what you want
for a toast or notification overlay.
Neither AppKit nor WebKit deliver pointer movement to a window that
can't become key (so CSS `:hover` and mouseenter/mouseleave are dead).
Instead, while the window is visible an event monitor publishes the
pointer to the page as `window.__hsPointer(x, y, inside)` (CSS pixel
coordinates, ~40 Hz, one `inside=false` call as the pointer leaves) —
define that function and hit-test (e.g. `document.elementFromPoint`)
to drive hover effects yourself.
Combine with `canBecomeKey(true)` for a Spotlight-style panel that takes
keyboard input while the previous app stays active, or with
`canBecomeKey(false)` so the page never captures keyboard at all.
Must be set before `show()`.
     * @param value true to host the webview in a non-activating panel
     * @returns self for chaining
     */
    nonActivating(value: boolean): HSWebview;

    /**
     * Make the window click-through: mouse events pass to whatever is beneath it. Essential for a
transparent, screen-covering HUD overlay so it never steals the user's input.
A click-through window's page never receives pointer movement either (CSS
`:hover` is dead), so — like `nonActivating(true)` — while the window is
visible an event monitor publishes the pointer to the page as
`window.__hsPointer(x, y, inside)` (CSS pixel coordinates, ~40 Hz, one
`inside=false` call as the pointer leaves). Define that function and
hit-test (e.g. `document.elementFromPoint`) to drive hover effects for
any host-side click handling (e.g. an eventtap consuming clicks over
reported keycap rects).
     * @param value true to ignore mouse events
     * @returns self for chaining
     */
    ignoresMouseEvents(value: boolean): HSWebview;

    /**
     * Make the window appear on every Space and stay put across Space switches (HUD overlay).
     * @param value true to join all Spaces (canJoinAllSpaces + stationary)
     * @returns self for chaining
     */
    canJoinAllSpaces(value: boolean): HSWebview;

    /**
     * Control the system window shadow. If never called, the window's shadow
is left entirely untouched (AppKit decides). Turn it off for
transparent overlays whose page draws its own CSS shadows — the system
shadow is computed from the window's opaque pixels and can show up as
a rectangular halo/edge around translucent content (backdrop-filter
regions especially).
     * @param value false to disable the system window shadow
     * @returns self for chaining
     */
    windowShadow(value: boolean): HSWebview;

    /**
     * Center the window on the main screen on `show()`.
     * @returns self for chaining
     */
    center(): HSWebview;

    /**
     * Set window corner radius. Applied to the contentView (clipped) so the
rounded shape is preserved when the window is transparent.
     * @param radius pixel radius
     * @returns self for chaining
     */
    windowCornerRadius(radius: number): HSWebview;

    /**
     * Set the background color used by the host NSWindow and content wrapper.
This color is what users see during the brief window between window
creation and the page's own background painting — set it to match your
page's body background to eliminate the "white flash" on open. Also
disables the WKWebView's own opaque background so the window color is
visible through any gaps before/around the page content.
     * @param color hex string (e.g. `'#18181C'`) or an `HSColor`
     * @returns self for chaining
     */
    backgroundColor(color: any): HSWebview;

    /**
     * Keep the page rendering even when the window is inactive or considered
not visible. By default WebKit suspends a page whose window is non-key /
occluded — for a transparent, click-through HUD overlay (which can never
become key) the compositor parks after a few seconds and JS-driven UI
changes stop painting. Pass `true` BEFORE `show()` to opt the page out
of that suspension (`WKPreferences.inactiveSchedulingPolicy = .none`).
     * @param value whether to keep rendering while inactive
     * @returns self for chaining
     */
    keepsRenderingWhenInactive(value: boolean): HSWebview;

    /**
     * Show the window. If already shown (or pre-warmed), activates the app,
makes the window key, and brings it to front.
     * @returns self for chaining
     */
    show(): HSWebview;

    /**
     * Build and load the page WITHOUT showing the window — a warm, off-screen
instance ready for an instant `show()`. The WKWebView spins up, the page
loads and renders, but the window is never ordered front and the app is
never activated (so it won't steal focus at boot). Pair with
`keepsRenderingWhenInactive(true)` so the never-visible page actually
paints instead of being suspended by WebKit. A later `show()` is then a
near-instant order-front of an already-rendered window.
     * @returns self for chaining
     */
    prewarm(): HSWebview;

    /**
     * Hide the window. Keeps the WKWebView and its loaded page in memory.
     * @returns self for chaining
     */
    hide(): HSWebview;

    /**
     * Close and destroy the window. Drops the WKWebView and frees handlers.
     */
    close(): void;

    /**
     * Bring the window to the foreground without reordering across spaces.
     * @returns self for chaining
     */
    bringToFront(): HSWebview;

    /**
     * Return the current on-screen frame as `{x, y, w, h}`, or null if not shown.
     * @returns `{x, y, w, h}` in NSWindow (bottom-left origin) coordinates, or null if not shown
     */
    currentFrame(): Record<string, number> | null;

    /**
     * Resize and/or move the on-screen window.
     * @param rect `{ x, y, w, h }` in NSWindow coordinates
     * @returns self for chaining
     */
    setFrame(rect: any): HSWebview;

    /**
     * Render the page to a PNG file at the given path. Uses WKWebView's own
`takeSnapshot`, which renders in the web content process — so it sees the
real page even when WebKit composites it out-of-process (GPU-accelerated
layers), where an AppKit `cacheDisplay` capture intermittently came back
blank/white. No Screen Recording permission is required. The capture is
asynchronous: pass a callback to learn when the file is written.
written; on failure `errorMessage` describes why. Pass `null` to skip.
     * @param path absolute filesystem path to write
     * @param callback optional `(ok, errorMessage)` — `ok` is true once the PNG is
     */
    snapshotToPNG(path: string, callback: any): void;

    /**
     * Register a named handler for messages posted from JS.
In the page, call `window.webkit.messageHandlers.<name>.postMessage(body)`.
The Swift callback fires with the deserialized body (object/string/number).
Pass `null` to unregister.
     * @param name handler name (matches the page's `messageHandlers.<name>`)
     * @param callback function to call with each message body, or null to remove
     * @returns self for chaining
     */
    setMessageHandler(name: string, callback: any): HSWebview;

    /**
     * Inject JavaScript that runs at document-start, before the page's own scripts.
Use to install a bridge client so postMessage calls work from page load.
     * @param source JavaScript source
     * @returns self for chaining
     */
    injectUserScript(source: string): HSWebview;

    /**
     * Evaluate a JS expression inside the page. Optional callback receives
`(result, errorMessage)` — result is the stringified JS value (null if
not representable as JSON), errorMessage is null on success.
     * @param script JS expression or block
     * @param callback optional completion `(result, error) => void`
     */
    evaluateJavaScript(script: string, callback: any): void;

    /**
     * Register a callback for window lifecycle events. Currently fires with
the string `'closing'` when the window is about to close.
     * @param callback `(event) => void`
     * @returns self for chaining
     */
    windowCallback(callback: any): HSWebview;

    /**
     * Register a callback for native file drops onto the webview. When set,
dragging files from Finder onto the page is handled natively and the
callback fires with an array of absolute filesystem paths — so you can
stream the real file from disk instead of reading its bytes through the
JS bridge. The page's own HTML5 `drop` event does NOT fire for files
while a handler is registered; non-file drags (text, images from other
apps) fall through to WebKit unchanged. While a file drag is over the
window the page is notified via `window.__hsFileDrag(active)` (a boolean)
so it can show a drop highlight. Pass `null` to unregister (file drops
then revert to the page's own HTML5 handling).
absolute file paths, or null to unregister
     * @param callback `(paths) => void` where `paths` is an array of
     * @returns self for chaining
     */
    onFileDrop(callback: any): HSWebview;

    /**
     * Test hook: invoke the registered `onFileDrop` callback directly with
`paths`, bypassing the AppKit drag session (which a unit test can't
stage). No-op if the webview isn't shown or no handler is registered.
     * @param paths absolute file paths to deliver to the handler
     */
    _simulateFileDrop(paths: string[]): void;

    /**
     * Enable Safari "Inspect Element" right-click for this webview. Off by default.
     * @param enabled whether to enable
     * @returns self for chaining
     */
    developerExtras(enabled: boolean): HSWebview;

}

/**
 * Module for interacting with windows
 */
declare namespace hs.window {
    /**
     * Get the currently focused window
     * @returns The focused window, or nil if none
     */
    function focusedWindow(): HSWindow | null;

    /**
     * Get all windows from all applications
     * @returns An array of all windows
     */
    function allWindows(): HSWindow[];

    /**
     * Get all visible (not minimized) windows
     * @returns An array of visible windows
     */
    function visibleWindows(): HSWindow[];

    /**
     * Get windows for a specific application
     * @param app An HSApplication object
     * @returns An array of windows for that application
     */
    function windowsForApp(app: HSApplication): HSWindow[];

    /**
     * Get all windows on a specific screen
     * @param screenIndex The screen index (0 for main screen)
     * @returns An array of windows on that screen
     */
    function windowsOnScreen(screenIndex: number): HSWindow[];

    /**
     * Get the window at a specific screen position
     * @param point An HSPoint containing the coordinates
     * @returns The topmost window at that position, or nil if none
     */
    function windowAtPoint(point: HSPoint): HSWindow | null;

    /**
     * Get ordered windows (front to back)
     * @returns An array of windows in z-order
     */
    function orderedWindows(): HSWindow[];

    /**
     * Get a snapshot of the live window registry — apps and their windows in
MRU order, populated from observers. Reads from cache; no AX calls on
the hot path. Use this in latency-sensitive code like switchers.
     * @returns An array of dictionaries: `[{pid, name, bundleID, iconBase64, windows: [{id, title}]}]`
     */
    function snapshot(): Record<string, any>[];

    /**
     * Find windows by title
Parameter title: The window title to search for. All windows with titles that include this string, will be matched
     * @param title The window title to search for. All windows with titles that include this string, will be matched
     * @returns An array of HSWindow objects with matching titles
     */
    function findByTitle(title: any): any;

    /**
     * Get all windows for the current application
     * @returns An array of HSWindow objects
     */
    function currentWindows(): any;

    /**
     * Move a window to left half of screen
Parameter win: An HSWindow object
     * @param win An HSWindow object
     * @returns True if the operation was successful, otherwise False
     */
    function moveToLeftHalf(win: any): any;

    /**
     * Move a window to right half of screen
Parameter win: An HSWindow object
     * @param win An HSWindow object
     * @returns True if the operation was successful, otherwise False
     */
    function moveToRightHalf(win: any): any;

    /**
     * Maximize a window
Parameter win: An HSWindow object
     * @param win An HSWindow object
     * @returns True if the operation was successful, otherwise false
     */
    function maximize(win: any): any;

    /**
     * SKIP_DOCS
     */
    function cycleWindows(): void;

}

/**
 * Object representing a window. You should not instantiate these directly, but rather, use the methods in hs.window to create them for you.
Note that this type uses private macOS APIs
 */
declare class HSWindow {
    /**
     * Focus this window
     * @returns true if successful
     */
    focus(): boolean;

    /**
     * Minimize this window
     * @returns true if successful
     */
    minimize(): boolean;

    /**
     * Unminimize this window
     * @returns true if successful
     */
    unminimize(): boolean;

    /**
     * Raise this window to the front
     * @returns true if successful
     */
    raise(): boolean;

    /**
     * Toggle fullscreen mode
     * @returns true if successful
     */
    toggleFullscreen(): boolean;

    /**
     * Close this window
     * @returns true if successful
     */
    close(): boolean;

    /**
     * Center the window on the screen
     */
    centerOnScreen(): void;

    /**
     * Get the underlying AXElement
     * @returns The accessibility element for this window
     */
    axElement(): HSAXElement;

    /**
     * The window's title
     */
    readonly title: string | null;

    /**
     * The application that owns this window
     */
    readonly application: HSApplication | null;

    /**
     * The process ID of the application that owns this window
     */
    readonly pid: number;

    /**
     * The window's underlying ID.
A value of 0 or -1 likely means no window ID could be determined.
     */
    readonly id: number;

    /**
     * Whether the window is minimized
     */
    isMinimized: boolean;

    /**
     * Whether the window is visible (not minimized or hidden)
     */
    readonly isVisible: boolean;

    /**
     * Whether the window is focused
     */
    readonly isFocused: boolean;

    /**
     * Whether the window is fullscreen
     */
    isFullscreen: boolean;

    /**
     * Whether the window is standard (has a titlebar)
     */
    readonly isStandard: boolean;

    /**
     * The window's position on screen {x: Int, y: Int}
     */
    position: HSPoint | null;

    /**
     * The window's size {w: Int, h: Int}
     */
    size: HSSize | null;

    /**
     * The window's frame {x: Int, y: Int, w: Int, h: Int}
     */
    frame: HSRect | null;

    /**
     * The screen that contains the largest portion of this window.
     */
    readonly screen: HSScreen | null;

}

