# Getting Started with Claude Phone

This guide walks you through setting up Claude Phone from scratch on a single machine. By the end, you'll be able to pick up your phone and talk to Claude.

## Before You Start

You'll need accounts and software ready before running the installer. Gather these first:

### Accounts & API Keys

| What | Where to Get It | What You Need |
|------|----------------|---------------|
| **ElevenLabs** | [elevenlabs.io](https://elevenlabs.io/) | API key + a Voice ID |
| **OpenAI** | [platform.openai.com](https://platform.openai.com/) | API key (for Whisper speech-to-text) |
| **Claude Code CLI** | [claude.ai/code](https://claude.ai/code) | Requires a Claude Max subscription |

**Finding your ElevenLabs API key:**
1. Sign in at [elevenlabs.io](https://elevenlabs.io/)
2. Click your profile icon (bottom-left) → **API Keys**
3. Copy your API key

**Finding your ElevenLabs Voice ID:**
1. Go to **Voices** in the sidebar
2. Click a voice you like (or create one)
3. Click the **ID** button next to the voice name to copy it

**Finding your OpenAI API key:**
1. Sign in at [platform.openai.com](https://platform.openai.com/)
2. Go to **API Keys** in the left sidebar (or visit [platform.openai.com/api-keys](https://platform.openai.com/api-keys))
3. Click **Create new secret key**, copy it immediately (you won't see it again)

### Software

| What | How to Check | Install If Missing |
|------|-------------|-------------------|
| **Node.js 18+** | `node --version` | [nodejs.org](https://nodejs.org/) |
| **Docker & Docker Compose** | `docker --version` | [docker.com](https://docs.docker.com/get-docker/) |
| **Git** | `git --version` | Usually pre-installed; [git-scm.com](https://git-scm.com/) if not |

Docker Desktop must be **running** (not just installed). On Mac, open Docker Desktop from Applications. On Linux, make sure the Docker daemon is started (`sudo systemctl start docker`).

### Platform

- **macOS** or **Linux** (including Raspberry Pi)
- **Windows**: Not directly supported, but may work under WSL2

### SIP Softphone

You need a SIP softphone app to make calls. Install one of these now — you'll configure it in Step 4:

| App | Platforms | Link |
|-----|-----------|------|
| **Linphone** (recommended) | iOS, Android, Windows, Mac, Linux | [linphone.org](https://www.linphone.org/) |
| **MicroSIP** | Windows | [microsip.org](https://www.microsip.org/) |

---

## Step 1: Install Claude Phone

Run this in your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/danjustice2/claude-phone/main/install.sh | bash
```

The installer will:
- Check for Node.js 18+, Docker, and Git (offers to install if missing)
- Clone the repository to `~/.claude-phone-cli`
- Install dependencies
- Create the `claude-phone` command

When it finishes, you should see a success message. Verify the command works:

```bash
claude-phone --version
```

---

## Step 2: Run Setup

```bash
claude-phone setup
```

The setup wizard will ask you a series of questions. Here's what to expect at each prompt:

### Installation Type

```
? What are you installing?
  Voice Server (Pi/Linux) - Handles calls, needs Docker
  API Server - Claude Code wrapper, minimal setup
❯ Both (all-in-one) - Full stack on one machine
```

**Choose "Both"** if you're running everything on one machine (most common for getting started).

### API Keys

```
? ElevenLabs API key: ****
```
Paste the API key you copied from the ElevenLabs dashboard. The wizard validates it against the ElevenLabs API.

```
? ElevenLabs default voice ID: ****
```
Paste the Voice ID you copied earlier. The wizard will confirm the voice name if valid.

```
? OpenAI API key (for Whisper STT): ****
```
Paste your OpenAI API key. The wizard validates this too.

### SIP Configuration

```
? SIP domain (used in SIP headers): claude-phone.local
? Asterisk registrar IP (127.0.0.1 for local Docker): 127.0.0.1
```

**Press Enter for both** to accept the defaults. These control internal SIP routing and the defaults work for a single-machine setup.

### Device Configuration

A "device" is a Claude AI personality that answers on its own extension. This is **not** your phone — it's Claude's identity. Your phone will register separately as extension 1001 (covered in Step 4).

```
? Device name (e.g., Morpheus): Morpheus
```
A friendly name for this AI assistant. Call it whatever you like.

```
? SIP extension number (e.g., 9000): 9000
```
The extension number for this AI device — the number you'll **dial** to reach Claude. **9000** is the default.

```
? SIP auth ID: 9000
```
Used for internal SIP authentication between Docker containers. **Use the same value as the extension** (e.g., `9000`).

```
? SIP password: ****
```
A password for this device's internal SIP registration. Pick something (e.g., `claude9000`). This is only used between Docker containers — not for your phone.

```
? ElevenLabs voice ID: ****
```
Pre-filled from the default you entered earlier. Press Enter to keep it.

```
? System prompt: You are a helpful AI assistant. Keep voice responses under 40 words.
```
The personality prompt for this device. The default works well. Keep it short — this is voice, not chat.

### Server Configuration

```
? Server LAN IP (for RTP audio): 192.168.1.100
```
This is your machine's IP address on your local network. The wizard auto-detects it. **Make sure this is correct** — if it's wrong, you'll get calls with no audio.

How to find your LAN IP if needed:
- **Mac**: `ipconfig getifaddr en0` (or `en1` for Wi-Fi)
- **Linux**: `hostname -I | awk '{print $1}'`

```
? Claude API server port: 3333
? Voice app HTTP port: 3000
```

**Press Enter for both** to accept the defaults.

### Setup Complete

You should see:

```
✓ Configuration saved
✓ Setup complete!

Next steps:
  1. Run "claude-phone start" to launch all services
  2. Call extension 9000 from your phone
  3. Start talking to Claude!
```

---

## Step 3: Start Services

```bash
claude-phone start
```

This launches Docker containers (Asterisk PBX, voice-app with drachtio/FreeSWITCH) and the Claude API server. It takes a minute the first time as Docker images are pulled.

Configuration files are generated in `~/.claude-phone/`:
- `.env` — environment variables (API keys, passwords, ports)
- `docker-compose.yml` — container orchestration
- `config.json` — setup wizard settings

### Verify Everything is Running

```bash
claude-phone status
```

You should see all services showing as running. You can also check Docker directly:

```bash
docker ps
```

You should see containers for `asterisk` and `voice-app` (which includes drachtio and FreeSWITCH).

If something isn't running, check the logs:

```bash
claude-phone logs          # All logs
claude-phone logs asterisk # Just Asterisk
```

---

## How Extensions Work

Before setting up your phone, it helps to understand that there are **two types of extensions** in Claude Phone:

| Type | Example | Purpose | Configured In |
|------|---------|---------|---------------|
| **User phone extensions** | 1001, 1002 | Your SIP softphone registers as one of these | Auto-created by Asterisk |
| **Device extensions** | 9000 | Claude AI personality that answers calls | `devices.json` (created during setup) |

You register your softphone as **1001**, then dial **9000** to talk to Claude. Think of 1001 as your phone's identity, and 9000 as Claude's phone number.

## Step 4: Set Up Your SIP Phone

Configure your softphone to register with Asterisk using these settings:

| Setting | Value |
|---------|-------|
| **Server / Domain** | Your machine's LAN IP (e.g., `192.168.1.100`) |
| **Port** | `5060` |
| **Transport** | UDP |
| **Username** | `1001` |
| **Password** | `changeme` |

The password comes from `USER_EXT_PASSWORD` in your `.env` file (generated by `claude-phone start`). The default is `changeme`. To change it, edit the `.env` file in your claude-phone directory and restart with `claude-phone stop && claude-phone start`.

### Linphone (Recommended)

1. Download from [linphone.org](https://www.linphone.org/) or your device's app store:
   - [iOS App Store](https://apps.apple.com/us/app/linphone/id360065638)
   - [Google Play](https://play.google.com/store/apps/details?id=org.linphone)
   - [Mac](https://download.linphone.org/releases/macosx/latest_app) / [Windows](https://download.linphone.org/releases/windows/latest_app_win64) / [Linux](https://download.linphone.org/releases/linux/latest_app)
2. Open Linphone, go to **Assistant** (or **Use SIP Account** on mobile)
3. Choose **Use SIP Account** (or **I already have a SIP account**)
4. Enter:
   - **Username**: `1001`
   - **SIP Domain**: your machine's LAN IP (e.g., `192.168.1.100`)
   - **Password**: `changeme`
   - **Transport**: UDP
5. Tap **Log in** / **Connect**
6. The status should show a green dot or "Connected" — this means your phone registered with Asterisk

### MicroSIP (Windows)

1. Download from [microsip.org](https://www.microsip.org/)
2. Go to **Menu** → **Add Account**
3. Enter:
   - **Account Name**: Claude Phone
   - **SIP Server**: your machine's LAN IP (e.g., `192.168.1.100`)
   - **SIP Proxy**: (leave empty)
   - **Username**: `1001`
   - **Domain**: your machine's LAN IP
   - **Password**: `changeme`
4. Click **Save**
5. The status bar should show "Online"

---

## Step 5: Call Claude

1. In your softphone, dial **9000** and press call
2. You should hear a brief pause while the connection is established
3. Start talking — Claude will respond with voice
4. Hang up when you're done

Each call gets its own Claude session, so you can have a multi-turn conversation within a single call.

---

## Optional: Admin Panel

If you enabled the web admin panel during setup, you can view Asterisk status at:

```
http://YOUR_LAN_IP:8080
```

The dashboard shows:
- Registered SIP endpoints (online/offline)
- Active calls and channels
- Configured Claude devices
- Asterisk system health

This is read-only — use the `claude-phone` CLI to make changes. To enable it later, re-run `claude-phone setup` and answer yes to "Enable web admin panel?".

---

## Troubleshooting

### Call connects but no audio

Your `EXTERNAL_IP` / Server LAN IP is probably wrong. This is the most common issue.

1. Find your actual LAN IP (see [Step 2](#server-configuration))
2. Re-run `claude-phone setup` and correct the IP
3. Restart with `claude-phone stop && claude-phone start`

### Phone won't register / "Registration failed"

- Make sure the SIP server field is your machine's **LAN IP**, not `localhost` or `127.0.0.1` (your phone is a separate device on the network)
- Verify Asterisk is running: `docker ps | grep asterisk`
- Check Asterisk logs: `claude-phone logs asterisk`
- Make sure port 5060/UDP isn't blocked by a firewall
- Confirm you're using username `1001` (not `9000` — that's the Claude device extension)

### Call is rejected / doesn't ring

- Check Asterisk knows about extension 9000: `claude-phone logs asterisk`
- Make sure voice-app is running: `claude-phone status`
- Verify the device is configured: `claude-phone device list`

### "Sorry, something went wrong" during a call

This usually means the Claude API server is unreachable or crashed:

1. Check status: `claude-phone status`
2. Check API server logs: `claude-phone logs`
3. Make sure Claude Code CLI is installed and working: `claude --version`
4. Test the API server directly: `curl http://localhost:3333/health`

### General debugging

```bash
claude-phone doctor   # Automated health checks
claude-phone status   # Service status overview
claude-phone logs     # Tail all logs (Ctrl+C to stop)
```

For more issues, see the full [Troubleshooting Guide](TROUBLESHOOTING.md).
