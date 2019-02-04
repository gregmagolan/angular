/**
 * @license
 * Copyright Google Inc. All Rights Reserved.
 *
 * Use of this source code is governed by an MIT-style license that can be
 * found in the LICENSE file at https://angular.io/license
 *
 * @fileoverview Schematics for ng-new project that builds with Bazel.
 */

import { SchematicContext, apply, applyTemplates, chain, mergeWith, move, Rule, schematic, Tree, url, SchematicsException, UpdateRecorder, } from '@angular-devkit/schematics';
import { parseJsonAst, JsonAstObject, strings, JsonValue } from '@angular-devkit/core';
import { findPropertyInAstObject, insertPropertyInAstObjectInOrder } from '@schematics/angular/utility/json-utils';
import { validateProjectName } from '@schematics/angular/utility/validation';
import { getWorkspacePath } from '@schematics/angular/utility/config';
import { Schema } from './schema';

/**
 * Packages that build under Bazel require additional dev dependencies. This
 * function adds those dependencies to "devDependencies" section in
 * package.json.
 */
function addDevDependenciesToPackageJson(options: Schema) {
  return (host: Tree) => {
    const packageJson = 'package.json';
    if (!host.exists(packageJson)) {
      throw new Error(`Could not find ${packageJson}`);
    }
    const packageJsonContent = host.read(packageJson);
    if (!packageJsonContent) {
      throw new Error('Failed to read package.json content');
    }
    const jsonAst = parseJsonAst(packageJsonContent.toString()) as JsonAstObject;
    const deps = findPropertyInAstObject(jsonAst, 'dependencies') as JsonAstObject;
    const devDeps = findPropertyInAstObject(jsonAst, 'devDependencies') as JsonAstObject;

    const angularCoreNode = findPropertyInAstObject(deps, '@angular/core');
    if (!angularCoreNode) {
      throw new Error('@angular/core dependency not found in package.json');
    }
    const angularCoreVersion = angularCoreNode.value as string;

    const devDependencies: { [ k: string ]: string } = {
      '@angular/bazel': angularCoreVersion,
      // TODO(kyliau): Consider moving this to latest-versions.ts
      '@bazel/bazel': '^0.22.1',
      '@bazel/ibazel': '^0.9.0',
      '@bazel/karma': '^0.23.2',
      '@bazel/typescript': '^0.23.2',
    };

    const recorder = host.beginUpdate(packageJson);
    for (const packageName of Object.keys(devDependencies)) {
      const version = devDependencies[ packageName ];
      const indent = 4;
      insertPropertyInAstObjectInOrder(recorder, devDeps, packageName, version, indent);
    }
    host.commitUpdate(recorder);
    return host;
  };
}

/**
 * Append main.dev.ts and main.prod.ts to src directory. These files are needed
 * by Bazel for devserver and prodserver, respectively. They are different from
 * main.ts generated by CLI because they use platformBrowser (AOT) instead of
 * platformBrowserDynamic (JIT).
 */
function addDevAndProdMainForAot(options: Schema) {
  return (host: Tree) => {
    return mergeWith(apply(url('./files'), [
      applyTemplates({
        utils: strings,
        ...options,
        'dot': '.',
      }),
      move('/src'),
    ]));
  };
}

/**
 * Append '/bazel-out' to the gitignore file.
 */
function updateGitignore() {
  return (host: Tree) => {
    const gitignore = '/.gitignore';
    if (!host.exists(gitignore)) {
      return host;
    }
    const gitIgnoreContent = host.read(gitignore).toString();
    if (gitIgnoreContent.includes('\n/bazel-out\n')) {
      return host;
    }
    const compiledOutput = '# compiled output\n';
    const index = gitIgnoreContent.indexOf(compiledOutput);
    const insertionIndex = index >= 0 ? index + compiledOutput.length : gitIgnoreContent.length;
    const recorder = host.beginUpdate(gitignore);
    recorder.insertRight(insertionIndex, '/bazel-out\n');
    host.commitUpdate(recorder);
    return host;
  };
}

function replacePropertyInAstObject(
  recorder: UpdateRecorder, node: JsonAstObject, propertyName: string, value: JsonValue,
  indent: number) {
  const property = findPropertyInAstObject(node, propertyName);
  if (property === null) {
    throw new Error(`Property ${propertyName} does not exist in JSON object`);
  }
  const { start, text } = property;
  recorder.remove(start.offset, text.length);
  const indentStr = '\n' +
    ' '.repeat(indent);
  const content = JSON.stringify(value, null, '  ').replace(/\n/g, indentStr);
  recorder.insertLeft(start.offset, content);
}

function updateAngularJsonToUseBazelBuilder(options: Schema): Rule {
  return (host: Tree, context: SchematicContext) => {
    const { name } = options;
    const workspacePath = getWorkspacePath(host);
    if (!workspacePath) {
      throw new Error('Could not find angular.json');
    }
    const workspaceContent = host.read(workspacePath).toString();
    const workspaceJsonAst = parseJsonAst(workspaceContent) as JsonAstObject;
    const projects = findPropertyInAstObject(workspaceJsonAst, 'projects');
    if (!projects) {
      throw new SchematicsException('Expect projects in angular.json to be an Object');
    }
    const project = findPropertyInAstObject(projects as JsonAstObject, name);
    if (!project) {
      throw new SchematicsException(`Expected projects to contain ${name}`);
    }
    const recorder = host.beginUpdate(workspacePath);
    const indent = 8;
    const architect =
      findPropertyInAstObject(project as JsonAstObject, 'architect') as JsonAstObject;
    replacePropertyInAstObject(
      recorder, architect, 'build', {
        builder: '@angular/bazel:build',
        options: {
          targetLabel: '//src:bundle.js',
          bazelCommand: 'build',
        },
        configurations: {
          production: {
            targetLabel: '//src:bundle',
          },
        },
      },
      indent);
    replacePropertyInAstObject(
      recorder, architect, 'serve', {
        builder: '@angular/bazel:build',
        options: {
          targetLabel: '//src:devserver',
          bazelCommand: 'run',
        },
        configurations: {
          production: {
            targetLabel: '//src:prodserver',
          },
        },
      },
      indent);
    replacePropertyInAstObject(
      recorder, architect, 'test', {
        builder: '@angular/bazel:build',
        options: { 'bazelCommand': 'test', 'targetLabel': '//src/...' },
      },
      indent);

    const e2e = `${options.name}-e2e`;
    const e2eNode = findPropertyInAstObject(projects as JsonAstObject, e2e);
    if (e2eNode) {
      const architect =
        findPropertyInAstObject(e2eNode as JsonAstObject, 'architect') as JsonAstObject;
      replacePropertyInAstObject(
        recorder, architect, 'e2e', {
          builder: '@angular/bazel:build',
          options: {
            bazelCommand: 'test',
            targetLabel: '//e2e:devserver_test',
          },
          configurations: {
            production: {
              targetLabel: '//e2e:prodserver_test',
            },
          }
        },
        indent);
    }

    host.commitUpdate(recorder);
    return host;
  };
}

/**
 * Create a backup for the original angular.json file in case user wants to
 * eject Bazel and revert to the original workflow.
 */
function backupAngularJson(): Rule {
  return (host: Tree, context: SchematicContext) => {
    const workspacePath = getWorkspacePath(host);
    if (!workspacePath) {
      return;
    }
    host.create(
      `${workspacePath}.bak`, '// This is a backup file of the original angular.json. ' +
      'This file is needed in case you want to revert to the workflow without Bazel.\n\n' +
      host.read(workspacePath));
  };
}

export default function (options: Schema): Rule {
  return (host: Tree) => {
    validateProjectName(options.name);

    return chain([
      schematic('bazel-workspace', options),
      addDevAndProdMainForAot(options),
      addDevDependenciesToPackageJson(options),
      backupAngularJson(),
      updateAngularJsonToUseBazelBuilder(options),
      updateGitignore(),
    ]);
  };
}
