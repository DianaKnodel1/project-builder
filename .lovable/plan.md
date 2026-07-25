## Prüfergebnis: 12 von 14 Schritten werden sauber protokolliert, 2 nicht

Ich habe jede der 14 Stufen gegen die tatsächlich schreibende Funktion und gegen die Kachel-Liste im E-Mail-Center abgeglichen.

| # | Stufe | Funktion | schreibt in email_send_log | Name im Log | Kachel im Center |
|---|---|---|---|---|---|
| 1 | Bewerbung eingegangen | send-invitation-email | ja | application_received | ja |
| 2 | Terminbestätigung | send-booking-confirmation | ja | booking_confirmation | ja |
| 3 | Interview-Einladung 30 Min | send-appointment-reminders | ja | interview_invite_30min | **nein – Kachel heißt bewerbung_magic_link** |
| 4 | Kein Termin 24h | send-application-reminders | ja | vermittlung_no_booking_24h | ja |
| 5 | Kein Termin 72h | send-application-reminders | ja | vermittlung_no_booking_72h | ja |
| 6 | No-Show 24h | send-application-reminders | ja | vermittlung_no_show_24h | ja |
| 7 | Rebook 24h | send-application-reminders | ja | vermittlung_/fasttrack_rebook_after_cancel_24h | ja |
| 8 | Rebook 72h | send-application-reminders | ja | ..._72h | ja |
| 9 | Willkommen / Zusage | send-invitation-email | ja | invitation | ja |
| 10 | E-Mail-Bestätigung | send-signup-confirmation | ja | signup_confirmation | ja |
| 11 | Bestätigung erneut senden | resend-signup-confirmation | **nein – kein Log-Insert** | – | – |
| 12 | Passwort zurücksetzen | send-password-reset | ja | password_reset | ja |
| 13 | Einladung noch offen | send-reminders | ja | reminder_invite | ja |
| 14 | Registrierung abschließen | send-reminders | ja | reminder_complete_registration | ja |

### Die zwei konkreten Lücken

1. **Schritt 11 (Bestätigung erneut senden)** schreibt gar keinen Log-Eintrag — die Mail geht raus, taucht aber nirgends im Center auf.
2. **Schritt 3 (Interview-Einladung)** wird als `interview_invite_30min` geloggt, die Kachel im Center sucht aber `bewerbung_magic_link`. Ergebnis: Kachel steht auf 0, obwohl Mails rausgehen. Auch das Label fehlt, in der Liste steht der rohe technische Name.

Zusätzlich: Fehlversuche bei Schritt 11 werden ebenfalls nicht sichtbar, und im Center gibt es keine Möglichkeit zu erkennen, ob eine Stufe der Kette bei einem Bewerber nie ausgelöst wurde.

## Umsetzung

1. **resend-signup-confirmation**: Log-Insert einbauen analog zu send-signup-confirmation — bei Erfolg `status: sent`, bei Fehler `status: failed` mit Fehlertext, Template-Name `signup_confirmation_resend`, inklusive `tenant_id`, `rendered_subject`, `rendered_html` und `sender_email`, damit die HTML-Vorschau im Log-Modal funktioniert.
2. **E-Mail-Center Kachel Schritt 3 korrigieren**: Kachel-Key auf `interview_invite_30min` umstellen und `bewerbung_magic_link` als Alias-Key mitführen, damit alte Log-Zeilen weiter gezählt werden.
3. **Neue Kachel „Bestätigung erneut senden"** in der Gruppe Reminder, gebündelt mit `signup_confirmation` unter „E-Mail bestätigen" oder als eigene Kachel — ich bündle sie in die bestehende Kachel „E-Mail bestätigen", damit die Liste kompakt bleibt.
4. **Labels ergänzen** in `src/lib/email-stats.ts`: `interview_invite_30min` und `signup_confirmation_resend`, damit in der Log-Tabelle Klartext statt technischer Name steht.
5. **Vollständigkeits-Check im Center**: eine kleine Statuszeile über den Kacheln, die anzeigt, wie viele der 14 aktiven Kettenschritte im gewählten Zeitraum mindestens einen Versand hatten (z. B. „13 von 14 Schritten aktiv"), damit stumme Stufen sofort auffallen.

### Technische Details
- Betroffene Dateien: `supabase/functions/resend-signup-confirmation/index.ts`, `src/routes/admin.email-center.tsx`, `src/lib/email-stats.ts`.
- Keine Schema-Änderung nötig; `email_send_log` hat alle benötigten Spalten.
- Die Edge Function muss auf Backend 123 neu deployed werden (`git pull` + Funktions-Deploy), die Frontend-Änderungen wirken direkt.
