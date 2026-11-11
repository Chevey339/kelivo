// Rebuild the bundled Mermaid runtime with: node tool/build_mermaid_runtime.mjs
// The diagram engine calls structuredClone and Object.hasOwn during startup.
// Supply those standard APIs for the Android WebViews supported by the app.
// Keep the vendored Mermaid payload unchanged and use core-js instead of a
// partial JSON-based clone that would corrupt Maps, Sets or cyclic data.
import { execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const asset = new URL('../assets/mermaid.min.js', import.meta.url);
const begin = '/* Kelivo Mermaid runtime: begin */';
const end = '/* Kelivo Mermaid runtime: end */';
const current = await readFile(asset, 'utf8');
let mermaid = current;
if (current.startsWith(begin)) {
  const offset = current.indexOf(end);
  if (offset < 0) throw new Error('Missing Mermaid runtime end marker');
  mermaid = current.slice(offset + end.length + 1);
}

const workspace = await mkdtemp(join(tmpdir(), 'kelivo-mermaid-runtime-'));
try {
  // These packages have no unpinned runtime dependencies. Install outside the
  // repository so regenerating this asset leaves no node_modules in the app.
  execFileSync('npm', [
    'install', '--prefix', workspace, '--ignore-scripts', '--no-audit',
    '--no-fund', '--save-exact', 'core-js@3.51.0', 'esbuild@0.28.2',
  ], { stdio: 'inherit' });
  const require = createRequire(join(workspace, 'package.json'));
  const { build } = require('esbuild');
  const result = await build({
    absWorkingDir: workspace,
    stdin: {
      contents: "import 'core-js/actual/structured-clone';\nimport 'core-js/actual/object/has-own';",
      resolveDir: workspace,
      sourcefile: 'mermaid-runtime.js',
    },
    bundle: true,
    format: 'iife',
    platform: 'browser',
    target: 'chrome91',
    minify: true,
    legalComments: 'inline',
    write: false,
  });
  const license = await readFile(
    join(workspace, 'node_modules/core-js/LICENSE'), 'utf8',
  );
  const runtime = result.outputFiles[0].text;
  await writeFile(asset,
    `${begin}\n/*! core-js 3.51.0, bundled by esbuild 0.28.2\n${license}*/\n${runtime}${end}\n${mermaid}`,
  );
  console.log(`Added ${Buffer.byteLength(runtime)} bytes of Mermaid runtime APIs.`);
} finally {
  await rm(workspace, { recursive: true, force: true });
}
