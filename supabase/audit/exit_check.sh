#!/usr/bin/env bash
# ============================================================
# Phase 1 exit check — black-box probes with the PUBLIC ANON KEY,
# i.e. exactly what an attacker who unzips the APK can do.
#
# Run BEFORE applying migrations to see the vulnerable baseline (many
# FAILs), and AFTER to confirm lockdown (all PASS).
#
# Non-destructive: writes use an impossible id filter so zero rows match.
# Usage:  bash supabase/audit/exit_check.sh
# ============================================================
set -u
ENV_FILE="$(dirname "$0")/../../.env"
ANON=$(grep SUPABASE_ANON_KEY "$ENV_FILE" | cut -d= -f2 | tr -d '\r\n ')
URL=$(grep SUPABASE_URL "$ENV_FILE" | cut -d= -f2 | tr -d '\r\n ')
NONE="00000000-0000-0000-0000-000000000000"
H_KEY="apikey: $ANON"; H_AUTH="Authorization: Bearer $ANON"
pass=0; fail=0

# rowcount TABLE  -> prints number of rows anon can read
rowcount() {
  curl -s -o /dev/null -D - "$URL/rest/v1/$1?select=id" \
    -H "$H_KEY" -H "$H_AUTH" -H "Prefer: count=exact" -H "Range: 0-0" \
    | tr -d '\r' | awk -F/ 'tolower($0) ~ /^content-range/ {print $2}'
}
code() { # METHOD TABLE [QUERY] [BODY]
  local m=$1 t=$2 q=${3:-} b=${4:-}
  curl -s -o /dev/null -w "%{http_code}" -X "$m" "$URL/rest/v1/$t$q" \
    -H "$H_KEY" -H "$H_AUTH" -H "Content-Type: application/json" \
    -H "Prefer: return=minimal" ${b:+-d "$b"}
}
check() { # LABEL  CONDITION(0/1)  DETAIL
  if [ "$2" = "1" ]; then echo "  PASS  $1  ($3)"; pass=$((pass+1));
  else echo "  FAIL  $1  ($3)"; fail=$((fail+1)); fi
}

echo "== Visit Gondar — Phase 1 exit check =="
echo "target: $URL"
echo

echo "[PII reads must be 0 for anon]"
for t in bookings emergency_requests users; do
  n=$(rowcount "$t"); n=${n:-?}
  check "anon cannot read $t" "$([ "$n" = "0" ] && echo 1 || echo 0)" "rows=$n"
done

echo
echo "[content stays publicly readable]"
n=$(rowcount "hotels"); check "anon can read published hotels" "$([ "${n:-0}" -gt 0 ] 2>/dev/null && echo 1 || echo 0)" "rows=${n:-?}"

echo
echo "[draft content hidden from anon]"
dc=$(curl -s "$URL/rest/v1/hotels?select=id&publish_status=eq.draft" -H "$H_KEY" -H "$H_AUTH")
check "anon cannot read draft hotels" "$([ "$dc" = "[]" ] && echo 1 || echo 0)" "resp=${dc:0:40}"

echo
echo "[no client writes to protected tables]"
c=$(code PATCH  bookings "?id=eq.$NONE" '{"status":"confirmed"}'); check "anon UPDATE bookings blocked"     "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"
c=$(code DELETE bookings "?id=eq.$NONE");                          check "anon DELETE bookings blocked"     "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"
c=$(code DELETE emergency_requests "?id=eq.$NONE");                check "anon DELETE emergency blocked"     "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"
c=$(code PATCH  users "?id=eq.$NONE" '{"full_name":"x"}');        check "anon UPDATE users blocked"         "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"
c=$(code DELETE danger_zones "?id=eq.$NONE");                      check "anon DELETE danger_zones blocked"  "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"

echo
echo "[commissions ledger — zero client access]"
c=$(code GET commissions "?select=id&limit=1"); check "anon read commissions blocked" "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"

echo
echo "[booking cannot be created with a client-chosen price]"
# return=representation so we can DELETE the row if the (vulnerable) DB
# actually lets the insert through — keeps this probe non-destructive.
MARK="exitcheck-$$"
ins=$(curl -s -w $'\n%{http_code}' -X POST "$URL/rest/v1/bookings" \
  -H "$H_KEY" -H "$H_AUTH" -H "Content-Type: application/json" -H "Prefer: return=representation" \
  -d '{"item_type":"hotel","item_name":"'$MARK'","customer_name":"'$MARK'","customer_contact":"'$MARK'","booking_date":"2030-01-01","status":"pending","price":1,"total_price":1,"commission_amount":0}')
c=$(printf '%s' "$ins" | tail -n1)
check "direct booking INSERT blocked" "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"
if [ "$c" -lt 400 ] 2>/dev/null; then
  curl -s -o /dev/null -X DELETE "$URL/rest/v1/bookings?item_name=eq.$MARK" -H "$H_KEY" -H "$H_AUTH"
  echo "  (cleaned up the row this probe created — DB is still open)"
fi

echo
echo "[create_booking RPC requires auth]"
c=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL/rest/v1/rpc/create_booking" \
  -H "$H_KEY" -H "$H_AUTH" -H "Content-Type: application/json" \
  -d '{"p_item_type":"hotel","p_item_id":"'$NONE'","p_check_in":"2030-01-01","p_check_out":"2030-01-03","p_guests":1,"p_customer_name":"x","p_customer_contact":"x"}')
check "anon create_booking rejected" "$([ "$c" -ge 400 ] && echo 1 || echo 0)" "http=$c"

echo
echo "== $pass passed, $fail failed =="
[ "$fail" = "0" ]
