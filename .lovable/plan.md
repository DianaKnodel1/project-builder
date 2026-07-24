## Was los ist

Der Fehler `Tenant or user not found` kommt **nicht** von der Datenbank, sondern vom **Supavisor-Pooler** vor der DB. Supavisor verlangt bei self-hosted Supabase einen speziellen Benutzernamen im Format `postgres.<tenant_id>` – `postgres` allein reicht ihm nicht, deshalb lehnt er ab, bevor überhaupt ein Passwort geprüft wird.

Das ist der Grund, warum wir "rotieren": jeder neue Anlauf trifft eine andere Hürde derselben Kette (Env-Var → falsches Passwort-Feld → Pooler-Auth). Mit dem **Endkunden-Mailversand hat das nichts zu tun** – der läuft über Edge Functions und `LOVABLE_API_KEY`/Resend, nicht über `psql`. Bewerber sind davon nicht betroffen. Betroffen ist nur unser **Testskript**, das den DB-Zustand backdatet.

## Fix: Pooler umgehen, direkt zum DB-Container

Der DB-Container `supabase-db` exponiert Port 5432 nur intern (Docker-Netzwerk), nicht am Host. Über die Container-IP erreichen wir ihn direkt und umgehen den Pooler.

### Schritte auf Backend (123)

1. Passwort neu laden (falls Shell frisch):
   ```bash
   export POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' /opt/supabase/docker/.env | head -1 | cut -d= -f2-)"
   ```

2. Container-IP der DB ermitteln und `DATABASE_URL` setzen:
   ```bash
   DB_IP="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' supabase-db | awk '{print $1}')"
   echo "DB_IP=$DB_IP"
   export DATABASE_URL="postgresql://supabase_admin:${POSTGRES_PASSWORD}@${DB_IP}:5432/postgres"
   psql "$DATABASE_URL" -c "select 1" >/dev/null && echo "DB OK"
   ```
   Falls `supabase_admin` scheitert, als Fallback `postgres` probieren – bei self-hosted Supabase ist `supabase_admin` aber der Superuser.

3. Wenn `DB OK` erscheint, alle übrigen Vars setzen und Suite starten:
   ```bash
   read -rsp "SERVICE_ROLE: " SERVICE_ROLE; echo; export SERVICE_ROLE
   export TEST_EMAIL="jessikasemen@outlook.com"
   export TEST_TENANT_ID="ad57153e-c326-408e-80bf-3b2de31ec375"
   export TEST_SOURCE_LANDING_ID="8d4a3aac-ad75-4083-a153-fe4c8960b61b"
   export TEST_TARGET_LANDING_ID="e9942bd1-7c11-4df0-b0b6-32c1be32571d"
   export PAGER=cat PSQL_PAGER=cat
   bash /opt/apps/portal-migrations/scripts/email-test/run-full-chain.sh
   ```

### Fallback, falls die Container-IP-Route blockiert

Direkt im DB-Container ausführen:
```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres -c "select 1"
```
Falls das klappt, passe ich das Testskript so an, dass alle SQL-Snippets über `docker exec` laufen statt über `psql` vom Host.

## Zur eigentlichen Sorge: "Bewerber bekommt keine Mails"

Der Mailversand für Bewerber läuft **komplett unabhängig** von diesem Testskript:
- Edge Function `send-invitation-email` / `send-booking-confirmation` → Resend/Lovable Mail API → Bewerber.
- Das Testskript backdatet nur Datensätze, damit wir Reminder-Fenster künstlich auslösen, ohne Tage zu warten.

Ob echte Bewerbermails ankommen, prüfen wir separat über die Edge-Function-Logs im Supabase Studio (Functions → send-invitation-email → Logs). Sag Bescheid, wenn du willst, dass ich das als eigenen, kleinen "Live-Check"-Schritt in den Ablauf einbaue – ganz ohne DB-Manipulation.

## Nach dem Test

Der Service-Role-Key, den du oben im Chat gepostet hast, sollte rotiert werden: Supabase Studio → Settings → API → JWT Secret neu generieren. Danach in allen Deployments (Frontend `.env`, Edge Functions) den neuen Key setzen.