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
     * Update this color's value
     * @param value New color as a hex string (e.g. "#FF0000") or another HSColor object
     */
    static set(value: JSValue): void;

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
    .then(image => console.log("Image loaded:", image.size()))
    .catch(err => console.error("Failed to load image:", err))

// Or with async/await
const image = await HSImage.fromURL("https://example.com/image.png")
```
## Image Manipulation
```javascript
const img = HSImage.fromPath("/path/to/image.png")

// Get size
const size = img.size()  // Returns HSSize

// Resize image
const resized = img.setSize({w: 100, h: 100}, false)  // Proportional

// Crop image
const cropped = img.croppedCopy({x: 10, y: 10, w: 50, h: 50})

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
    static fromPath(path: string): HSImage | undefined;

    /**
     * Load a system image by name
     * @param name Name of the system image (e.g., "NSComputer", "NSFolder")
     * @returns An HSImage object, or null if the image couldn't be found
     */
    static fromName(name: string): HSImage | undefined;

    /**
     * Load an app's icon by bundle identifier
     * @param bundleID Bundle identifier of the application
     * @returns An HSImage object, or null if the app couldn't be found
     */
    static fromAppBundle(bundleID: string): HSImage | undefined;

    /**
     * Get the icon for a file
     * @param path Path to the file
     * @returns An HSImage object representing the file's icon
     */
    static iconForFile(path: string): HSImage | undefined;

    /**
     * Get the icon for a file type
     * @param fileType File extension or UTI (e.g., "png", "public.png")
     * @returns An HSImage object representing the file type's icon
     */
    static iconForFileType(fileType: string): HSImage | undefined;

    /**
     * Create an image from an SF Symbol name (e.g. "magnifyingglass",
"gearshape", "terminal", "arrow.up.right.square"). Returns nil if
the symbol name is not recognised by the system.
     * @param name SF Symbol identifier
     * @returns An HSImage wrapping the SF Symbol, or nil if the symbol name is not found
     */
    static fromSymbol(name: string): HSImage | undefined;

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
     * Get or set the image size
     * @param size Optional HSSize to set (if provided, returns a resized copy)
     * @returns The current size as HSSize, or a resized copy if size was provided
     */
    static size(size: JSValue): JSValue;

    /**
     * Get or set the image name
     * @param name Optional name to set
     * @returns The current or new name
     */
    static name(name: JSValue): string | undefined;

    /**
     * Create a resized copy of the image
     * @param size Target size as HSSize
     * @param absolute If true, resize exactly to specified dimensions. If false, maintain aspect ratio
     * @returns A new resized HSImage
     */
    static setSize(size: JSValue, absolute: boolean): HSImage | undefined;

    /**
     * Create a copy of the image
     * @returns A new HSImage copy
     */
    static copyImage(): HSImage | undefined;

    /**
     * Create a cropped copy of the image
     * @param rect HSRect defining the crop area
     * @returns A new cropped HSImage, or null if cropping failed
     */
    static croppedCopy(rect: JSValue): HSImage | undefined;

    /**
     * Save the image to a file
     * @param path Destination file path (extension determines format: png, jpg, tiff, bmp, gif)
     * @returns true if saved successfully, false otherwise
     */
    static saveToFile(path: string): boolean;

    /**
     * Get or set the template image flag
     * @param state Optional boolean to set template state
     * @returns Current template state
     */
    static template(state: JSValue): boolean;

    /**
     * Replace the image with a new one, triggering a re-render if bound to a UI element
     * @param value New image as an HSImage object or a file path string
     */
    static set(value: JSValue): void;

    /**
     * Encode the image to a base64 string.
(maximum quality). Ignored when `format` is `"png"`.
     * @param format `"jpeg"` or `"png"` (case-insensitive). Any other value is treated as `"png"`.
     * @param quality JPEG compression quality in the range `0.0` (maximum compression) to `1.0`
     * @returns A base64-encoded string of the encoded image data, or `null` if encoding failed.
     */
    static encode(format: string, quality: number): string | undefined;

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
    static set(newValue: string): void;

    /**
     * The current string value
     */
    value: string;

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
    function matchingName(name: string): HSApplication | undefined;

    /**
     * Fetch the first running application that matches a Bundle ID
     * @param bundleID The identifier to search for
     * @returns The first matching application, or nil if none matched
     */
    function matchingBundleID(bundleID: string): HSApplication | undefined;

    /**
     * Fetch the running application that matches a POSIX PID
     * @param pid The PID to search for
     * @returns The matching application, or nil if none matched
     */
    function fromPID(pid: number): HSApplication | undefined;

    /**
     * Fetch the currently focused application
     * @returns The matching application, or nil if none matched
     */
    function frontmost(): HSApplication | undefined;

    /**
     * Fetch the application which currently owns the menu bar
     * @returns The matching application, or nil if none matched
     */
    function menuBarOwner(): HSApplication | undefined;

    /**
     * Fetch the filesystem path for an application
     * @param bundleID The application bundle identifier to search for (e.g. "com.apple.Safari")
     * @returns The application's filesystem path, or nil if it was not found
     */
    function pathForBundleID(bundleID: string): string | undefined;

    /**
     * Render the application's icon as a base64-encoded PNG string. Use the
returned string as the body of a `data:image/png;base64,…` URL to render
the icon in HTML/SwiftUI without exposing the underlying .icns path.
Falls back to NSWorkspace's generic icon if no application is found.
     * @param bundleID The application bundle identifier (e.g. "com.apple.Safari")
     * @returns The base64-encoded PNG bytes, or null if the bundle could not be located
     */
    function iconForBundleID(bundleID: string): string | undefined;

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
    function pathForFileType(fileType: string): string | undefined;

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
5. Any caller-supplied extra roots
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
    function installedApps(extraRoots: JSValue): [[String: Any]];

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
    function addWatcher(listener: JSValue): void;

    /**
     * Remove a watcher for application events
     * @param listener The javascript function/lambda that was previously being used to handle events
     */
    function removeWatcher(listener: JSValue): void;

}

/**
 * Object representing an application. You should not instantiate this directly in JavaScript, but rather, use the methods from hs.application which will return appropriate HSApplication objects.
 */
declare class HSApplication {
    /**
     * Terminate the application
     * @returns True if the application was terminated, otherwise false
     */
    static kill(): boolean;

    /**
     * Force-terminate the application
     * @returns True if the application was force-terminated, otherwise false
     */
    static kill9(): boolean;

    /**
     * The application's HSAXElement object, for use with the hs.ax APIs
     * @returns An HSAXElement object, or nil if it could not be obtained
     */
    static axElement(): HSAXElement | undefined;

    /**
     * POSIX Process Identifier
     */
    pid: number;

    /**
     * Bundle Identifier (e.g. com.apple.Safari)
     */
    bundleID: string | undefined;

    /**
     * The application's title
     */
    title: string | undefined;

    /**
     * Location of the application on disk
     */
    bundlePath: string | undefined;

    /**
     * Is the application hidden
     */
    isHidden: boolean;

    /**
     * Is the application focused
     */
    isActive: boolean;

    /**
     * The main window of this application, or nil if there is no main window
     */
    mainWindow: HSWindow | undefined;

    /**
     * The focused window of this application, or nil if there is no focused window
     */
    focusedWindow: HSWindow | undefined;

    /**
     * All windows of this application
     */
    allWindows: HSWindow[];

    /**
     * All visible (ie non-hidden) windows of this application
     */
    visibleWindows: HSWindow[];

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
    function defaultOutputDevice(): HSAudioDevice | undefined;

    /**
     * The current system default input device.
     * @returns An HSAudioDevice, or null if none is set
     */
    function defaultInputDevice(): HSAudioDevice | undefined;

    /**
     * The current system alert sound device.
     * @returns An HSAudioDevice, or null if none is set
     */
    function defaultEffectDevice(): HSAudioDevice | undefined;

    /**
     * Find the first audio device whose name matches the given string.
     * @param name The device name to search for
     * @returns An HSAudioDevice if found, null otherwise
     */
    function findDeviceByName(name: string): HSAudioDevice | undefined;

    /**
     * Find the audio device with the given unique identifier.
     * @param uid The device UID to search for
     * @returns An HSAudioDevice if found, null otherwise
     */
    function findDeviceByUID(uid: string): HSAudioDevice | undefined;

    /**
     * Register a listener for all system-level audio configuration events.
     * @param listener A JavaScript function that receives the event name string
     */
    function addWatcher(listener: JSValue): void;

    /**
     * Remove a previously registered system-level listener.
     * @param listener The JavaScript function that was passed to ``addWatcher(_:)``
     */
    function removeWatcher(listener: JSValue): void;

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
    static currentOutputDataSource(): NSDictionary | undefined;

    /**
     * The current input data source as `{ id, name }`, or `null` if unavailable.
     * @returns A dictionary containing the id and name of the current input data source
     */
    static currentInputDataSource(): NSDictionary | undefined;

    /**
     * All available output data sources as an array of `{ id, name }` objects.
     * @returns A dictionary containing the ids and names of all available output data sources
     */
    static outputDataSources(): NSDictionary[];

    /**
     * All available input data sources as an array of `{ id, name }` objects.
     * @returns A dictionary containing the ids and names of all available input data sources
     */
    static inputDataSources(): NSDictionary[];

    /**
     * Select an output data source by its numeric ID.
     * @param sourceID The `id` value from ``outputDataSources()``
     * @returns `true` on success
     */
    static setCurrentOutputDataSource(sourceID: number): boolean;

    /**
     * Select an input data source by its numeric ID.
     * @param sourceID The `id` value from ``inputDataSources()``
     * @returns `true` on success
     */
    static setCurrentInputDataSource(sourceID: number): boolean;

    /**
     * Make this device the system default output device.
     * @returns `true` on success
     */
    static setDefaultOutputDevice(): boolean;

    /**
     * Make this device the system default input device.
     * @returns `true` on success
     */
    static setDefaultInputDevice(): boolean;

    /**
     * Make this device the system alert sound (effect) device.
     * @returns `true` on success
     */
    static setDefaultEffectDevice(): boolean;

    /**
     * Register a listener for a per-device property-change event.
     * @param listener A JavaScript function that receives an event name string
     */
    static addWatcher(listener: JSValue): void;

    /**
     * Remove a previously registered per-device listener.
     * @param listener The JavaScript function that was passed to ``addWatcher(_:)``
     */
    static removeWatcher(listener: JSValue): void;

    /**
     * The CoreAudio object ID of this device.
     */
    id: number;

    /**
     * The human-readable name of this device (e.g. `"Built-in Output"`).
     */
    name: string;

    /**
     * The persistent unique identifier for this device.
     */
    uid: string;

    /**
     * Whether this device has output streams (can play audio).
     */
    isOutput: boolean;

    /**
     * Whether this device has input streams (can record audio).
     */
    isInput: boolean;

    /**
     * The transport mechanism: `"built-in"`, `"usb"`, `"bluetooth"`, `"bluetooth-le"`,
`"hdmi"`, `"display-port"`, `"firewire"`, `"airplay"`, `"avb"`,
`"thunderbolt"`, `"virtual"`, `"aggregate"`, `"pci"`, or `"unknown"`.
     */
    transportType: string;

    /**
     * Number of output channels, or 0 if the device has no output.
     */
    outputChannels: number;

    /**
     * Number of input channels, or 0 if the device has no input.
     */
    inputChannels: number;

    /**
     * Output volume scalar in the range `0.0`–`1.0`, or `null` if the device has
no controllable output volume. Setting `null` is a no-op.
     */
    volume: NSNumber | undefined;

    /**
     * Whether output is muted. Always `false` if the device has no mutable output.
     */
    muted: boolean;

    /**
     * Output stereo balance in the range `0.0` (full left)–`1.0` (full right),
or `null` if balance control is not available.
     */
    balance: NSNumber | undefined;

    /**
     * Input (microphone) volume scalar in the range `0.0`–`1.0`, or `null` if
the device has no controllable input volume.
     */
    inputVolume: NSNumber | undefined;

    /**
     * Whether input is muted. Always `false` if the device has no mutable input.
     */
    inputMuted: boolean;

    /**
     * The current nominal sample rate in Hz (e.g. `44100`), or `null` if unknown.
     */
    sampleRate: NSNumber | undefined;

    /**
     * All sample rates (in Hz) that this device supports.
For devices that support a range, both the minimum and maximum are included.
     */
    availableSampleRates: NSNumber[];

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
    function systemWideElement(): HSAXElement | undefined;

    /**
     * Get the accessibility element for an application
     * @param element An HSApplication object
     * @returns The AXElement for the application, or nil if accessibility is not available
     */
    function applicationElement(element: HSApplication): HSAXElement | undefined;

    /**
     * Get the accessibility element for a window
     * @param window An HSWindow  object
     * @returns The AXElement for the window, or nil if accessibility is not available
     */
    function windowElement(window: HSWindow): HSAXElement | undefined;

    /**
     * Get the accessibility element at the specific screen position
     * @param point An HSPoint object containing screen coordinates
     * @returns The AXElement at that position, or nil if none found
     */
    function elementAtPoint(point: HSPoint): HSAXElement | undefined;

    /**
     * Add a watcher for application AX events
     * @param application An HSApplication object
     * @param notification An event name
     * @param listener A function/lambda to be called when the event is fired. The function/lambda will be called with two arguments: the name of the event, and the element it applies to
     */
    function addWatcher(application: HSApplication, notification: string, listener: JSValue): void;

    /**
     * Remove a watcher for application AX events
     * @param application An HSApplication object
     * @param notification The event name to stop watching
     * @param listener The function/lambda provided when adding the watcher
     */
    function removeWatcher(application: HSApplication, notification: string, listener: JSValue): void;

    /**
     * Fetch the focused UI element
     * @returns An HSAXElement representing the focused UI element, or null if none was found
     */
    function focusedElement(): any;

    /**
     * Find AX elements for a given role
     * @param role The role name to search for
     * @param parent An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
     * @returns An array of found elements
     */
    function findByRole(role: any, parent: any): any;

    /**
     * Find AX elements by title
     * @param title The name to search for
     * @param parent An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
     * @returns An array of found elements
     */
    function findByTitle(title: any, parent: any): any;

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

    /**
     * Fetch the focused UI element. Swift-retained storage for the JS implementation.
     */
    const focusedElement: JSValue | undefined;

    /**
     * Find AX elements by role. Swift-retained storage for the JS implementation.
     */
    const findByRole: JSValue | undefined;

    /**
     * Find AX elements by title. Swift-retained storage for the JS implementation.
     */
    const findByTitle: JSValue | undefined;

    /**
     * Print the element hierarchy. Swift-retained storage for the JS implementation.
     */
    const printHierarchy: JSValue | undefined;

}

/**
 * Object representing an Accessibility element. You should not instantiate this directly, but rather, use the hs.ax methods to create these as required.
 */
declare class HSAXElement {
    /**
     * The element's children
     * @returns An array of HSAXElement objects
     */
    static children(): HSAXElement[];

    /**
     * Get a specific child by index
     * @param index The index to fetch
     * @returns An HSAXElement object, if a child exists at the given index
     */
    static childAtIndex(index: number): HSAXElement | undefined;

    /**
     * Get all available attribute names
     * @returns An array of attribute names
     */
    static attributeNames(): string[];

    /**
     * Get the value of a specific attribute
     * @param attribute The attribute name to fetch the value for
     * @returns The requested value, or nil if none was found
     */
    static attributeValue(attribute: string): any | undefined;

    /**
     * Set the value of a specific attribute
     * @param attribute The attribute name to set
     * @param value The value to set
     * @returns True if the operation succeeded, otherwise False
     */
    static setAttributeValue(attribute: string, value: any): boolean;

    /**
     * Check if an attribute is settable
     * @param attribute An attribute name
     * @returns True if the attribute is settable, otherwise False
     */
    static isAttributeSettable(attribute: string): boolean;

    /**
     * Get all available action names
     * @returns An array of available action names
     */
    static actionNames(): string[];

    /**
     * Perform a specific action
     * @param action The action to perform
     * @returns True if the action succeeded, otherwise False
     */
    static performAction(action: string): boolean;

    /**
     * The element's role (e.g., "AXWindow", "AXButton")
     */
    role: string | undefined;

    /**
     * The element's subrole
     */
    subrole: string | undefined;

    /**
     * The element's title
     */
    title: string | undefined;

    /**
     * The element's value
     */
    value: any | undefined;

    /**
     * The element's description
     */
    elementDescription: string | undefined;

    /**
     * Whether the element is enabled
     */
    isEnabled: boolean;

    /**
     * Whether the element is focused
     */
    isFocused: boolean;

    /**
     * The element's position on screen
     */
    position: HSPoint | undefined;

    /**
     * The element's size
     */
    size: HSSize | undefined;

    /**
     * The element's frame (position and size combined)
     */
    frame: HSRect | undefined;

    /**
     * The element's parent
     */
    parent: HSAXElement | undefined;

    /**
     * Get the process ID of the application that owns this element
     */
    pid: number;

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
    static onState(cb: JSValue): HSBLECentral;

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
    static connect(config: Record<string, any>): HSBLEPeripheral;

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
    static onConnect(cb: JSValue): HSBLEPeripheral;

    /**
     * Register a callback fired when the peripheral disconnects.
     * @param cb `function(reason)` — `reason` is the disconnect error text, or `"clean"`.
     * @returns self, for chaining.
     */
    static onDisconnect(cb: JSValue): HSBLEPeripheral;

    /**
     * Register a callback fired for each notify payload from the controller.
     * @param cb `function(line)` — `line` is the UTF-8 payload (a JSON string the relay layer parses).
     * @returns self, for chaining.
     */
    static onNotify(cb: JSValue): HSBLEPeripheral;

    /**
     * Write a line to the relay write characteristic (target → controller), `.withoutResponse`.
     * @param s the UTF-8 payload (caller-supplied JSON; keep it under the ATT MTU, ~240 B).
     * @returns `true` if queued; `false` if not connected or the payload exceeds the MTU.
     */
    static write(s: string): boolean;

    /**
     * Disconnect the peripheral and stop auto-reconnect.
     */
    static disconnect(): void;

    /**
     * The peripheral's system UUID. Persist this (e.g. in your config) and pass it
back as `connect({ peerUUID })` for instant re-attach to the non-advertising
bonded peer. Empty until first connected.
     */
    uuid: string;

}

/**
 * Discover and publish Bonjour (mDNS / Zeroconf) network services.
Use `newSearch()` to search the network for services advertised by other
devices, and `advertise()` to advertise your own. The `networkServices()`
convenience function returns a snapshot of all service types currently
active on the local network.
## Common service type strings
The `hs.bonjour.serviceTypes` object maps short names to their mDNS strings,
e.g. `hs.bonjour.serviceTypes.ssh` → `"_ssh._tcp."`.
## Searching for a service
```js
// Find all SSH services on the local network and resolve each one
const search = hs.bonjour.newSearch()
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
    function newSearch(): HSBonjourSearch;

    /**
     * Stops and removes a previously created search.
     * @param search the search returned by `newSearch()`
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
     * @param domain mDNS domain; defaults to `"local."` if omitted
     * @param callback optional `function(event, data?)` called on status changes
     */
    function advertise(name: string, type: string, port: Int32, domain: JSValue, callback: JSValue): void;

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
     * @param callback `function(event, service, moreComing)` called for each result
     * @returns self, for chaining
     */
    static findServices(type: string, domain: string, callback: JSValue): HSBonjourSearch;

    /**
     * Searches for domains visible to this machine (browsable domains).
If a browsable-domain search is already active it is stopped before
starting the new one. Service and registration-domain searches are
unaffected. The callback receives `(event, domain, moreComing)`.
     * @param callback `function(event, domain, moreComing)` called for each result
     * @returns self, for chaining
     */
    static findBrowsableDomains(callback: JSValue): HSBonjourSearch;

    /**
     * Searches for domains on which this machine can register services.
If a registration-domain search is already active it is stopped before
starting the new one. Service and browsable-domain searches are
unaffected. The callback receives `(event, domain, moreComing)`.
     * @param callback `function(event, domain, moreComing)` called for each result
     * @returns self, for chaining
     */
    static findRegistrationDomains(callback: JSValue): HSBonjourSearch;

    /**
     * Stops all active searches. Safe to call when no search is active.
     * @returns self, for chaining
     */
    static stop(): HSBonjourSearch;

    /**
     * A unique identifier for this search object.
     */
    identifier: string;

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
     * @param callback `function(event, data?)` called on status changes
     * @returns self, for chaining
     */
    static resolve(timeout: number, callback: JSValue): HSBonjourService;

    /**
     * Starts monitoring the TXT record for changes. The callback fires whenever
the TXT record is updated.
Call `stopMonitoring()` to unsubscribe.
     * @param callback `function(txtRecord)` called when TXT data changes
     * @returns self, for chaining
     */
    static monitor(callback: JSValue): HSBonjourService;

    /**
     * Stops any active resolution.
     * @returns self, for chaining
     */
    static stop(): HSBonjourService;

    /**
     * Stops TXT record monitoring started by `monitor()`.
     * @returns self, for chaining
     */
    static stopMonitoring(): HSBonjourService;

    /**
     * A unique identifier assigned to this service object.
     */
    identifier: string;

    /**
     * The service name (e.g. `"My Web Server"`).
     */
    name: string;

    /**
     * The service type string (e.g. `"_http._tcp."`).
     */
    type: string;

    /**
     * The mDNS domain (almost always `"local."`).
     */
    domain: string;

    /**
     * The resolved hostname, or `null` before `resolve()` completes.
     */
    hostname: string | undefined;

    /**
     * The service port. `-1` until `resolve()` completes.
     */
    port: number;

    /**
     * IP address strings (IPv4 and/or IPv6) populated after `resolve()` completes.
     */
    addresses: string[];

    /**
     * The TXT record as a `{key: value}` object, or `null` if none is available.
Populated after `resolve()` completes or when updated via `monitor()`.
     */
    txtRecord: Record<string, string> | undefined;

    /**
     * Whether peer-to-peer Bluetooth/Wi-Fi is included in resolution.
     */
    includesPeerToPeer: boolean;

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
    function findByName(name: string): HSCamera | undefined;

    /**
     * Find the camera with the given unique identifier.
     * @param uid The device UID to search for
     * @returns An `HSCamera` if found, `null` otherwise
     */
    function findByUID(uid: string): HSCamera | undefined;

    /**
     * Register a listener for camera device connect/disconnect events.
     * @param listener A JavaScript function receiving `(event: string, camera: HSCamera)`
     */
    function addWatcher(listener: JSValue): void;

    /**
     * Remove a previously registered module-level event listener.
     * @param listener The function originally passed to ``addWatcher(_:)``
     */
    function removeWatcher(listener: JSValue): void;

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
     * @param listener A JavaScript function receiving `(isInUse: boolean)`
     */
    static addWatcher(listener: JSValue): void;

    /**
     * Remove a previously registered per-camera in-use listener.
     * @param listener The function originally passed to ``addWatcher(_:)``
     */
    static removeWatcher(listener: JSValue): void;

    /**
     * Capture a still image from this camera.
Camera permission must be granted via `hs.permissions.requestCamera()` before calling
this method. The returned `HSImage` can be saved, displayed in a UI element, or
passed to other image-processing APIs.
     * @returns A Promise that resolves to an `HSImage`, or rejects on error
     */
    static captureImage(): Promise<HSImage>;

    /**
     * The type name for JavaScript introspection. Always `"HSCamera"`.
     */
    typeName: string;

    /**
     * The persistent unique identifier for this camera.
     */
    uid: string;

    /**
     * The human-readable name of this camera (e.g. `"FaceTime HD Camera"`).
     */
    name: string;

    /**
     * Whether this camera is currently being used by any application.
Queries the underlying CoreMediaIO device state each time it is read.
     */
    isInUse: boolean;

}

/**
 * Module for controlling the Hammerspoon console
 */
declare namespace hs.console {
    /**
     * Open the console window
     */
    function open(): void;

    /**
     * Close the console window
     */
    function close(): void;

    /**
     * Clear all console output
     */
    function clear(): void;

    /**
     * Print a message to the console
     * @param message The message to print
     */
    function print(message: string): void;

    /**
     * Print a debug message to the console
     * @param message The message to print
     */
    function debug(message: string): void;

    /**
     * Print an info message to the console
     * @param message The message to print
     */
    function info(message: string): void;

    /**
     * Print a warning message to the console
     * @param message The message to print
     */
    function warning(message: string): void;

    /**
     * Print an error message to the console
     * @param message The message to print
     */
    function error(message: string): void;

}

/**
 */
declare namespace hs.crypto {
    /**
     * AES-256-GCM encrypt. Inputs and outputs are base64 strings.
     * @param opts `{ keyB64: string, nonceB64: string, plaintext: string }`
     * @returns `{ nonceB64, ciphertextB64 }` where ciphertextB64 includes the 16-byte tag at the end
     */
    function aesGcmEncryptB64(opts: JSValue): Record<string, string> | undefined;

    /**
     * AES-256-GCM authenticate-and-decrypt. Returns the plaintext UTF-8 string,
or null on auth failure / bad input. Designed to round-trip with Android's
Cipher.getInstance("AES/GCM/NoPadding") output (ciphertext+tag concatenated).
     * @param opts `{ keyB64: string, nonceB64: string, ciphertextB64: string }`
     * @returns the decoded UTF-8 plaintext, or null if authentication failed
     */
    function aesGcmDecryptB64(opts: JSValue): string | undefined;

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
 * Module for creating CGEventTap-based global keyboard event monitors
 */
declare namespace hs.eventtap {
    /**
     * Create a new event tap for the specified event types.
Call .start() on the returned object to begin receiving events.
Requires Accessibility permission (active event taps; keyboard monitoring may also need Input Monitoring).
'systemDefined' delivers media-key events (brightness, volume, play/pause…): `{type, subtype, modifiers}` plus — for subtype 8 (aux control buttons) — `key` (e.g. 'BRIGHTNESS_UP'), `nxKeyCode`, `down`, `isRepeat`.
'gesture' delivers raw trackpad touch frames: `{type, modifiers, touchCount, touches: [{id, phase, x, y}]}` with x/y normalized to the pad (origin bottom-left).
     * @param eventTypes Array of event type strings: 'keyDown', 'keyUp', 'flagsChanged', 'mouseMoved', 'leftMouseDown', 'leftMouseUp', 'rightMouseDown', 'rightMouseUp', 'otherMouseDown', 'otherMouseUp', 'leftMouseDragged', 'rightMouseDragged', 'scrollWheel', 'systemDefined', 'gesture'.
     * @param callback Function called with an event object. Return true to consume (suppress) the event.
     * @returns An HSEventTap instance
     */
    function makeTap(eventTypes: string[], callback: JSValue): HSEventTap;

    /**
     * Synthesise a key stroke: press the modifiers + key, hold, then release.
and keyUp. Defaults to 200000 (200 ms), matching upstream Hammerspoon's
`hs.eventtap.keyStroke`. A zero/too-short hold is frequently dropped by the target
app — the clipboard gets set but the paste never lands.
     * @param mods Array of modifier strings, e.g. ['cmd']
     * @param key Key name, e.g. 'v'
     * @param delay Optional number of microseconds the key is held between keyDown
     */
    function keyStroke(mods: string[], key: string, delay: JSValue): void;

    /**
     * Synthesise a scroll-wheel event at the current mouse position.
The window server routes scroll events to the window under the cursor —
independent of keyboard focus — so this scrolls whatever the mouse is over.
     * @param dx Horizontal scroll amount (positive scrolls left, like a physical wheel tilt-left)
     * @param dy Vertical scroll amount (positive scrolls up, like a physical wheel-up)
     * @param unit Optional unit string: 'pixel' (default) or 'line'
     */
    function scrollWheel(dx: number, dy: number, unit: JSValue): void;

    /**
     * Synthesise a left mouse click (press + release) at a point in global
top-left screen coordinates (the same space as `hs.mouse.position()` and
window frames). Does not move the visible cursor.
Defaults to 200000 (200 ms), matching upstream Hammerspoon's `hs.eventtap.leftClick`.
     * @param point A point object `{x, y}` to click at
     * @param delay Optional number of microseconds between mouseDown and mouseUp.
     */
    function leftClick(point: Record<string, number>, delay: JSValue): void;

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
    static start(): boolean;

    /**
     * Stop the event tap.
     */
    static stop(): void;

    /**
     * Whether the tap is currently running.
     */
    isRunning: boolean;

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
    function read(path: string, offset: number, length: number): string | undefined;

    /**
     * Read a file line-by-line, invoking a callback for each line.
Lines are delivered with newline characters stripped. Both `\n` and `\r\n` line endings are handled.
     * @param path Path to the file. `~` is expanded.
     * @param callback Called once per line with the line text. Return `true` to continue reading, or `false` to stop early.
     * @returns `true` if the file was read successfully (including early stops requested by the callback), or `false` if the file could not be opened.
     */
    function readLines(path: string, callback: JSValue): boolean;

    /**
     * Write a UTF-8 string to a file, creating it or overwriting any existing content.
Intermediate directories are not created automatically; use `mkdir` first if needed.
     * @param path Path to the file. `~` is expanded.
     * @param content String to write.
     * @param inPlace Whether to write the file in-place or atomically. Defaults to atomically
     * @returns `true` on success, `false` on failure.
     */
    function write(path: string, content: string, inPlace: boolean): boolean;

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
     * Delete a file or directory.
Directories are removed recursively. To remove only an empty directory,
use `rmdir` instead.
     * @param path Path to delete. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function delete(path: string): boolean;

    /**
     * List the immediate contents of a directory.
Returns bare filenames (not full paths), sorted alphabetically.
The `.` and `..` entries are never included.
     * @param path Path to the directory. `~` is expanded.
     * @returns Sorted array of filenames, or `null` if the path cannot be read.
     */
    function list(path: string): string[] | undefined;

    /**
     * Recursively list all entries under a directory.
Returns paths relative to `path`, sorted alphabetically.
     * @param path Path to the root directory. `~` is expanded.
     * @returns Sorted array of relative paths, or `null` if the path cannot be read.
     */
    function listRecursive(path: string): string[] | undefined;

    /**
     * Create a directory, including all necessary intermediate directories.
Succeeds silently if the directory already exists.
     * @param path Path of the directory to create. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function mkdir(path: string): boolean;

    /**
     * Remove an empty directory.
Fails if the directory is not empty. Use `delete` to remove a non-empty
directory recursively.
     * @param path Path of the directory to remove. `~` is expanded.
     * @returns `true` on success, `false` on failure.
     */
    function rmdir(path: string): boolean;

    /**
     * Returns the current working directory of the process.
     * @returns Current directory path, or `null` on error.
     */
    function currentDir(): string | undefined;

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
    function pathToAbsolute(path: string): string | undefined;

    /**
     * Return the localised display name for a file or directory as shown by Finder.
For example, `/Library` appears as `"Library"` in Finder even though its
on-disk name is the same.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Display name string, or `null` if the path does not exist.
     */
    function displayName(path: string): string | undefined;

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
    function attributes(path: string): NSDictionary | undefined;

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
    function readlink(path: string): string | undefined;

    /**
     * Get the Finder tags assigned to a file or directory.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Array of tag name strings, or `null` if no tags are set.
     */
    function tags(path: string): string[] | undefined;

    /**
     * Replace all Finder tags on a file or directory.
This function is only available on macOS Tahoe (26) or later.
     * @param path Path to the file.
     * @returns `true` on success, `false` on failure.
     */
    function fileUTI(path: string): string | undefined;

    /**
     * Encode a file path as a persistent bookmark that survives file moves and renames.
The returned string is base64-encoded bookmark data that can be stored and
later resolved with `pathFromBookmark`.
     * @param path Path to the file or directory. `~` is expanded.
     * @returns Base64-encoded bookmark string, or `null` on failure.
     */
    function pathToBookmark(path: string): string | undefined;

    /**
     * Resolve a base64-encoded bookmark back to a file path.
     * @param data Base64-encoded bookmark string produced by `pathToBookmark`.
     * @returns The current file path, or `null` if the bookmark cannot be resolved.
     */
    function pathFromBookmark(data: string): string | undefined;

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
    function base64Decode(data: string): string | undefined;

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
     * @param callbackPressed A JavaScript function to call when the hotkey is pressed
     * @param callbackReleased A JavaScript function to call when the hotkey is released
     * @returns A hotkey object, or nil if binding failed
     */
    function bind(mods: JSValue, key: string, callbackPressed: JSValue, callbackReleased: JSValue): HSHotkey | undefined;

    /**
     * Bind a hotkey with a message description
     * @param mods An array of modifier key strings
     * @param key The key name or character
     * @param message A description of what this hotkey does (currently unused, for future features)
     * @param callbackPressed A JavaScript function to call when the hotkey is pressed
     * @param callbackReleased A JavaScript function to call when the hotkey is released
     * @returns A hotkey object, or nil if binding failed
     */
    function bindSpec(mods: JSValue, key: string, message: string | undefined, callbackPressed: JSValue, callbackReleased: JSValue): HSHotkey | undefined;

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
    function testDoubleTapSequence(modifier: string, sequence: JSValue): number;

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
    function bindDoubleTap(modifier: string, callback: JSValue): HSDoubleTapHotkey | undefined;

}

/**
 * Object representing a system-wide hotkey. You should not create these objects directly, but rather, use the methods in hs.hotkey to instantiate these.
 */
declare class HSHotkey {
    /**
     * Enable the hotkey
     * @returns True if the hotkey was enabled, otherwise False
     */
    static enable(): boolean;

    /**
     * Disable the hotkey
     */
    static disable(): void;

    /**
     * Check if the hotkey is currently enabled
     * @returns True if the hotkey is enabled, otherwise False
     */
    static isEnabled(): boolean;

    /**
     * Delete the hotkey (disables and clears callbacks)
     */
    static delete(): void;

    /**
     * The callback function to be called when the hotkey is pressed
     */
    callbackPressed: JSValue | undefined;

    /**
     * The callback function to be called when the hotkey is released
     */
    callbackReleased: JSValue | undefined;

}

/**
 * Object representing a double-tap hotkey binding. Use .unbind() to remove it.
 */
declare class HSDoubleTapHotkey {
    /**
     * Remove the double-tap binding
     */
    static unbind(): void;

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
    function serve(opts: JSValue): HSHttpServer | undefined;

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
    static make(init_: JSValue): HSHttpHeaders;

    /**
     * Get the combined value for a header name (case-insensitive). Multi-value
headers are joined with `, ` per RFC 7230 §3.2.2.
     * @param name the header name to look up (case-insensitive)
     * @returns the combined header value, or null if the header is not present
     */
    static get(name: string): string | undefined;

    /**
     * Set a header to a single value, replacing any prior value(s).
     * @param name the header name (case-insensitive)
     * @param value the value to set
     */
    static set(name: string, value: string): void;

    /**
     * True if the header is present.
     * @param name the header name to test (case-insensitive)
     * @returns true if the header is present
     */
    static has(name: string): boolean;

    /**
     * Remove a header.
     * @param name the header name to remove (case-insensitive)
     */
    static deleteHeader(name: string): void;

    /**
     * Append a value to a header; the prior value(s) are kept.
     * @param name the header name (case-insensitive)
     * @param value the value to append
     */
    static append(name: string, value: string): void;

    /**
     * All header names (lower-cased).
     * @returns all header names, lower-cased
     */
    static keys(): string[];

    /**
     * All header values, in the same order as `keys()`.
     * @returns all header values, in the same order as `keys()`
     */
    static values(): string[];

    /**
     * `[[name, value], …]` pairs.
     * @returns `[[name, value], …]` pairs of every header
     */
    static entries(): [[String]];

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
    static text(): Promise<string>;

    /**
     * Decode and JSON.parse the request body.
     * @returns A Promise resolving to the parsed JSON value.
     */
    static json(): Promise<any>;

    /**
     * HTTP method, upper-cased (e.g. `"GET"`, `"POST"`).
     */
    method: string;

    /**
     * Absolute URL of the request (e.g. `"http://127.0.0.1:9876/path?q=1"`).
     */
    url: string;

    /**
     * Path component of the URL, without query string (e.g. `"/path"`).
     */
    pathname: string;

    /**
     * Request headers.
     */
    headers: HSHttpHeaders;

    /**
     * Remote IP address of the client (e.g. `"127.0.0.1"`).
     */
    remoteAddress: string;

    /**
     * True if the body has already been consumed by `text()` or `json()`.
     */
    bodyUsed: boolean;

    /**
     * Raw query string from the URL (without leading `?`), or empty string.
The JS-side shim in `hs.httpserver.js` wraps this as `URLSearchParams`.
     */
    search: string;

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
    static make(body: JSValue, init_: JSValue): HSHttpResponse;

    /**
     * JSON convenience: `Response.json({ok: true})` → JSON-stringified body
with `Content-Type: application/json`.
     * @param value JS value to JSON-stringify as the response body
     * @param init_ optional response init object with `status`, `statusText`, and `headers`
     * @returns a new HSHttpResponse with JSON body and `Content-Type: application/json`
     */
    static json(value: JSValue, init_: JSValue | undefined): HSHttpResponse;

    /**
     * Redirect: sets `Location` header and a 3xx status (default 302).
     * @param url the URL to redirect to (set as the `Location` header)
     * @param status HTTP status code (default 302); must be a 3xx redirect code
     * @returns a new HSHttpResponse with the Location header set
     */
    static redirect(url: string, status: NSNumber | undefined): HSHttpResponse;

    /**
     * HTTP status code (e.g. 200, 404).
     */
    status: number;

    /**
     * HTTP status text. Defaults from `status` per RFC 7231 if not provided.
     */
    statusText: string;

    /**
     * Response headers.
     */
    headers: HSHttpHeaders;

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
    static stop(): void;

    /**
     * Hostname the server is bound to (e.g. `"127.0.0.1"` or `"0.0.0.0"`).
     */
    hostname: string;

    /**
     * TCP port the server is listening on.
     */
    port: number;

    /**
     * Base URL of the server (e.g. `"http://127.0.0.1:9876/"`).
     */
    url: string;

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
    function get(account: string): string | undefined;

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
    function lookupAddress(address: string): Promise<placemarkTable[]>;

    /**
     * Reverse-geocodes a locationTable into an array of placemarkTables.
Returns a Promise that resolves with matching placemarks or rejects with
an error.
     * @param locationTable an object with at least `latitude` and `longitude`
     * @returns a Promise resolving to an array of placemarkTables
     */
    function lookupLocation(locationTable: JSValue): Promise<placemarkTable[]>;

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
    function get(): Record<AnyHashable, any> | undefined;

    /**
     * Calculates the straight-line distance in metres between two locationTables.
Does not require Location Services.
     * @param from locationTable with at least `latitude` and `longitude`
     * @param to locationTable with at least `latitude` and `longitude`
     * @returns distance in metres, or `-1` if either table is invalid
     */
    function distance(from: JSValue, to: JSValue): number;

    /**
     * Returns the time of sunrise for the given coordinates and date as seconds
since the Unix epoch, or null if the sun does not rise on that date (polar
night). Pass a JS `Date` for `date`, or omit/pass null to use today.
     * @param latitude degrees north (positive) or south (negative)
     * @param longitude degrees east (positive) or west (negative)
     * @param date optional JS `Date`; defaults to today
     * @returns seconds since epoch of sunrise, or null
     */
    function sunrise(latitude: number, longitude: number, date: JSValue): NSNumber | undefined;

    /**
     * Returns the time of sunset for the given coordinates and date as seconds
since the Unix epoch, or null if the sun does not set on that date (midnight
sun). Pass a JS `Date` for `date`, or omit/pass null to use today.
     * @param latitude degrees north (positive) or south (negative)
     * @param longitude degrees east (positive) or west (negative)
     * @param date optional JS `Date`; defaults to today
     * @returns seconds since epoch of sunset, or null
     */
    function sunset(latitude: number, longitude: number, date: JSValue): NSNumber | undefined;

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

    /**
     * The geocoder subobject for forward and reverse geocoding.
     */
    const geocoder: HSLocationGeocoder;

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
    static start(): HSLocationWatcher;

    /**
     * Stops location updates.
     * @returns self, for chaining
     */
    static stop(): HSLocationWatcher;

    /**
     * Sets the callback function invoked when location events occur.
     * @param fn `function(event, data)` — see type documentation for event names
     * @returns self, for chaining
     */
    static setCallback(fn: JSValue): HSLocationWatcher;

    /**
     * Returns the most recently received location, or null if none yet.
     * @returns a locationTable, or null
     */
    static location(): Record<AnyHashable, any> | undefined;

    /**
     * The unique identifier assigned to this watcher.
     */
    identifier: string;

    /**
     * The minimum distance in metres the device must move before a new update
is delivered. Defaults to `kCLDistanceFilterNone` (all movements reported).
     */
    distanceFilter: number;

}

/**
 * A single status item in the macOS menu bar, created via `hs.menubar.new()`.
Provides a builder-style API for setting an icon, title, click callback, and
querying the on-screen frame so callers can anchor a popover beneath it.
 */
declare namespace hs.menubar {
    /**
     * Create a new status item in the macOS menu bar.
     * @returns an `HSMenubarItem`. Chain `.setIcon(...)`, `.setTitle(...)`,
     */
    function new(): HSMenubarItem;

}

/**
 * A single status item in the macOS menu bar, created via `hs.menubar.new()`.
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
    static setTitle(text: string, opts: JSValue): HSMenubarItem;

    /**
     * Set the status-item icon from an SF Symbol name.
When `color` is omitted the icon is a template (adapts to the menu bar).
     * @param symbolName an SF Symbol name (e.g. `'eye'`, `'eye.slash'`)
     * @param opts `{ pointSize?: number, color?: hex string, accessibilityLabel?: string }` — all optional.
     * @returns self for chaining
     */
    static setIcon(symbolName: string, opts: JSValue): HSMenubarItem;

    /**
     * Set the status-item image from a base64-encoded PNG.
     * @param base64PNG PNG bytes, base64-encoded (a leading `data:image/png;base64,` is tolerated)
     * @param opts `{ template?: bool }` — template images adapt to light/dark menu bars (default true)
     * @returns self for chaining
     */
    static setImage(base64PNG: string, opts: JSValue): HSMenubarItem;

    /**
     * Set the status-item image from an SVG document string. Rendered as a
template by default so macOS draws it adaptively (white on the dark menu
bar, black on light). Ideal for a vector glyph you regenerate over time
(e.g. a progress ring).
     * @param svg an SVG document string (should include an `xmlns`)
     * @param opts `{ template?: bool, size?: number }` — template defaults true, size defaults 18 (pt)
     * @returns self for chaining
     */
    static setSVG(svg: string, opts: JSValue): HSMenubarItem;

    /**
     * Register a function called (with no arguments) when the item is clicked.
     * @param fn a JavaScript function
     * @returns self for chaining
     */
    static setCallback(fn: JSValue): HSMenubarItem;

    /**
     * Highlight (or un-highlight) the status-item button background.
     * @param on whether to draw the highlighted background
     * @returns self for chaining
     */
    static highlight(on: boolean): HSMenubarItem;

    /**
     * The on-screen rect of the status-item button as `{x, y, w, h}`, in
NSWindow (bottom-left origin) coordinates — the same convention as
`hs.webview` `currentFrame()`/`setFrame()`, so a webview can be anchored
to it. Returns null if the item has no realized on-screen button.
     * @returns `{x, y, w, h}` or null
     */
    static frame(): Record<string, number> | undefined;

    /**
     * Remove the status item from the menu bar.
     */
    static remove(): void;

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
    static start(): void;

    /**
     * Stop advertising/browsing and disconnect the session.
     */
    static stop(): void;

    /**
     * Tear down and recreate the underlying session/advertiser/browser, then
resume if it was started. The JS watchdog calls this to clear a wedged
AWDL/MPC state.
     */
    static reset(): void;

    /**
     * Register a callback for peer connection-state changes.
     * @param cb `function(peerName, state)` — state is `"connected"`, `"connecting"`, or `"disconnected"`.
     * @returns self, for chaining.
     */
    static onPeer(cb: JSValue): HSMPCSession;

    /**
     * Register a callback for received payloads.
     * @param cb `function(base64, peerName)` — `base64` is the received bytes, base64-encoded.
     * @returns self, for chaining.
     */
    static onReceive(cb: JSValue): HSMPCSession;

    /**
     * Send a payload to all connected peers.
     * @param base64 the payload bytes, base64-encoded.
     * @param opts `{ reliable }` — `reliable` defaults to `true`.
     * @returns `true` if sent to at least one peer; `false` if there are no peers, the base64 is invalid, or send failed.
     */
    static send(base64: string, opts: JSValue): boolean;

    /**
     * The display names of all currently connected peers.
     */
    peers: string[];

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
const n = hs.notify.new({
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
| `userInfo` | object | The `userInfo` object originally passed to `new()`, if any |
| `notificationId` | string | The notification's unique identifier |
## Options for `new()`
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
Pass a `trigger` object in `new()`'s options to schedule the notification instead of delivering it
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
Receives a response object (see module docs for shape).
     * @param title The notification title
     * @param body The notification body text
     * @param callback Optional function called when the user taps the notification.
     */
    function show(title: string, body: string, callback: JSValue): void;

    /**
     * Create a richly configured notification without sending it yet.
     * @param options A JavaScript object — see module documentation for supported keys.
     * @returns An `HSNotification` object. Call `.send()` on it to deliver the notification.
     */
    function new(options: JSValue): HSNotification | undefined;

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
    static send(): HSNotification;

    /**
     * Remove this notification from Notification Center (if delivered) or cancel it (if pending).
     */
    static withdraw(): void;

    /**
     * The unique identifier assigned to this notification.
Use it to correlate with system notification APIs if needed.
     */
    identifier: string;

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
    function applescriptSync(source: string): Record<string, any> | undefined;

    /**
     * Run an OSA JavaScript source string synchronously.
Blocks the JS thread until the script completes.
     * @param source The OSA JavaScript source code to compile and execute.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function javascriptSync(source: string): Record<string, any> | undefined;

    /**
     * Read a file from disk and execute its contents as AppleScript synchronously.
     * @param path Absolute path to the AppleScript source file.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function applescriptSyncFromFile(path: string): Record<string, any> | undefined;

    /**
     * Read a file from disk and execute its contents as OSA JavaScript synchronously.
     * @param path Absolute path to the OSA JavaScript source file.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function javascriptSyncFromFile(path: string): Record<string, any> | undefined;

    /**
     * Low-level synchronous execution entry point.
Prefer `applescriptSync()` or `javascriptSync()` over calling this directly.
     * @param source The script source code.
     * @param language The OSA language name — must be `"AppleScript"` or `"JavaScript"`.
     * @returns An object `{ success, result, raw }`, or `null` on XPC failure.
     */
    function _executeSync(source: string, language: string): Record<string, any> | undefined;

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
    function readString(): string | undefined;

    /**
     * Read HTML from the pasteboard
     * @returns The HTML string, or null if not available
     */
    function readHTML(): string | undefined;

    /**
     * Read RTF from the pasteboard
     * @returns The RTF string, or null if not available
     */
    function readRTF(): string | undefined;

    /**
     * Read a URL from the pasteboard
     * @returns The URL as a string, or null if not available
     */
    function readURL(): string | undefined;

    /**
     * Read an image from the pasteboard
     * @returns An HSImage, or null if not available
     */
    function readImage(): HSImage | undefined;

    /**
     * Read raw data for a specific UTI type, returned as a base64-encoded string.
Use this for types not covered by the convenience read methods.
     * @param uti A UTI type string (e.g. "com.adobe.pdf")
     * @returns A base64-encoded string, or null if the type is not available
     */
    function readData(uti: string): string | undefined;

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
    function writeObjects(representations: JSValue): boolean;

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
     * @param listener A function called with one argument: the new `changeCount` integer
     */
    function addWatcher(listener: JSValue): void;

    /**
     * Remove a previously registered pasteboard watcher
     * @param listener The function previously passed to `addWatcher`
     */
    function removeWatcher(listener: JSValue): void;

    /**
     * The pasteboard change count. Increments each time any application writes to the pasteboard.
Comparing a saved value to the current value is the standard way to detect external changes.
     */
    const changeCount: number;

    /**
     * The polling interval for the pasteboard watcher, in seconds. Defaults to 0.5.
Changes take effect the next time a watcher is started (i.e. after removing and re-adding).
     */
    const watcherInterval: number;

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
    function currentAssertions(): NSArray;

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
    function batteryInfo(): NSDictionary | undefined;

    /**
     * Registers a listener that fires when system power events occur.
`"screensDidSleep"`, `"screensDidWake"`, `"screensDidLock"`, `"screensDidUnlock"`,
`"screensaverDidStart"`, `"screensaverDidStop"`, `"screensaverWillStop"`,
`"systemWillSleep"`, `"systemDidWake"`, `"systemWillPowerOff"`,
`"sessionDidBecomeActive"`, `"sessionDidResignActive"`.
The OS notification subscription starts lazily on the first listener and
is released automatically when the last listener is removed.
     * @param listener A function receiving `(eventName: string)`.
     */
    function addEventWatcher(listener: JSValue): void;

    /**
     * Removes a previously registered power event listener.
     * @param listener The function originally passed to `addEventWatcher`.
     */
    function removeEventWatcher(listener: JSValue): void;

    /**
     * Registers a listener that fires whenever battery state changes.
The listener receives no arguments; call `batteryInfo()` or read individual
properties inside the callback to determine what changed.
The OS notification subscription starts lazily on the first listener and
is released automatically when the last listener is removed.
     * @param listener A function called with no arguments on battery state change.
     */
    function addBatteryWatcher(listener: JSValue): void;

    /**
     * Removes a previously registered battery change listener.
     * @param listener The function originally passed to `addBatteryWatcher`.
     */
    function removeBatteryWatcher(listener: JSValue): void;

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
    function main(): HSScreen | undefined;

    /**
     * The primary display — the one that contains the global menu bar.
     * @returns An HSScreen object or `null` if no primary screen can be determined.
     */
    function primary(): HSScreen | undefined;

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
    static setMode(width: number, height: number, scale: number, frequency: number): boolean;

    /**
     * Capture the current contents of this screen as an image.
Requires **Screen Recording** permission.
     * @returns Resolves with the captured image, or rejects if the capture fails (e.g. permission denied).
     */
    static snapshot(): Promise<HSImage>;

    /**
     * The next screen in `hs.screen.all()` order, wrapping around.
     * @returns An HSScreen object
     */
    static next(): HSScreen;

    /**
     * The previous screen in `hs.screen.all()` order, wrapping around.
     * @returns An HSScreen object
     */
    static previous(): HSScreen;

    /**
     * The nearest screen whose left edge is at or beyond this screen's right edge, or `null`.
     * @returns An HSScreen object
     */
    static toEast(): HSScreen | undefined;

    /**
     * The nearest screen whose right edge is at or before this screen's left edge, or `null`.
     * @returns An HSScreen object
     */
    static toWest(): HSScreen | undefined;

    /**
     * The nearest screen that is physically above this screen, or `null`.
     * @returns An HSScreen object
     */
    static toNorth(): HSScreen | undefined;

    /**
     * The nearest screen that is physically below this screen, or `null`.
     * @returns An HSScreen object
     */
    static toSouth(): HSScreen | undefined;

    /**
     * Move this screen so its top-left corner is at the given position in global Hammerspoon coordinates.
     * @param x The X coordinate to move to
     * @param y The Y coordinate to move to
     * @returns `true` on success.
     */
    static setOrigin(x: number, y: number): boolean;

    /**
     * Designate this screen as the primary display (moves the menu bar here).
     * @returns `true` on success.
     */
    static setPrimary(): boolean;

    /**
     * Configure this screen to mirror another screen.
     * @param screen The screen to mirror.
     * @returns `true` on success.
     */
    static mirrorOf(screen: HSScreen): boolean;

    /**
     * Stop mirroring, restoring this screen to an independent display.
     * @returns `true` on success.
     */
    static mirrorStop(): boolean;

    /**
     * Convert a rect in global Hammerspoon coordinates to coordinates local to this screen.
The result origin is relative to this screen's top-left corner.
     * @param rect An `HSRect` in global Hammerspoon coordinates.
     * @returns The rect offset to be relative to this screen's top-left, or `null` if the input is invalid.
     */
    static absoluteToLocal(rect: JSValue): HSRect | undefined;

    /**
     * Convert a rect in local screen coordinates to global Hammerspoon coordinates.
     * @param rect An `HSRect` relative to this screen's top-left corner.
     * @returns The rect in global Hammerspoon coordinates, or `null` if the input is invalid.
     */
    static localToAbsolute(rect: JSValue): HSRect | undefined;

    /**
     * Unique display identifier (matches `CGDirectDisplayID`).
     */
    id: number;

    /**
     * The manufacturer-assigned localized display name.
     */
    name: string;

    /**
     * The display's UUID string.
     */
    uuid: string;

    /**
     * The usable screen area in Hammerspoon coordinates, excluding the menu bar and Dock.
     */
    frame: HSRect;

    /**
     * The full screen area in Hammerspoon coordinates, including menu bar and Dock regions.
     */
    fullFrame: HSRect;

    /**
     * The screen's top-left corner in global Hammerspoon coordinates.
     */
    position: HSPoint;

    /**
     * The currently active display mode.
An object with keys: `width`, `height`, `scale`, `frequency`.
     */
    mode: NSDictionary;

    /**
     * All display modes supported by this screen.
Each element has keys: `width`, `height`, `scale`, `frequency`.
     */
    availableModes: NSDictionary[];

    /**
     * The current screen rotation in degrees (0, 90, 180, or 270).
Assign one of `0`, `90`, `180`, or `270` to rotate the display.
     */
    rotation: number;

    /**
     * The URL string of the current desktop background image for this screen, or `null`.
Assign a new absolute file path or `file://` URL string to change the wallpaper.
     */
    desktopImage: string | undefined;

}

/**
 * Module for enumerating and opening serial ports (e.g. a USB-attached ESP32).
 */
declare namespace hs.serial {
    /**
     * List available serial ports (devices matching `/dev/cu.*`).
     * @returns An array of `{ path, name }` objects (empty if none are present).
     */
    function list(): [[String: String]];

    /**
     * Open a serial port by device path.
     * @param path The device path, e.g. `/dev/cu.usbmodem1`.
     * @returns An `HSSerialPort` object, or `null` if the port could not be opened.
     */
    function open(path: string): HSSerialPort | undefined;

    /**
     * Open the first serial port whose name contains the given string.
     * @param match A substring to search for in each port's name.
     * @returns An `HSSerialPort` object, or `null` if no matching port was found or could not be opened.
     */
    function openFirst(match: string): HSSerialPort | undefined;

}

/**
 * An open serial port. Do not construct directly — use hs.serial.open().
 */
declare class HSSerialPort {
    /**
     * Close the port.
     */
    static close(): void;

    /**
     * Write a string to the port (caller includes any trailing "\n").
     * @param s the bytes to write (UTF-8).
     * @returns true if all bytes were written.
     */
    static write(s: string): boolean;

    /**
     * Register a callback invoked once per inbound line (newline/CR-delimited).
     * @param cb a function called with each line string.
     * @returns this port (chainable).
     */
    static onLine(cb: JSValue): HSSerialPort;

    /**
     * Register a callback invoked when the port closes.
     * @param cb a function called when the port closes.
     * @returns this port (chainable).
     */
    static onClose(cb: JSValue): HSSerialPort;

    /**
     * The device path this port was opened on.
     */
    path: string;

    /**
     * Whether the port is currently open.
     */
    isOpen: boolean;

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
    function open(path: string): HSSqliteDB | undefined;

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
    static exec(sql: string): boolean;

    /**
     * Run a parameterized write. Returns an object `{ changes, lastInsertRowid }`
on success, or null on error.
     * @param sql Parameterized SQL with `?` placeholders
     * @param params Array of values to bind (or null/undefined for no params)
     * @returns `{ changes: number, lastInsertRowid: number }` or null
     */
    static run(sql: string, params: JSValue): JSValue | undefined;

    /**
     * Run a parameterized read. Returns an array of plain JS objects keyed by
column name. Empty array if no rows.
     * @param sql Parameterized SELECT
     * @param params Array of values to bind
     * @returns An array of objects
     */
    static query(sql: string, params: JSValue): [[String: Any]];

    /**
     * Run a JS function inside a BEGIN/COMMIT pair. If the function throws,
the transaction is rolled back and the exception is re-thrown to the
caller. Returns the function's return value on success.
Nested transactions throw — savepoints are not supported in v1.
     * @param fn A function with no arguments
     * @returns The function's return value, or null on rollback
     */
    static transaction(fn: JSValue): JSValue | undefined;

    /**
     * Close the database. Idempotent — second call is a no-op. Throws if
called inside a transaction.
     */
    static close(): void;

    /**
     * The filesystem path of the database.
     */
    path: string;

    /**
     * Whether the database is currently open. Becomes false after `close()`.
     */
    isOpen: boolean;

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
     * @param cfg Object with optional keys:
     * @returns `{ disable: function }` on success, or `{ error: string }`
     */
    function enable(cfg: JSValue): Record<string, any>;

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
    function debugState(): Record<string, any> | undefined;

    /**
     * Programmatically move the current session's selection (no UI events).
     * @param axis `'app'` to move between app columns, `'window'` to move between windows within an app
     * @param delta direction to move — `+1` for forward, `-1` for backward
     * @returns true if a session was active to move.
     */
    function debugMove(axis: string, delta: number): boolean;

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
     * @param completionCallback Optional callback function called when the task terminates
     * @param environment Optional dictionary of environment variables for the task
     * @param streamingCallback Optional callback function called when the task produces output
     * @returns A task object. Call start() to begin execution.
     */
    function new(launchPath: string, arguments: string[], completionCallback: JSValue | undefined, environment: JSValue | undefined, streamingCallback: JSValue | undefined): HSTask;

    /**
     * Run a short-lived command synchronously and return its stdout as a
string. Use sparingly — this blocks the JS thread until the process
exits. Intended for fast utilities (`ps`, `whoami`, `uname`) where
awaiting a Promise would add UI flicker.
     * @param launchPath Absolute path to the executable
     * @param arguments Argument array
     * @returns Combined stdout as a string, or null on failure
     */
    function runSync(launchPath: string, arguments: string[]): string | undefined;

    /**
     * Create and run a task asynchronously
     * @param launchPath - Full path to the executable
     * @param args - Array of arguments
     * @param options - Options object or legacy callback
     * @param options .environment - Environment variables (optional)
     * @param options .workingDirectory - Working directory (optional)
     * @param options .onOutput - Callback for streaming output: (stream, data) => {} (optional)
     * @param legacyStreamCallback - Legacy streaming callback (optional)
     * @returns {Promise<{exitCode: number, stdout: string, stderr: string}>}
     */
    function runAsync(launchPath: string, args: string[], options: Object|Function, options: Object, options: string, options: Function, legacyStreamCallback: Function): any;

    /**
     * Run a shell command asynchronously
     * @param command - Shell command to execute
     * @param options - Options (same as run)
     * @returns {Promise<{exitCode: number, stdout: string, stderr: string}>}
     */
    function shell(command: string, options: Object): any;

    /**
     * Run multiple tasks in parallel
     * @param tasks - Array of task specifications: [{path, args, options}, ...]
     * @returns Array of results
     */
    function parallel(tasks: Array): Promise<Array>;

    /**
     * Create a task builder for fluent API
     * @param launchPath - Full path to the executable
     * @returns {TaskBuilder}
     */
    function builder(launchPath: string): any;

    /**
     * Run a task, returning a Promise. Swift-retained storage for the JS implementation.
     */
    const runAsync: JSValue | undefined;

    /**
     * Run a shell command. Swift-retained storage for the JS implementation.
     */
    const shell: JSValue | undefined;

    /**
     * Run multiple tasks in parallel. Swift-retained storage for the JS implementation.
     */
    const parallel: JSValue | undefined;

    /**
     * Run multiple tasks in sequence. Swift-retained storage for the JS implementation.
     */
    const sequence: JSValue | undefined;

    /**
     * Create a task builder. Swift-retained storage for the JS implementation.
     */
    const builder: JSValue | undefined;

    /**
     * TaskBuilder class. Swift-retained storage for the JS implementation.
     */
    const TaskBuilder: JSValue | undefined;

}

/**
 * Object representing an external process task
 */
declare class HSTask {
    /**
     * Start the task
     * @returns The task object for chaining
     */
    static start(): HSTask;

    /**
     * Terminate the task (send SIGTERM)
     */
    static terminate(): void;

    /**
     * Terminate the task with extreme prejudice (send SIGKILL)
     */
    static kill9(): void;

    /**
     * Interrupt the task (send SIGINT)
     */
    static interrupt(): void;

    /**
     * Pause the task (send SIGSTOP)
     */
    static pause(): void;

    /**
     * Resume the task (send SIGCONT)
     */
    static resume(): void;

    /**
     * Wait for the task to complete (blocking)
     */
    static waitUntilExit(): void;

    /**
     * Write data to the task's stdin
     * @param data The string data to write
     */
    static sendInput(data: string): void;

    /**
     * Close the task's stdin
     */
    static closeInput(): void;

    /**
     * Check if the task is currently running
     */
    isRunning: boolean;

    /**
     * The process ID of the running task
     */
    pid: Int32;

    /**
     * The environment variables for the task
     */
    environment: Record<string, string>;

    /**
     * The working directory for the task
     */
    workingDirectory: string | undefined;

    /**
     * The termination status of the task
     */
    terminationStatus: NSNumber | undefined;

    /**
     * The termination reason
     */
    terminationReason: string | undefined;

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
    function create(interval: number, callback: JSValue, continueOnError: boolean): HSTimer;

    /**
     * Create a new timer (alias for create())
     * @param interval The interval in seconds at which the timer should fire
     * @param callback A JavaScript function to call when the timer fires
     * @param continueOnError If true, the timer will continue running even if the callback throws an error
     * @returns A timer object. Call start() to begin the timer.
     */
    function new(interval: number, callback: JSValue, continueOnError: boolean): HSTimer;

    /**
     * Create and start a one-shot timer
     * @param seconds Number of seconds to wait before firing
     * @param callback A JavaScript function to call when the timer fires
     * @returns A timer object (already started)
     */
    function doAfter(seconds: number, callback: JSValue): HSTimer;

    /**
     * Create and start a repeating timer
     * @param interval The interval in seconds at which the timer should fire
     * @param callback A JavaScript function to call when the timer fires
     * @returns A timer object (already started)
     */
    function doEvery(interval: number, callback: JSValue): HSTimer;

    /**
     * Create and start a timer that fires at a specific time
     * @param time Seconds since midnight (local time) when the timer should first fire
     * @param repeatInterval If provided, the timer will repeat at this interval. Pass 0 for one-shot.
     * @param callback A JavaScript function to call when the timer fires
     * @param continueOnError If true, the timer will continue running even if the callback throws an error
     * @returns A timer object (already started)
     */
    function doAt(time: number, repeatInterval: number, callback: JSValue, continueOnError: boolean): HSTimer;

    /**
     * Block execution for a specified number of microseconds (strongly discouraged)
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
    function absoluteTime(): UInt64;

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

    /**
     * Repeat a function until a predicate returns true. Swift-retained storage for the JS implementation.
     */
    const doUntil: JSValue | undefined;

    /**
     * Repeat a function while a predicate returns true. Swift-retained storage for the JS implementation.
     */
    const doWhile: JSValue | undefined;

    /**
     * Wait to call a function until a predicate returns true. Swift-retained storage for the JS implementation.
     */
    const waitUntil: JSValue | undefined;

    /**
     * Wait to call a function until a predicate returns false. Swift-retained storage for the JS implementation.
     */
    const waitWhile: JSValue | undefined;

}

/**
 * Object representing a timer. You should not instantiate these yourself, but rather, use the methods in hs.timer to create them for you.
 */
declare class HSTimer {
    /**
     * Start the timer
     */
    static start(): void;

    /**
     * Stop the timer
     */
    static stop(): void;

    /**
     * Immediately fire the timer's callback
     */
    static fire(): void;

    /**
     * Check if the timer is currently running
     * @returns true if the timer is running, false otherwise
     */
    static running(): boolean;

    /**
     * Get the number of seconds until the timer next fires
     * @returns Seconds until next trigger, or a negative value if the timer is not running
     */
    static nextTrigger(): number;

    /**
     * Set when the timer should next fire
     * @param seconds Number of seconds from now when the timer should fire
     */
    static setNextTrigger(seconds: number): void;

    /**
     * The timer's interval in seconds
     */
    interval: number;

    /**
     * Whether the timer repeats
     */
    repeats: boolean;

}

/**
 * # hs.ui
**Create custom user interfaces, alerts, dialogs, and file pickers**
The `hs.ui` module provides a set of tools for creating custom user interfaces
in Hammerspoon with SwiftUI-like declarative syntax.
## Key Features
then call `.set()` on it from any callback to re-render the canvas automatically
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
        if (index === 0) print("Saving...");
    })
    .show();
```
### Text Input Prompt
```javascript
hs.ui.textPrompt("Enter your name")
    .defaultText("John Doe")
    .onButton((buttonIndex, text) => {
        print("User entered: " + text);
    })
    .show();
```
### File Picker
```javascript
hs.ui.filePicker()
    .message("Choose a file")
    .allowedFileTypes(["txt", "md"])
    .onSelection((path) => {
        if (path) print("Selected: " + path);
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
            btnColor.set(isHovered ? "#E24A4A" : "#4A90E2");
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
            const next = (icon.name() === "NSStatusAvailable")
                ? HSImage.fromName("NSStatusUnavailable")
                : HSImage.fromName("NSStatusAvailable");
            icon.set(next);
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
                cardColor.set(isHovered ? "#E74C3C" : "#3498DB");
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

}

/**
 * # HSUIWindow
**A custom window with declarative UI building**
`HSUIWindow` allows you to create custom borderless windows with a SwiftUI-like
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
    static show(): HSUIWindow;

    /**
     * Hide the window (keeps it in memory)
     */
    static hide(): void;

    /**
     * Close and destroy the window
     */
    static close(): void;

    /**
     * Return the window's actual on-screen frame after show(), as
`{x, y, w, h}` in bottom-origin (NSWindow) coordinates. Returns null
if the window has not been shown. For debugging/testing only.
     * @returns `{x, y, w, h}` on-screen frame in NSWindow coordinates, or null if not shown
     */
    static currentFrame(): Record<string, number> | undefined;

    /**
     * Render this window's content view to a PNG file at the given path.
Uses NSView.cacheDisplay — this does NOT capture the screen, only
re-renders this view's own drawing, so no Screen Recording permission
is required and only this window's pixels are produced.
     * @param path absolute filesystem path to write
     * @returns true on success
     */
    static snapshotToPNG(path: string): boolean;

    /**
     * Set the window's background color
     * @param colorValue Color as hex string (e.g., "#FF0000") or HSColor object
     * @returns Self for chaining
     */
    static backgroundColor(colorValue: JSValue): HSUIWindow;

    /**
     * Add a rectangle shape
     * @returns Self for chaining (apply modifiers like `fill()`, `frame()`)
     */
    static rectangle(): HSUIWindow;

    /**
     * Add a circle shape
     * @returns Self for chaining (apply modifiers like `fill()`, `frame()`)
     */
    static circle(): HSUIWindow;

    /**
     * Add a text element
or an `HSString` object (from `hs.ui.string()`) for reactive text
     * @param content The text to display — a plain JS string for static text,
     * @returns Self for chaining (apply modifiers like `font()`, `foregroundColor()`)
     */
    static text(content: JSValue): HSUIWindow;

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
    static attributedText(content: JSValue): HSUIWindow;

    /**
     * Set the accent color used for `accent: true` segments inside an
`attributedText()` element. No effect on other elements.
     * @param colorValue Color as hex string or HSColor
     * @returns Self for chaining
     */
    static accentColor(colorValue: JSValue): HSUIWindow;

    /**
     * Add an image element
     * @param imageValue Image as HSImage object or file path string
     * @returns Self for chaining (apply modifiers like `resizable()`, `aspectRatio()`, `frame()`)
     */
    static image(imageValue: JSValue): HSUIWindow;

    /**
     * Add a button element
or an `HSString` object (from `hs.ui.string()`) for reactive text
     * @param label The button label — a plain JS string for static text,
     * @returns Self for chaining (apply `.fill()`, `.cornerRadius()`, `.font()`,
     */
    static button(label: JSValue): HSUIWindow;

    /**
     * Add a single-line text input field
(from `hs.ui.string()`). When you pass an HSString, the field is two-way
bound: typing updates the HSString and `hsString.set(...)` updates the field.
     * @param initial The initial value — a plain JS string OR an `HSString`
     * @returns Self for chaining (apply `.placeholder()`, `.focused()`,
     */
    static textField(initial: JSValue): HSUIWindow;

    /**
     * Set placeholder text for the current text field (greyed-out hint when empty)
     * @param text The placeholder string
     * @returns Self for chaining
     */
    static placeholder(text: string): HSUIWindow;

    /**
     * Control whether the current text field grabs first-responder when shown.
Default is true.
     * @param enabled true to autofocus
     * @returns Self for chaining
     */
    static focused(enabled: boolean): HSUIWindow;

    /**
     * Register a callback that fires whenever the current text field's value changes.
Called with the new string.
     * @param callback `(value: string) => void`
     * @returns Self for chaining
     */
    static onChange(callback: JSValue): HSUIWindow;

    /**
     * Register a callback that fires when the current text field submits (Enter pressed
and not consumed by `onKey`). Called with the current value.
     * @param callback `(value: string) => void`
     * @returns Self for chaining
     */
    static onSubmit(callback: JSValue): HSUIWindow;

    /**
     * Begin a vertical stack (elements arranged top to bottom)
     * @returns Self for chaining (call `end()` when done)
     */
    static vstack(): HSUIWindow;

    /**
     * Begin a horizontal stack (elements arranged left to right)
     * @returns Self for chaining (call `end()` when done)
     */
    static hstack(): HSUIWindow;

    /**
     * Begin a z-stack (overlapping elements)
     * @returns Self for chaining (call `end()` when done)
     */
    static zstack(): HSUIWindow;

    /**
     * Add flexible spacing that expands to fill available space
     * @returns Self for chaining
     */
    static spacer(): HSUIWindow;

    /**
     * End the current layout container
     * @returns Self for chaining
     */
    static end(): HSUIWindow;

    /**
     * Fill a shape with a color
     * @param colorValue Color as hex string or HSColor
     * @returns Self for chaining
     */
    static fill(colorValue: JSValue): HSUIWindow;

    /**
     * Add a stroke (border) to a shape
     * @param colorValue Color as hex string or HSColor
     * @returns Self for chaining
     */
    static stroke(colorValue: JSValue): HSUIWindow;

    /**
     * Set the stroke width
     * @param width Width in points
     * @returns Self for chaining
     */
    static strokeWidth(width: number): HSUIWindow;

    /**
     * Round the corners of a shape
     * @param radius Corner radius in points
     * @returns Self for chaining
     */
    static cornerRadius(radius: number): HSUIWindow;

    /**
     * Set the frame (size) of an element
     * @param dict Dictionary with `w` and/or `h` (can be numbers or percentage strings like "50%")
     * @returns Self for chaining
     */
    static frame(dict: Record<string, any>): HSUIWindow;

    /**
     * Set the opacity of an element
     * @param value Opacity from 0.0 (transparent) to 1.0 (opaque)
     * @returns Self for chaining
     */
    static opacity(value: number): HSUIWindow;

    /**
     * Set the font for a text element
     * @param font An HSFont object (e.g., `HSFont.title()`)
     * @returns Self for chaining
     */
    static font(font: HSFont): HSUIWindow;

    /**
     * Set the text color
     * @param colorValue Color as hex string or HSColor
     * @returns Self for chaining
     */
    static foregroundColor(colorValue: JSValue): HSUIWindow;

    /**
     * Make an image resizable (allows it to scale with frame size)
     * @returns Self for chaining
     */
    static resizable(): HSUIWindow;

    /**
     * Set the aspect ratio mode for an image
     * @param mode "fit" (scales to fit within frame) or "fill" (scales to fill frame)
     * @returns Self for chaining
     */
    static aspectRatio(mode: string): HSUIWindow;

    /**
     * Add padding around a layout container
     * @param value Padding in points
     * @returns Self for chaining
     */
    static padding(value: number): HSUIWindow;

    /**
     * Set spacing between elements in a stack
     * @param value Spacing in points
     * @returns Self for chaining
     */
    static spacing(value: number): HSUIWindow;

    /**
     * Set a callback to fire when the element is clicked
     * @param callback A JavaScript function to call on click
     * @returns Self for chaining
     */
    static onClick(callback: JSValue): HSUIWindow;

    /**
     * Set a callback to fire when the cursor enters or leaves the element
     * @param callback A JavaScript function called with a boolean: true when entering, false when leaving
     * @returns Self for chaining
     */
    static onHover(callback: JSValue): HSUIWindow;

    /**
     * Remove the window's title bar and chrome, making it completely borderless.
     * @returns Self for chaining
     */
    static borderless(): HSUIWindow;

    /**
     * Set the window level by name.
     * @param name One of 'normal', 'floating', 'popUpMenu', 'screenSaver'
     * @returns Self for chaining
     */
    static level(name: string): HSUIWindow;

    /**
     * Center the window on the main screen when shown.
     * @returns Self for chaining
     */
    static center(): HSUIWindow;

    /**
     * Control whether the window can become the key window (receive keyboard events).
     * @param enabled true to allow the window to become key
     * @returns Self for chaining
     */
    static canBecomeKey(enabled: boolean): HSUIWindow;

    /**
     * Make the window click-through: mouse events pass straight to whatever is beneath it.
Essential for a transparent full-screen overlay (otherwise it would swallow every click).
     * @param enabled true to ignore mouse events (overlay/HUD); false for a normal window
     * @returns Self for chaining
     */
    static ignoresMouseEvents(enabled: boolean): HSUIWindow;

    /**
     * Register a callback that fires on local key events while this window is key.
and modifiers is an array of strings like 'shift', 'cmd', etc.
     * @param callback Function called with (key, modifiers) where key is a character string
     * @returns Self for chaining
     */
    static onKey(callback: JSValue): HSUIWindow;

    /**
     * Register a callback that fires when the window loses key status (blurs).
     * @param callback Function to invoke when the window resigns key
     * @returns Self for chaining
     */
    static onBlur(callback: JSValue): HSUIWindow;

    /**
     * Round the window's outer corners (Spotlight/Raycast popup look).
Applies layer cornerRadius + masksToBounds to the window's content view
and makes the NSWindow background fully transparent so the corners
outside the rounded shape are see-through.
     * @param radius Corner radius in points. 0 disables rounding.
     * @returns Self for chaining
     */
    static windowCornerRadius(radius: number): HSUIWindow;

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
    static font(font: HSFont): HSUIAlert;

    /**
     * Set how long the alert is displayed
     * @param seconds Duration in seconds (default: 5.0)
     * @returns Self for chaining
     */
    static duration(seconds: number): HSUIAlert;

    /**
     * Set the padding around the alert text
     * @param points Padding in points (default: 20)
     * @returns Self for chaining
     */
    static padding(points: number): HSUIAlert;

    /**
     * Set a custom position for the alert
     * @param dict Dictionary with `x` and `y` coordinates
     * @returns Self for chaining
     */
    static position(dict: Record<string, any>): HSUIAlert;

    /**
     * Show the alert
     * @returns Self for chaining (can store reference to close manually)
     */
    static show(): HSUIAlert;

    /**
     * Close the alert immediately
     */
    static close(): void;

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
            print("Saving...");
        } else if (index === 1) {
            print("Discarding changes...");
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
    static informativeText(text: string): HSUIDialog;

    /**
     * Set custom button labels
     * @param labels Array of button labels (default: ["OK"])
     * @returns Self for chaining
     */
    static buttons(labels: string[]): HSUIDialog;

    /**
     * Set the dialog style
     * @param style Style name (e.g., "informational", "warning", "critical")
     * @returns Self for chaining
     */
    static style(style: string): HSUIDialog;

    /**
     * Set the callback for button presses
     * @param callback Function receiving button index (0-based)
     * @returns Self for chaining
     */
    static onButton(callback: JSValue): HSUIDialog;

    /**
     * Show the dialog
     * @returns Self for chaining
     */
    static show(): HSUIDialog;

    /**
     * Close the dialog programmatically
     */
    static close(): void;

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
            print("Selected: " + path);
        } else {
            print("User cancelled");
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
            paths.forEach(p => print("Dir: " + p));
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
    static message(text: string): HSUIFilePicker;

    /**
     * Set the starting directory
     * @param path Path to directory (supports `~` for home)
     * @returns Self for chaining
     */
    static defaultPath(path: string): HSUIFilePicker;

    /**
     * Set whether files can be selected
     * @param value true to allow file selection (default: true)
     * @returns Self for chaining
     */
    static canChooseFiles(value: boolean): HSUIFilePicker;

    /**
     * Set whether directories can be selected
     * @param value true to allow directory selection (default: false)
     * @returns Self for chaining
     */
    static canChooseDirectories(value: boolean): HSUIFilePicker;

    /**
     * Set whether multiple items can be selected
     * @param value true to allow multiple selection (default: false)
     * @returns Self for chaining
     */
    static allowsMultipleSelection(value: boolean): HSUIFilePicker;

    /**
     * Restrict to specific file types
     * @param types Array of file extensions (e.g., ["txt", "md"])
     * @returns Self for chaining
     */
    static allowedFileTypes(types: string[]): HSUIFilePicker;

    /**
     * Set whether to resolve symbolic links
     * @param value true to resolve aliases (default: true)
     * @returns Self for chaining
     */
    static resolvesAliases(value: boolean): HSUIFilePicker;

    /**
     * Set the callback for file selection
     * @param callback Function receiving selected path(s) or null if cancelled
     * @returns Self for chaining
     */
    static onSelection(callback: JSValue): HSUIFilePicker;

    /**
     * Show the file picker dialog
     */
    static show(): void;

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
            print("User entered: " + text);
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
    static informativeText(text: string): HSUITextPrompt;

    /**
     * Set the default text in the input field
     * @param text Default text value
     * @returns Self for chaining
     */
    static defaultText(text: string): HSUITextPrompt;

    /**
     * Set custom button labels
     * @param labels Array of button labels (default: ["OK", "Cancel"])
     * @returns Self for chaining
     */
    static buttons(labels: string[]): HSUITextPrompt;

    /**
     * Set the callback for button presses
     * @param callback Function receiving (buttonIndex, inputText)
     * @returns Self for chaining
     */
    static onButton(callback: JSValue): HSUITextPrompt;

    /**
     * Show the prompt dialog
     */
    static show(): void;

}

/**
 * A WKWebView hosted inside a borderless NSWindow, created via `hs.webview.new()`.
Provides a builder-style API for loading URLs or HTML, styling the window,
registering JS message handlers, evaluating JavaScript, and managing the window lifecycle.
 */
declare namespace hs.webview {
    /**
     * Create a new webview hosted in a borderless NSWindow.
     * @param rect `{ x, y, w, h }` in NSWindow coordinates
     * @returns an `HSWebview` configured to host a WKWebView. Chain
     */
    function new(rect: JSValue): HSWebview | undefined;

}

/**
 * A WKWebView hosted inside a borderless NSWindow, created via `hs.webview.new()`.
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
    static url(urlString: string): HSWebview;

    /**
     * Load HTML source directly into the webview.
     * @param html HTML source string
     * @param baseURL optional base URL (string) for resolving relative refs; null to use about:blank
     * @returns self for chaining
     */
    static html(html: string, baseURL: JSValue): HSWebview;

    /**
     * Reload the currently-loaded content.
     * @returns self for chaining
     */
    static reload(): HSWebview;

    /**
     * Configure window chrome.
`transparent: true` makes the NSWindow opaque-bg false so the page's own background shows through.
     * @param opts `{ titled?, closable?, resizable?, miniaturizable?, transparent? }` — all optional booleans.
     * @returns self for chaining
     */
    static windowStyle(opts: JSValue): HSWebview;

    /**
     * Set the window level by name. Same vocabulary as `hs.ui.window.level()`.
     * @param name `'normal' | 'floating' | 'modal' | 'popup' | 'screensaver' | 'mainmenu' | 'status'`
     * @returns self for chaining
     */
    static level(name: string): HSWebview;

    /**
     * Allow this window to become key (capture keyboard focus). Default true for webviews.
     * @param value whether the window can become key
     * @returns self for chaining
     */
    static canBecomeKey(value: boolean): HSWebview;

    /**
     * Make the window click-through: mouse events pass to whatever is beneath it. Essential for a
transparent, screen-covering HUD overlay so it never steals the user's input.
     * @param value true to ignore mouse events
     * @returns self for chaining
     */
    static ignoresMouseEvents(value: boolean): HSWebview;

    /**
     * Make the window appear on every Space and stay put across Space switches (HUD overlay).
     * @param value true to join all Spaces (canJoinAllSpaces + stationary)
     * @returns self for chaining
     */
    static canJoinAllSpaces(value: boolean): HSWebview;

    /**
     * Center the window on the main screen on `show()`.
     * @returns self for chaining
     */
    static center(): HSWebview;

    /**
     * Set window corner radius. Applied to the contentView (clipped) so the
rounded shape is preserved when the window is transparent.
     * @param radius pixel radius
     * @returns self for chaining
     */
    static windowCornerRadius(radius: number): HSWebview;

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
    static backgroundColor(color: JSValue): HSWebview;

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
    static keepsRenderingWhenInactive(value: boolean): HSWebview;

    /**
     * Show the window. If already shown, brings it to front.
     * @returns self for chaining
     */
    static show(): HSWebview;

    /**
     * Hide the window. Keeps the WKWebView and its loaded page in memory.
     * @returns self for chaining
     */
    static hide(): HSWebview;

    /**
     * Close and destroy the window. Drops the WKWebView and frees handlers.
     */
    static close(): void;

    /**
     * Bring the window to the foreground without reordering across spaces.
     * @returns self for chaining
     */
    static bringToFront(): HSWebview;

    /**
     * Return the current on-screen frame as `{x, y, w, h}`, or null if not shown.
     * @returns `{x, y, w, h}` in NSWindow (bottom-left origin) coordinates, or null if not shown
     */
    static currentFrame(): Record<string, number> | undefined;

    /**
     * Resize and/or move the on-screen window.
     * @param rect `{ x, y, w, h }` in NSWindow coordinates
     * @returns self for chaining
     */
    static setFrame(rect: JSValue): HSWebview;

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
    static snapshotToPNG(path: string, callback: JSValue): void;

    /**
     * Register a named handler for messages posted from JS.
In the page, call `window.webkit.messageHandlers.<name>.postMessage(body)`.
The Swift callback fires with the deserialized body (object/string/number).
Pass `null` to unregister.
     * @param name handler name (matches the page's `messageHandlers.<name>`)
     * @param callback function to call with each message body, or null to remove
     * @returns self for chaining
     */
    static setMessageHandler(name: string, callback: JSValue): HSWebview;

    /**
     * Inject JavaScript that runs at document-start, before the page's own scripts.
Use to install a bridge client so postMessage calls work from page load.
     * @param source JavaScript source
     * @returns self for chaining
     */
    static injectUserScript(source: string): HSWebview;

    /**
     * Evaluate a JS expression inside the page. Optional callback receives
`(result, errorMessage)` — result is the stringified JS value (null if
not representable as JSON), errorMessage is null on success.
     * @param script JS expression or block
     * @param callback optional completion `(result, error) => void`
     */
    static evaluateJavaScript(script: string, callback: JSValue): void;

    /**
     * Register a callback for window lifecycle events. Currently fires with
the string `'closing'` when the window is about to close.
     * @param callback `(event) => void`
     * @returns self for chaining
     */
    static windowCallback(callback: JSValue): HSWebview;

    /**
     * Enable Safari "Inspect Element" right-click for this webview. Off by default.
     * @param enabled whether to enable
     * @returns self for chaining
     */
    static developerExtras(enabled: boolean): HSWebview;

}

/**
 * Module for interacting with windows
 */
declare namespace hs.window {
    /**
     * Get the currently focused window
     * @returns The focused window, or nil if none
     */
    function focusedWindow(): HSWindow | undefined;

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
    function windowAtPoint(point: HSPoint): HSWindow | undefined;

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
    function snapshot(): [[String: Any]];

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
 */
declare class HSWindow {
    /**
     * Focus this window
     * @returns true if successful
     */
    static focus(): boolean;

    /**
     * Minimize this window
     * @returns true if successful
     */
    static minimize(): boolean;

    /**
     * Unminimize this window
     * @returns true if successful
     */
    static unminimize(): boolean;

    /**
     * Raise this window to the front
     * @returns true if successful
     */
    static raise(): boolean;

    /**
     * Toggle fullscreen mode
     * @returns true if successful
     */
    static toggleFullscreen(): boolean;

    /**
     * Close this window
     * @returns true if successful
     */
    static close(): boolean;

    /**
     * Center the window on the screen
     */
    static centerOnScreen(): void;

    /**
     * Get the underlying AXElement
     * @returns The accessibility element for this window
     */
    static axElement(): HSAXElement;

    /**
     * The window's title
     */
    title: string | undefined;

    /**
     * The application that owns this window
     */
    application: HSApplication | undefined;

    /**
     * The process ID of the application that owns this window
     */
    pid: number;

    /**
     * Whether the window is minimized
     */
    isMinimized: boolean;

    /**
     * Whether the window is visible (not minimized or hidden)
     */
    isVisible: boolean;

    /**
     * Whether the window is focused
     */
    isFocused: boolean;

    /**
     * Whether the window is fullscreen
     */
    isFullscreen: boolean;

    /**
     * Whether the window is standard (has a titlebar)
     */
    isStandard: boolean;

    /**
     * The window's position on screen {x: Int, y: Int}
     */
    position: HSPoint | undefined;

    /**
     * The window's size {w: Int, h: Int}
     */
    size: HSSize | undefined;

    /**
     * The window's frame {x: Int, y: Int, w: Int, h: Int}
     */
    frame: HSRect | undefined;

    /**
     * The screen that contains the largest portion of this window.
     */
    screen: HSScreen | undefined;

}

