---
spec_file: DOCS/specs/bugfix/fix-122-programm-freigabe.md
spec_sha256: ea3c23f27c0d8b2ec9529d7075d3de56cad4fc4c175efd74014acf276fbd9613
spec_frozen_sha256: e2a9483c0b89ea8c2e3fbf55918aefc81076455b96703592245593799b979ed2
---

# PO-Briefing: fix-122-programm-freigabe

- **Spec:** DOCS/specs/bugfix/fix-122-programm-freigabe.md
- **Issue:** #122
- **Erstellt:** 2026-11-27

## Was gebaut wird

Beim Start eines Workout-Programms prüft die App die Health-Freigabe und meldet, wenn das Training nicht gespeichert wird.

## Definition of Done

Im Simulator fragt oder warnt die App je nach Freigabe vor dem Programmstart und meldet Speicherfehler nach dem Ende, belegt mit Screenshots.

## Wie geprüft wird

Automatische Tests belegen Entscheidung, Startablauf und Fehlerhinweis; der echte Speicherfehler wird nur simuliert und im Simulator durchgespielt, nicht automatisiert.

## Kritische Anmerkungen

- Freies Workout und Meditation behalten dieselbe Lücke bei verweigerter Freigabe; Folgeticket 129, von dir so entschieden.
- Bei zu kurzem Training erscheint bewusst kein Hinweis; es zählt dann still nicht für die Serie.

## Freigabe-Frage

Keine – Ampel gruen.

## Ampel

Ampel: gruen
