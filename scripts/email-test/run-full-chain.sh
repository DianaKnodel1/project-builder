#!/usr/bin/env bash
# =============================================================================
# run-full-chain.sh — sendet alle automatischen Bewerber-/Mitarbeiter-Mails an
# EINEN Test-Bewerber. Die Cron-Funktionen werden vor dem echten Versand mit
# dry_run:true aufgerufen und prüfen, ob NUR der Test-Bewerber im aktuellen
# Zustand liegt. Liegen weitere Kandidaten im selben Zustand, bricht das
# Skript ab, damit keine Produktions-E-Mails versendet werden.
#
# Voraussetzungen (Env):
#   SUPABASE_URL        z.B. https://xxxx.supabase.co
#   SERVICE_ROLE        Service-Role-Key
#   DATABASE_URL        Postgres-Connection-String (für psql-State-Manipulation)
#   TEST_TENANT_ID      Tenant-UUID (aktiv, mit SMTP)
#   TEST_LANDING_ID     Landing-UUID (mit Domain / Buchungslink)
#   TEST_EMAIL          Empfänger, MUSS mit "test+" beginnen
#
# Optional:
#   SKIP="no_show_24h,password_reset"   Stufen überspringen (Kommaliste)
#   PAUSE_SECONDS=6                      Pause zwischen Sends (SMTP-Rate-Limit)
#   FORCE_SEND=true                     Umgeht dry_run-Sicherheitscheck (NICHT empfohlen)
#
# Nutzung:
#   bash scripts/email-test/run-full-chain.sh
# =============================================================================
set -euo pipefail

: "${SUPABASE_URL:?set SUPABASE_URL}"
: "${SERVICE_ROLE:?set SERVICE_ROLE}"
: "${DATABASE_URL:?set DATABASE_URL}"
: "${TEST_TENANT_ID:?set TEST_TENANT_ID}"
: "${TEST_LANDING_ID:?set TEST_LANDING_ID}"
: "${TEST_EMAIL:?set TEST_EMAIL}"

PAUSE_SECONDS="${PAUSE_SECONDS:-6}"
SKIP="${SKIP:-}"
FORCE_SEND="${FORCE_SEND:-false}"

# ---------- Sicherheits-Guard ------------------------------------------------
if [[ "$TEST_EMAIL" != test+*@* ]]; then
  echo "FEHLER: TEST_EMAIL muss mit 'test+' beginnen (z.B. test+gfndfghrzbg@outlook.com)."
  echo "Aktuell: $TEST_EMAIL"
  exit 1
fi

skip() { [[ ",$SKIP," == *",$1,"* ]]; }

psql_run() {
  local file="$1"; shift
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q \
    -v test_email="$TEST_EMAIL" \
    -v tenant_id="$TEST_TENANT_ID" \
    -v landing_id="$TEST_LANDING_ID" \
    "$@" \
    -f "$file"
}

invoke_fn() {
  local fn="$1"
  local body="${2:-{}}"
  curl -fsS -X POST "$SUPABASE_URL/functions/v1/$fn" \
    -H "Authorization: Bearer $SERVICE_ROLE" \
    -H "Content-Type: application/json" \
    -d "$body"
}

require_success_response() {
  local out="$1"
  if ! echo "$out" | jq -e . >/dev/null 2>&1; then
    echo "   ❌ Ungültige Antwort: $out"
    return 1
  fi
  if echo "$out" | jq -e '(.error? != null) or (.success? == false)' >/dev/null; then
    echo "   ❌ Versand fehlgeschlagen: $out"
    return 1
  fi
  echo "$out"
}

# Query EINEN Spaltenwert aus der DB (quiet).
psql_value() {
  psql "$DATABASE_URL" -tA -q -v ON_ERROR_STOP=1 -c "$1"
}

# Sicherheitscheck: Cron-Funktion dry-run ausführen, prüfen, dass Test-E-Mail
# als einzige Kandidat vorhanden ist, dann echten Versand triggern.
# $1 = Stufen-Key, $2 = Beschreibung, $3 = Function-Name, $4 = Body-JSON
invoke_cron_safely() {
  local key="$1" desc="$2" fn="$3" body="$4"

  if [[ "$FORCE_SEND" == "true" ]]; then
    echo "   ⚠️  FORCE_SEND=true — Sicherheits-Check übersprungen!"
    local out
    out=$(invoke_fn "$fn" "$body")
    echo "$out" | jq -c '{sent, skipped, failed, candidates}'
    return 0
  fi

  # 1) dry_run
  local dryBody
  dryBody=$(echo "$body" | jq -c '. + {dry_run:true}')
  local dryOut
  dryOut=$(invoke_fn "$fn" "$dryBody")

  local candidates
  candidates=$(echo "$dryOut" | jq -r --arg email "$TEST_EMAIL" '[.results[]? | select(.to == $email)] | length')
  local total
  total=$(echo "$dryOut" | jq -r '(.results | length) // 0')

  echo "   dry_run: candidates=$total, target=$candidates"

  if [[ "$candidates" != "1" ]]; then
    echo "   ❌ Abbruch: $fn würde $candidates Mal an $TEST_EMAIL senden, total=$total"
    echo "   Output: $dryOut"
    return 1
  fi

  # 2) realer Versand
  local out
  out=$(invoke_fn "$fn" "$body")
  echo "$out" | jq -c '{sent, skipped, failed, candidates}'
}

STAGE=0
run_stage() {
  STAGE=$((STAGE + 1))
  local key="$1" desc="$2" cb="$3"
  if skip "$key"; then
    printf "⏭️  %2d/14 %-36s (SKIP)\n" "$STAGE" "$key"
    return 0
  fi
  printf "▶️  %2d/14 %-36s %s\n" "$STAGE" "$key" "$desc"
  if "$cb"; then
    printf "✅ %2d/14 %-36s → %s\n" "$STAGE" "$key" "$TEST_EMAIL"
  else
    printf "❌ %2d/14 %-36s (siehe Ausgabe oben)\n" "$STAGE" "$key"
    return 1
  fi
  sleep "$PAUSE_SECONDS"
}

SNIP="$(dirname "$0")/sql-snippets"

# Hilfs-Variablen, die mehrere Stufen brauchen
APP_ID=""
TENANT_DOMAIN=""

load_app_context() {
  APP_ID=$(psql_value "SELECT id FROM applications WHERE email = '$TEST_EMAIL' LIMIT 1;")
  TENANT_DOMAIN=$(psql_value "SELECT COALESCE(primary_domain, domain) FROM tenants WHERE id = '$TEST_TENANT_ID' LIMIT 1;")
  echo "   App-ID: $APP_ID | Tenant-Domain: $TENANT_DOMAIN"
}

preflight() {
  echo "Vorabcheck: Datenbank, Tenant und Landing …"
  psql_value "SELECT 1;" >/dev/null

  local tenant_exists landing_exists
  tenant_exists=$(psql_value "SELECT count(*) FROM tenants WHERE id = '$TEST_TENANT_ID';")
  landing_exists=$(psql_value "SELECT count(*) FROM landings WHERE id = '$TEST_LANDING_ID';")

  if [[ "$tenant_exists" != "1" ]]; then
    echo "FEHLER: TEST_TENANT_ID wurde nicht gefunden."
    return 1
  fi
  if [[ "$landing_exists" != "1" ]]; then
    echo "FEHLER: TEST_LANDING_ID wurde nicht gefunden."
    return 1
  fi
  echo "Vorabcheck erfolgreich."
}

# ---------- Stufe 1: Bewerbung eingegangen ----------------------------------
stage_application_received() {
  psql_run "$SNIP/chain-01-application-received.sql"
  load_app_context
  local link="https://portal.${TENANT_DOMAIN}/termin/buchen/${APP_ID}?ref=${APP_ID}"
  local out
  out=$(invoke_fn send-invitation-email \
    "$(jq -nc \
        --arg to "$TEST_EMAIL" \
        --arg link "$link" \
        --arg tid "$TEST_TENANT_ID" \
        --arg appId "$APP_ID" \
        '{to:$to, registrationLink:$link, tenantId:$tid, applicationId:$appId, firstName:"Test", lastName:"Kette", templateNameOverride:"application_received"}')")
  require_success_response "$out" | jq -c '{status: (.status // "?"), error: (.error // null), success: (.success // null)}'
}

# ---------- Stufe 2: Termin bestätigt ---------------------------------------
stage_booking_confirmation() {
  psql_run "$SNIP/chain-02-booking-confirmation.sql"
  invoke_cron_safely "booking_confirmation" "Terminbestätigung" "send-booking-confirmation" "{}"
}

# ---------- Stufe 3: Interview-Einladung 30min ------------------------------
stage_interview_invite_30min() {
  psql_run "$SNIP/chain-03-interview-invite-30min.sql"
  invoke_cron_safely "interview_invite_30min" "Interview-Einladung" "send-appointment-reminders" "{}"
}

# ---------- Stufe 4: No-Booking 24h -----------------------------------------
stage_no_booking_24h() {
  psql_run "$SNIP/chain-04-no-booking-24h.sql"
  invoke_cron_safely "no_booking_24h" "Kein Termin 24h" "send-application-reminders" "{}"
}

# ---------- Stufe 5: No-Booking 72h -----------------------------------------
stage_no_booking_72h() {
  psql_run "$SNIP/chain-05-no-booking-72h.sql"
  invoke_cron_safely "no_booking_72h" "Kein Termin 72h" "send-application-reminders" "{}"
}

# ---------- Stufe 6: No-Show 24h --------------------------------------------
stage_no_show_24h() {
  psql_run "$SNIP/chain-06-no-show-24h.sql"
  invoke_cron_safely "no_show_24h" "No-Show" "send-application-reminders" "{}"
}

# ---------- Stufe 7: Rebook 24h nach Absage ---------------------------------
stage_rebook_after_cancel_24h() {
  psql_run "$SNIP/chain-07-rebook-after-cancel-24h.sql"
  invoke_cron_safely "rebook_after_cancel_24h" "Rebook 24h" "send-application-reminders" "{}"
}

# ---------- Stufe 8: Rebook 72h nach Absage ---------------------------------
stage_rebook_after_cancel_72h() {
  psql_run "$SNIP/chain-08-rebook-after-cancel-72h.sql"
  invoke_cron_safely "rebook_after_cancel_72h" "Rebook 72h" "send-application-reminders" "{}"
}

# ---------- Stufe 9: Willkommens-/Registrierungs-Einladung ------------------
stage_welcome_invitation() {
  psql_run "$SNIP/chain-09-welcome-invitation.sql"
  load_app_context
  local link="https://portal.${TENANT_DOMAIN}/register?app=${APP_ID}"
  invoke_fn send-invitation-email \
    "$(jq -nc \
        --arg to "$TEST_EMAIL" \
        --arg link "$link" \
        --arg tid "$TEST_TENANT_ID" \
        --arg appId "$APP_ID" \
        '{to:$to, registrationLink:$link, tenantId:$tid, applicationId:$appId, firstName:"Test", lastName:"Kette", templateNameOverride:"welcome"}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null), success: (.success // null)}'
}

# ---------- Stufe 10: E-Mail-Bestätigung (Signup) ---------------------------
stage_signup_confirmation() {
  invoke_fn send-signup-confirmation \
    "$(jq -nc \
        --arg email "$TEST_EMAIL" \
        --arg tid "$TEST_TENANT_ID" \
        '{email:$email, password:"Test1234!", tenant_id:$tid, full_name:"Test Kette"}')" \
    | jq -c '{success: (.success // null), user_id: (.user_id // null), error: (.error // null)}'
}

# ---------- Stufe 11: E-Mail-Bestätigung erneut senden ----------------------
stage_signup_confirmation_resend() {
  invoke_fn resend-signup-confirmation \
    "$(jq -nc \
        --arg email "$TEST_EMAIL" \
        --arg tid "$TEST_TENANT_ID" \
        '{email:$email, tenant_id:$tid}')" \
    | jq -c '{success: (.success // null), error: (.error // null)}'
}

# ---------- Stufe 12: Passwort zurücksetzen ---------------------------------
stage_password_reset() {
  load_app_context
  invoke_fn send-password-reset \
    "$(jq -nc \
        --arg email "$TEST_EMAIL" \
        --arg host "$TENANT_DOMAIN" \
        '{email:$email, host:$host}')" \
    | jq -c '{ok: (.ok // null)}'
}

# ---------- Stufe 13: Einladung noch offen (Drip) ---------------------------
# Hinweis: Diese Stufe wird aktuell vom Edge-Function "send-reminders" immer
# übersprungen, da der automatische invite-Reminder deaktiviert ist.
stage_reminder_invite() {
  psql_run "$SNIP/chain-13-reminder-invite.sql"
  local out
  out=$(invoke_fn send-reminders \
    "$(jq -nc '{dry_run:true, only_type:"invite", ignore_quiet_hours:true}')")
  echo "$out" | jq -c '{by_type, skipped: .skipped, sent: .sent}'
}

# ---------- Stufe 14: Registrierung abschließen (Drip) ----------------------
stage_reminder_complete_registration() {
  psql_run "$SNIP/chain-14-reminder-complete-registration.sql"
  invoke_fn send-reminders \
    "$(jq -nc '{dry_run:false, only_type:"confirm_email", ignore_quiet_hours:true}')" \
    | jq -c '{by_type, skipped: .skipped, sent: .sent}'
}

# ============================================================================
echo "=========================================================================="
echo "E-Mail-Kette starten für: $TEST_EMAIL"
echo "Tenant:  $TEST_TENANT_ID"
echo "Landing: $TEST_LANDING_ID"
echo "Pause zwischen Mails: ${PAUSE_SECONDS}s   SKIP=$SKIP"
echo "=========================================================================="

preflight

run_stage application_received          "Bewerbung eingegangen"            stage_application_received
run_stage booking_confirmation          "Termin bestätigt"                 stage_booking_confirmation
run_stage interview_invite_30min        "Interview-Einladung 30min"        stage_interview_invite_30min
run_stage no_booking_24h                "Kein Termin – 24h Erinnerung"     stage_no_booking_24h
run_stage no_booking_72h                "Kein Termin – 72h Erinnerung"     stage_no_booking_72h
run_stage no_show_24h                   "No-Show – erneut buchen"          stage_no_show_24h
run_stage rebook_after_cancel_24h       "Rebook 24h nach Absage"           stage_rebook_after_cancel_24h
run_stage rebook_after_cancel_72h       "Rebook 72h nach Absage"           stage_rebook_after_cancel_72h
run_stage welcome_invitation            "Willkommens-/Registrierungs-Mail" stage_welcome_invitation
run_stage signup_confirmation           "E-Mail-Bestätigung"               stage_signup_confirmation
run_stage signup_confirmation_resend    "Bestätigung erneut senden"        stage_signup_confirmation_resend
run_stage password_reset                "Passwort zurücksetzen"            stage_password_reset
run_stage reminder_invite               "Einladung noch offen"             stage_reminder_invite
run_stage reminder_complete_registration "Registrierung abschließen"       stage_reminder_complete_registration

echo ""
echo "=========================================================================="
echo "Fertig. Cleanup (Zeiten zurücksetzen, Logs leeren)? [y/N]"
read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  psql_run "$SNIP/chain-99-cleanup.sql"
  echo "Cleanup ausgeführt."
else
  echo "Cleanup übersprungen. Manuell: psql \"\$DATABASE_URL\" -f $SNIP/chain-99-cleanup.sql"
fi
