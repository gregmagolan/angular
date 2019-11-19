// @ts-check
// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { SpecReporter } = require('jasmine-spec-reporter');

// Run in headless when under `bazel test` as tests may be parallized
const headless = process.env['BAZEL_TARGET'] && !process.env['BUILD_WORKSPACE_DIRECTORY'];

/**
 * @type { import("protractor").Config }
 */
exports.config = {
  allScriptsTimeout: 11000,
  specs: [
    './src/**/*.e2e-spec.ts'
  ],
  capabilities: {
    browserName: 'chrome',
    chromeOptions: {
      args: headless ? ['--headless', '--disable-gpu', '--disable-dev-shm-usage'] : [],
    },
  },
  directConnect: true,
  // Port comes from package.json `e2e` script `ng e2e --port 4205`
  baseUrl: 'http://localhost:4205/',
  framework: 'jasmine',
  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000,
    print: function() {}
  },
  onPrepare() {
    require('ts-node').register({
      project: require('path').join(__dirname, './tsconfig.json')
    });
    jasmine.getEnv().addReporter(new SpecReporter({ spec: { displayStacktrace: true } }));
  }
};