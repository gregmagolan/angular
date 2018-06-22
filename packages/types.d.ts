/**
 * @license
 * Copyright Google Inc. All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

// This file contains all ambient imports needed to compile the packages/ source code

/// <reference types="zone.js" />
/// <reference types="hammerjs" />
/// <reference types="jasmine" />
/// <reference types="node" />
/// <reference types="selenium-webdriver" />
/// <reference path="./es6-subset.d.ts" />
/// <reference path="./system.d.ts" />
/// <reference path="./goog.d.ts" />

declare let isNode: boolean;
declare let isBrowser: boolean;

declare namespace jasmine {
  interface Matchers {
    toHaveProperties(obj: any): boolean;
  }
}
