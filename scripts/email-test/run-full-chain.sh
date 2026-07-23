#!/usr/bin/env bash
# =============================================================================
# run-full-chain.sh — sendet alle 14 automatischen Mails an EINEN Test-Bewerber.
#
# Voraussetzungen (Env):
#   SUPABASE_URL        z.B. https://xxxx.supabase.co
#   SERVICE_ROLE        Service-Role-Key
#   DATABASE_URL        Postgres-Connection-String (für psql-State-Manipulation)
#   TEST_TENANT_ID      Tenant-UUID (aktiv, mit SMTP)
#   TEST_LANDING_ID     Landing-UUID (mit Domain)
#   TEST_EMAIL          Empfänger, MUSS mit "test+" beginnen
#
# Optional:
#   SKIP="no_show_24h,password_reset"   Stufen überspringen (Kommaliste)
#   PAUSE_SECONDS=6                      Pause zwischen Sends (SMTP-Rate-Limit)
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

# ---------- Sicherheits-Guard ------------------------------------------------
if [[ "$TEST_EMAIL" != test+*@* ]]; then
  echo "FEHLER: TEST_EMAIL muss mit 'test+' beginnen (z.B. test+chain@deine-domain.de)."
  echo "Aktuell: $TEST_EMAIL"
  exit 1
fi

skip() { [[ ",$SKIP," == *",$1,"* ]]; }

psql_run() {
  # $1 = SQL-Datei (Pfad), rest = -v var=val Argumente
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
  curl -sS -X POST "$SUPABASE_URL/functions/v1/$fn" \
    -H "Authorization: Bearer $SERVICE_ROLE" \
    -H "Content-Type: application/json" \
    -d "$body"
}

STAGE=0
run_stage() {
  # $1 = Stufen-Key (für SKIP), $2 = Beschreibung, $3 = Callback (function name)
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
  fi
  sleep "$PAUSE_SECONDS"
}

SNIP="$(dirname "$0")/sql-snippets"

# ---------- Stufe 1: Bewerbung eingegangen ----------------------------------
stage_application_received() {
  psql_run "$SNIP/chain-01-application-received.sql"
  # Function wird durch die Insert-Trigger-Kette bereits angestoßen;
  # zusätzlich rufen wir explizit send-invitation-email für application_received auf,
  # falls der Trigger nicht greift.
  invoke_fn send-invitation-email \
    "$(jq -nc --arg email "$TEST_EMAIL" '{email:$email, kind:"application_received"}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null)}'
}

# ---------- Stufe 2: Termin bestätigt ---------------------------------------
stage_booking_confirmation() {
  psql_run "$SNIP/chain-02-booking-confirmation.sql"
  invoke_fn send-booking-confirmation "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 3: Interview-Einladung 30min ------------------------------
stage_interview_invite_30min() {
  psql_run "$SNIP/chain-03-interview-invite-30min.sql"
  invoke_fn send-appointment-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 4: No-Booking 24h -----------------------------------------
stage_no_booking_24h() {
  psql_run "$SNIP/chain-04-no-booking-24h.sql"
  invoke_fn send-application-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 5: No-Booking 72h -----------------------------------------
stage_no_booking_72h() {
  psql_run "$SNIP/chain-05-no-booking-72h.sql"
  invoke_fn send-application-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 6: No-Show 24h --------------------------------------------
stage_no_show_24h() {
  psql_run "$SNIP/chain-06-no-show-24h.sql"
  invoke_fn send-application-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 7: Rebook 24h nach Absage ---------------------------------
stage_rebook_after_cancel_24h() {
  psql_run "$SNIP/chain-07-rebook-after-cancel-24h.sql"
  invoke_fn send-application-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 8: Rebook 72h nach Absage ---------------------------------
stage_rebook_after_cancel_72h() {
  psql_run "$SNIP/chain-08-rebook-after-cancel-72h.sql"
  invoke_fn send-application-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 9: Willkommens-/Registrierungs-Einladung ------------------
stage_welcome_invitation() {
  psql_run "$SNIP/chain-09-welcome-invitation.sql"
  invoke_fn send-invitation-email \
    "$(jq -nc --arg email "$TEST_EMAIL" '{email:$email, kind:"welcome"}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null)}'
}

# ---------- Stufe 10: E-Mail-Bestätigung (Signup) ---------------------------
stage_signup_confirmation() {
  invoke_fn send-signup-confirmation \
    "$(jq -nc --arg email "$TEST_EMAIL" --arg tid "$TEST_TENANT_ID" \
        '{email:$email, tenant_id:$tid}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null)}'
}

# ---------- Stufe 11: E-Mail-Bestätigung erneut senden ----------------------
stage_signup_confirmation_resend() {
  invoke_fn resend-signup-confirmation \
    "$(jq -nc --arg email "$TEST_EMAIL" --arg tid "$TEST_TENANT_ID" \
        '{email:$email, tenant_id:$tid}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null)}'
}

# ---------- Stufe 12: Passwort zurücksetzen ---------------------------------
stage_password_reset() {
  invoke_fn send-password-reset \
    "$(jq -nc --arg email "$TEST_EMAIL" --arg tid "$TEST_TENANT_ID" \
        '{email:$email, tenant_id:$tid}')" \
    | jq -c '{status: (.status // "?"), error: (.error // null)}'
}

# ---------- Stufe 13: Einladung noch offen (Drip) ---------------------------
stage_reminder_invite() {
  psql_run "$SNIP/chain-13-reminder-invite.sql"
  invoke_fn send-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ---------- Stufe 14: Registrierung abschließen (Drip) ----------------------
stage_reminder_complete_registration() {
  psql_run "$SNIP/chain-14-reminder-complete-registration.sql"
  invoke_fn send-reminders "{}" | jq -c '{sent, skipped, failed}'
}

# ============================================================================
echo "=========================================================================="
echo "E-Mail-Kette starten für: $TEST_EMAIL"
echo "Tenant:  $TEST_TENANT_ID"
echo "Landing: $TEST_LANDING_ID"
echo "Pause zwischen Mails: ${PAUSE_SECONDS}s   SKIP=$SKIP"
echo "=========================================================================="

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
echo "Fertig. Cleanup (Zeiten zurücksetzen, Log leeren)? [y/N]"
read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  psql_run "$SNIP/chain-99-cleanup.sql"
  echo "Cleanup ausgeführt."
else
  echo "Cleanup übersprungen. Manuell: psql \"\$DATABASE_URL\" -f $SNIP/chain-99-cleanup.sql"
fi
