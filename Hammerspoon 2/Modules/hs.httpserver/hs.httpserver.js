// hs.httpserver — JS enhancements
//
// Exposes Fetch-API names (`Response`, `Headers`) as globals so fetch handlers
// can write `new Response('hi')` / `Response.json({})` etc. the same way they
// would in Bun, Deno, Cloudflare Workers, or a browser.
//
// JSC's class-export model has trouble binding a JS constructor when the
// underlying Obj-C init takes JSValue parameters (HSColor avoids this with
// static `.rgb()` / `.hex()` factories). We follow the same pattern: the
// Swift class exposes `HSHttpResponse.make(body, init)` and `HSHttpHeaders.make(init)`
// as statics, and this file wraps them in JS functions that work with `new`.
//
// `new Response(body, init)` → returns the object the function returns,
// which is the @objc HSHttpResponse instance — fully usable downstream.

"use strict";

(function () {
  function Response(body, init) {
    return HSHttpResponse.make(body, init);
  }
  // Mirror the Fetch-spec statics.
  Response.json = function (value, init) {
    return HSHttpResponse.json(value, init);
  };
  Response.redirect = function (url, status) {
    return HSHttpResponse.redirect(url, status);
  };

  function Headers(init) {
    return HSHttpHeaders.make(init);
  }

  if (typeof globalThis.Response === 'undefined') globalThis.Response = Response;
  if (typeof globalThis.Headers === 'undefined') globalThis.Headers = Headers;
})();
