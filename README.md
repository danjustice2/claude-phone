<p align="center">
  <img src="assets/logo.png" alt="Claude Phone" width="200">
</p>

# Claude Phone

Voice interface for Claude Code via SIP/Asterisk. Call your AI, and your AI can call you.

> Forked from [theNetworkChuck/claude-phone](https://github.com/theNetworkChuck/claude-phone) and adapted to use [Asterisk](https://www.asterisk.org/) (open-source PBX) instead of 3CX.

## What is this?

Claude Phone gives your Claude Code installation a phone number. You can:

- **Inbound**: Call an extension and talk to Claude - run commands, check status, ask questions
- **Outbound**: Your server can call YOU with alerts, then have a conversation about what to do

## What changed from the original?

This fork replaces the proprietary 3CX cloud PBX with **Asterisk**, a free and open-source PBX that runs locally in Docker alongside the other services. No cloud PBX account needed.

| Feature | Original (3CX) | This Fork (Asterisk) |
|---------|----------------|---------------------|
| PBX | 3CX Cloud (proprietary) | Asterisk (open-source, self-hosted) |
| Account required | 3CX cloud account | None - runs locally |
| SIP extensions | Created in 3CX admin panel | Auto-generated from devices.json |
| Configuration | Manual 3CX setup | Automatic via Docker |

## Prerequisites

| Requirement | Where to Get It | Notes |
|-------------|-----------------|-------|
| **Docker & Docker Compose** | [docker.com](https://docs.docker.com/get-docker/) | For running all services |
| **ElevenLabs API Key** | [elevenlabs.io](https://elevenlabs.io/) | For text-to-speech |
| **OpenAI API Key** | [platform.openai.com](https://platform.openai.com/) | For Whisper speech-to-text |
| **Claude Code CLI** | [claude.ai/code](https://claude.ai/code) | Requires Claude Max subscription |
| **SIP Softphone** | [Ooh la SIP](https://ooh.la/) / [Ooh la SIP - iOS](https://apps.apple.com/app/ooh-la-sip/id6740046500) / [Ooh la SIP - Android](https://play.google.com/store/apps/details?id=la.ooh.ooh_la_sip) / [Ooh la SIP - Desktop](https://ooh.la/) | To make calls to the AI |

## Platform Support

| Platform | Status |
|----------|--------|
| **macOS** | Fully supported |
| **Linux** | Fully supported (including Raspberry Pi) |
| **Windows** | Not supported (may work with WSL) |

## Quick Start

### 1. Install

```bash
curl -sSL https://raw.githubusercontent.com/danjustice2/claude-phone/main/install.sh | bash
```

The installer will:
- Check for Node.js 18+, Docker, and git (offers to install if missing)
- Clone the repository to `~/.claude-phone-cli`
- Install dependencies
- Create the `claude-phone` command

### 2. Setup

```bash
claude-phone setup
```

The setup wizard asks what you're installing:

| Type | Use Case | What It Configures |
|------|----------|-------------------|
| **Voice Server** | Pi or dedicated voice box | Docker containers, connects to remote API server |
| **API Server** | Mac/Linux with Claude Code | Just the Claude API wrapper |
| **Both** | All-in-one single machine | Everything on one box |

### 3. Configure your devices

Edit `voice-app/config/devices.json` with your extensions. Asterisk auto-generates matching SIP credentials from this file:

```json
{
  "9000": {
    "name": "Assistant",
    "extension": "9000",
    "authId": "9000",
    "password": "claude9000",
    "voiceId": "your-elevenlabs-voice-id",
    "prompt": "You are a helpful AI assistant. Keep voice responses under 40 words."
  }
}
```

### 4. Start

```bash
claude-phone start
```

### 5. Connect your SIP phone

Register a SIP softphone with Asterisk using these settings:

| Setting | Value |
|---------|-------|
| Server | Your server's LAN IP |
| Port | 5060 |
| Username | 1001 |
| Password | changeme (or your USER_EXT_PASSWORD) |

Then dial **9000** to talk to Claude!

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SIP Phone / Softphone                                       │
│      │                                                       │
│      ↓ Dial extension 9000                                  │
│  ┌─────────────────────────────────────────────────┐       │
│  │     Asterisk PBX (Docker)                        │       │
│  │     Open-source, self-hosted                     │       │
│  └──────┬──────────────────────────────────────────┘       │
│         │ SIP (port 5060 → 5070)                            │
│         ↓                                                    │
│  ┌─────────────────────────────────────────────────┐       │
│  │           voice-app (Docker)                     │       │
│  │  ┌─────────────────────────────────────────┐   │       │
│  │  │ drachtio  │  FreeSWITCH  │  Node.js     │   │       │
│  │  │ (SIP)     │  (Media)     │  (Logic)     │   │       │
│  │  └─────────────────────────────────────────┘   │       │
│  └────────────────────┬────────────────────────────┘       │
│                       │ HTTP                                │
│                       ↓                                      │
│  ┌─────────────────────────────────────────────────┐       │
│  │   claude-api-server                              │       │
│  │   Wraps Claude Code CLI with session management │       │
│  └─────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Modes

### All-in-One (Single Machine)

Best for: Mac or Linux server that's always on and has Claude Code installed.

```
┌─────────────────────────────────────────────────────────────┐
│  SIP Softphone                                               │
│      │                                                       │
│      ↓ Dial extension 9000                                  │
│  ┌─────────────────────────────────────────────┐           │
│  │     Single Server (Mac/Linux)                │           │
│  │  ┌──────────┐                               │           │
│  │  │ Asterisk │ (Docker)                      │           │
│  │  └────┬─────┘                               │           │
│  │       ↓                                      │           │
│  │  ┌───────────┐    ┌───────────────────┐    │           │
│  │  │ voice-app │ ←→ │ claude-api-server │    │           │
│  │  │ (Docker)  │    │ (Claude Code CLI) │    │           │
│  │  └───────────┘    └───────────────────┘    │           │
│  └─────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

**Setup:**
```bash
claude-phone setup    # Select "Both"
claude-phone start    # Launches Docker + API server
```

### Split Mode (Pi + API Server)

Best for: Dedicated Pi for voice services, Claude running on your main machine.

```
┌─────────────────────────────────────────────────────────────┐
│  SIP Softphone                                               │
│      │                                                       │
│      ↓ Dial extension 9000                                  │
│  ┌─────────────┐         ┌─────────────────────┐           │
│  │ Raspberry Pi │   ←→   │ Mac/Linux with      │           │
│  │ (Asterisk + │  HTTP   │ Claude Code CLI     │           │
│  │  voice-app) │         │ (claude-api-server) │           │
│  └─────────────┘         └─────────────────────┘           │
└─────────────────────────────────────────────────────────────┘
```

**On your Pi (Voice Server):**
```bash
claude-phone setup    # Select "Voice Server", enter API server IP when prompted
claude-phone start    # Launches Docker containers
```

**On your Mac/Linux (API Server):**
```bash
claude-phone api-server    # Starts Claude API wrapper on port 3333
```

Note: On the API server machine, you don't need to run `claude-phone setup` first - the `api-server` command works standalone.

## CLI Commands

| Command | Description |
|---------|-------------|
| `claude-phone setup` | Interactive configuration wizard |
| `claude-phone start` | Start services based on installation type |
| `claude-phone stop` | Stop all services |
| `claude-phone status` | Show service status |
| `claude-phone doctor` | Health check for dependencies and services |
| `claude-phone api-server [--port N]` | Start API server standalone (default: 3333) |
| `claude-phone device add` | Add a new device/extension |
| `claude-phone device list` | List configured devices |
| `claude-phone device remove <name>` | Remove a device |
| `claude-phone logs [service]` | Tail logs (voice-app, drachtio, freeswitch, asterisk) |
| `claude-phone config show` | Display configuration (secrets redacted) |
| `claude-phone config path` | Show config file location |
| `claude-phone config reset` | Reset configuration |
| `claude-phone backup` | Create configuration backup |
| `claude-phone restore` | Restore from backup |
| `claude-phone update` | Update Claude Phone |
| `claude-phone uninstall` | Complete removal |

## Device Personalities

Each SIP extension can have its own identity with a unique name, voice, and personality prompt:

```bash
claude-phone device add
```

Example devices:
- **Assistant** (ext 9000) - General assistant
- **ServerBot** (ext 9002) - Storage monitoring bot

## Asterisk Configuration

Asterisk auto-generates its PJSIP configuration from `voice-app/config/devices.json` on startup. It also creates default user phone extensions (1001, 1002) for SIP softphones.

### User Phone Extensions

| Extension | Username | Password | Notes |
|-----------|----------|----------|-------|
| 1001 | 1001 | changeme | Set USER_EXT_PASSWORD in .env |
| 1002 | 1002 | changeme | Set USER_EXT_PASSWORD in .env |

### Adding a SIP Trunk (for PSTN)

To make/receive calls from real phone numbers, add a SIP trunk provider (e.g., Twilio, VoIP.ms) to `asterisk/entrypoint.sh` or mount a custom `pjsip_trunk.conf`.

## API Endpoints

The voice-app exposes these endpoints on port 3000:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/outbound-call` | Initiate an outbound call |
| GET | `/api/call/:callId` | Get call status |
| GET | `/api/calls` | List active calls |
| POST | `/api/query` | Query a device programmatically |
| GET | `/api/devices` | List configured devices |

See [Outbound API Reference](voice-app/README-OUTBOUND.md) for details.

## Troubleshooting

### Quick Diagnostics

```bash
claude-phone doctor    # Automated health checks
claude-phone status    # Service status
claude-phone logs      # View logs
```

### Common Issues

| Problem | Likely Cause | Solution |
|---------|--------------|----------|
| Calls connect but no audio | Wrong external IP | Re-run `claude-phone setup`, verify LAN IP |
| Extension not registering | Asterisk not running | Check `docker ps \| grep asterisk` |
| "Sorry, something went wrong" | API server unreachable | Check `claude-phone status` |
| Port conflict on startup | Another service using 5060 | Stop conflicting service or change ASTERISK_SIP_PORT |

See [Troubleshooting Guide](docs/TROUBLESHOOTING.md) for more.

## Configuration

Configuration is stored in `~/.claude-phone/config.json` with restricted permissions (chmod 600).

```bash
claude-phone config show    # View config (secrets redacted)
claude-phone config path    # Show file location
```

## Development

```bash
# Run tests
npm test

# Lint
npm run lint
npm run lint:fix
```

## Documentation

- [CLI Reference](cli/README.md) - Detailed CLI documentation
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [Outbound API](voice-app/README-OUTBOUND.md) - Outbound calling API reference
- [Deployment](voice-app/DEPLOYMENT.md) - Production deployment guide

## License

MIT
