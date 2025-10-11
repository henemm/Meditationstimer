Datum: 11.10.2025

Fehlversuch 10 – AtemView: zentrale Engine/Activity-Instanz

Kurz: Die `SessionCard` im `AtemView` wurde angepasst, damit sie keine eigene `SessionEngine` oder `LiveActivityController` mehr erstellt. Stattdessen hält `AtemView` die Instanzen und gibt sie an das Overlay weiter.

Ziel: Doppelte Timer/LiveActivity-Controller eliminieren, die das Live Activity / Dynamic Island am Laufen halten, obwohl die GUI das Overlay schließt.

Status: Codeänderung angewendet in `Meditationstimer iOS/Tabs/AtemView.swift`. Noch nicht verifiziert (Simulator‑Run und Logs ausstehend).

Nächste Schritte:
- Logs mit Tag `[TIMER-BUG]` in LiveActivityController (Services + iOS copy) und in `SessionEngine` einfügen.
- App im Simulator laufen lassen, Ablauf reproduzieren, Logs sammeln.
- Je nach Ergebnis: weiter debuggen oder Revert durchführen.

Anmerkung: Vor einem Revert sammeln wir erst reproduzierbare Logs, damit wir genau wissen, ob diese Änderung hilft oder Probleme verschlimmert.
