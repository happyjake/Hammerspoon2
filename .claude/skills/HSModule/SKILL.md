---
name: hs2module
description: Ensure all Hammerspoon v2 modules follow established patterns
---

# Hammerspoon 2 Module Requirements

Hammerspoon 2 consists of two main components:
 * a core engine that bridges native Swift code into JavaScript for the user to write their configuration file
 * Various "modules" that add expose macOS APIs into the JavaScript engine.

## Where do Hammerspoon 2 modules live?

In the directory "Hammerspoon 2/Modules", each within a further directory that shares the name they will be exposed to JS with, e.g. "hs.location"

## Basic structure of a module

For the case of a module that we intend to be accessible in JS as "hs.foo", the following structural rules must be observed:

 * All of the code for hs.foo should live in "Hammerspoon 2/Modules/hs.foo"
 * The code to be loaded when JavaScript accesses "hs.foo" should live in a file called "HSFooModule.swift"
 * HSFooModule.swift should always import the "Foundation" and "JavaScriptCore" frameworks
 * HSFooModule.swift should always contain at least the following:
  * A protocol definition of the form "@objc protocol HSFooModuleAPI: JSExport" - this is where we define the API that will be exported to JSON
  * A class implementation of "HSFooModuleAPI" of the form: "@objc class HSFooModule: NSObject, HSModuleAPI, HSFooModuleAPI"

## JavaScript API considerations

The HSFooModuleAPI protocol should observe the following rules:

 * Method parameters need to have their labels omitted, ie "@objc func doFoo(_ someParameter: String)" - the underscore before the label means it will not be required to call the method with the label. If this rule is ignored, the name of the method exposed to JavaScript will be a complex mixture of the name of the method and the labels of its parameters.
 * If for some reason we must have parameter labels, the name of the method exposed to JavaScript can be overridden thusly: "@objc(doFoo:) func doFoo(someParameter: String)"
 * If we are allowing users to create "watcher" objects that respond to macOS events and call user-supplied JS callbacks, they should be created/destroyed with methods called "addWatcher" and "removeWatcher"

## Watchers

A common pattern is to register a callback with macOS that will be called when particular system events occur. Here are some considerations for when you are exposing watchers to JavaScript:

 * Any watcher objects created must be weakly tracked by HSFooModule so they can be stopped and destroyed in its shutdown() method
 * If the underlying macOS API only allows for one watcher object to be created, we will addtionally include a file with the module called "hs.foo.js" that contains a multiplexer allowing the user to register multiple JS callbacks for the event:
  * In HSFooModule, expose a property of the form: @objc var _watcherEmitter: JSValue?
