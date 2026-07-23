-- Stufe 1: Bewerbung eingegangen
-- Legt den Test-Bewerber im Vermittlungs-Flow an (Source = Broker, Target = Fast-Track)
-- und leert die Reminder-Logs.
-- Erwartete psql-Variablen: :test_email, :tenant_id, :source_landing_id, :target_landing_id, :landing_id

BEGIN;

-- Alte Reminder-Log-Einträge vom Test-Bewerber löschen
DELETE FROM application_reminder_log
WHERE application_id IN (
  SELECT id FROM applications WHERE email = :'test_email'
);
DELETE FROM reminder_log
WHERE email = :'test_email';

-- Alte Testtermine entfernen. So bekommt jeder Durchlauf eine neue Appointment-ID
-- und kollidiert nicht mit früheren Versand-Logs der Terminbestätigung.
DELETE FROM interview_appointments
WHERE application_id IN (
  SELECT id FROM applications WHERE email = :'test_email'
);

-- Bewerber upsert. tenant_id = Broker-/Source-Tenant, source_landing_id = Vermittlung,
-- target_landing_id = Fast-Track. Der DB-Trigger füllt daraus broker_tenant_id
-- und fasttrack_tenant_id automatisch.
INSERT INTO applications (
  email, first_name, last_name, full_name, tenant_id,
  source_landing_id, target_landing_id, status, flow_type,
  booking_status, created_at, updated_at
)
VALUES (
  :'test_email', 'Test', 'Kette', 'Test Kette', :'tenant_id'::uuid,
  :'source_landing_id'::uuid, :'target_landing_id'::uuid, 'neu', 'broker',
  NULL, now(), now()
)
ON CONFLICT (email) DO UPDATE
  SET tenant_id = EXCLUDED.tenant_id,
      source_landing_id = EXCLUDED.source_landing_id,
      target_landing_id = EXCLUDED.target_landing_id,
      status = EXCLUDED.status,
      flow_type = EXCLUDED.flow_type,
      booking_status = NULL,
      scheduled_at = NULL,
      created_at = now(),
      updated_at = now();

COMMIT;

-- Kontrolle: alle Routing-Spalten müssen jetzt gefüllt sein.
SELECT id, email, tenant_id, broker_tenant_id, fasttrack_tenant_id,
       source_landing_id, target_landing_id, flow_type, status, booking_status
FROM applications WHERE email = :'test_email';
