import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
const pages = JSON.parse(readFileSync(new URL('../assets/legal/pages.json', import.meta.url)));
const escape = value => value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
for (const [name, translations] of Object.entries(pages)) {
  const directory = new URL(`../web/${name}/`, import.meta.url);
  mkdirSync(directory, { recursive: true });
  const sections = Object.entries(translations).map(([lang, paragraphs]) => `<section lang="${lang}"><h1>${escape(paragraphs[0])}</h1>${paragraphs.slice(1).map(p => `<p>${escape(p)}</p>`).join('')}</section>`).join('');
  const contact = `mailto:feedback@fiestaaa.app?subject=${encodeURIComponent(name === 'delete-account' ? 'Suppression de compte Fiestaaa' : 'Fiestaaa — Bêta')}`;
  writeFileSync(new URL('index.html', directory), `<!doctype html><html lang="fr"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escape(translations.fr[0])} — Fiestaaa</title><style>body{font:18px/1.65 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 24px;color:#18232d}a{color:#7543bb}section{margin:40px 0}nav{display:flex;gap:18px;flex-wrap:wrap}</style><nav><a href="/">Fiestaaa</a>${Object.keys(pages).map(p=>`<a href="/${p}">${escape(pages[p].fr[0])}</a>`).join('')}</nav>${sections}<p><a href="${contact}">feedback@fiestaaa.app</a></p></html>\n`);
}
