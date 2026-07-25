## Ziel
Auf der Bewerber-Detailseite (`/admin/personen/:id`) eine kompakte **Termin-Historie** anzeigen, damit man sofort sieht: „gebucht → abgesagt → neu gebucht".

## Umsetzung

### 1) Neue Server-Function `adminListAppointmentsForApplication`
Datei: `src/lib/appointments.functions.ts`

- Input: `{ application_id: uuid }`
- Middleware: `requireSupabaseAuth` + `requireAdmin`
- Query: `interview_appointments` gefiltert nach `application_id`, sortiert nach `created_at DESC`
- Felder: `id, starts_at, ends_at, status, cancelled_at, cancelled_by, cancel_reason, applicant_timezone, created_at`

### 2) Neue Komponente `AppointmentHistory`
Datei: `src/components/AppointmentHistory.tsx`

Rendert eine chronologische Zeitleiste (neueste oben) mit einem Eintrag pro Termin:

```text
● 12.08.2026 · 14:00 – aktuell gebucht     (grün)
● 10.08.2026 · 10:00 – abgesagt (Bewerber) (grau, durchgestrichen)
● 05.08.2026 · 09:00 – abgesagt (Admin)    (grau, durchgestrichen)
```

Pro Eintrag:
- Termin-Datum/-Uhrzeit
- Badge: `gebucht` / `abgesagt` / `no_show` / `wahrgenommen`
- Bei Absage: „abgesagt am … durch Bewerber/Admin" + optional Grund
- Bei mehr als 1 Termin: Header-Zeile „Neu gebucht nach Absage" beim aktuellen Eintrag

Nutzt `useQuery` + die neue Server-Function. Zeigt nichts, wenn 0 Termine existieren (fallback: bestehende Anzeige bleibt).

### 3) Einbindung in Bewerber-Detailseite
Datei: `src/routes/admin.personen.$id.tsx`

Innerhalb des Schritts `appointment` (ca. Zeile 295–307) wird `<AppointmentHistory applicationId={app.id} />` unter der bestehenden Status-Zeile gerendert. Bestehende Logik (aktueller Termin, Overdue-Warnung) bleibt unverändert.

## Nicht Teil dieses Plans
- Keine Änderung an DB, Buchungs-Flow, E-Mails oder `admin.appointments.tsx`.
- Reine Anzeige – Daten sind bereits vollständig in `interview_appointments` vorhanden.