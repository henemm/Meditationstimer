-- B3a Rückblick (#58): Abschrift Fassung 2 (zusätzlich "history"). Spec: openspec/specs/integrations/claude-rueckblick.md
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

-- Die beiden CHECKs aus 002 haben keine Namen; Postgres vergibt transcripts_doc_check und transcripts_doc_check1 nach Reihenfolge.
-- Namen werden hier aus dem Katalog ermittelt, damit die Migration nicht von der Vergabe abhängt.
DO $$
DECLARE c record;
BEGIN
  FOR c IN SELECT conname FROM pg_constraint
    WHERE conrelid = 'transcripts'::regclass AND contype = 'c'
      AND (pg_get_constraintdef(oid) ~ 'version"\s*:\s*1' OR pg_get_constraintdef(oid) LIKE '%keyvalue()%')
  LOOP
    EXECUTE format('ALTER TABLE transcripts DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;

ALTER TABLE transcripts
  ADD CONSTRAINT transcripts_version_check CHECK (doc @> '{"version":1}' OR doc @> '{"version":2}'),
  -- Datenschutzgrenze, zweite Wand: in Fassung 1 die sechs bisherigen Schlüssel, in Fassung 2 zusätzlich history.
  ADD CONSTRAINT transcripts_top_keys_check CHECK (NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries)$"))')
    OR (doc @> '{"version":2}' AND NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries|history)$"))')));
