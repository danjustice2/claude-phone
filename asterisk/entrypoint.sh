#!/bin/sh
set -e

DEVICES_FILE="/app/config/devices.json"
PJSIP_CONF="/etc/asterisk/pjsip.conf"
EXTENSIONS_CONF="/etc/asterisk/extensions.conf"

echo "[ASTERISK] Generating configuration..."

# ============================================================
# Generate pjsip.conf
# ============================================================

cat > "$PJSIP_CONF" << 'EOF'
;
; Auto-generated PJSIP configuration for Claude Phone
; This file is regenerated on container start from devices.json
;

[global]
type=global
user_agent=Claude-Phone-PBX/1.0

EOF

# Transport section with optional external IP
cat >> "$PJSIP_CONF" << EOF
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:${ASTERISK_SIP_PORT:-5060}
EOF

if [ -n "$EXTERNAL_IP" ]; then
  cat >> "$PJSIP_CONF" << EOF
external_media_address=${EXTERNAL_IP}
external_signaling_address=${EXTERNAL_IP}
EOF
fi

echo "" >> "$PJSIP_CONF"

# Generate voice-app extensions from devices.json
if [ -f "$DEVICES_FILE" ]; then
  echo "[ASTERISK] Generating extensions from $DEVICES_FILE"

  python3 << 'PYGEN'
import json
import os

devices_file = os.environ.get('DEVICES_FILE', '/app/config/devices.json')
pjsip_conf = os.environ.get('PJSIP_CONF', '/etc/asterisk/pjsip.conf')

with open(devices_file) as f:
    devices = json.load(f)

with open(pjsip_conf, 'a') as out:
    out.write("; ============================================================\n")
    out.write("; Voice-app extensions (registered by drachtio)\n")
    out.write("; ============================================================\n\n")

    for ext, dev in devices.items():
        auth_id = dev.get('authId', ext)
        password = dev.get('password', 'changeme')
        name = dev.get('name', 'Extension ' + ext)

        out.write('; ' + name + '\n')
        out.write('[' + ext + ']\n')
        out.write('type=endpoint\n')
        out.write('context=claude-phone\n')
        out.write('disallow=all\n')
        out.write('allow=ulaw\n')
        out.write('allow=alaw\n')
        out.write('auth=' + ext + '-auth\n')
        out.write('aors=' + ext + '\n')
        out.write('direct_media=no\n')
        out.write('\n')

        out.write('[' + ext + '-auth]\n')
        out.write('type=auth\n')
        out.write('auth_type=userpass\n')
        out.write('username=' + auth_id + '\n')
        out.write('password=' + password + '\n')
        out.write('\n')

        out.write('[' + ext + ']\n')
        out.write('type=aor\n')
        out.write('max_contacts=1\n')
        out.write('remove_existing=yes\n')
        out.write('qualify_frequency=60\n')
        out.write('\n')

        print('[ASTERISK]   Extension ' + ext + ' (' + name + ') configured')

print('[ASTERISK]   ' + str(len(devices)) + ' voice-app extension(s) generated')
PYGEN
else
  echo "[ASTERISK] WARNING: $DEVICES_FILE not found, creating default extension 9000"

  cat >> "$PJSIP_CONF" << 'EOF'
; ============================================================
; Default voice-app extension (no devices.json found)
; ============================================================

; Default Claude AI Assistant
[9000]
type=endpoint
context=claude-phone
disallow=all
allow=ulaw
allow=alaw
auth=9000-auth
aors=9000
direct_media=no

[9000-auth]
type=auth
auth_type=userpass
username=9000
password=claude9000

[9000]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

EOF
fi

# Generate user phone extensions (for SIP softphones to register)
USER_PASSWORD="${USER_EXT_PASSWORD:-changeme}"

cat >> "$PJSIP_CONF" << EOF
; ============================================================
; User phone extensions (for SIP softphones/desk phones)
; Register your SIP phone with these credentials
; ============================================================

; User Extension 1001
[1001]
type=endpoint
context=claude-phone
disallow=all
allow=ulaw
allow=alaw
auth=1001-auth
aors=1001
direct_media=no

[1001-auth]
type=auth
auth_type=userpass
username=1001
password=${USER_PASSWORD}

[1001]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

; User Extension 1002
[1002]
type=endpoint
context=claude-phone
disallow=all
allow=ulaw
allow=alaw
auth=1002-auth
aors=1002
direct_media=no

[1002-auth]
type=auth
auth_type=userpass
username=1002
password=${USER_PASSWORD}

[1002]
type=aor
max_contacts=1
remove_existing=yes
qualify_frequency=60

EOF

echo "[ASTERISK] pjsip.conf generated"

# ============================================================
# Generate extensions.conf (dialplan)
# ============================================================

cat > "$EXTENSIONS_CONF" << 'EOF'
;
; Auto-generated dialplan for Claude Phone
;

[general]

[globals]

[claude-phone]
; Route calls to Claude AI extensions (9XXX range)
exten => _9XXX,1,NoOp(Calling Claude AI extension ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN},60)
 same => n,Hangup()

; Route calls between user phone extensions (1XXX range)
exten => _1XXX,1,NoOp(Calling user extension ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN},30)
 same => n,Hangup()

; Outbound calls via SIP trunk (if configured)
; Prefix with 9 for external calls (e.g., 9+15551234567)
exten => _9.,1,NoOp(Outbound call to ${EXTEN:1})
 same => n,Set(CALLERID(num)=${CALLERID(num)})
 same => n,Dial(PJSIP/${EXTEN:1}@trunk,60)
 same => n,Hangup()
EOF

echo "[ASTERISK] extensions.conf generated"

# ============================================================
# Fix permissions and start Asterisk
# ============================================================

chown -R asterisk:asterisk /etc/asterisk/ 2>/dev/null || true

echo "[ASTERISK] Starting Asterisk PBX..."
echo "[ASTERISK] SIP port: ${ASTERISK_SIP_PORT:-5060}"
echo "[ASTERISK] External IP: ${EXTERNAL_IP:-not set}"

exec /usr/sbin/asterisk -vvvdddf -T -W -U asterisk -p
