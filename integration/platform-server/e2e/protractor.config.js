/**
 * @license
 * Copyright Google Inc. All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

// Run in headless when under `bazel test` as tests may be parallized
const headless = process.env['BAZEL_TARGET'] && !process.env['BUILD_WORKSPACE_DIRECTORY'];

exports.config = {
  specs: ['../built/e2e/*-spec.js'],
  capabilities: {
    browserName: 'chrome',
    chromeOptions: {
      args: ['--no-sandbox'].concat(headless ? ['--headless', '--disable-gpu', '--disable-dev-shm-usage'] : []),
    },
  },
  directConnect: true,
  // Port comes from lite-serve config `/src/server.ts` `app.listen(4213,...`
  baseUrl: 'http://localhost:4213/',
  framework: 'jasmine',
  useAllAngular2AppRoots: true
};
