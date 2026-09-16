const crypto = require('crypto');

function id(prefix) {
  return `${prefix}_${crypto.randomBytes(4).toString('hex')}`;
}

// One shared demo account + fleet, matching the design prototype's defaults
// (project/PetPulse App.dc.html) so the app looks identical to the mock
// coming from Claude Design.
const users = new Map(); // token -> { email }

const pet = {
  name: 'Milo',
  breed: 'Corgi',
  age_value: 2,
  age_unit: 'yrs',
  weight_value: 12,
  weight_unit: 'kg',
  health_conditions: [],
  notes: '',
};

const devices = [
  { id: 'hub-1', name: 'ESP32-S3 Main Hub', kind: 'hub', status: 'online', battery_pct: 82, meta: 'Controller', ip_address: '127.0.0.1' },
  { id: 'cam-1', name: 'ESP32-CAM Feeder Cam', kind: 'cam', status: 'online', battery_pct: null, meta: 'Live video', ip_address: '127.0.0.1' },
  { id: 'lc-1', name: 'Load Cell + HX711', kind: 'load_cell', status: 'online', battery_pct: null, meta: 'Bowl weight sensor', ip_address: null },
  { id: 'us-1', name: 'Ultrasonic Sensor', kind: 'ultrasonic', status: 'online', battery_pct: null, meta: 'Food-level sensor', ip_address: null },
];

let bowlWeightGrams = 12.5;
let foodLevelPct = 78;
// Set via ?connectivity= query param on /api/v1/telemetry for demoing
// offline/error/low-battery states without real hardware, mirroring the
// `connectivityState` prop the .dc.html prototype exposes to designers.
let connectivityOverride = 'online';

const DAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
let schedule = [];
function seedSchedule() {
  schedule = [];
  for (const day of ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']) {
    schedule.push({ id: id('sch'), day, time: '8:00 AM', grams: 40, enabled: true });
    schedule.push({ id: id('sch'), day, time: '6:00 PM', grams: 45, enabled: true });
  }
  for (const day of ['Sat', 'Sun']) {
    schedule.push({ id: id('sch'), day, time: '9:00 AM', grams: 50, enabled: true });
    schedule.push({ id: id('sch'), day, time: '7:00 PM', grams: 50, enabled: true });
  }
}
seedSchedule();

const feedJobs = new Map(); // job_id -> { targetGrams, dispensedGrams, status, timer }

const historyBars = [
  { label: 'Mon', grams: 76 }, { label: 'Tue', grams: 82 }, { label: 'Wed', grams: 70 },
  { label: 'Thu', grams: 80 }, { label: 'Fri', grams: 84 }, { label: 'Sat', grams: 92 },
  { label: 'Sun', grams: 60 },
];
const historyEvents = [
  { id: id('ev'), timestamp: new Date(Date.now() - 2 * 3600e3).toISOString(), grams: 45, result: 'completed', note: '' },
  { id: id('ev'), timestamp: new Date(Date.now() - 10 * 3600e3).toISOString(), grams: 40, result: 'completed', note: '' },
  { id: id('ev'), timestamp: new Date(Date.now() - 26 * 3600e3).toISOString(), grams: 0, result: 'skipped', note: 'Bowl already full' },
  { id: id('ev'), timestamp: new Date(Date.now() - 34 * 3600e3).toISOString(), grams: 40, result: 'completed', note: '' },
];

const alerts = [
  { id: id('al'), title: 'Low food level', detail: '12% remaining — please refill the hopper', timestamp: new Date(Date.now() - 2 * 3600e3).toISOString(), severity: 'warning', read: false },
  { id: id('al'), title: 'Reduced intake detected', detail: 'Milo ate 15% less than usual this week', timestamp: new Date().toISOString(), severity: 'warning', read: false },
  { id: id('al'), title: 'Feeding complete', detail: '45g dispensed at 6:00 PM', timestamp: new Date().toISOString(), severity: 'info', read: false },
  { id: id('al'), title: 'Feeder Cam reconnected', detail: 'Back online after a brief drop', timestamp: new Date(Date.now() - 22 * 3600e3).toISOString(), severity: 'info', read: true },
];

const pairingSessions = new Map(); // session_id -> { startedAt, deviceIndex }
let nextPairedDeviceIndex = 0;
const pairableDevices = [
  { id: 'hub-2', name: 'PetPulse-Feeder-1', kind: 'hub', status: 'online', battery_pct: 100, meta: 'Controller', ip_address: '127.0.0.1' },
  { id: 'cam-2', name: 'PetPulse-Feeder-2', kind: 'cam', status: 'online', battery_pct: null, meta: 'A new ESP32-CAM on your network', ip_address: '127.0.0.1' },
];

let camMicOn = false;
let camNightVisionOn = false;
let lastSnapshotAt = null;

module.exports = {
  id, users, pet, devices, DAYS,
  get schedule() { return schedule; },
  set schedule(v) { schedule = v; },
  feedJobs, historyBars, historyEvents, alerts,
  pairingSessions, pairableDevices,
  get nextPairedDeviceIndex() { return nextPairedDeviceIndex; },
  incPairedDeviceIndex() { nextPairedDeviceIndex++; },
  get bowlWeightGrams() { return bowlWeightGrams; },
  set bowlWeightGrams(v) { bowlWeightGrams = v; },
  get foodLevelPct() { return foodLevelPct; },
  set foodLevelPct(v) { foodLevelPct = v; },
  get connectivityOverride() { return connectivityOverride; },
  set connectivityOverride(v) { connectivityOverride = v; },
  get camMicOn() { return camMicOn; },
  set camMicOn(v) { camMicOn = v; },
  get camNightVisionOn() { return camNightVisionOn; },
  set camNightVisionOn(v) { camNightVisionOn = v; },
  get lastSnapshotAt() { return lastSnapshotAt; },
  set lastSnapshotAt(v) { lastSnapshotAt = v; },
};
