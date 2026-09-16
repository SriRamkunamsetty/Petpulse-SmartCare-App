# Deploying to Render (free tier)

This gets `mock_server` running 24/7 on a public URL your phone can reach
from anywhere — not just your home Wi-Fi — with **no credit card and no
payment**, using Render's free web service tier.

## One-time setup

1. Push this repo to GitHub (Render deploys from a Git repo, not a local
   folder — if it's not already on GitHub, create a repo and push).
2. In the [Render dashboard](https://dashboard.render.com), click
   **New +** → **Web Service**.
3. Connect the GitHub repo. Render should detect `render.yaml` at the repo
   root and offer to use it — accept that (it already points at
   `app/mock_server` and sets the right build/start commands). If it
   doesn't pick it up automatically, fill these in by hand instead:
   - **Root Directory:** `app/mock_server`
   - **Runtime:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
   - **Instance Type:** **Free**
4. Click **Create Web Service**. First deploy takes a few minutes. When it
   finishes you'll have a URL like `https://petpulse-mock-server.onrender.com`.
5. In the app, go to **Settings** and set the cloud base URL to that
   `https://...onrender.com` address (or set
   `ApiService.defaultCloudBaseUrl` to it before building, if you'd rather
   it be the default from first launch).

## The free-tier tradeoff — cold starts

Render's free web services **spin down after 15 minutes with no incoming
requests**, and take roughly 30–60 seconds to spin back up on the next
request. That's the entire cost of "free" here. Two ways to deal with it,
not mutually exclusive:

- **The app already tolerates this** — cold-start requests use a longer
  timeout and show a "waking up your feeder's server..." message instead
  of a hard "Couldn't reach PetPulse" error (see `ApiService` /
  `home_screen.dart`). So even with zero extra setup, worst case is a
  ~30-60s wait the first time you open the app after it's been idle.
- **Keep it warm** with a free external pinger hitting `/health` every
  10 minutes, so it never actually goes to sleep during hours you're
  likely to use it: [cron-job.org](https://cron-job.org) or
  [UptimeRobot](https://uptimerobot.com) both have free tiers that do
  exactly this — point either one at
  `https://<your-service>.onrender.com/health` on a 5–10 minute interval.
  (This uses your free monthly request quota on the pinger's side, not
  Render's — both have generous enough free allowances for one URL
  pinged every few minutes.)

## Data is in-memory, not persisted

`mock_server` keeps all state (pet profile, schedule, alerts, history) in
memory (`state.js`) — a redeploy or a Render restart resets it back to the
demo defaults. Fine for a hobby feeder where the ESP32-S3 hub is the real
source of truth for telemetry/feed (those go straight to the hub on your
LAN, bypassing Render entirely — see `firmware/README.md` §4). If you want
schedule/history/alerts to actually persist across restarts, that needs a
real database, which is out of scope for the free-tier "just get 24/7
uptime" goal here.
