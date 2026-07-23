## Ziel

Alle 15 automatischen Mails schnell und sicher testen, ohne echte Bewerber/Zeiten abzuwarten und ohne Live-Empfänger zu spammen.

## Strategie in 3 Ebenen

### 1) Rendering testen (Sekunden, keine Wartezeit)

Alle Mails nutzen `renderEmail()` aus `supabase/functions/_shared/email-wrapper.ts`. Damit lässt sich pro Template Subject/HTML/Text rendern, **ohne SMTP-Versand**.

Neuer Endpoint: `supabase/functions/email-preview/index.ts` (Service-Role only)
- POST `{ template: "application_received" | "booking_confirmation" | "interview_invite_30min" | "no_booking_24h" | ... , tenant_id, sample_vars? }`
- Lädt Tenant + Logo-Resolver-Chain wie im Live-Versand, rendert mit Fake-Daten (`first_name: "Max"`, `appointment_date: …`), gibt `{subject, html, text}` zurück.
- Optional `?send_to=meine@mail.de` → schickt Rendering **einmalig** an eine Testadresse via Tenant-SMTP.

Vorteil: In < 1 s pro Template siehst du Logo, Layout, Platzhalter, Broker-Flow-Reihenfolge.

### 2) End-to-End dry-run gegen echten Datenbestand (Minuten)

Alle bestehenden Cron-Functions unterstützen bereits `{"dry_run": true}` und geben `results[]` mit `status: "would_send"` + Empfänger zurück. Damit testest du **Trigger-Logik**, ohne dass eine Mail rausgeht:

```bash
# alle vier Cron-Endpunkte im Dry-Run
for fn in send-application-reminders send-appointment-reminders send-booking-confirmation send-reminders; do
  curl -s -X POST "$SUPABASE_URL/functions/v1/$fn" \
    -H "Authorization: Bearer $SERVICE_ROLE" -H "Content-Type: application/json" \
    -d '{"dry_run": true}' | jq '{fn: "'$fn'", candidates, todo, sent, results}'
done
```

Ergebnis: pro Function eine Liste „wer würde jetzt was bekommen" — reicht für Regressions-Check nach jedem Deploy.

### 3) Echter Versand mit Test-Bewerber + Zeit-Manipulation (10 Min pro Mail)

Damit die Cron-Gates (24h, 30 Min vor Termin, 72h) nicht abgewartet werden müssen: **eine SQL-Test-Suite** in `scripts/email-test/` mit Snippets, die genau einen Test-Bewerber in den richtigen State versetzen:

- **#1 application_received**: neuen Test-Bewerber via UI/API anlegen → sofort akzeptieren → Mail geht raus.
- **#2 booking_confirmation**: Slot buchen → Cron alle 2 Min, oder Function manuell POST-triggern.
- **#3 interview_invite_30min**: `UPDATE interview_appointments SET scheduled_at = now() + interval '30 min'` → nächster 10-Min-Cron.
- **#4 no_booking_24h**: `UPDATE applications SET created_at = now() - interval '25 hours'` → nächster 30-Min-Cron.
- **#5 no_booking_72h**: `created_at = now() - interval '73 hours'`.
- **#6 no_show_24h**: Termin auf `now() - interval '25 hours'` + Status auf `missed`.
- **#7 rebook_after_cancel**: Termin auf `cancelled`, `updated_at = now() - interval '25 hours'`.
- **#8–#14 Onboarding/Drip**: analog `profiles.created_at` / `email_confirmed_at` vordatieren.

Jede Zeit-Manipulation läuft gegen **einen** dedizierten Test-Bewerber (`E-Mail: test+<kind>@deine-domain.de`), damit echte Kandidaten nicht betroffen sind. Nach dem Test: Row löschen oder Zeiten zurücksetzen.

## Empfohlener Workflow

```text
┌────────────────────────────────────────────────────────┐
│ nach jedem Template-Edit                                │
│   → email-preview Endpoint (1) → optisch prüfen         │
│                                                         │
│ vor jedem Deploy                                        │
│   → dry_run auf alle Crons (2) → Liste checken          │
│                                                         │
│ einmal pro Kind bei größeren Änderungen                 │
│   → SQL-Snippet + echter Testversand an dich (3)        │
└────────────────────────────────────────────────────────┘
```

## Was ich einbauen würde (Umfang)

1. **`supabase/functions/email-preview/index.ts`** — neuer Endpoint mit Service-Role-Guard. Rendert alle 15 Kinds über die zentralen Defaults, wahlweise `send_to`-Testversand. ~200 LOC, keine DB-Migrationen.
2. **`scripts/email-test/`** — README + 15 SQL-Snippets (state setzen) + `test-all.sh` (curl-Loop für alle dry-runs mit hübschem `jq`-Output).
3. **Kein Eingriff** in bestehende Cron-Functions — die haben schon `dry_run`.

## Sicherheits-/Spam-Schutz

- Preview-Endpoint nur mit Service-Role-Key.
- `send_to` erlaubt nur **eine** Adresse pro Request, keine Bulk-Liste.
- Test-Bewerber-Suffix `+test-` → per RLS/Filter aus Analytics ausschließen (optional).
- Vor Zeit-Manipulation immer `SELECT id, email FROM applications WHERE …` zur Sicherheit ausgeben lassen.

## Offen — bitte kurz bestätigen

- Soll der Preview-Endpoint auch **echt versenden** (`send_to`) oder nur HTML/Text zurückgeben? (Ich empfehle beides, per Query-Param.)
- Reicht dir eine **JSON-Antwort** mit `html`-String, oder willst du zusätzlich eine kleine HTML-Preview-Seite (z. B. `/functions/v1/email-preview/ui`) mit Dropdown pro Template und Live-Vorschau?
