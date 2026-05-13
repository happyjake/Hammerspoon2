//
//  hs.application.js
//  Hammerspoon 2
//
//  Created by Chris Jones on 23/10/2025.
//

"use strict";

// one-to-many event emitter for hs.application events
class ApplicationModuleWatcherEmitter {
    #listeners = []

    constructor() {}

    #handleEvent(event, appObject) {
        var listeners = this.#listeners.slice();
        const length = listeners.length;

        for (var i = 0; i < length; i++) {
            listeners[i].apply(null, [event, appObject]);
        }
    }

    on(listener) {
        if (typeof listener !== 'function') {
            throw new Error("hs.application.addWatcher(): The provided handler must be a function")
        }

        if (this.#listeners.includes(listener)) {
            console.error("hs.application.addWatcher(): The provided handler is already registered.")
            return;
        }

        if (this.#listeners.length === 0) {
            hs.application._addWatcher((event, appObject) => { this.#handleEvent(event, appObject) });
        }

        this.#listeners.push(listener);
    }

    removeListener(listener) {
        const idx = this.#listeners.indexOf(listener);

        if (idx > -1) {
            this.#listeners.splice(idx, 1);
        }

        if (this.#listeners.length === 0) {
            hs.application._removeWatcher();
        }
    }
}

// Store an instance of the Watcher/Emitter in a Swift-retained property so it is not garbage collected.
hs.application._watcherEmitter = new ApplicationModuleWatcherEmitter();
