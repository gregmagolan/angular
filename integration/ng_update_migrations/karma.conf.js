// Karma configuration file, see link for more information
// https://karma-runner.github.io/1.0/config/configuration-file.html

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

module.exports = function (config) {
  config.set({
    basePath: '',
    frameworks: ['jasmine', '@angular-devkit/build-angular'],
    plugins: [
      require('karma-jasmine'),
      require('karma-chrome-launcher'),
      require('karma-jasmine-html-reporter'),
      require('@angular-devkit/build-angular/plugins/karma')
    ],
    client: {
      clearContext: false // leave Jasmine Spec Runner output visible in browser
    },
    reporters: ['progress', 'kjhtml'],
    port: 9876,
    colors: true,
    logLevel: config.LOG_INFO,
    autoWatch: true,
    browsers: [headless ? 'ChromeHeadless' : 'Chrome'],
    singleRun: false,
    restartOnFileChange: true
  });
};
