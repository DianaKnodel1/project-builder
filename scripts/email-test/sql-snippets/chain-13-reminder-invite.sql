-- Stufe 13: Drip "Einladung noch offen" — angenommen vor 4 Tagen, kein Account

BEGIN;

UPDATE applications
   SET accepted_at = now() - interval '4 days',
       updated_at = now() - interval '4 days'
 WHERE email = :'test_email';

DELETE FROM reminder_log
 WHERE email = :'test_email'
   AND reminder_type = 'invite';

COMMIT;
