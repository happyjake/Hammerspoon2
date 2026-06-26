// hs.http — JavaScript enhancements
//
// Promise sugar over the cancellable callback core `hs.http.request(options, cb)`.
// These resolve with the response object `{status, headers, bytes, body?, path?}`
// and reject (Error) only on transport failure / cancellation — a non-2xx status
// still resolves, so callers inspect `res.status` themselves (Fetch-like).

"use strict";

(function () {
  function req(options) {
    return new Promise((resolve, reject) => {
      hs.http.request(options || {}, (err, res) => {
        if (err) reject(new Error(err));
        else resolve(res);
      });
    });
  }

  hs.http.fetch = function (options) {
    return req(options || {});
  };

  hs.http.get = function (url, options) {
    return req(Object.assign({}, options || {}, { url: url, method: "GET" }));
  };

  hs.http.post = function (url, body, options) {
    return req(Object.assign({}, options || {}, { url: url, method: "POST", body: body }));
  };
})();
