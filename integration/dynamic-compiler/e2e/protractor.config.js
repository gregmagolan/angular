// Run in headless when under `bazel test` as tests may be parallized
const headless = process.env['BAZEL_TARGET'] && !process.env['BUILD_WORKSPACE_DIRECTORY'];

exports.config = {
  specs: [
    '../dist/e2e/*.e2e-spec.js'
  ],
  capabilities: {
    browserName: 'chrome',
    chromeOptions: {
      args: ['--no-sandbox'].concat(headless ? ['--headless', '--disable-gpu', '--disable-dev-shm-usage'] : []),
    },
  },
  directConnect: true,
  // Port comes from lite-serve config `/e2e/browser.config.json` `"port": 4207`
  baseUrl: 'http://localhost:4207/',
  framework: 'jasmine',
  useAllAngular2AppRoots: true
};
