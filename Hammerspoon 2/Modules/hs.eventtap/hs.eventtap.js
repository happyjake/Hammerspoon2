// hs.eventtap.js - JavaScript enhancements for hs.eventtap
"use strict";

// Expose `new` as a JS-friendly alias for `make` (Swift cannot expose a method
// named `new` because Objective-C reserves it for memory management).
hs.eventtap.new = hs.eventtap.make;
