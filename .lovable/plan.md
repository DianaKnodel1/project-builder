## Was ich im Code gesehen habe (verifiziert)

**1. "In Warteschlange 7" ist fast sicher ein Zähl-Artefakt, kein echter Queue-Stand.**
Es gibt keine echte Warteschlange. `status = 'pending'` wird nur an einer Stelle geschrieben: in `send-application-reminders` (Zeile 757), wenn das SMTP-Stundenlimit greift ("wird später erneut versucht"). Beim nächsten Cron-Lauf entsteht eine **neue** Zeile mit `sent`/`failed` — die alte `pending`-Zeile bleibt für immer stehen.

**2. Die Dedup-Logik lässt diese alten Zeilen nie verschwinden.**
- Dashboard (`admin.index.tsx`) und E-Mail-Center (`admin.email-center.tsx`) deduplizieren über `message_id`, und wenn keine da ist über `template:email:created_at`. Eine `pending`-Zeile hat **keine** `message_id` und einen anderen Timestamp als der spätere Erfolg → sie wird nie mit dem erfolgreichen Versand zusammengeführt und zählt doppelt.
- Zusätzlich rechnet das Dashboard `total = computed.total + pending`, also 88 + 12 + 7 = 107 "eindeutige Mails", obwohl es real z. B. 100 logische Mails sind.

**3. Drei verschiedene Zählweisen für dieselbe Frage.**
`src/lib/email-stats.ts` hat eine gute logische Dedup-Funktion (`emailLogKey`/`dedupeEmailLogs`, Tenant + Template + Empfänger + Tag, Status-Priorität), aber:
- Dashboard nutzt sie nur teilweise (pending separat, eigene Vor-Dedup).
- E-Mail-Center nutzt sie **gar nicht** — es hat seine eigene message_id-Dedup, KPI-Berechnung und Per-Template-Zählung.
Deshalb weichen Screenshot 1 (KPI) und Screenshot 2 (Template-Kacheln, z. B. ✓59 / ✗7) voneinander ab und wirken "verbuggt".

**4. Nicht verifiziert:** die exakten 7 Pending- und 12 Fehler-Zeilen konnte ich nicht in der Datenbank nachsehen (Cloud-DB liegt auf dem eigenen Backend). Schritt 1 des Plans prüft das, bevor gefixt wird.

## Plan

**Schritt 1 — Datenbild bestätigen (read-only)**
Diagnose-Abfrage auf `email_send_log` (letzte 7 Tage): Verteilung nach `status`, `template_name`, Alter der `pending`-Zeilen, und für jede `pending`-Zeile prüfen, ob für Empfänger + Template später eine `sent`-Zeile existiert. Damit ist bewiesen, ob die 7 "Warteschlange" reine Alt-Artefakte sind oder echte Hänger.

**Schritt 2 — Eine gemeinsame Wahrheit für die Statistik**
In `src/lib/email-stats.ts`:
- `emailLogKey` so erweitern, dass Retry-Zeilen (pending → sent/failed) desselben logischen Versands zusammenfallen: logischer Schlüssel `tenant|template|empfänger|tag` auch dann, wenn eine `message_id` fehlt, plus ein Zeitfenster für Retries über Tagesgrenzen.
- Status-Priorität so, dass der **neueste finale** Status gewinnt (sent/failed/bounced schlagen pending).
- `computeEmailStats` liefert zusätzlich `pending` (nur echte Hänger: pending ist der letzte Zustand) und `stalePending` (pending älter als 6 h ohne Nachfolger).
- Erfolgsquote = sent / (sent + failed + bounced), pending zählt nicht gegen die Quote.

**Schritt 3 — Dashboard-Widget auf diese Werte umstellen**
`admin.index.tsx`: eigene Vor-Dedup und `total + pending` entfernen, alle vier Kacheln direkt aus `computeEmailStats` speisen. Kachel "In Warteschlange" zeigt nur echte Hänger; bei `stalePending > 0` ein eigener Hinweis ("hängt seit >6 h") statt stiller Amber-Zahl.

**Schritt 4 — E-Mail-Center auf dieselbe Logik**
`admin.email-center.tsx`: lokale Dedup löschen und `dedupeEmailLogs` verwenden — für KPI, Per-Template-Kacheln, Fehler-Feed und Verlauf. Danach stimmen Dashboard-KPI und Summe der Template-Kacheln überein. Ergänzend: die Kacheln zeigen ihre Zahlen nur noch aus deduplizierten Zeilen, damit z. B. ✗7 exakt den 7 Zeilen im Fehler-Feed entspricht.

**Schritt 5 — Ursache statt Symptom: pending sauber abschließen**
In `supabase/functions/send-application-reminders/index.ts`: beim erfolgreichen Retry die vorhandene `pending`-Zeile desselben logischen Versands auf den Endstatus **updaten** statt eine zweite Zeile zu schreiben (bzw. die alte pending-Zeile als `superseded` markieren). Damit entstehen keine neuen Artefakte mehr, unabhängig von der UI.

**Schritt 6 — Altlasten**
SQL-Snippet für den RUNBOOK: bestehende `pending`-Zeilen, für die es später einen finalen Versand gibt, auf `superseded` setzen; echte Hänger bleiben sichtbar. Du führst es auf Backend 123 aus, ich liefere es fertig.

**Schritt 7 — Gegencheck**
Nach dem Fix: Dashboard und E-Mail-Center nebeneinander prüfen — identische Gesamtzahl, Summe der Template-Kacheln = KPI, Fehler-Feed-Länge = Fehlerzahl, Erfolgsquote plausibel.

## Technische Details

- Betroffene Dateien: `src/lib/email-stats.ts` (Kern), `src/routes/admin.index.tsx`, `src/routes/admin.email-center.tsx`, `src/routes/admin.email-logs.tsx` (nur Konsistenz-Check), `supabase/functions/send-application-reminders/index.ts`.
- Keine Schema-Migration nötig; `superseded` ist nur ein Statuswert in der bestehenden Textspalte.
- Edge-Function-Änderung (Schritt 5) muss auf Backend 123 deployt werden.
