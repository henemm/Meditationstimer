-- Übernommen aus loose-ends server/migrations/001_claude_schema.sql (Muster: Abschrift-Tabelle) @ 24a6da6; angepasst: Abschrift Fassung 1 des Claude-Dienstes (Übungen, Programme, Atemübungen, Lieferungen)
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

-- Eine Abschrift je Konto, kein Verlauf. generated_at ist per CHECK ans Dokument gebunden (ein Cast von Text
-- nach timestamptz ist nicht unveränderlich und taugt daher nicht als erzeugte Spalte).
CREATE TABLE transcripts (
  account_id text PRIMARY KEY,
  doc jsonb NOT NULL,
  generated_at timestamptz NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  CHECK (generated_at = (doc->>'generatedAt')::timestamptz),
  -- generatedAt muss da sein und mit Zeitzone (Z oder +hh:mm) enden, sonst hinge der Cast oben von der
  -- Zeitzone der Sitzung ab. Der Typ wird einzeln geprüft, weil der Lax-Modus ein Array vor dem Filter auspackt.
  CHECK (jsonb_typeof(doc->'generatedAt') = 'string'
    AND jsonb_path_exists(doc, '$.generatedAt ? (@ like_regex "(Z|[+-][0-9]{2}:[0-9]{2})$")')),
  CHECK (doc @> '{"version":1}'),
  -- Datenschutzgrenze, zweite Wand: nur diese Schlüssel auf oberster Ebene. Ein Nicht-Objekt als Dokument
  -- lässt keyvalue() einen Fehler werfen und wird ebenfalls abgewiesen.
  CHECK (NOT jsonb_path_exists(doc,
    '$.keyvalue() ? (!(@.key like_regex "^(version|generatedAt|exercises|programs|breaths|deliveries)$"))'))
);
