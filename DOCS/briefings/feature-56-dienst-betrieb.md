---
spec_file: docs/specs/infra/habits-dienst-betrieb.md
spec_sha256: 78062afa765b62d1bf402ca08dc3e01ec595b65afa1e8e9b4516ce87ed1dbbb1
spec_frozen_sha256: 7d2e1876fecd79b1d7c669e003905ec4ff84ae587ed4f036b2ab9645086d3e73
---

# PO-Briefing: feature-56-dienst-betrieb

- **Spec:** docs/specs/infra/habits-dienst-betrieb.md (Abschnitt 2)
- **Issue:** #56
- **Erstellt:** 2026-11-28

## Was gebaut wird

Der Habits-Dienst läuft unter eigener Adresse, gesichert und überwacht, und Claude liefert darüber Übungen in Hennings Konto.

## Definition of Done

Dienst antwortet unter habits.henemm.com, Sicherung und Prüfung laufen belegt, und eine Beispiel-Lieferung zeigt in Claude den Status „wartet“.

## Wie geprüft wird

Echte Abrufe, Rückspielprobe und ein Claude-Gespräch weisen es nach; automatische Tests gibt es nur für die Datenbank-Version.

## Kritische Anmerkungen

- Abweichung: Issue nennt genau einen PO-Schritt; Spec verlangt zwei Termine (Apple-Portal plus DNS, dann Konnektor), etwa 35 Minuten.
- Zusatz: neuer Apple-Schlüssel statt Mitbenutzung des Loose-Ends-Schlüssels sowie Datenbank-Update auf 18.7; nicht verlangt, technisch begründet.

## Freigabe-Frage

Akzeptierst du zwei Termine (Apple/DNS, dann Konnektor) statt des im Issue genannten einen Schritts?

## Ampel

Ampel: rot
