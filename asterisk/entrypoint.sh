#!/bin/sh
set -e

DEVICES_FILE="/app/config/devices.json"
USERS_FILE="/app/config/users.json"
PJSIP_CONF="/etc/asterisk/pjsip.conf"
PJSIP_DEVICES_CONF="/app/config/pjsip_devices.conf"
PJSIP_USERS_CONF="/app/config/pjsip_users.conf"
EXTENSIONS_CONF="/etc/asterisk/extensions.conf"

echo "[ASTERISK] Generating configuration..."

# ============================================================
# Generate base pjsip.conf (global + transport + includes)
# ============================================================

cat > "$PJSIP_CONF" << 'EOF'
;
; Auto-generated PJSIP configuration for Claude Phone
; Device and user extensions are included from the shared config volume
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

# Include device and user configs from shared volume
cat >> "$PJSIP_CONF" << 'EOF'

; Device extensions (Claude AI personalities) — managed by admin panel or CLI
#include /app/config/pjsip_devices.conf

; User extensions (SIP softphones) — managed by admin panel or CLI
#include /app/config/pjsip_users.conf
EOF

echo "[ASTERISK] Base pjsip.conf generated with #include directives"

# ============================================================
# Generate pjsip_devices.conf from devices.json
# ============================================================

if [ -f "$DEVICES_FILE" ]; then
  echo "[ASTERISK] Generating device extensions from $DEVICES_FILE"

  python3 << 'PYGEN'
import json
import os

devices_file = os.environ.get('DEVICES_FILE', '/app/config/devices.json')
output_file = os.environ.get('PJSIP_DEVICES_CONF', '/app/config/pjsip_devices.conf')

with open(devices_file) as f:
    devices = json.load(f)

with open(output_file, 'w') as out:
    out.write("; ============================================================\n")
    out.write("; Voice-app extensions (registered by drachtio)\n")
    out.write("; Auto-generated from devices.json\n")
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
  echo "[ASTERISK] WARNING: $DEVICES_FILE not found, creating default device extension 9000"

  cat > "$PJSIP_DEVICES_CONF" << 'EOF'
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

echo "[ASTERISK] pjsip_devices.conf generated"

# ============================================================
# Generate pjsip_users.conf from users.json or env defaults
# ============================================================

USER_PASSWORD="${USER_EXT_PASSWORD:-changeme}"

# Create initial users.json if it doesn't exist
if [ ! -f "$USERS_FILE" ]; then
  echo "[ASTERISK] Creating initial users.json with default extensions 1001, 1002"
  cat > "$USERS_FILE" << EOF
{
  "1001": { "name": "User 1001", "extension": "1001", "password": "${USER_PASSWORD}" },
  "1002": { "name": "User 1002", "extension": "1002", "password": "${USER_PASSWORD}" }
}
EOF
fi

# Generate pjsip_users.conf from users.json
echo "[ASTERISK] Generating user extensions from $USERS_FILE"

python3 << 'PYGEN'
import json
import os

users_file = os.environ.get('USERS_FILE', '/app/config/users.json')
output_file = os.environ.get('PJSIP_USERS_CONF', '/app/config/pjsip_users.conf')

with open(users_file) as f:
    users = json.load(f)

with open(output_file, 'w') as out:
    out.write("; ============================================================\n")
    out.write("; User phone extensions (for SIP softphones/desk phones)\n")
    out.write("; Auto-generated from users.json\n")
    out.write("; ============================================================\n\n")

    for ext, user in users.items():
        name = user.get('name', 'User ' + ext)
        password = user.get('password', 'changeme')

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
        out.write('username=' + ext + '\n')
        out.write('password=' + password + '\n')
        out.write('\n')

        out.write('[' + ext + ']\n')
        out.write('type=aor\n')
        out.write('max_contacts=1\n')
        out.write('remove_existing=yes\n')
        out.write('qualify_frequency=60\n')
        out.write('\n')

        print('[ASTERISK]   User extension ' + ext + ' (' + name + ') configured')

print('[ASTERISK]   ' + str(len(users)) + ' user extension(s) generated')
PYGEN

echo "[ASTERISK] pjsip_users.conf generated"

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
# Generate manager.conf (AMI) if enabled
# ============================================================

MANAGER_CONF="/etc/asterisk/manager.conf"

if [ "$AMI_ENABLED" = "true" ] && [ -n "$AMI_SECRET" ]; then
  echo "[ASTERISK] AMI enabled, generating manager.conf..."

  cat > "$MANAGER_CONF" << EOF
;
; Auto-generated AMI configuration for Claude Phone admin panel
;

[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1

[admin]
secret = ${AMI_SECRET}
read = system,call,agent,user,config
write = system,command,config
EOF

  echo "[ASTERISK] manager.conf generated (AMI on 127.0.0.1:5038, read+write)"
else
  # Disable AMI
  cat > "$MANAGER_CONF" << 'EOF'
[general]
enabled = no
EOF
  echo "[ASTERISK] AMI disabled"
fi

# ============================================================
# Fix permissions and start Asterisk
# ============================================================

chown -R asterisk:asterisk /etc/asterisk/ 2>/dev/null || true

echo "[ASTERISK] Starting Asterisk PBX..."
echo "[ASTERISK] SIP port: ${ASTERISK_SIP_PORT:-5060}"
echo "[ASTERISK] External IP: ${EXTERNAL_IP:-not set}"

exec /usr/sbin/asterisk -vvvdddf -T -W -U asterisk -p
