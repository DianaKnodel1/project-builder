-- Stufe 1: Bewerbung eingegangen
-- Legt den Test-Bewerber an (bzw. resettet ihn) und leert die Reminder-Logs.
-- Erwartete psql-Variablen: :test_email, :tenant_id, :landing_id

BEGIN;

-- Alte Reminder-Log-Einträge vom Test-Bewerber löschen
DELETE FROM application_reminder_log
WHERE application_id IN (
  SELECT id FROM applications WHERE email = :'test_email'
);
DELETE FROM reminder_log
WHERE email = :'test_email';

-- Bewerber upsert
INSERT INTO applications (
  email, first_name, last_name, full_name, tenant_id,
  source_landing_id, target_landing_id, status,
  booking_status, created_at, updated_at
)
VALUES (
  :'test_email', 'Test', 'Kette', 'Test Kette', :'tenant_id'::uuid,
  :'landing_id'::uuid, :'landing_id'::uuid, 'neu',
  NULL, now(), now()
)
ON CONFLICT (email) DO UPDATE
  SET tenant_id = EXCLUDED.tenant_id,
      source_landing_id = EXCLUDED.source_landing_id,
      target_landing_id = EXCLUDED.target_landing_id,
      status = EXCLUDED.status,
      booking_status = NULL,
      scheduled_at = NULL,
      accepted_at = NULL,
      created_at = now(),
      updated_at = now();

COMMIT;

SELECT id, email, booking_status, status, created_at
FROM applications WHERE email = :'test_email';
