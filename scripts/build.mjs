import { build } from 'esbuild';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { Script } from 'node:vm';

const result = await build({
  entryPoints: ['src/main.js'], bundle: true, minify: true,
  format: 'iife', target: 'es2022', write: false,
  loader: { '.glsl': 'text' }, outfile: 'app.js',
});
const js = result.outputFiles.find(f => f.path.endsWith('.js')).text;
const css = result.outputFiles.find(f => f.path.endsWith('.css')).text;
let html = await readFile('index.html', 'utf8');
const notices = await readFile('THIRD_PARTY_NOTICES.md', 'utf8');
html = html.replace('</head>', () => `<style>${css}</style>\n</head>`)
  .replace('<script type="module" src="/src/main.js"></script>', () => `<script>${js.replaceAll('</script', '<\\/script')}</script>`);
html = html.replace('</html>', `<!--\n${notices}\n-->\n</html>`);
// Validate the code after HTML interpolation, not only esbuild's input bundle.
const embeddedScript = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
if (!embeddedScript) throw new Error('Standalone script was not embedded.');
new Script(embeddedScript, { filename: 'dist/index.html' });
await mkdir('dist', { recursive: true });
await writeFile('dist/index.html', html);
console.log(`Built dist/index.html (${(Buffer.byteLength(html) / 1024).toFixed(0)} KiB). No external assets or network required.`);
