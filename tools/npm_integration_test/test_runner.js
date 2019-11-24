/**
 * @license
 * Copyright Google Inc. All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 */

const spawnSync = require('child_process').spawnSync;
const fs = require('fs');
const path = require('path');
const tmp = require('tmp');

const VERBOSE_LOGS = !!process.env['VERBOSE_LOGS'];

// Set TEST_MANIFEST to true and use `bazel run` to excersize the MANIFEST
// file code path on Linux and OSX
const TEST_MANIFEST = false;

// File permissions to set for files copied to tmp folders.
// These are needed a files copied out of bazel-bin will have
// restrictive permissions that may break tests.
const FILE_PERMISSIONS = '644';

function fail(...m) {
  console.error();
  console.error('[test_runner.js]');
  console.error('error:', ...m);
  console.error();
  process.exit(1);
}

function log(...m) {
  console.error('[test_runner.js]', ...m);
}

function log_verbose(...m) {
  if (VERBOSE_LOGS) console.error('[test_runner.js]', ...m);
}

/**
 * Create a new directory and any necessary subdirectories
 * if they do not exist.
 */
function mkdirp(p) {
  if (!fs.existsSync(p)) {
    mkdirp(path.dirname(p));
    fs.mkdirSync(p);
  }
}

/**
 * Checks if a given path exists and is a file.
 * Note: fs.statSync() is used which resolves symlinks.
 */
function isFile(p) {
  return fs.existsSync(p) && fs.statSync(p).isFile();
}

/**
 * Given a list of files, the root directory is returned
 */
function rootDirectory(files) {
  let root = files[0];
  for (f of files) {
    const maybe = path.dirname(f);
    if (maybe.length < root.length) {
      root = maybe;
    }
  }
  for (f of files) {
    if (!f.startsWith(root)) {
      fail(`not all test files are under the same root (${f} does not start with ${root}!`);
    }
  }
  return root;
}

/**
 * Utility function to copy a list of files under a common root to a destination folder.
 */
function copy(files, root, to) {
  for (src of files) {
    if (!src.startsWith(root)) {
      fail(`file to copy ${src} is not under root ${root}`);
    }
    if (isFile(src)) {
      const rel = src.slice(root.length + 1);
      if (rel.startsWith('node_modules/')) {
        // don't copy nested node_modules
        continue;
      }
      const dest = path.posix.join(to, rel);
      mkdirp(path.dirname(dest));
      fs.copyFileSync(src, dest);
      fs.chmodSync(dest, FILE_PERMISSIONS);
      log_verbose(`copying file ${src} -> ${dest}`);
    } else {
      fail('directories in test_files not supported');
    }
  }
  return to;
}

class TestRunner {
  constructor(config, args) {
    this.config = config;
    this.args = args;
    this.successful = 0;
    this._setupRunfilesManifest();
    this._setupTestFiles();
    this._patchPackageJson();
  }

  run() {
    for (const command of this.config.commands) {
      const split = command.split(' ');
      const binary = split[0].startsWith('./') ?
          split[0] :
          this._resolveFile(split[0].replace(/^external\//, ''));
      const args = split.slice(1);
      log(`running test command '${binary} ${args.join(' ')}' in ${this.testRoot}`);
      const spawnedProcess = spawnSync(binary, args, {cwd: this.testRoot, stdio: 'inherit'});
      if (spawnedProcess.status) {
        return spawnedProcess.status;
      }
      this.successful++;
    }
    return 0;
  }

  /** @internal */
  _patchPackageJson() {
    const packageJson = path.posix.join(this.testRoot, 'package.json');
    if (!isFile(packageJson)) {
      fail(`no package.json file found at test root ${this.testRoot}`);
    }
    let contents = fs.readFileSync(packageJson, {encoding: 'utf-8'});
    // replace npm packages
    for (const key of Object.keys(this.config.npmPackages)) {
      const path = this._resolveFile(this.config.npmPackages[key]);
      const regex = new RegExp(`\"${key}\"\\s*\:\\s*\"[^"]+`);
      const replacement = `"${key}": "file:${path}`;
      contents = contents.replace(regex, replacement);
      if (!contents.includes(path)) {
        fail(`package.json replacement for npm package '${key}' failed`);
      }
      log(`overriding '${key}' npm package with 'file:${path}' in package.json file`);
    }
    // check packages
    const failedPackages = [];
    for (const key of this.config.checkNpmPackages) {
      if (contents.includes(`"${key}"`) &&
          (!contents.includes(`"${key}": "file:`) || contents.includes(`"${key}": "file:.`))) {
        failedPackages.push(key);
      }
    }
    if (failedPackages.length) {
      fail(
          `expected replacement of npm packages ${JSON.stringify(failedPackages)} for locally generated npm_package not found; add these to npm_packages attribute`);
    }
    log(`package.json file:\n${contents}`);
    fs.writeFileSync(packageJson, contents);
  }

  /** @internal */
  _setupTestFiles() {
    if (!this.config.testFiles.length) {
      fail(`no test files`);
    }
    if (this.config.debug) {
      // Setup the test in the test files root directory
      const workspaceDirectory = process.env['BUILD_WORKSPACE_DIRECTORY'];
      if (!workspaceDirectory) {
        fail(`debug mode only available with 'bazel run ${process.env['TEST_TARGET']}'`);
      }
      const testWorkspace = process.env['TEST_WORKSPACE'];
      if (!testWorkspace) {
        fail(`TEST_WORKSPACE not set`);
      }
      const root = rootDirectory(this.config.testFiles);
      if (!root.startsWith(`${testWorkspace}/`)) {
        fail(`debug mode only available with test files in the test workspace '${testWorkspace}'`);
      }
      this.testRoot = path.posix.join(workspaceDirectory, '..', root);
      log(`configuring test in-place under ${this.testRoot}`);
    } else {
      this.testRoot = this._copyToTmp(this.config.testFiles);
      log(`test files from '${rootDirectory(this.config.testFiles)}' copied to tmp folder ${this.testRoot}`);
    }
  }

  /** @internal */
  _copyToTmp(files) {
    const resolved = files.map(f => this._resolveFile(f));
    return copy(
        resolved, rootDirectory(resolved), tmp.dirSync({keep: false, unsafeCleanup: true}).name);
  }

  /** @internal */
  _resolveFile(file) {
    return this.runfilesManifest ? this.runfilesManifest[file] :
                                   path.posix.join(process.cwd(), '..', file);
  }

  /** @internal */
  _setupRunfilesManifest() {
    // Loads the Bazel MANIFEST file and returns its contents as an object
    // if is found. Returns undefined if there is no MANIFEST file.
    // On Windows, Bazel sets RUNFILES_MANIFEST_ONLY=1 and RUNFILES_MANIFEST_FILE.
    // On Linux and OSX RUNFILES_MANIFEST_FILE is not set and not available in the test
    // sandbox but outside of the test sandbox (when executing with `bazel run` for example)
    // we can look for the MANIFEST file and load it. This allows us to exercise the
    // manifest loading code path on Linux and OSX.
    if (this.runfilesManifest) {
      return;
    }
    const runfilesManifestFile = path.posix.join(process.env['RUNFILES_DIR'], 'MANIFEST');
    const isRunfilesManifestFile = isFile(runfilesManifestFile);
    if (process.env['RUNFILES_MANIFEST_ONLY'] === '1' ||
        (TEST_MANIFEST && isRunfilesManifestFile)) {
      const manifestPath = process.env['RUNFILES_MANIFEST_FILE'] || runfilesManifestFile;
      this.runfilesManifest = Object.create(null);
      const input = fs.readFileSync(manifestPath, {encoding: 'utf-8'});
      for (const line of input.split('\n')) {
        if (!line) continue;
        const [runfilesPath, realPath] = line.split(' ');
        this.runfilesManifest[runfilesPath] = realPath;
      }
    }
  }
}


const config = require(process.argv[2]);
const args = process.argv.slice(3);

// set env vars passed from --define
for (const k of Object.keys(config.envVars)) {
  const v = config.envVars[k];
  process.env[k] = v;
  log_verbose(`set environment variable ${k}='${v}'`);
}

log_verbose(`env: ${JSON.stringify(process.env, null, 2)}`);
log_verbose(`config: ${JSON.stringify(config, null, 2)}`);
log_verbose(`args: ${JSON.stringify(args, null, 2)}`);
log(`running in ${process.cwd()}`);

const testRunner = new TestRunner(config, args);
const result = testRunner.run();
log(`${testRunner.successful} of ${config.commands.length} test commands successful`);
if (result) {
  log(`test command ${testRunner.successful+1} failed with status code ${result}`);
  if (!config.debug) {
    log(`to run test in debug mode:

    bazel run ${process.env['TEST_TARGET']}.debug`);
  }
}
if (config.debug) {
  log(`test may be re-run manually under ${testRunner.testRoot}`);
}
process.exit(result);
