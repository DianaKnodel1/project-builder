## Ziel
Alle 14 Stufen der E-Mail-Kette laufen sauber durch. Aktuell scheitert Stufe 2, weil die Snippets ungültige `booking_status`-Werte verwenden.

## Ursache (verifiziert)
`applications.booking_status` hat einen CHECK-Constraint (siehe `supabase/manual-migrations/20260618100000_calendly_integration.sql:28`):

```
booking_status IN ('none','pending','scheduled','cancelled','no_show','completed')
```

Die Edge Functions bestätigen das ebenfalls — z. B. `send-application-reminders/index.ts:523` und `send-appointment-reminders/index.ts:209` filtern auf `booking_status = 'scheduled'`.

Falsche Werte in den Snippets:
- `chain-02` setzt `'confirmed'` → ungültig → aktueller Fehler.
- `chain-09` setzt `'accepted'` → ungültig, würde als nächstes brechen.
- `chain-04` und `chain-05` setzen `booking_status = NULL` → verstößt gegen NOT-NULL (Default `'none'`).

Alle anderen Snippets (`scheduled`, `cancelled`, `no_show`) sind bereits gültig.

## Fix — Snippet-Korrekturen
| Datei | Änderung |
|---|---|
| `chain-02-booking-confirmation.sql` | `booking_status = 'scheduled'` (statt `'confirmed'`) |
| `chain-04-no-booking-24h.sql` | `booking_status = 'none'` (statt `NULL`) |
| `chain-05-no-booking-72h.sql` | `booking_status = 'none'` (statt `NULL`) |
| `chain-09-welcome-invitation.sql` | `booking_status = 'completed'` (statt `'accepted'`); `status = 'akzeptiert'` bleibt |

Zusätzlich im Runner:
- `SUITE_VERSION` auf `2026-07-23.5` erhöhen.
- Vorabcheck erweitern: grep prüft, dass keines der `chain-*.sql`-Snippets die verbotenen Werte `'confirmed'` oder `'accepted'` für `booking_status` enthält (verhindert erneut veraltete Kopien auf Server 123).
- `invoke_fn`-Fehlerausgabe bleibt wie in Version `2026-07-23.4`, damit Stufen 4/5 (Kein-Termin-Reminder) und 6 (No-Show) den tatsächlichen HTTP-Body zeigen, falls die Edge Function den Kandidaten nicht triggert.

## Sync-/Ausführungs-Schritte
1. Frontend (124):
   ```bash
   cd /opt/apps/portal && git pull
   tar -czf /tmp/email-test-suite.tgz -C scripts email-test
   scp /tmp/email-test-suite.tgz root@190.97.167.123:/tmp/
   ssh root@190.97.167.123 \
     'rm -rf /opt/apps/portal-migrations/scripts/email-test &&
      mkdir -p /opt/apps/portal-migrations/scripts &&
      tar -xzf /tmp/email-test-suite.tgz -C /opt/apps/portal-migrations/scripts'
   ```
2. Backend (123) mit den bereits exportierten ENV-Variablen:
   ```bash
   bash scripts/email-test/run-full-chain.sh
   ```

## Erwartetes Ergebnis
Alle 14 Stufen liefern `✅` und lösen je eine E-Mail an `jessikasemen@outlook.com` aus (Bewerbung eingegangen, Terminbestätigung, 30-min-Erinnerung, 24h/72h-ohne-Termin, No-Show, Rebook 24h/72h, Willkommen, Signup-Bestätigung + Resend, Passwort-Reset, Einladung offen, Registrierung abschließen).

## Nicht Teil dieses Plans
- Keine Änderungen an Edge Functions oder Templates.
- Kein DB-Schema-Change.
