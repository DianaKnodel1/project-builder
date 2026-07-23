# E-Mail Test-Suite

Schnelles, sicheres Testen aller automatischen Bewerber-/Mitarbeiter-Mails
ohne Wartezeit auf reale Trigger.

## Voraussetzungen

```bash
export SUPABASE_URL="https://<PROJECT>.supabase.co"      # oder self-hosted URL
export SERVICE_ROLE="<SERVICE_ROLE_KEY>"                 # aus /opt/apps/portal/.env
export DATABASE_URL="postgresql://…"                     # nur für Stufe 4 + 5
export TEST_TENANT_ID="<uuid>"                           # ein realer Tenant
export TEST_LANDING_ID="<uuid>"                          # Landing mit Domain
export TEST_EMAIL="test+chain@deine-domain.de"           # MUSS mit test+ beginnen
```

## Ebene 1 — Rendering-Preview (Sekunden, KEIN Versand)

Ein einzelnes Template als HTML im Browser ansehen:

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/email-preview?format=html" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"template\": \"booking_confirmation\", \"tenant_id\": \"$TEST_TENANT_ID\"}" \
  > /tmp/preview.html && xdg-open /tmp/preview.html
```

## Ebene 2 — Einmal-Testversand an deine eigene Adresse

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/email-preview" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"template\": \"application_received\", \"tenant_id\": \"$TEST_TENANT_ID\", \"send_to\": \"$TEST_EMAIL\"}"
```

## Ebene 3 — Dry-Run gegen echte Cron-Daten

```bash
bash scripts/email-test/dry-run-all.sh
```

## Ebene 4 — Einzelnen Cron-Send auslösen (mit vordatiertem Test-Bewerber)

State-Snippets in `sql-snippets/chain-*.sql` einzeln laufen lassen und
danach die passende Function triggern. Siehe `set-test-states.sql` für
Kommentare zu jeder Manipulation.

## Ebene 5 — Komplette Kette mit EINEM Skript

Sendet nacheinander **alle 14 automatischen Mails** an `$TEST_EMAIL` – jede
mit echter State-Manipulation und echtem Cron-Aufruf.

```bash
bash scripts/email-test/run-full-chain.sh
```

Was das Skript macht (pro Stufe):

1. Lädt `sql-snippets/chain-<n>-*.sql`, das per `psql` den Test-Bewerber in
   den richtigen Zustand versetzt (backdated `created_at`, Termin auf
   `cancelled`, o. ä.) und die passende Zeile aus
   `application_reminder_log` löscht.
2. Ruft die zuständige Edge Function auf (`send-application-reminders`,
   `send-booking-confirmation`, `send-appointment-reminders`,
   `send-invitation-email`, `send-signup-confirmation`,
   `resend-signup-confirmation`, `send-password-reset`, `send-reminders`).
3. Wartet `PAUSE_SECONDS` (Standard 6s) gegen SMTP-Rate-Limit.

Ablauf im Postfach:

```
 1/14 application_received            → test+chain@…
 2/14 booking_confirmation            → test+chain@…
 3/14 interview_invite_30min          → test+chain@…
 4/14 no_booking_24h                  → test+chain@…
 5/14 no_booking_72h                  → test+chain@…
 6/14 no_show_24h                     → test+chain@…
 7/14 rebook_after_cancel_24h         → test+chain@…
 8/14 rebook_after_cancel_72h         → test+chain@…
 9/14 welcome_invitation              → test+chain@…
10/14 signup_confirmation             → test+chain@…
11/14 signup_confirmation_resend      → test+chain@…
12/14 password_reset                  → test+chain@…
13/14 reminder_invite                 → test+chain@…
14/14 reminder_complete_registration  → test+chain@…
```

Einzelne Stufen überspringen:

```bash
SKIP="no_show_24h,password_reset" bash scripts/email-test/run-full-chain.sh
```

Am Ende fragt das Skript, ob `chain-99-cleanup.sql` laufen soll (Zeiten
zurücksetzen, Log leeren) – damit ist der nächste Durchlauf sofort möglich.

## Sicherheits-Regeln

- **`TEST_EMAIL` muss mit `test+` beginnen** – sonst bricht das Skript ab.
- Alle SQL-Updates sind auf **genau eine** `applications`-Row per E-Mail gescoped.
- Preview-Endpoint: nur Service-Role.
- Nach dem Test: Cleanup ausführen oder Test-Bewerber löschen.
