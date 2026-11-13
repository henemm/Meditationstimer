-- B6a Stufenplan, Tagesziel, neue Gewohnheit (#64): Abschrift Fassung 2 erhält zusätzlich "trackers". Spec: openspec/specs/integrations/claude-gewohnheit-stufenplan.md Abschnitt 3
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

ALTER TABLE transcripts DROP CONSTRAINT transcripts_top_keys_check;
ALTER TABLE transcripts
  -- Datenschutzgrenze, zweite Wand: in Fassung 1 die sechs bisherigen Schlüssel, in Fassung 2 zusätzlich history, reminders, challenges und trackers.
  ADD CONSTRAINT transcripts_top_keys_check CHECK (NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries)$"))')
    OR (doc @> '{"version":2}' AND NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries|history|reminders|challenges|trackers)$"))')));
