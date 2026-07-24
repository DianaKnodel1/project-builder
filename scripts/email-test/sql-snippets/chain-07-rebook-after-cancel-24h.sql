-- Stufe 7: 24h nach Absage — neuen Termin buchen

BEGIN;

-- Bewerbung als abgesagt markieren, updated_at 25h zurück
UPDATE applications
   SET booking_status = 'cancelled',
       scheduled_at = NULL,
       status = 'neu',
       updated_at = now() - interval '25 hours'
 WHERE email = :'test_email';

UPDATE interview_appointments
   SET status = 'cancelled',
       updated_at = now() - interval '25 hours'
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email');

-- Invitation-Token entfernen: sonst greift der Registration-Pending-Branch
-- und der Rebook-Branch wird nie erreicht.
DELETE FROM invitation_tokens
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email');

DELETE FROM application_reminder_log
 WHERE application_id IN (SELECT id FROM applications WHERE email = :'test_email')
   AND reminder_kind = 'rebook_after_cancel_24h';

COMMIT;
