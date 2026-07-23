-- Stufe 8: 72h nach Absage — zweite Erinnerung

BEGIN;

UPDATE applications
   SET booking_status = 'cancelled',
       scheduled_at = NULL,
       updated_at = now() - interval '73 hours'
 WHERE email = :'test_email';

UPDATE interview_appointments
   SET status = 'cancelled',
       updated_at = now() - interval '73 hours'
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email');

DELETE FROM application_reminder_log
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email')
   AND reminder_kind = 'rebook_after_cancel_72h';

COMMIT;
