/**
 * @license
 * Copyright 2015 The Emscripten Authors
 * SPDX-License-Identifier: MIT
 */

// Pthread Web Worker startup routine:
// This is the entry point file that is loaded first by each Web Worker
// that executes pthreads on the Emscripten application.

'use strict';

var Module = {};

// Thread-local guard variable for one-time init of the JS state
var initializedJS = false;

function assert(condition, text) {
  if (!condition) abort('Assertion failed: ' + text);
}

function threadPrintErr() {
  var text = Array.prototype.slice.call(arguments).join(' ');
  console.error(text);
}
function threadAlert() {
  var text = Array.prototype.slice.call(arguments).join(' ');
  postMessage({cmd: 'alert', text: text, threadId: Module['_pthread_self']()});
}
// We don't need out() for now, but may need to add it if we want to use it
// here. Or, if this code all moves into the main JS, that problem will go
// away. (For now, adding it here increases code size for no benefit.)
var out = () => { throw 'out() is not defined in worker.js.'; }
var err = threadPrintErr;
self.alert = threadAlert;

Module['instantiateWasm'] = (info, receiveInstance) => {
  // Instantiate from the module posted from the main thread.
  // We can just use sync instantiation in the worker.
  var module = Module['wasmModule'];
  // We don't need the module anymore; new threads will be spawned from the main thread.
  Module['wasmModule'] = null;
  var instance = new WebAssembly.Instance(module, info);
  // TODO: Due to Closure regression https://github.com/google/closure-compiler/issues/3193,
  // the above line no longer optimizes out down to the following line.
  // When the regression is fixed, we can remove this if/else.
  return receiveInstance(instance);
}

// Turn unhandled rejected promises into errors so that the main thread will be
// notified about them.
self.onunhandledrejection = (e) => {
  throw e.reason ?? e;
};

function handleMessage(e) {
  try {
    if (e.data.cmd === 'load') { // Preload command that is called once per worker to parse and load the Emscripten code.

    // Until we initialize the runtime, queue up any further incoming messages.
    let messageQueue = [];
    self.onmessage = (e) => messageQueue.push(e);

    // And add a callback for when the runtime is initialized.
    self.startWorker = (instance) => {
      Module = instance;
      // Notify the main thread that this thread has loaded.
      postMessage({ 'cmd': 'loaded' });
      // Process any messages that were queued before the thread was ready.
      for (let msg of messageQueue) {
        handleMessage(msg);
      }
      // Restore the real message handler.
      self.onmessage = handleMessage;
    };

      // Module and memory were sent from main thread
      Module['wasmModule'] = e.data.wasmModule;

      // Use `const` here to ensure that the variable is scoped only to
      // that iteration, allowing safe reference from a closure.
      for (const handler of e.data.handlers) {
        Module[handler] = function() {
          postMessage({ cmd: 'callHandler', handler, args: [...arguments] });
        }
      }

      Module['wasmMemory'] = e.data.wasmMemory;

      Module['buffer'] = Module['wasmMemory'].buffer;

      Module['workerID'] = e.data.workerID;

      Module['ENVIRONMENT_IS_PTHREAD'] = true;

      if (typeof e.data.urlOrBlob == 'string') {
        importScripts(e.data.urlOrBlob);
      } else {
        var objectUrl = URL.createObjectURL(e.data.urlOrBlob);
        importScripts(objectUrl);
        URL.revokeObjectURL(objectUrl);
      }
      Godot(Module);
    } else if (e.data.cmd === 'run') {
      // Pass the thread address to wasm to store it for fast access.
      Module['__emscripten_thread_init'](e.data.pthread_ptr, /*isMainBrowserThread=*/0, /*isMainRuntimeThread=*/0, /*canBlock=*/1);

      // Await mailbox notifications with `Atomics.waitAsync` so we can start
      // using the fast `Atomics.notify` notification path.
      Module['__emscripten_thread_mailbox_await'](e.data.pthread_ptr);

      assert(e.data.pthread_ptr);
      // Also call inside JS module to set up the stack frame for this pthread in JS module scope
      Module['establishStackSpace']();
      Module['PThread'].receiveObjectTransfer(e.data);
      Module['PThread'].threadInitTLS();

      if (!initializedJS) {
        initializedJS = true;
      }

      try {
        Module['invokeEntryPoint'](e.data.start_routine, e.data.arg);
      } catch(ex) {
        if (ex != 'unwind') {
          // The pthread "crashed".  Do not call `_emscripten_thread_exit` (which
          // would make this thread joinable).  Instead, re-throw the exception
          // and let the top level handler propagate it back to the main thread.
          throw ex;
        }
      }
    } else if (e.data.cmd === 'cancel') { // Main thread is asking for a pthread_cancel() on this thread.
      if (Module['_pthread_self']()) {
        Module['__emscripten_thread_exit'](-1);
      }
    } else if (e.data.target === 'setimmediate') {
      // no-op
    } else if (e.data.cmd === 'checkMailbox') {
      if (initializedJS) {
        Module['checkMailbox']();
      }
    } else if (e.data.cmd) {
      // The received message looks like something that should be handled by this message
      // handler, (since there is a e.data.cmd field present), but is not one of the
      // recognized commands:
      err('worker.js received unknown command ' + e.data.cmd);
      err(e.data);
    }
  } catch(ex) {
    err('worker.js onmessage() captured an uncaught exception: ' + ex);
    if (ex && ex.stack) err(ex.stack);
    if (Module['__emscripten_thread_crashed']) {
      Module['__emscripten_thread_crashed']();
    }
    throw ex;
  }
};

self.onmessage = handleMessage;


