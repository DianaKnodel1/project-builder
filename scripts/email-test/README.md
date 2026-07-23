# E-Mail Test-Suite

Schnelles, sicheres Testen aller automatischen Bewerber-/Mitarbeiter-Mails
ohne Wartezeit auf reale Trigger.

## Voraussetzungen

```bash
export SUPABASE_URL="https://<PROJECT>.supabase.co"      # oder self-hosted URL
export SERVICE_ROLE="<SERVICE_ROLE_KEY>"                 # aus /opt/apps/portal/.env
export TEST_TENANT_ID="<uuid>"                           # ein realer Tenant
export TEST_LANDING_ID="<uuid>"                          # optional: für Landing-Logo
export TEST_EMAIL="dein-postfach@example.com"            # Empfänger für Live-Tests
```

## Ebene 1 — Rendering-Preview (Sekunden, KEIN Versand)

Alle Templates auf einmal rendern (Subject + Text-Preview):

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/email-preview" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"tenant_id\": \"$TEST_TENANT_ID\", \"landing_id\": \"$TEST_LANDING_ID\"}" \
  | jq '.rendered[] | {kind, subject, text_preview}'
```

Ein einzelnes Template als HTML im Browser ansehen:

```bash
# öffnet ein einzelnes Template als HTML — zum Anschauen in Browser oder Mail-Client
curl -s -X POST "$SUPABASE_URL/functions/v1/email-preview?format=html" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"template\": \"booking_confirmation\", \"tenant_id\": \"$TEST_TENANT_ID\"}" \
  > /tmp/preview.html && xdg-open /tmp/preview.html
```

Verfügbare `template`-Werte:
`application_received`, `booking_confirmation`, `interview_invite_30min`,
`no_booking_24h`, `no_booking_72h`, `no_show_24h`,
`rebook_after_cancel_24h`, `rebook_after_cancel_72h`,
`welcome_invitation`, `signup_confirmation`, `password_reset`,
`reminder_invite`, `reminder_confirm_email`, `reminder_complete_registration`.

## Ebene 2 — Einmal-Testversand an deine eigene Adresse

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/email-preview" \
  -H "Authorization: Bearer $SERVICE_ROLE" \
  -H "Content-Type: application/json" \
  -d "{\"template\": \"application_received\", \"tenant_id\": \"$TEST_TENANT_ID\", \"send_to\": \"$TEST_EMAIL\"}" \
  | jq
```

- Betreff bekommt `[PREVIEW]`-Präfix, damit du echte Mails nicht verwechselst.
- Sendet über Tenant-SMTP — testet also auch die Zustellkette.
- Nur EIN Template pro Request, nur EINE Adresse.

## Ebene 3 — Dry-Run gegen echte Cron-Daten

Alle vier Cron-Endpunkte gleichzeitig, nichts wird gesendet, du bekommst
die Liste „wer wäre jetzt dran":

```bash
bash scripts/email-test/dry-run-all.sh
```

## Ebene 4 — Echten Cron-Send auslösen (mit vordatiertem Test-Bewerber)

1. Lege einen dedizierten Test-Bewerber an (per UI oder API), z. B.
   `test+booking@deine-domain.de`.
2. Setze den State mit einem Snippet aus `sql-snippets/` (Zeit vordatieren).
3. Trigger die passende Function:

```bash
curl -s -X POST "$SUPABASE_URL/functions/v1/send-application-reminders" \
  -H "Authorization: Bearer $SERVICE_ROLE" -d '{}'
```

**Wichtig:** Immer erst `SELECT id, email FROM applications WHERE …`
ausführen, um sicherzustellen, dass nur der Test-Bewerber getroffen wird.

## Sicherheits-Regeln

- Preview-Endpoint: nur Service-Role.
- `send_to`: nur eine Adresse pro Request, mit `[PREVIEW]`-Präfix.
- Zeit-Manipulation: immer auf einen `test+…@`-Bewerber beschränken.
- Nach dem Test: Test-Bewerber löschen oder `created_at` zurücksetzen.
