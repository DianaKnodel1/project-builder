
## Antworten auf deine zwei Rückfragen

**1. Ist das 8/Std ein Namecheap-Limit oder unser Code?**
Es ist **unser Code**, nicht Namecheap. In `supabase/functions/send-application-reminders/index.ts` Zeile 546:
```
const MAX_PER_1H_PER_TENANT = 8;
const MAX_PER_12H_PER_TENANT = 80;
```
Das ist ein Schutzlimit gegen Massenversand pro Tenant, kein SMTP-Limit. Namecheap Private Email hat je nach Plan 300–2000 Mails/Std – da sind wir weit drunter. Ich kann das Limit gefahrlos auf z.B. 50/Std hochziehen.

**2. Wie wichtig sind Alerts?**
Bei „viele Bewerber + Mitarbeiter" **hoch**. Ohne Alerts merkst du erst über Beschwerden, dass jemand nicht abgeholt wurde. Ein einzelner Cron-Fehler kann tagelang unbemerkt bleiben. Empfehlung: einbauen, ist Standard-Aufwand.

---

## Plan: Testkette grün + Prod-Härtung

### Phase 1 – Testkette 14/14 sauber durchlaufen
1. **Limit anheben**: `MAX_PER_1H_PER_TENANT` von 8 → 50, `MAX_PER_12H_PER_TENANT` von 80 → 300. Deploy in Mount-Verzeichnis, Container-Restart.
2. **Testsuite-Skript reparieren**: Der Skript-Aufruf für Schritt 4/14 übergibt `only_email` offenbar nicht (`candidates: 14` statt 1). Aufruf in `scripts/email-test/run-full-chain.sh` fixen, sodass jeder Reminder-Schritt mit `{"only_email": "$TEST_EMAIL"}` gefiltert wird.
3. **Skript-Diagnose verbessern**: Bei `status: "skipped"` den `reason` explizit ausgeben statt „0 Treffer" – dann brechen wir nicht mit Nebelmeldung ab.
4. **Vollständigen Lauf durchziehen** und alle 14 Schritte grün bekommen (jeder Fehler ab hier wird punktuell nachgezogen, statt jetzt zu spekulieren).

### Phase 2 – Prod-Härtung: „Jeder wird abgeholt"
Ziel: Kein Bewerber/Mitarbeiter fällt still durchs Raster.

5. **Trigger-Inventar dokumentieren**: Kurze Tabelle in `RUNBOOK.md` – welcher Zustand löst welche Mail aus, welcher Cron/Trigger, welche Log-Tabelle beweist den Versand.
6. **Cron-Health-Endpoint erweitern** (`src/lib/cron-health.functions.ts` existiert bereits): Pro Cron letzten erfolgreichen Lauf + Fehlerquote der letzten 24h. Sichtbar im Admin-Panel.
7. **„Verwaiste"-Reports pro Trigger**: SQL-Views die zeigen wer „hätte abgeholt werden müssen aber wurde nicht":
   - Bewerber mit Zusage aber >24h keine Portal-Registrierung und kein `registration_pending_24h`-Log
   - Mitarbeiter ohne Personalausweis/Vertrag >48h ohne passenden Reminder-Log
   - Bewerber >72h ohne Buchung und kein `no_booking_72h`-Log
   Pro View: Zähler + Detail-Ansicht in `/admin`.
8. **Alerts**: Wenn ein „Verwaisten"-Zähler > 0 oder ein Cron > 30 Min nicht gelaufen ist, tägliche Zusammenfassungsmail an Admin. Baut auf existierendem Email-Wrapper auf.

### Phase 3 – Absicherung neuer Registrierungen
9. **End-to-end Smoke-Test** für Neu-Bewerber-Flow (kein DB-Mock, echte Test-Bewerbung durch die Funnel-URL) – manuell dokumentiert im Runbook, damit du selbst jederzeit prüfen kannst.

### Technische Details (nur für dich, überspringbar)
- Änderungen betreffen: `supabase/functions/send-application-reminders/index.ts` (Limit), `scripts/email-test/run-full-chain.sh` (Filter + Diagnose), `src/lib/cron-health.functions.ts` (Erweiterung), neue SQL-Views als Migration in `supabase/manual-migrations/`, neuer Cron `daily-health-report` für Alerts.
- Kein Schema-Umbau nötig, alle Log-Tabellen existieren bereits (`application_reminder_log`, `reminder_log`, `email_log`).
- Deploy-Pfad wie gehabt: Repo bearbeiten → `/opt/supabase/docker/volumes/functions/...` kopieren → Container-Restart.

### Vorschlag Vorgehen
- **Heute**: Phase 1 komplett (Limit + Skript + Testlauf grün). ~30 Min Arbeit + Testlauf-Zeit.
- **Danach**: Phase 2 einzeln Punkt für Punkt, damit jederzeit prüfbar bleibt was passiert.
- Phase 3 wenn Phase 2 steht.

Sag mir ob du so starten willst, oder ob du zuerst nur Phase 1 haben willst und Phase 2/3 später entscheidest.
