-- Stufe 14: Drip "Registrierung abschließen" — Account existiert, aber E-Mail unbestätigt
-- Setzt für einen bereits vorhandenen auth.users-Eintrag zur Test-Adresse
-- die confirmed-Timestamps zurück und legt einen Reminder-Anker an.
-- Falls kein auth.users-Eintrag existiert, wird nichts gemacht (dann Stufe 10/11 vorher laufen lassen).

BEGIN;

UPDATE auth.users
   SET email_confirmed_at = NULL,
       confirmed_at = NULL,
       created_at = now() - interval '2 days'
 WHERE email = :'test_email';

DELETE FROM application_reminder_log
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email')
   AND reminder_kind = 'reminder_complete_registration';

COMMIT;
