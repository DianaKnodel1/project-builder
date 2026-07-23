-- Stufe 2: Termin bestätigt
-- Buchungs-Status auf 'confirmed', Termin in 2 Tagen.
-- Reminder-Log leeren, damit die Confirmation-Mail feuern darf.

BEGIN;

UPDATE applications
   SET booking_status = 'confirmed',
       scheduled_at = now() + interval '2 days',
       updated_at = now()
 WHERE email = :'test_email';

DELETE FROM application_reminder_log
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email')
   AND reminder_kind = 'booking_confirmation';

-- Falls interview_appointments verwendet wird: passenden Termin anlegen/updaten
INSERT INTO interview_appointments (application_id, starts_at, ends_at, status, created_at, updated_at)
SELECT id, now() + interval '2 days', now() + interval '2 days' + interval '20 minutes',
       'scheduled', now(), now()
  FROM applications WHERE email = :'test_email'
ON CONFLICT (application_id) DO UPDATE
  SET starts_at = EXCLUDED.starts_at,
      ends_at = EXCLUDED.ends_at,
      status = 'scheduled',
      updated_at = now();

COMMIT;
