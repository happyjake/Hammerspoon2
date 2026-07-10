// hs.ax.js
// JavaScript enhancements for the hs.ax module

"use strict";

// One-to-many event emitter for hs.ax events
// Similar to ApplicationModuleWatcherEmitter, this allows multiple JavaScript listeners
// for the same notification, while Swift only manages a single callback per app+notification
class AXModuleWatcherEmitter {
    #events = {}

    constructor() {}

    #handleEvent(key, notification, element) {
        if (Array.isArray(this.#events[key])) {
            var listeners = this.#events[key].slice();
            const length = listeners.length;

            for (var i = 0; i < length; i++) {
                listeners[i].apply(null, [notification, element]);
            }
        }
    }

    on(application, notification, listener) {
        if (typeof listener !== 'function') {
            throw new Error("hs.ax.addWatcher(): The provided handler must be a function");
        }

        // Create a unique key for this application+notification combination
        const key = `${application.pid}:${notification}`;

        if (!Array.isArray(this.#events[key])) {
            this.#events[key] = [];
            // First listener for this app+notification - register with Swift
            hs.ax._addWatcher(application, notification, (notif, elem) => {
                this.#handleEvent(key, notif, elem);
            });
        }

        if (this.#events[key].includes(listener)) {
            console.error(`hs.ax.addWatcher(): The provided handler for '${notification}' is already registered.`);
            return;
        }

        this.#events[key].push(listener);
    }

    removeListener(application, notification, listener) {
        const key = `${application.pid}:${notification}`;
        var idx;

        if (Array.isArray(this.#events[key])) {
            idx = this.#events[key].indexOf(listener);

            if (idx > -1) {
                this.#events[key].splice(idx, 1);
            }

            // If no more listeners for this app+notification, remove from Swift
            if (this.#events[key].length == 0) {
                hs.ax._removeWatcher(application, notification);
                delete this.#events[key];
            }
        }
    }
}

// Store an instance of the Watcher/Emitter in a Swift-retained property so it is not garbage collected.
hs.ax._watcherEmitter = new AXModuleWatcherEmitter();

// Convenience function to get the focused element
/// Fetch the focused UI element
/// Returns: An HSAXElement representing the focused UI element, or null if none was found
/// Example:
/// ```js
/// const el = hs.ax.focusedElement()
/// console.log(el.role, el.title)
/// ```
hs.ax.focusedElement = function() {
    const focusedApp = hs.application.frontmost();
    if (!focusedApp) {
        return null;
    }

    const appElement = hs.ax.applicationElement(focusedApp);
    if (!appElement) {
        return null;
    }

    // Find the focused element within the app
    const children = appElement.children();
    for (let child of children) {
        if (child.isFocused) {
            return child;
        }
    }

    return appElement;
};

// Helper to search for elements by role
/// Find AX elements for a given role
/// Parameters:
///  - role: The role name to search for
///  - parent: An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
///  - options: Optional object: { maxDepth: number, maxNodes: number }. maxDepth limits how many levels below the search root are visited (0 = the root only; unlimited when omitted). maxNodes caps the total number of elements visited (default 10000; pass 0 for unlimited). Every AX call is a synchronous IPC round-trip on the JS thread, so an uncapped walk of a large app (or the system-wide element) can freeze Hammerspoon for minutes — the default cap turns that into a bounded, warned-about truncation.
/// Returns: An array of found elements
/// Example:
/// ```js
/// const app = hs.application.frontmost()
/// const buttons = hs.ax.findByRole(app, "AXButton")
/// const windows = hs.ax.findByRole('AXWindow', appElem, { maxDepth: 1 })
/// ```
hs.ax.findByRole = function(role, parent, options) {
    const searchRoot = parent || hs.ax.systemWideElement();
    if (!searchRoot) {
        return [];
    }
    return hs.ax._boundedWalk(searchRoot, options, 'hs.ax.findByRole', function(element, results) {
        if (element.role === role) {
            results.push(element);
        }
    });
};

// Helper to search for elements by title
/// Find AX elements by title
/// Parameters:
///  - title: The name to search for
///  - parent: An HSAXElement object to search. If none is supplied, the search will be conducted system-wide
///  - options: Optional object: { maxDepth: number, maxNodes: number }. maxDepth limits how many levels below the search root are visited (0 = the root only; unlimited when omitted). maxNodes caps the total number of elements visited (default 10000; pass 0 for unlimited). Every AX call is a synchronous IPC round-trip on the JS thread, so an uncapped walk of a large app (or the system-wide element) can freeze Hammerspoon for minutes — the default cap turns that into a bounded, warned-about truncation.
/// Returns: An array of found elements
/// Example:
/// ```js
/// const app = hs.application.frontmost()
/// const matches = hs.ax.findByTitle(app, "OK")
/// const shallow = hs.ax.findByTitle('OK', appElem, { maxDepth: 4 })
/// ```
hs.ax.findByTitle = function(title, parent, options) {
    const searchRoot = parent || hs.ax.systemWideElement();
    if (!searchRoot) {
        return [];
    }
    return hs.ax._boundedWalk(searchRoot, options, 'hs.ax.findByTitle', function(element, results) {
        if (element.title && element.title.includes(title)) {
            results.push(element);
        }
    });
};

// Shared bounded depth-first walk for the find* helpers.
// Not part of the public API. Visits at most maxNodes elements (default
// 10000, 0 = unlimited) and descends at most maxDepth levels (unlimited when
// omitted). Warns on the console once per call when the node budget
// truncates the search, so silent partial results don't masquerade as
// exhaustive ones.
/// SKIP_DOCS
hs.ax._boundedWalk = function(searchRoot, options, label, visit) {
    const maxDepth = (options && typeof options.maxDepth === 'number') ? options.maxDepth : Infinity;
    let maxNodes = (options && typeof options.maxNodes === 'number') ? options.maxNodes : 10000;
    if (maxNodes === 0) {
        maxNodes = Infinity;
    }

    const results = [];
    const stack = [{ element: searchRoot, depth: 0 }];
    let visited = 0;

    while (stack.length > 0) {
        if (visited >= maxNodes) {
            console.warn(label + ": stopped after visiting " + visited +
                " elements (results may be incomplete). Pass { maxNodes: 0 } to search without a budget, or scope the search with a smaller parent / { maxDepth: n }.");
            break;
        }
        const { element, depth } = stack.pop();
        visited++;

        visit(element, results);

        if (depth >= maxDepth) {
            continue;
        }
        const children = element.children();
        for (let child of children) {
            stack.push({ element: child, depth: depth + 1 });
        }
    }

    return results;
};

// Helper to print element hierarchy
/// Prints the hierarchy of a given element to the Console
/// Parameters:
///  - element: An HSAXElement
///  - depth: This parameter should not be supplied
/// Example:
/// ```js
/// const app = hs.application.frontmost()
/// hs.ax.printHierarchy(app)
/// ```
hs.ax.printHierarchy = function(element, depth = 0) {
    element = element || hs.ax.systemWideElement();
    if (!element) {
        console.log("No element provided");
        return;
    }

    // Depth alone doesn't bound the work: five levels of a browser can be
    // tens of thousands of elements, each costing a synchronous AX IPC on
    // the JS thread (plus a console line). Budget the total node count.
    let budget = 2000;

    const walk = function(el, d) {
        if (budget <= 0) {
            return;
        }
        budget--;

        const indent = "  ".repeat(d);
        const role = el.role || "unknown";
        const title = el.title || "";
        const titleStr = title ? ` "${title}"` : "";

        console.log(`${indent}${role}${titleStr}`);

        if (d < 5) { // Limit depth to avoid infinite recursion
            const children = el.children();
            for (let child of children) {
                walk(child, d + 1);
            }
        }
    };

    walk(element, depth);
    if (budget <= 0) {
        console.warn("hs.ax.printHierarchy: output truncated after 2000 elements");
    }
};
