# Production Deployment Guide

Guide for deploying Claude Phone in production environments.

## Architecture Overview

Claude Phone consists of four Docker containers and an optional API server:

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Containers                         │
│  ┌──────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │ Asterisk │  │  drachtio   │  │ freeswitch  │           │
│  │ (PBX)    │  │  (SIP)      │  │  (Media)    │           │
│  │ Port 5060│  │  Port 5070  │  │ RTP 30000+  │           │
│  └──────────┘  └─────────────┘  └─────────────┘           │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                   voice-app                          │   │
│  │                 (Node.js app)                        │   │
│  │                  Port 3000                           │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │     claude-api-server         │
              │     (Claude Code wrapper)     │
              │     Port 3333                 │
              └───────────────────────────────┘
```

## Network Requirements

### Ports

| Port | Protocol | Service | Direction |
|------|----------|---------|-----------|
| 5060 | UDP/TCP | Asterisk PBX SIP | Inbound (from SIP phones) |
| 5070 | UDP/TCP | drachtio SIP signaling | Internal (from Asterisk) |
| 3000 | TCP | Voice app HTTP API | Inbound (optional) |
| 3333 | TCP | Claude API server | Internal |
| 30000-30100 | UDP | RTP audio (FreeSWITCH) | Bidirectional |

### Firewall Rules

For voice to work correctly, you must allow:

```bash
# SIP signaling (Asterisk PBX - for SIP phones to connect)
sudo ufw allow 5060/udp
sudo ufw allow 5060/tcp

# RTP audio (critical for audio to work)
sudo ufw allow 30000:30100/udp

# Voice app API (if exposing externally)
sudo ufw allow 3000/tcp
```

### NAT Considerations

The `EXTERNAL_IP` setting must be your server's LAN IP that can receive RTP packets. On NAT networks:

- Use your server's private IP (e.g., 192.168.1.50)
- Ensure RTP ports are forwarded if behind NAT
- Asterisk handles NAT traversal for SIP; RTP is direct

## Docker Configuration

The CLI generates `~/.claude-phone/docker-compose.yml` automatically. Key settings:

### Network Mode

All containers use `network_mode: host` for RTP to work correctly:

```yaml
asterisk:
  network_mode: host

voice-app:
  network_mode: host
```

This allows FreeSWITCH to bind RTP ports directly.

### Port Assignment

- **Asterisk**: port 5060 (standard SIP port for phones/softphones)
- **drachtio**: port 5070 (avoids conflict with Asterisk)
- **FreeSWITCH**: port 5080 (internal SIP), 30000-30100 (RTP)

### RTP Port Range

FreeSWITCH uses ports 30000-30100 by default:

```yaml
freeswitch:
  command: >
    --rtp-range-start 30000
    --rtp-range-end 30100
```

### Environment Variables

Key environment variables in the generated `.env`:

| Variable | Purpose |
|----------|---------|
| `EXTERNAL_IP` | Server LAN IP for RTP routing |
| `CLAUDE_API_URL` | URL to claude-api-server |
| `ELEVENLABS_API_KEY` | TTS API key |
| `OPENAI_API_KEY` | Whisper STT API key |
| `SIP_DOMAIN` | SIP domain for headers |
| `SIP_REGISTRAR` | Asterisk registrar address (127.0.0.1) |
| `USER_EXT_PASSWORD` | Password for user phone extensions |

## Asterisk Auto-Configuration

Asterisk generates its PJSIP config automatically from `voice-app/config/devices.json` at container startup. This means:

- Device extensions (9000, 9002, etc.) are auto-created with matching credentials
- User phone extensions (1001, 1002) are created for SIP softphones
- No manual Asterisk configuration is needed

To add more devices, update `devices.json` and restart:

```bash
claude-phone stop
claude-phone start
```

## Split Deployment

### Voice Server (Pi/Linux)

Requirements:
- Docker and Docker Compose
- Network access to API server
- Static IP recommended

The voice server runs Docker containers (including Asterisk) and connects to a remote API server:

```bash
claude-phone setup    # Select "Voice Server"
claude-phone start
```

### API Server (Mac/Linux with Claude Code)

Requirements:
- Node.js 18+
- Claude Code CLI installed and authenticated
- Network accessible from voice server

```bash
claude-phone api-server --port 3333
```

For persistent operation, use a process manager:

```bash
# Using pm2
npm install -g pm2
pm2 start "claude-phone api-server" --name claude-api

# Using systemd (Linux)
# Create /etc/systemd/system/claude-api.service
```

## Monitoring

### Health Checks

```bash
# Overall status
claude-phone status

# Comprehensive diagnostics
claude-phone doctor

# Container health
docker ps
docker compose logs -f
```

### Log Locations

```bash
# All logs
claude-phone logs

# Specific service
claude-phone logs voice-app
claude-phone logs drachtio
claude-phone logs freeswitch
claude-phone logs asterisk
```

### Key Log Messages

**Healthy startup:**
```
[ASTERISK] Starting Asterisk PBX...
[ASTERISK] 2 voice-app extension(s) generated
[SIP] Connected to drachtio
[SIP] Registered extension 9000 with Asterisk
[HTTP] Server listening on port 3000
```

**Common errors:**
```
# Wrong external IP
AUDIO RTP REPORTS ERROR: [Bind Error]

# SIP registration failed
Registration failed: 401 Unauthorized

# API server unreachable
Error connecting to Claude API
```

## Security Considerations

### API Keys

- Config file has restricted permissions (chmod 600)
- Never commit `~/.claude-phone/config.json` to version control
- Use environment variables in CI/CD pipelines

### Network Security

- Voice app API (port 3000) should not be publicly exposed without authentication
- Claude API server (port 3333) should only be accessible from voice server
- Consider VPN for split deployments across networks

### SIP Security

- Change default passwords for SIP extensions (USER_EXT_PASSWORD)
- Use strong passwords in devices.json for voice-app extensions
- Monitor for unusual call patterns
- Consider enabling Asterisk's fail2ban integration for brute-force protection

## Troubleshooting

### No Audio

1. Verify `EXTERNAL_IP` matches your server's LAN IP
2. Check RTP ports (30000-30100) are open
3. Ensure `network_mode: host` is set for all containers
4. Check FreeSWITCH logs for RTP errors

### SIP Registration Fails

1. Verify device credentials in `devices.json` match Asterisk config
2. Check Asterisk is running: `docker ps | grep asterisk`
3. Ensure drachtio port (5070) doesn't conflict with other services
4. Check Asterisk logs: `docker logs asterisk`

### API Server Connection Issues

1. Verify API server is running: `curl http://API_IP:3333/health`
2. Check firewall allows port 3333
3. Verify URL in voice server config matches API server

## Backup and Recovery

### Configuration Backup

```bash
claude-phone backup
```

Backups are stored in `~/.claude-phone/backups/` with timestamps.

### Recovery

```bash
claude-phone restore
```

Interactive selection of available backups.

### Manual Backup

```bash
cp -r ~/.claude-phone ~/.claude-phone.backup
```

## Updating

```bash
claude-phone update
```

This pulls the latest code and restarts services. Configuration is preserved.

## Uninstalling

```bash
claude-phone uninstall
```

This removes:
- Docker containers and images
- CLI installation
- Optionally: configuration files
