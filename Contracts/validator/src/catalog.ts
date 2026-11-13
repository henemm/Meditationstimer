// Katalog der eingebauten Übungen, einmal geladen und gecacht.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export type CatalogEntry = { id: string; name: string; category: string };

let cache: CatalogEntry[] | undefined;

export function loadCatalog(): CatalogEntry[] {
  if (cache === undefined) {
    const file = join(import.meta.dirname, '..', '..', 'catalog', 'builtin-exercises.json');
    const parsed = JSON.parse(readFileSync(file, 'utf8')) as { exercises: CatalogEntry[] };
    cache = parsed.exercises;
  }
  return cache;
}
