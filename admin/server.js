const express = require('express');
const path = require('path');
const fs = require('fs');
const AsteriskManager = require('asterisk-manager');

const app = express();
const PORT = parseInt(process.env.ADMIN_PORT || '8080', 10);
const AMI_HOST = process.env.AMI_HOST || '127.0.0.1';
const AMI_PORT = parseInt(process.env.AMI_PORT || '5038', 10);
const AMI_SECRET = process.env.AMI_SECRET || '';
const DEVICES_CONFIG = process.env.DEVICES_CONFIG || '/app/config/devices.json';

let ami = null;
let amiConnected = false;

function connectAMI() {
  if (ami) {
    try { ami.disconnect(); } catch (e) { /* ignore */ }
  }

  ami = new AsteriskManager(AMI_PORT, AMI_HOST, 'admin', AMI_SECRET, true);

  ami.on('connect', () => {
    amiConnected = true;
    console.log(`[ADMIN] Connected to AMI at ${AMI_HOST}:${AMI_PORT}`);
  });

  ami.on('error', (err) => {
    amiConnected = false;
    console.error('[ADMIN] AMI error:', err.message);
  });

  ami.on('close', () => {
    amiConnected = false;
    console.log('[ADMIN] AMI connection closed, reconnecting in 5s...');
    setTimeout(connectAMI, 5000);
  });
}

// Helper: send AMI action as promise
function amiAction(action) {
  return new Promise((resolve, reject) => {
    if (!ami || !amiConnected) {
      return reject(new Error('AMI not connected'));
    }
    ami.action(action, (err, res) => {
      if (err) return reject(err);
      resolve(res);
    });
  });
}

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// API: overall status
app.get('/api/status', async (req, res) => {
  const status = {
    ami: amiConnected,
    timestamp: new Date().toISOString()
  };

  if (amiConnected) {
    try {
      const coreStatus = await amiAction({ action: 'CoreStatus' });
      status.asterisk = {
        version: coreStatus.coreversion || 'unknown',
        uptime: coreStatus.coreuptime || 'unknown',
        reloadTime: coreStatus.corereloadtime || 'unknown',
        currentCalls: parseInt(coreStatus.corecurrentcalls || '0', 10)
      };
    } catch (err) {
      status.asterisk = { error: err.message };
    }
  }

  res.json(status);
});

// API: registered endpoints
app.get('/api/endpoints', async (req, res) => {
  if (!amiConnected) {
    return res.json({ error: 'AMI not connected', endpoints: [] });
  }

  try {
    const result = await amiAction({ action: 'PJSIPShowEndpoints' });
    // AMI returns events, parse endpoint data from the response
    const endpoints = [];

    // The response may contain endpoint info directly or we need to
    // listen for events. For simplicity, use the command action.
    const cmdResult = await amiAction({
      action: 'Command',
      command: 'pjsip show endpoints'
    });

    const output = cmdResult.content || cmdResult.output || '';
    const lines = output.split('\n');

    for (const line of lines) {
      // Match lines like: 1001/1001  PJSIP/1001  Avail  ...
      const match = line.match(/^\s*([\w]+)\/[\w]+\s+\S+\s+(\w+)/);
      if (match) {
        endpoints.push({
          extension: match[1],
          status: match[2].toLowerCase()
        });
      }
    }

    res.json({ endpoints });
  } catch (err) {
    res.json({ error: err.message, endpoints: [] });
  }
});

// API: active channels/calls
app.get('/api/channels', async (req, res) => {
  if (!amiConnected) {
    return res.json({ error: 'AMI not connected', channels: [] });
  }

  try {
    const cmdResult = await amiAction({
      action: 'Command',
      command: 'core show channels concise'
    });

    const output = cmdResult.content || cmdResult.output || '';
    const channels = [];
    const lines = output.split('\n').filter(l => l.trim());

    for (const line of lines) {
      const parts = line.split('!');
      if (parts.length >= 5) {
        channels.push({
          channel: parts[0],
          context: parts[1],
          extension: parts[2],
          state: parts[4]
        });
      }
    }

    res.json({ channels });
  } catch (err) {
    res.json({ error: err.message, channels: [] });
  }
});

// API: configured devices from devices.json
app.get('/api/devices', (req, res) => {
  try {
    if (fs.existsSync(DEVICES_CONFIG)) {
      const data = JSON.parse(fs.readFileSync(DEVICES_CONFIG, 'utf8'));
      const devices = Object.entries(data).map(([ext, dev]) => ({
        extension: ext,
        name: dev.name || ext,
        prompt: dev.prompt || ''
      }));
      res.json({ devices });
    } else {
      res.json({ devices: [], error: 'devices.json not found' });
    }
  } catch (err) {
    res.json({ devices: [], error: err.message });
  }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[ADMIN] Claude Phone admin panel listening on port ${PORT}`);

  if (AMI_SECRET) {
    connectAMI();
  } else {
    console.warn('[ADMIN] No AMI_SECRET configured, AMI features disabled');
  }
});
