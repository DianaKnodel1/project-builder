
# Ziel

Mit **einem** Test-Bewerber (z. B. `test+chain@deine-domain.de`) alle 14 automatischen Mails wirklich durchlaufen – inklusive Cron-Trigger und SMTP-Versand – ohne 24/72 Stunden warten zu müssen. Ergebnis: du siehst jede Mail nacheinander in deinem Postfach.

# Prinzip

Für jede Mail machen wir drei Schritte hintereinander:

1. **State setzen** – ein SQL-Snippet backdatet den Test-Bewerber so, dass das jeweilige Cron-Gate sofort feuert.
2. **Cron-Endpoint aufrufen** – ohne `dry_run`, damit wirklich versendet wird.
3. **Aufräumen** – `application_reminder_log`-Zeile für den nächsten Test löschen, Zeitstempel zurücksetzen.

Alle drei Schritte packen wir in **ein einziges Skript** `scripts/email-test/run-full-chain.sh`, das nacheinander alle 14 Stufen durchläuft und zwischen den Sends 5–10 Sekunden pausiert (SMTP-Rate-Limit).

# Was neu entsteht

### 1. `scripts/email-test/run-full-chain.sh`
Bash-Skript, das die Kette komplett durchspielt. Erwartet:
- `SUPABASE_URL`, `SERVICE_ROLE`, `TEST_TENANT_ID`, `TEST_EMAIL`, `TEST_LANDING_ID`
- optional `SKIP="no_show_24h,password_reset"` um einzelne Stufen zu überspringen

Pro Stufe:
- schreibt/updated die Test-Bewerber-Row per `psql` oder Supabase REST
- ruft die passende Function (echter Versand)
- prüft `email_send_log` auf `status='sent'`
- loggt „✅ 3/14 booking_confirmation → dein-postfach@…"

### 2. `scripts/email-test/sql-snippets/chain-*.sql`
Ein Snippet pro Stufe (14 Files), jedes idempotent: setzt den State, ohne den Bewerber zu duplizieren. Beispiele:
- `chain-01-application-received.sql` – Bewerber neu anlegen bzw. resetten
- `chain-04-no-booking-24h.sql` – `created_at = now() - 25h`, `booking_status = null`
- `chain-06-no-show.sql` – Termin in Vergangenheit + `status='missed'`
- `chain-07-rebook.sql` – Termin `cancelled`, `updated_at = -25h`

### 3. `scripts/email-test/README.md` erweitern
- neuer Abschnitt „**Stufe 5 — Komplette Kette mit einem Skript**"
- Warnung: nur mit `test+…@`-Adresse ausführen, Skript verweigert andere Empfänger

# Zuordnung Stufe → Function → State-Trick

| # | Mail | Function | State-Manipulation |
|---|------|----------|--------------------|
| 1 | Bewerbung eingegangen | direkt beim Insert via `send-invitation-email` | Bewerber-Row neu erstellen |
| 2 | Termin bestätigt | `send-booking-confirmation` | `booking_status='confirmed'`, `scheduled_at=+2d` |
| 3 | Interview-Einladung 30min | `send-appointment-reminders` | `scheduled_at=now()+30min` |
| 4 | No-Booking 24h | `send-application-reminders` | `created_at=-25h`, `booking_status=null` |
| 5 | No-Booking 72h | `send-application-reminders` | `created_at=-73h` |
| 6 | No-Show 24h | `send-application-reminders` | Termin `-25h`, `status='missed'` |
| 7 | Rebook 24h nach Absage | `send-application-reminders` | Termin `cancelled`, `updated_at=-25h` |
| 8 | Rebook 72h nach Absage | `send-application-reminders` | `updated_at=-73h` |
| 9 | Willkommens/Invite | `send-invitation-email` (`kind=welcome`) | `applications.accepted_at=now()` |
| 10 | E-Mail-Bestätigung | `send-signup-confirmation` | neuen Auth-User anlegen |
| 11 | Bestätigung erneut | `resend-signup-confirmation` | direkter Call |
| 12 | Passwort-Reset | `send-password-reset` | direkter Call mit `TEST_EMAIL` |
| 13 | Einladung noch offen | `send-reminders` (`reminder_invite`) | `accepted_at=-4d`, kein Account |
| 14 | Registrierung abschließen | `send-reminders` (`reminder_complete_registration`) | Account existiert, `email_confirmed_at=null, -2d` |

Zwischen jeder Stufe: `DELETE FROM application_reminder_log WHERE application_id=…` damit der nächste Kind feuern darf.

# Sicherheit

- Skript prüft, dass `TEST_EMAIL` mit `test+` beginnt – sonst Abbruch.
- Alle UPDATEs sind auf genau **eine** `application_id` gescoped.
- Am Ende: Cleanup-Query setzt alle Zeitstempel zurück und löscht die Log-Zeilen, damit der Test wiederholbar ist.

# Was du danach machst

```bash
export SUPABASE_URL=... SERVICE_ROLE=... TEST_TENANT_ID=... TEST_EMAIL=test+chain@… TEST_LANDING_ID=...
bash scripts/email-test/run-full-chain.sh
```

→ 14 Mails landen innerhalb weniger Minuten nacheinander in deinem Postfach, jede mit realer Cron-Verarbeitung, echtem SMTP, echtem Logging.

# Was NICHT im Plan ist

- Kein neuer Edge-Function-Code, keine Schema-Änderungen. Nur Test-Tooling.
- `email-preview` bleibt unverändert (für „nur ansehen"-Fälle).
