// Usage: npm run fixtures. Writes ../shared/fixtures/*.json from the web engine. Commit the output.
process.env.TZ = 'UTC';
const { writeFileSync, mkdirSync } = await import('node:fs');
const { buildFixtures, fixtureText } = await import('./fixtures');
const dir = new URL('../../shared/fixtures/', import.meta.url);
mkdirSync(dir, { recursive: true });
for (const [name, data] of Object.entries(buildFixtures())) {
  writeFileSync(new URL(name, dir), fixtureText(name, data));
  console.log(`wrote shared/fixtures/${name}`);
}
