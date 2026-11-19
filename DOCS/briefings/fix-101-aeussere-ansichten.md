---
spec_file: DOCS/specs/bugfix/fix-101-aeussere-ansichten.md
spec_sha256: 4d08ea8084dca5bc7ba910fcd5cd07bcf70a8e7f7cd9fb6050e617f742213d02
spec_frozen_sha256: 202180450fc79f2287bb97202cafaf37886eb16a47d2d5fabdd8a602ade8a07e
---

# PO-Briefing: fix-101-aeussere-ansichten

- **Spec:** DOCS/specs/bugfix/fix-101-aeussere-ansichten.md
- **Issue:** #101 (Text nicht abrufbar; geprüft gegen die Anfragezusammenfassung im Kontext-Dokument)
- **Erstellt:** 2026-11-19

## Was gebaut wird

Unerreichbarer Altcode der Meditations- und Workout-Ansichten wird entfernt; die App sieht aus und verhält sich unverändert.

## Definition of Done

Meditation- und Workout-Reiter funktionieren im Simulator wie zuvor, beide Builds und alle Testläufe sind grün, der tote Code samt zwölf Texten ist weg.

## Wie geprüft wird

Suchskript vorher rot und nachher grün, Builds, Unit- und UI-Tests, Simulator-Durchlauf; eine Prüfung auf deinen Geräten findet nicht statt.

## Kritische Anmerkungen

- Kurzbefehl "Atem starten" hat keinen eigenen Test, belegt nur durch "bestehende Tests bzw. Durchlauf". Geringes Risiko, da dieser Code unangetastet bleibt.
- Spec nennt zwölf statt elf Übersetzungstexte; Korrektur ist begründet und wird per Skript gegengeprüft.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
