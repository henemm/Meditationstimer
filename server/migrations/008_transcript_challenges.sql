-- B5a Einfache Impuls-Challenge (#62): Abschrift Fassung 2 erhält zusätzlich "challenges". Spec: openspec/specs/integrations/claude-challenge.md Abschnitt 3
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

ALTER TABLE transcripts DROP CONSTRAINT transcripts_top_keys_check;
ALTER TABLE transcripts
  -- Datenschutzgrenze, zweite Wand: in Fassung 1 die sechs bisherigen Schlüssel, in Fassung 2 zusätzlich history, reminders und challenges.
  ADD CONSTRAINT transcripts_top_keys_check CHECK (NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries)$"))')
    OR (doc @> '{"version":2}' AND NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries|history|reminders|challenges)$"))')));
