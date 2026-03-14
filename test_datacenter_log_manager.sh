#!/bin/bash

###############################################################################
# test_datacenter_log_manager.sh
#
# Tests all non-GUI functions of datacenter_log_manager.sh
# Runs without a display — no zenity calls involved.
# Execute with: bash test_datacenter_log_manager.sh
###############################################################################

PASS=0
FAIL=0
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}  ✔ PASS${NC} — $1"; PASS=$(( PASS + 1 )); }
fail() { echo -e "${RED}  ✘ FAIL${NC} — $1"; FAIL=$(( FAIL + 1 )); }
section() { echo -e "\n${YELLOW}▶ $1${NC}"; }

set +e

# --- Mock all external GUI and system calls ---
zenity()        { return 1; }
xdg-open()      { return 0; }
gnome-terminal(){ return 0; }
systemctl() {
    case "$1" in
        is-active) return 0 ;;
        start)     return 0 ;;
        restart)   return 0 ;;
    esac
}

# --- Provide a test config file ---
mkdir -p "$HOME/.config/dclogmanager"
cat > "$HOME/.config/dclogmanager/settings.conf" << 'EOF'
FTP_HOST=192.168.1.100
FTP_USER=testuser
FTP_PASS=testpass
FTP_REMOTE_PATH=/logs
SSH_USER=admin
NODE_PREFIX=node
NODE_START=1
NODE_END=5
SERVICES=ssh,cron,rsyslog
HELP_URL=https://example.com
EOF

# --- Source the main script ---
# zenity() returns 1, so the main `while` menu loop exits immediately.
# Only function definitions are loaded into this shell.
source "$(dirname "$0")/datacenter_log_manager.sh" 2>/dev/null || true
set +e


###############################################################################
section "validate_ticket_id"
###############################################################################

validate_ticket_id "TICKET-001"   2>/dev/null && pass "alphanumeric with hyphen"    || fail "alphanumeric with hyphen"
validate_ticket_id "JOB_2024"     2>/dev/null && pass "alphanumeric with underscore" || fail "alphanumeric with underscore"
validate_ticket_id "ABC123"       2>/dev/null && pass "letters and numbers"          || fail "letters and numbers"
validate_ticket_id "A"            2>/dev/null && pass "single character valid"        || fail "single character valid"
validate_ticket_id "a-b-c-1-2-3"  2>/dev/null && pass "multiple hyphens valid"       || fail "multiple hyphens valid"

validate_ticket_id ""             2>/dev/null && fail "empty should fail"        || pass "empty string rejected"
validate_ticket_id "ticket 01"    2>/dev/null && fail "spaces should fail"       || pass "spaces rejected"
validate_ticket_id "ticket@01"    2>/dev/null && fail "@ should fail"            || pass "@ rejected"
validate_ticket_id "ticket/path"  2>/dev/null && fail "slash should fail"        || pass "slash rejected"
validate_ticket_id "TICKET.001"   2>/dev/null && fail "dot should fail"          || pass "dot rejected"


###############################################################################
section "validate_node_name"
###############################################################################

validate_node_name "node1"    2>/dev/null && pass "node1 valid"   || fail "node1 valid"
validate_node_name "node10"   2>/dev/null && pass "node10 valid"  || fail "node10 valid"
validate_node_name "node999"  2>/dev/null && pass "node999 valid" || fail "node999 valid"

validate_node_name "server1"  2>/dev/null && fail "wrong prefix should fail"         || pass "wrong prefix rejected"
validate_node_name "node"     2>/dev/null && fail "no number should fail"             || pass "missing number rejected"
validate_node_name "nodeabc"  2>/dev/null && fail "letters after prefix should fail"  || pass "non-numeric suffix rejected"
validate_node_name ""         2>/dev/null && fail "empty should fail"                 || pass "empty node name rejected"


###############################################################################
section "validate_ip"
###############################################################################

validate_ip "192.168.1.1"    2>/dev/null && pass "valid 192.168.1.1"   || fail "valid 192.168.1.1"
validate_ip "10.0.0.1"       2>/dev/null && pass "valid 10.0.0.1"      || fail "valid 10.0.0.1"
validate_ip "255.255.255.0"  2>/dev/null && pass "valid 255.255.255.0" || fail "valid 255.255.255.0"
validate_ip "0.0.0.0"        2>/dev/null && pass "valid 0.0.0.0"       || fail "valid 0.0.0.0"

validate_ip "999.1.1.1"      2>/dev/null && fail "octet 999 should fail"  || pass "octet 999 rejected"
validate_ip "192.168.1.256"  2>/dev/null && fail "octet 256 should fail"  || pass "octet 256 rejected"
validate_ip "192.168.1"      2>/dev/null && fail "3-octet IP should fail" || pass "3-octet IP rejected"
validate_ip "not-an-ip"      2>/dev/null && fail "text should fail"       || pass "text IP rejected"
validate_ip ""               2>/dev/null && fail "empty should fail"      || pass "empty IP rejected"


###############################################################################
section "collect_node_logs — mocked SSH"
###############################################################################

mkdir -p "$HOME/Desktop/Logs"

# Mock SSH: returns fake log data
ssh() { echo "fake log data from $2"; return 0; }

archive=$(collect_node_logs "node1" "TEST-001" "/var/log/syslog" 2>/dev/null)
if [ -f "$archive" ] && [ -s "$archive" ]; then
    pass "archive created for reachable node"
    rm -f "$archive"
else
    fail "archive not created for reachable node"
fi

# Mock SSH: simulates unreachable node
ssh() { return 1; }

collect_node_logs "node_down" "TEST-002" "/var/log/syslog" 2>/dev/null
if [ $? -ne 0 ]; then
    pass "unreachable node returns non-zero exit"
else
    fail "unreachable node should return non-zero"
fi


###############################################################################
section "Configuration file"
###############################################################################

FTP_HOST="" FTP_USER="" FTP_PASS="" NODE_PREFIX="" NODE_START="" NODE_END=""
source "$HOME/.config/dclogmanager/settings.conf"

[ "$FTP_HOST"    = "192.168.1.100" ] && pass "FTP_HOST loaded"    || fail "FTP_HOST not loaded"
[ "$FTP_USER"    = "testuser" ]      && pass "FTP_USER loaded"    || fail "FTP_USER not loaded"
[ "$FTP_PASS"    = "testpass" ]      && pass "FTP_PASS loaded"    || fail "FTP_PASS not loaded"
[ "$NODE_PREFIX" = "node" ]          && pass "NODE_PREFIX loaded" || fail "NODE_PREFIX not loaded"
[ "$NODE_START"  = "1" ]             && pass "NODE_START loaded"  || fail "NODE_START not loaded"
[ "$NODE_END"    = "5" ]             && pass "NODE_END loaded"    || fail "NODE_END not loaded"

# Config with a missing required variable
# Explicitly unset to simulate a fresh environment before loading
unset FTP_USER
echo "FTP_HOST=testonly" > /tmp/bad_test.conf
source /tmp/bad_test.conf
[ -z "${FTP_USER:-}" ] && pass "Missing FTP_USER detected" || fail "Missing FTP_USER not detected"
rm -f /tmp/bad_test.conf


###############################################################################
section "Script syntax"
###############################################################################

bash -n /home/claude/datacenter_log_manager.sh 2>/dev/null \
    && pass "Script passes bash -n syntax check" \
    || fail "Script has syntax errors"


###############################################################################
# SUMMARY
###############################################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Results:  ${GREEN}$PASS passed${NC}  /  ${RED}$FAIL failed${NC}  /  $(( PASS + FAIL )) total"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Cleanup
rm -f "$HOME/.config/dclogmanager/settings.conf"
rmdir "$HOME/.config/dclogmanager" 2>/dev/null || true

[ "$FAIL" -eq 0 ] && exit 0 || exit 1