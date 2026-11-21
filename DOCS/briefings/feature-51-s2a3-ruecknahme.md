---
spec_file: DOCS/specs/features/feature-51-s2a3-ruecknahme.md
spec_sha256: 11b48c0cc37c45a773f19685d621886d912fecbdc122b72b1f113a5cef6640b4
spec_frozen_sha256: f94f621f9574c96015c6814dcc5592061f76d3e824d28d3777c01e9dd9c975e8
---

# PO-Briefing: feature-51-s2a3-ruecknahme

- **Spec:** DOCS/specs/features/feature-51-s2a3-ruecknahme.md
- **Issue:** #51
- **Erstellt:** 2026-11-21

## Was gebaut wird

Die App kann eine Claude-Lieferung zurücknehmen, einzeln oder als ganzes Paket, ohne Netz.

## Definition of Done

Alle zehn neuen Tests und die gesamte Test-Suite sind grün, iPhone-, Watch- und Widget-App bauen, die unabhängige Prüfung bestätigt.

## Wie geprüft wird

Automatische Tests belegen Rücknahme, Ablehnung geänderter Bausteine und alle Beispiellieferungen; auf dem Gerät sichtbar ist noch nichts.

## Kritische Anmerkungen

- Noch unsichtbar: Die Rücknahme hat keine Oberfläche und speichert nichts; das folgt erst in späteren Schnitten.
- Verhalten bei widersprüchlichen Lieferungen (keine oder beide Kennungen) legte der Tech Lead fest; laut Vertrag kommen sie nie an.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
