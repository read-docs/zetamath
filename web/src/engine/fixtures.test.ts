import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildFixtures, fixtureText } from '../../scripts/fixtures';
import { parseHistory } from '../store/history';

// The Flutter app checks itself against the same files, so a change here must be re-exported with `npm run fixtures`.
const read = (name: string) => readFileSync(new URL(`../../../shared/fixtures/${name}`, import.meta.url), 'utf8');

describe('shared fixtures', () => {
  const fixtures = buildFixtures();
  it.each(Object.keys(fixtures))('%s matches the web engine', name => {
    expect(read(name)).toBe(fixtureText(name, fixtures[name]));
  });
  it('history export parses as a valid import', () => {
    expect(parseHistory(read('history-v1.json'))).toHaveLength(18);
  });
});
