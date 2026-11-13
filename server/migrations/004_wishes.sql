-- Wünsche, die Claude für Henning meldet (Werkzeug wish_report, B2a-5). Neu für den Claude-Dienst, kein Loose-Ends-Muster.
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.

-- account_id hat noch keinen Fremdschlüssel (Konten kommen mit B2b). Grenzen in Zeichen: Text 1–1000, Kontext 1–300.
CREATE TABLE wishes (
  id uuid PRIMARY KEY,
  account_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  text text NOT NULL CHECK (char_length(text) BETWEEN 1 AND 1000),
  context text CHECK (context IS NULL OR char_length(context) BETWEEN 1 AND 300)
);
CREATE INDEX wishes_by_account ON wishes (account_id, created_at);
