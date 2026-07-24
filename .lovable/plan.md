
## Ziel

1. Sicherstellen, dass **jeder** Bewerber/Mitarbeiter zuverlässig alle Mails bekommt (End-to-End-Audit der 8 Edge-Functions).
2. Im Mail-Center werden **alle** tatsächlich versendeten Mails sichtbar (aktuell fallen mehrere Template-Namen durchs Raster).
3. Neue SMTP-Kapazität ausschöpfen: **150/h pro Tenant**, Sendefenster **6–22 Uhr**, 16 h × 150 = 2 400/Tag.
4. Die im Template-Editor (`/admin/email-templates`) angezeigten Defaults werden 1:1 an das synchronisiert, was die Edge-Functions heute tatsächlich verschicken.

Reine Anzeige-/Konfig-Anpassungen. Kein Schema-Change (nur eine kleine SQL-Update-Empfehlung als Runbook, keine Migration nötig).

---

## Findings (verifiziert im Code)

**A) Mail-Center-Lücken** — `src/routes/admin.email-center.tsx` listet Templates per Whitelist (`ACTIVE_TEMPLATES`); Zeilen mit anderen `template_name` erscheinen nur im Rohlog-Verlauf, aber nicht in KPI/Kachel.
- `send-application-reminders` schreibt bei `isRegistration` als Prefix `fasttrack_…` (Zeile 718: `` `${isRegistration ? "fasttrack" : "vermittlung"}_${kind}` ``). Mail-Center erwartet aber `vermittlung_registration_pending_24h/72h` → **diese Reminder sind unsichtbar**.
- `rebook_after_cancel_24h` / `rebook_after_cancel_72h` werden versendet, sind aber **weder in `ACTIVE_TEMPLATES` noch in `EMAIL_TYPE_LABELS`**.
- `EMAIL_TYPE_LABELS` (`src/lib/email-stats.ts`) fehlen Labels für `fasttrack_registration_pending_*` und `rebook_after_cancel_*` → im Roh-Log stehen die Namen technisch.

**B) Rate-Limits zu konservativ** — `send-application-reminders` (Z. 545–547):
- `MAX_PER_1H_PER_TENANT = 50` (soll: 150)
- `MAX_PER_12H_PER_TENANT = 300` (soll: ~1 800 = 12 h × 150)
- `MAX_PER_RUN_PER_TENANT = 5` (bleibt; Cron-Läufe alle 30 min).
- `send-reminders` Quiet-Hours `QUIET_HOURS_START=8 / _END=20` → auf `6 / 22` erweitern.
- `process-invite-resend-queue` Quiet `5–23` bleibt (bereits weiter offen).

**C) Template-Defaults driften auseinander** — `admin.email-templates.tsx` `REMINDER_DEFAULTS` (Z. 28-76) vs. tatsächliche Edge-Function-Defaults (`send-invitation-email` `DEFAULT_APPLICATION_RECEIVED_TEMPLATE`, `send-booking-confirmation` `DEFAULT_BODY/SUBJECT/BUTTON`, `send-application-reminders`, `send-reminders`). Der neue Satz „Sollten Sie bereits einen Termin gebucht haben, müssen Sie nichts weiter tun.“ ist z.B. schon in der Edge-Function, aber nicht im Editor-Default.

**D) Alle Sender loggen bereits nach `email_send_log`** — kein Loch beim Schreiben. Das Problem ist rein die Anzeige-Whitelist (Punkt A).

---

## Änderungen

### 1) Mail-Center-Whitelist vervollständigen
`src/routes/admin.email-center.tsx`:
- `vermittlung_registration_pending`.keys erweitern um `fasttrack_registration_pending_24h`, `fasttrack_registration_pending_72h`.
- Neuen Eintrag `rebook_after_cancel` mit `keys: ["vermittlung_rebook_after_cancel_24h", "vermittlung_rebook_after_cancel_72h", "fasttrack_rebook_after_cancel_24h", "fasttrack_rebook_after_cancel_72h"]` unter Gruppe „Vermittlung".

`src/lib/email-stats.ts` — `EMAIL_TYPE_LABELS` ergänzen:
- `fasttrack_registration_pending_24h/72h` → „Fast-Track · Registrierung offen 24 h/72 h"
- `vermittlung_rebook_after_cancel_24h/72h` + `fasttrack_rebook_after_cancel_24h/72h` → „Vermittlung/Fast-Track · Neuer Termin nach Absage"

### 2) Rate-Limits & Sendefenster
`supabase/functions/send-application-reminders/index.ts` (Z. 545-547):
```text
MAX_PER_1H_PER_TENANT  = 150
MAX_PER_12H_PER_TENANT = 1800
MAX_PER_RUN_PER_TENANT =   8   (leichtes Anheben, bleibt konservativ)
```
`supabase/functions/send-reminders/index.ts` (Z. 42-43):
```text
QUIET_HOURS_START = 6
QUIET_HOURS_END   = 22
```

### 3) Template-Editor-Defaults an Edge-Function-Realität angleichen
`src/routes/admin.email-templates.tsx` (`REMINDER_DEFAULTS`, Z. 28-76) — Bodies & Subjects werden aus den Edge-Functions kopiert:
- `booking_confirmation` ← `DEFAULT_SUBJECT/BODY/BUTTON` aus `send-booking-confirmation`.
- `bewerbung_magic_link` ← Interview-Invite-Template aus `send-appointment-reminders`.
- `app_no_booking` / `app_no_show` / `app_registration` ← passende Templates aus `send-application-reminders`.
- `employee_signup` / `confirm` / `completion` / `no_booking` / `recovery_mitarbeiter` / `chat` ← Defaults aus `send-reminders` bzw. `send-chat-reminder`.
- Neuer Eintrag `application_received` ← `DEFAULT_APPLICATION_RECEIVED_TEMPLATE` aus `send-invitation-email` (inkl. „Sollten Sie bereits einen Termin gebucht haben, müssen Sie nichts weiter tun.").
- Neue Einträge `rebook_after_cancel_24h/72h` (damit Editor sie überhaupt zeigt).

### 4) Runbook-Hinweis (kein Code)
Ein Kurzabschnitt in `RUNBOOK.md`, wie Admin bei einem Tenant die alten überschriebenen DB-Fields (`booking_confirmation_*`, `application_received_*`, …) auf `NULL` setzt, damit der Edge-Function-Default greift:
```sql
UPDATE tenants
SET booking_confirmation_subject=NULL, booking_confirmation_body=NULL, booking_confirmation_button=NULL,
    application_received_subject=NULL, application_received_body=NULL, application_received_button_label=NULL
WHERE id = '<tenant>';
```
(User führt selbst per `psql` aus, ist nicht Teil dieses Change-Sets.)

---

## Verification

1. `run-full-chain.sh` mit neuer Testmail durchlaufen — alle 14 Stages müssen nach dem SMTP-Cooldown durchgehen.
2. `/admin/email-center` (Range 24 h) muss nach dem Lauf **jede** Kachel mit ≥ 1 Sent zeigen, insbesondere `Vermittlung: Registrierung offen` und die neue Kachel `Rebook nach Absage`.
3. `/admin/email-templates` — visuell prüfen, dass die neuen Defaults angezeigt werden und der Editor sie speichern kann.
4. Rate-Limits: manuell `curl … -d '{"dry_run":true}'` gegen `send-application-reminders`; im Response-JSON darf `tenant_1h_cap` erst ab 150 Sends greifen.

---

## Nicht Teil dieses PRs

- Keine DB-Migration, kein Schema-Change.
- Kein SMTP-Retry-Backoff (separate Diskussion — habe ich zuletzt vorgeschlagen).
- Kein neues Alerting/Dashboard über das hinaus, was Mail-Center + Email-Logs schon zeigen.
