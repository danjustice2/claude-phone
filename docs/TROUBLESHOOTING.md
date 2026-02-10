# Troubleshooting Guide

Common issues and solutions for Claude Phone (Asterisk edition).

## Quick Diagnostics

Start here for most problems:

```bash
claude-phone doctor   # Automated health checks
claude-phone status   # Service status overview
claude-phone logs     # View recent logs
```

## Setup Issues

### "API key validation failed"

**Symptom:** Setup fails when validating ElevenLabs or OpenAI key.

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Key is incorrect | Double-check you copied the full key |
| No billing enabled | Add payment method to your account |
| Account suspended | Check account status on provider dashboard |
| Network issue | Check internet connectivity |

**For OpenAI specifically:**
- New accounts need billing enabled before API works
- Free tier credits expire after 3 months
- Check [platform.openai.com/account/billing](https://platform.openai.com/account/billing)

**For ElevenLabs:**
- Free tier has limited characters/month
- Check [elevenlabs.io/subscription](https://elevenlabs.io/subscription)

### "Docker not found" or "Docker not running"

**Symptom:** Prerequisite check fails for Docker.

**Solutions:**

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker
# Then launch Docker Desktop from Applications
```

**Linux (Debian/Ubuntu):**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in
```

**Raspberry Pi:**
```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker pi
# Reboot the Pi
```

### Asterisk container fails to start

**Symptom:** `docker ps` shows asterisk container exiting or restarting.

**Solutions:**
1. Check Asterisk logs: `docker logs asterisk`
2. Verify `devices.json` is valid JSON: `python3 -m json.tool voice-app/config/devices.json`
3. Ensure port 5060 isn't already in use: `ss -tulnp | grep 5060`
4. Check if another PBX or SIP service is running on port 5060

## Connection Issues

### Calls don't connect at all

**Symptom:** Phone rings forever or immediately fails.

**Checklist:**
1. Is the extension registered with Asterisk?
   ```bash
   claude-phone status
   # Look for "SIP Registration: OK"
   ```

2. Is Asterisk running?
   ```bash
   docker ps | grep asterisk
   ```

3. Is the SIP domain correct?
   ```bash
   claude-phone config show
   # Check sip.domain
   ```

4. Are credentials correct?
   - Check `devices.json` matches what drachtio sends
   - Verify with Asterisk: `docker exec asterisk asterisk -rx "pjsip show endpoints"`

5. Is drachtio container running?
   ```bash
   docker ps | grep drachtio
   ```

### Extension not registering with Asterisk

**Symptom:** `claude-phone status` shows SIP registration failed.

**Solutions:**
1. Verify extension exists in `devices.json`
2. Check authId and password match between `devices.json` and Asterisk config
3. Restart containers to regenerate Asterisk config: `claude-phone stop && claude-phone start`
4. Check if another device is using the same extension
5. Check Asterisk registration status:
   ```bash
   docker exec asterisk asterisk -rx "pjsip show registrations"
   ```

### SIP softphone can't register

**Symptom:** Your SIP phone/softphone can't connect to Asterisk.

**Solutions:**
1. Verify you're using the correct credentials:
   - Username: `1001` (or `1002`)
   - Password: value of `USER_EXT_PASSWORD` in `.env` (default: `changeme`)
   - Server: Your server's LAN IP (not `127.0.0.1`)
   - Port: `5060`
2. Ensure port 5060 is reachable from your phone's network
3. Check Asterisk logs for auth failures: `docker logs asterisk | grep "401\|auth"`

### Calls connect but no audio

**Symptom:** Call connects, you can see it's answered, but there's silence.

**Most common cause:** Wrong `EXTERNAL_IP` setting.

**Fix:**
```bash
# Find your server's LAN IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# Re-run setup to fix
claude-phone setup
# Enter correct IP when prompted for "External IP"
```

**Other causes:**
- RTP ports blocked by firewall (needs 30000-30100 UDP)
- NAT issues (server can't receive return audio)
- FreeSWITCH container unhealthy

## Runtime Issues

### "Sorry, something went wrong" on every call

**Symptom:** Calls connect, but Claude always says there was an error.

**Causes:**

1. **API server unreachable:**
   ```bash
   claude-phone status
   # Check "Claude API Server" status

   # For split deployments, verify connectivity:
   curl http://<api-server-ip>:3333/health
   ```

2. **Claude Code CLI not working:**
   ```bash
   # On the API server machine:
   claude --version
   claude "Hello"  # Test basic functionality
   ```

3. **Session errors:**
   ```bash
   claude-phone logs voice-app | grep -i error
   ```

### Whisper transcription errors

**Symptom:** Claude responds to wrong words or doesn't understand speech.

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| OpenAI billing exhausted | Add credits to OpenAI account |
| Audio quality poor | Check microphone, reduce background noise |
| Network latency | Audio chunks may be lost; check connection |

### ElevenLabs TTS errors

**Symptom:** Claude's responses aren't spoken, or voice sounds wrong.

**Solutions:**
1. Check ElevenLabs character quota isn't exhausted
2. Verify voice ID is valid: `claude-phone device list`
3. Check API key still works

### Calls disconnect after a few seconds

**Symptom:** Call connects, maybe plays greeting, then drops.

**Causes:**
- FreeSWITCH timeout (check logs)
- SIP session timeout
- Network instability

```bash
# Check FreeSWITCH logs for clues
claude-phone logs freeswitch | tail -100
```

## Split Deployment Issues

### Pi can't reach API server

**Symptom:** Voice services start but calls fail with connection errors.

**Diagnostics:**
```bash
# On the Pi, test connectivity:
curl http://<api-server-ip>:3333/health

# Check configured API URL:
claude-phone config show | grep claudeApiUrl
```

**Solutions:**
1. Verify API server IP is correct in Pi's config
2. Ensure API server is running: `claude-phone api-server`
3. Check firewall allows port 3333
4. Verify both machines are on same network (or have routing)

### API server won't start

**Symptom:** `claude-phone api-server` fails immediately.

**Solutions:**
1. Check port 3333 isn't already in use:
   ```bash
   lsof -i :3333
   ```

2. Verify Claude Code CLI works:
   ```bash
   claude --version
   ```

3. Check for Node.js errors in output

## Asterisk-Specific Issues

### Checking Asterisk status

```bash
# View registered endpoints
docker exec asterisk asterisk -rx "pjsip show endpoints"

# View active channels (calls)
docker exec asterisk asterisk -rx "core show channels"

# View PJSIP registrations
docker exec asterisk asterisk -rx "pjsip show registrations"

# View loaded config
docker exec asterisk asterisk -rx "pjsip show aors"
```

### Asterisk config not updating

**Symptom:** Changes to `devices.json` aren't reflected in Asterisk.

**Solution:** Asterisk config is generated at container start. Restart to apply:
```bash
claude-phone stop
claude-phone start
```

### Port conflict with another SIP service

**Symptom:** Asterisk fails to bind to port 5060.

**Solution:**
1. Find what's using the port: `ss -tulnp | grep 5060`
2. Stop the conflicting service, or
3. Change `ASTERISK_SIP_PORT` in `.env` to another port (e.g., 5062)

## Getting Logs

### Voice App Logs
```bash
claude-phone logs voice-app
# or
docker compose logs -f voice-app
```

### SIP Server Logs
```bash
claude-phone logs drachtio
# or
docker compose logs -f drachtio
```

### Media Server Logs
```bash
claude-phone logs freeswitch
# or
docker compose logs -f freeswitch
```

### Asterisk PBX Logs
```bash
claude-phone logs asterisk
# or
docker logs -f asterisk
```

### API Server Logs
```bash
# If running in foreground, check terminal output
# If running via start command, check:
cat ~/.claude-phone/api-server.log
```

## Still Stuck?

1. **Run full diagnostics:** `claude-phone doctor`
2. **Check all container logs:** `docker compose logs`
3. **Open an issue:** [github.com/issues](../../issues)

When opening an issue, include:
- Output of `claude-phone doctor`
- Output of `claude-phone status`
- Relevant log snippets (redact any API keys!)
- Your deployment type (All-in-one or Split)
- Platform (macOS, Linux, Raspberry Pi)
