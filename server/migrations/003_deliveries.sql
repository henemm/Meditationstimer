-- Übernommen aus loose-ends server/migrations/001_claude_schema.sql (Muster: orders mit claimed_by/claimed_at "beide oder keins") @ 24a6da6;
-- angepasst: Lieferungen des Claude-Dienstes mit Zuständen und Verlauf (delivery_events).
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

-- Eine Lieferung ist genau ein Dokument im Lieferformat. Die Kennung kommt aus dem Dokument (CHECK), nie daneben.
-- account_id hat noch keinen Fremdschlüssel (Konten kommen mit B2b). seq ordnet den Eingang eindeutig.
CREATE TABLE deliveries (
  id text PRIMARY KEY,
  seq bigint GENERATED ALWAYS AS IDENTITY,
  account_id text NOT NULL,
  doc jsonb NOT NULL,
  state text NOT NULL CHECK (state IN ('waiting', 'claimed', 'accepted', 'rejected', 'superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_by text,
  claimed_at timestamptz,
  result jsonb,
  decided_at timestamptz,
  CHECK (doc->>'deliveryId' = id),
  CHECK ((claimed_by IS NULL) = (claimed_at IS NULL)),
  -- Nur waiting und superseded hatten nie ein Gerät; claimed, accepted und rejected haben eins.
  CHECK ((state IN ('waiting', 'superseded')) = (claimed_by IS NULL)),
  -- Ein Ergebnis und sein Zeitpunkt gehören genau zu accepted und rejected.
  CHECK ((state IN ('accepted', 'rejected')) = (decided_at IS NOT NULL)),
  CHECK ((state IN ('accepted', 'rejected')) = (result IS NOT NULL))
);
CREATE INDEX deliveries_open ON deliveries (account_id, state, created_at, seq);

-- Jeder Zustandswechsel: Zeitpunkt, Zustand, Gerät (bei waiting und superseded keins).
CREATE TABLE delivery_events (
  delivery_id text NOT NULL REFERENCES deliveries (id),
  at timestamptz NOT NULL DEFAULT now(),
  state text NOT NULL CHECK (state IN ('waiting', 'claimed', 'accepted', 'rejected', 'superseded')),
  device text
);
CREATE INDEX delivery_events_by_delivery ON delivery_events (delivery_id, at);
