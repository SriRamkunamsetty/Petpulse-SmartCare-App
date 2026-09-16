// Reference implementation of docs/API_CONTRACT.md for local development.
// Run: npm install && npm start   (defaults to PORT=4000)
// Then point the Flutter app's cloud base URL at http://<this-machine-ip>:4000
const express = require('express');
const crypto = require('crypto');
const state = require('./state');
const camera = require('./camera');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4000;

// ── Auth ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ ok: true }));

function issueToken(email) {
  const token = crypto.randomBytes(16).toString('hex');
  state.users.set(token, { email });
  return token;
}

app.post('/api/v1/auth/register', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  const token = issueToken(email);
  res.json({ token, user_id: email });
});

app.post('/api/v1/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) return res.status(400).json({ error: 'email and password required' });
  // Demo server: any email/password pair is accepted so the app is usable
  // without a real account system.
  const token = issueToken(email);
  res.json({ token, user_id: email });
});

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token || !state.users.has(token)) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
}
app.use('/api/v1', (req, res, next) => {
  // Camera routes are unauthenticated here to match real firmware
  // (esp32_cam.ino has no auth at all — the app never sends a token to
  // it, so mock_server can't require one either when standing in as a cam).
  if (req.path.startsWith('/auth/') || req.path.startsWith('/camera/')) {
    return next();
  }
  return requireAuth(req, res, next);
});

// ── Pet ──────────────────────────────────────────────────────────────
app.get('/api/v1/pet', (req, res) => res.json(state.pet));
app.put('/api/v1/pet', (req, res) => {
  Object.assign(state.pet, req.body || {});
  res.json(state.pet);
});

// ── Devices / pairing ────────────────────────────────────────────────
app.get('/api/v1/devices', (req, res) => res.json(state.devices));

app.post('/api/v1/devices/pair/start', (req, res) => {
  const sessionId = state.id('pair');
  state.pairingSessions.set(sessionId, { startedAt: Date.now() });
  res.json({ session_id: sessionId });
});

app.get('/api/v1/devices/pair/status', (req, res) => {
  const sessionId = req.query.session_id;
  const session = state.pairingSessions.get(sessionId);
  if (!session) return res.status(404).json({ error: 'unknown session' });
  const elapsed = Date.now() - session.startedAt;
  if (elapsed < 1200) {
    return res.json({ state: 'searching', device: null });
  }
  const device = state.pairableDevices[state.nextPairedDeviceIndex % state.pairableDevices.length];
  res.json({ state: 'found', device });
});

app.post('/api/v1/devices/pair/confirm', (req, res) => {
  const sessionId = req.body?.session_id;
  const session = state.pairingSessions.get(sessionId);
  if (!session) return res.status(404).json({ error: 'unknown session' });
  const device = state.pairableDevices[state.nextPairedDeviceIndex % state.pairableDevices.length];
  state.incPairedDeviceIndex();
  state.pairingSessions.delete(sessionId);
  if (!state.devices.find((d) => d.id === device.id)) {
    state.devices.push(device);
  }
  res.json(device);
});

// ── Telemetry ────────────────────────────────────────────────────────
app.get('/api/v1/telemetry', (req, res) => {
  const override = req.query.connectivity || state.connectivityOverride;
  // Slow organic drift so the Home screen visibly ticks during a demo.
  state.bowlWeightGrams = Math.max(0, state.bowlWeightGrams - 0.01);
  const hub = state.devices.find((d) => d.id === 'hub-1');
  // Simulated ultrasonic reading: more food in the bowl -> shorter distance
  // from the sensor down to the surface. Real hub reports the actual
  // pulseIn()-derived distance instead of this approximation.
  const bowlHeightCm = Math.max(1, 8 - state.bowlWeightGrams / 15);
  res.json({
    bowl_weight_grams: Math.round(state.bowlWeightGrams * 10) / 10,
    food_level_pct: state.foodLevelPct,
    bowl_height_cm: Math.round(bowlHeightCm * 10) / 10,
    next_feed_time: '6:00 PM',
    next_feed_grams: 45,
    connectivity: override,
    last_updated: new Date().toISOString(),
    last_refilled: '6:00 PM',
    hub_battery_pct: hub ? hub.battery_pct : null,
  });
});

// ── Manual feed ──────────────────────────────────────────────────────
app.post('/api/v1/feed/manual', (req, res) => {
  const grams = Number(req.body?.grams || 0);
  const jobId = state.id('job');
  const job = { targetGrams: grams, dispensedGrams: 0, status: 'dispensing' };
  state.feedJobs.set(jobId, job);
  const step = Math.max(1, Math.ceil(grams / 10));
  const timer = setInterval(() => {
    job.dispensedGrams = Math.min(grams, job.dispensedGrams + step);
    if (job.dispensedGrams >= grams) {
      job.status = 'done';
      state.bowlWeightGrams += grams;
      state.foodLevelPct = Math.max(0, state.foodLevelPct - 1);
      clearInterval(timer);
    }
  }, 180);
  res.json({ job_id: jobId });
});

app.get('/api/v1/feed/manual/:jobId', (req, res) => {
  const job = state.feedJobs.get(req.params.jobId);
  if (!job) return res.status(404).json({ error: 'unknown job' });
  res.json({ status: job.status, dispensed_grams: job.dispensedGrams });
});

// ── Schedule ─────────────────────────────────────────────────────────
app.get('/api/v1/schedule', (req, res) => res.json(state.schedule));

app.post('/api/v1/schedule', (req, res) => {
  const { day, time, grams } = req.body || {};
  if (!day || !time || !grams) return res.status(400).json({ error: 'day, time, grams required' });
  const entry = { id: state.id('sch'), day, time, grams: Number(grams), enabled: true };
  state.schedule = [...state.schedule, entry];
  res.json(entry);
});

app.patch('/api/v1/schedule/:id', (req, res) => {
  const entry = state.schedule.find((e) => e.id === req.params.id);
  if (!entry) return res.status(404).json({ error: 'not found' });
  if (typeof req.body?.enabled === 'boolean') entry.enabled = req.body.enabled;
  if (req.body?.time) entry.time = req.body.time;
  if (req.body?.grams) entry.grams = Number(req.body.grams);
  res.json(entry);
});

app.delete('/api/v1/schedule/:id', (req, res) => {
  state.schedule = state.schedule.filter((e) => e.id !== req.params.id);
  res.status(204).end();
});

// ── History ──────────────────────────────────────────────────────────
app.get('/api/v1/history', (req, res) => {
  res.json({ bars: state.historyBars, events: state.historyEvents });
});

// ── Alerts ───────────────────────────────────────────────────────────
app.get('/api/v1/alerts', (req, res) => res.json(state.alerts));
app.post('/api/v1/alerts/:id/read', (req, res) => {
  const alert = state.alerts.find((a) => a.id === req.params.id);
  if (alert) alert.read = true;
  res.status(204).end();
});

// ── Camera ───────────────────────────────────────────────────────────
// Root-level /stream matches how a real cam (esp32_cam.ino) serves it
// when the app talks to it directly on the LAN; /api/v1/camera/stream is
// kept too for relay-style access — see docs/API_CONTRACT.md "Camera".
camera.attachStream(app, '/stream');
camera.attachStream(app, '/api/v1/camera/stream');

app.get('/api/v1/camera/snapshot', (req, res) => {
  state.lastSnapshotAt = new Date().toISOString();
  res.set('Content-Type', 'image/jpeg');
  res.send(camera.snapshotJpeg());
});

app.post('/api/v1/camera/mic', (req, res) => {
  state.camMicOn = !!req.body?.on;
  res.status(204).end();
});

app.post('/api/v1/camera/night_vision', (req, res) => {
  state.camNightVisionOn = !!req.body?.on;
  res.status(204).end();
});

app.get('/api/v1/camera/status', (req, res) => {
  res.json({ signal: 'strong', last_snapshot_at: state.lastSnapshotAt });
});

app.listen(PORT, () => {
  console.log(`PetPulse mock server listening on http://0.0.0.0:${PORT}`);
  console.log('Implements docs/API_CONTRACT.md as an in-memory stand-in for the cloud relay + hub/cam.');
});
