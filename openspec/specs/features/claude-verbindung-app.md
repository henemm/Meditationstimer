# Spec: App verbindet sich mit dem Dienst – Anmeldung, Abgleich, Einstellungsseite (B2d, #57)

**Epic:** #44 · **Analyse:** `DOCS/context/analyse-51-57-claude-app.md` · **Dienst:** `openspec/specs/integrations/claude-dienst.md`,
`claude-anmeldung.md` · **Vorbild:** Loose Ends `LooseEnds/Claude/*` (nur lesen, Muster übernehmen)
**Stand:** 13.11.2026 · **Umsetzung:** am Mac (Swift), hier nur Spezifikation

## Leitlinie (PO 13.11.2026)

Wie Loose Ends, so einfach wie möglich: Das iPhone ist die Wahrheit; die App schickt eine Kopie (Abschrift) an den Dienst und holt
Claudes Lieferungen ab. Die Bausteine von Loose Ends werden übernommen und nur umbenannt.

## Verhalten

1. **Schalter:** Info-Schlüssel `HHClaudeEnabled` (Bool, Vorgabe aus). Eingeschaltet in Debug-Bauten und unter Tests; die
   Store-Version zeigt nichts von der Verbindung. Dienstadresse `HHServiceURL` = `https://habits.henemm.com` (nur https).
2. **Anmelden mit Apple** (wie Loose Ends `AccountState`, `Nonce`): ohne Scopes; Apple bekommt den SHA-256 der Nonce, der Dienst den
   Rohwert; `POST /auth/apple {identityToken, nonce, code}` → `sessionToken`, im Schlüsselbund dieses Geräts (`KeychainSessionStore`).
   Antworten: 401 „Dieses Apple-Konto ist nicht zugelassen“, 503 „Dienst gerade nicht erreichbar, später erneut“.
3. **Abgleich** beim Start und beim Wechsel in den Vordergrund, nur mit Sitzung (wie `ClaudeSync`/`ClaudeSyncTrigger`, unter Tests stumm):
   1. Lieferungen abholen (`POST /app/deliveries/claim`, Kopf `X-Device` = Geräte-UUID aus dem Schlüsselbund), jede mit #51 anwenden
      und das Ergebnis melden (`POST /app/deliveries/result`); höchstens 15 je Durchlauf.
   2. Danach die Abschrift senden (`POST /app/transcript`), **Fassung 1** (`Contracts/transcript/transcript-v1.schema.json`):
      Übungen, Programme, Atemübungen mit Herkunft, letzte 50 Lieferergebnisse. Nichts anderes (Datenschutzgrenze, Konzept 7).
      Fassung 2 (Verlauf) kommt mit #59.
   Jeder Fehler beendet den Durchlauf still; 401 meldet ab.
4. **Einstellungsseite „Claude-Verbindung“** (Link in den Einstellungen, nur bei eingeschaltetem Schalter): Anmelden/Abmelden,
   Zeitpunkt des letzten Abgleichs, Liste der letzten Lieferungen mit Ergebnis, „Was Claude sieht“ als kurzer Klartext,
   „Verbindung trennen“ mit Rückfrage (`POST /auth/delete`; Geliefertes bleibt auf dem iPhone).
5. **Entitlement:** Sign in with Apple für `henemm.Meditationstimer-iOS` (Portal und Datei, siehe Runbook Schritt 2 in henemm-infra).

## Tests (am Mac, zuerst rot)

- Schalter: Vorgabe aus, Release-Bau zeigt keinen Eintrag; Debug/Test an.
- Anmeldung, Abmelden, Trennen mit einer Transport-Attrappe (wie Loose Ends `HTTPTransport`): richtige Pfade, Körper, Statusbehandlung;
  Sitzung im Schlüsselbund (Attrappe), nie im Klartext gespeichert oder geloggt.
- Abgleich: Abholen → Anwenden → Melden → Abschrift, Höchstzahl, Abbruch bei Fehler, 401 meldet ab.
- Abschrift: aus festen Beständen erzeugt und gegen eingecheckte Goldendateien verglichen; die Goldendateien prüft die Contracts-CI mit
  dem Schema (`transcript-v1.schema.json`) — eine einzige Quelle der Regeln.
- UI-Test der Einstellungsseite mit Stand-in statt echtem Apple-Dialog. Echte Anmeldung erst nach der Inbetriebnahme (#56) und nur auf
  Hennings „jetzt ist ein Test möglich“.

## Schnitte (je ≤ 4–5 Dateien, ~250 Zeilen)

1. Schalter, Nonce, Schlüsselbund, Geräte-UUID (übernommen aus Loose Ends).
2. `ServiceClient` und `AccountState` (übernommen, Pfade angepasst).
3. Abschrift Fassung 1 + Goldendateien + CI-Schritt.
4. Abgleich und Auslöser, in den App-Start eingehängt.
5. Einstellungsseite mit Texten DE/EN und UI-Test.
