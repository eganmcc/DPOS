/**
 * flutter_svg does not apply CSS class rules from an SVG <style> block, so any shape styled
 * only by `class="stN"` renders black. This inlines those rules as presentation attributes,
 * which every SVG renderer honours — the file stays a valid SVG and looks identical in a browser.
 *
 * Usage: node inline-svg-css.js <file.svg> [...]
 */
const fs = require('fs');

function inlineCss(svg) {
  const styleMatch = svg.match(/<style[^>]*>([\s\S]*?)<\/style>/);
  if (!styleMatch) return { svg, changed: 0 };

  // .st0{fill:#FF5F00;} → { st0: 'fill:#FF5F00' }
  const rules = {};
  for (const m of styleMatch[1].matchAll(/\.([A-Za-z0-9_-]+)\s*\{([^}]*)\}/g)) {
    rules[m[1]] = m[2].trim().replace(/;$/, '');
  }
  if (!Object.keys(rules).length) return { svg, changed: 0 };

  let changed = 0;
  const out = svg.replace(/class="([A-Za-z0-9_ -]+)"/g, (whole, classList) => {
    const decls = classList
      .split(/\s+/)
      .map((c) => rules[c])
      .filter(Boolean)
      .join(';');
    if (!decls) return whole;
    changed++;
    // Keep the class too, so the file still matches its own <style> block elsewhere.
    const attrs = decls
      .split(';')
      .filter(Boolean)
      .map((d) => {
        const [prop, value] = d.split(':').map((x) => x.trim());
        return `${prop}="${value}"`;
      })
      .join(' ');
    return `${whole} ${attrs}`;
  });

  return { svg: out, changed };
}

for (const file of process.argv.slice(2)) {
  const before = fs.readFileSync(file, 'utf8');
  const { svg, changed } = inlineCss(before);
  if (changed) fs.writeFileSync(file, svg);
  console.log(`  ${file}: ${changed} styled element(s) inlined`);
}
