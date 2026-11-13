-- Übernommen aus loose-ends server/migrations/002–005 @ 24a6da6; angepasst: zu einer Datei zusammengezogen (apple_tokens gleich mit client_id NOT NULL
-- und Schlüssel (account_id, client_id)), Tabellen des Claude-Dienstes ohne Fremdschlüssel (deleteAccount räumt sie selbst).
-- Konten und Sitzungen der App sowie der Speicher des OAuth-Ausstellers. apple_sub ist der eine Kontoschlüssel, nie die E-Mail-Adresse.
-- Kein BEGIN/COMMIT: der Migrationslauf packt die Datei in eine eigene Transaktion.
-- transcripts, deliveries, delivery_events und wishes bleiben unverändert (account_id ohne Fremdschlüssel); deleteAccount löscht ihre Zeilen selbst.

-- id ist text, weil transcripts.account_id, deliveries.account_id und wishes.account_id text sind; es bleibt eine UUID in Textform.
CREATE TABLE accounts (
  id text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  apple_sub text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Gespeichert wird nur der SHA-256 eines Sitzungs-Tokens, nie das Token.
CREATE TABLE sessions (
  token_hash bytea PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX sessions_account_id ON sessions (account_id);

-- Das verschlüsselte Apple-Refresh-Token für das Widerrufen beim Löschen, eines je Konto und Client (App und Web-Anmeldung
-- führen je ein eigenes); der Widerruf muss genau die Client-ID senden, für die es ausgestellt wurde.
CREATE TABLE apple_tokens (
  account_id text NOT NULL REFERENCES accounts (id) ON DELETE CASCADE,
  client_id text NOT NULL,
  refresh_token_enc bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, client_id)
);

-- Speicher des OAuth-Ausstellers: eine Tabelle für jedes Modell von oidc-provider.
-- Kennungen liegen nur als SHA-256, jti nie im Payload, so steht kein Token im Klartext da.
-- grant_id, uid und account_id sind Kennungen, keine Zugangsdaten; account_id ist null bei Zeilen ohne Konto.
CREATE TABLE oauth_records (
  model text NOT NULL,
  id_hash bytea NOT NULL,
  payload jsonb NOT NULL,
  grant_id text,
  uid text,
  account_id text REFERENCES accounts (id) ON DELETE CASCADE,
  expires_at timestamptz,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (model, id_hash)
);
CREATE INDEX oauth_records_grant_id ON oauth_records (grant_id);
CREATE INDEX oauth_records_uid ON oauth_records (uid);
CREATE INDEX oauth_records_account_id ON oauth_records (account_id);
CREATE INDEX oauth_records_expires_at ON oauth_records (expires_at);
