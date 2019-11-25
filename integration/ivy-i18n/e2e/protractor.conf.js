// @ts-check
// Protractor configuration file, see link for more information
// https://github.com/angular/protractor/blob/master/lib/config.ts

const { SpecReporter } = require('jasmine-spec-reporter');

// If we're running this integration test under Bazel (with npm_integration_test)
// and we're on CIRCLECI then we need to run with headless or Chrome fails to start
// ```
// Chrome stderr: mkdir: cannot create directory '/.local': Permission denied
// touch: cannot touch '/.local/share/applications/mimeapps.list': No such file or directory
// (google-chrome:4468): Gtk-WARNING **: cannot open display: 
// [1122/065623.670987:ERROR:nacl_helper_linux.cc(310)] NaCl helper process running without a sandbox!
// Most likely you need to configure your SUID sandbox correctly
// ```
const headless = process.env['BAZEL_TARGET'] && process.env['CIRCLECI'];
// TODO(gregmagolan): figure out why this is the case; there are probably some environment variables not available
// to the action that Chrome needs to run in non-headless mode.

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
      args: ['--no-sandbox'].concat(headless ? ['--headless', '--disable-gpu', '--disable-dev-shm-usage'] : []),
    },
  },
  directConnect: true,
  baseUrl: 'http://localhost:4200/',
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
