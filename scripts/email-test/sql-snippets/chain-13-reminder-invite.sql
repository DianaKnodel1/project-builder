-- Stufe 13: Drip "Einladung noch offen" — angenommen vor 4 Tagen, kein Account

BEGIN;

UPDATE applications
   SET accepted_at = now() - interval '4 days',
       updated_at = now() - interval '4 days'
 WHERE email = :'test_email';

DELETE FROM application_reminder_log
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email')
   AND reminder_kind = 'reminder_invite';

COMMIT;
