/*
  @license
	Rollup.js v4.47.0
	Thu, 21 Aug 2025 05:42:30 GMT - commit 4a5d2da37018c4d0666fd0c9cda4071f2d1b7090

	https://github.com/rollup/rollup

	Released under the MIT License.
*/
export { version as VERSION, defineConfig, rollup, watch } from './shared/node-entry.js';
import './shared/parseAst.js';
import '../native.js';
import 'node:path';
import 'path';
import 'node:process';
import 'node:perf_hooks';
import 'node:fs/promises';
