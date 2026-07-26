## Teil 1 — Was sind die zentralen Limits?

Alle Zahlen stehen an genau einer Stelle: `supabase/functions/_shared/limits.ts`. Ändert man sie dort, gilt das für alle Versandfunktionen.

| Wert | Aktuell | Bedeutung |
|---|---|---|
| Sendefenster | 06:00–22:00 Berlin | Reminder/Kampagnen senden nur in diesem Fenster. Transaktionale Mails (Bestätigung, Passwort-Reset, Terminbestätigung, Einladung) ignorieren das Fenster bewusst. |
| Pro Stunde / Mandant | 150 | Harte Grenze des SMTP-Vertrags. |
| Pro 12 Stunden / Mandant | 1.800 | Zwischen-Puffer (12 × 150). |
| Pro Tag / Mandant | 2.400 | 16 Sendestunden × 150. |
| Bewerber-Reminder pro Cron-Lauf | 10 | Cron alle 5 Min → max. 120/h, bleibt unter 150. |
| Onboarding-Reminder pro Lauf, Mandant und Typ | 50 | Verhindert Burst-Versand. |

## Teil 2 — Logging und Statistik, einfach erklärt

**Jede Entscheidung wird protokolliert.** Es gibt eine Tabelle (`email_send_log`), in die jede Mail einen Eintrag schreibt — egal wie es ausgeht:
- `sent` = raus
- `failed` = Versand fehlgeschlagen
- `pending` = unterwegs / Wiederholung offen
- `skipped` = absichtlich nicht gesendet (z. B. Limit erreicht, Mandant pausiert, außerhalb Sendefenster) — mit Grund und Zählerstand

Daraus baut das Mail-Center: Gesamtvolumen, Balken pro Tag, Aufteilung pro Mandant, CSV-Export.

**Warum „dedupliziert"?** Eine Mail kann mehrere Zeilen erzeugen: erst `pending`, dann `sent`. Ohne Bereinigung würde dieselbe Mail zweimal gezählt. Die Statistik gruppiert deshalb nach *Mandant + Vorlage + Empfänger + Tag* und behält nur den „endgültigsten" Zustand: `sent`/`failed`/`bounced` gewinnen immer gegen `pending`, bei Gleichstand der neuere Eintrag. Ergebnis: 1 Versand = 1 Zeile in der Statistik, und die Erfolgsquote wird nur aus abgeschlossenen Versänden gerechnet (offene Retries drücken sie nicht künstlich).

## Teil 3 — Prüfung: drei echte Lücken gefunden

Die Prüfung hat drei Stellen ergeben, an denen der Anspruch „nichts reißt 150/h" heute noch nicht sauber gehalten wird:

1. **`send-reminders` hat keine Stunden-Grenze.** Es prüft nur 50 pro Lauf/Mandant/Typ und die Tagesgrenze. Bei 5 Reminder-Typen sind das bis zu 250 Mails in einem einzigen Lauf — über 150/h, obwohl die Tagesgrenze noch nicht erreicht ist.
2. **Falsch benannte Kappe in `send-reminders`.** Die Funktion `tenant12hCapReached` prüft gegen den 24h-Wert (2.400), nicht gegen 1.800. Wirkt harmlos, macht aber jede Fehlersuche irreführend, und die Meldung im Log heißt fälschlich `tenant_12h_cap_reached`.
3. **`process-invite-resend-queue` zählt zu optimistisch.** Es zählt nur `sent`, während der zentrale Guard `sent`, `pending`, `bounced`, `complained` zählt. Dadurch kann diese Queue die Kontingente überschreiten. Zusätzlich prüft sie gar keine Stunden-Grenze und hat ein eigenes Quiet-Hours-Fenster (05–23) statt des zentralen 06–22.

## Umsetzung

- **`send-reminders`**: 1h-Zähler pro Mandant beim Lauf-Start aus `email_send_log` laden (gleiche Status-Liste wie der Guard) und vor jedem Send prüfen; Skip als `tenant_1h_cap` loggen. Die 12h-Prüfung auf den echten 12h-Wert korrigieren und den Log-Grund entsprechend benennen.
- **`process-invite-resend-queue`**: die eigene Zähl-/Fenster-Logik durch `guardSend` aus `_shared/send-guard.ts` ersetzen (Kind `reminder`), sodass Stunden-, Tages- und Fenster-Regeln identisch gelten und Blockaden als `skipped` im Mail-Center landen. Das eigene 05–23-Fenster entfällt.
- **Keine Änderung an Limit-Werten selbst** — nur die Einhaltung wird korrigiert.
- Danach Typecheck/Build und eine Kontrolle, dass jede Versandfunktion entweder `guardSend` nutzt oder die Werte aus `_shared/limits.ts` importiert.

## Technische Details

- Betroffene Dateien: `supabase/functions/send-reminders/index.ts`, `supabase/functions/process-invite-resend-queue/index.ts`.
- Keine Migration, kein Schema-Eingriff, keine Änderung am Mail-Center-Frontend oder an `src/lib/email-stats.ts` nötig.
- Nach dem Deploy müssen `send-reminders` und `process-invite-resend-queue` neu deployt werden, damit die Änderungen greifen.
