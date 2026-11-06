# Prompt: Build "FLIP JAR", a One-Thumb Physics Merge Game for Android

## 1. Role

You are a senior mobile game developer and product designer. Help me design and build a simple, addictive Android game with strong viral potential. Work step by step. Ask me before making any decision not covered below.

---

## 2. Non-Technical Brief

### 2.1 Product Vision
A one-thumb physics drop-and-merge game (the Suika / Watermelon Game genre) with one unique twist: **you can flip the whole jar upside down**. Every day, all players get the **same seeded drop order**, so results are directly comparable and shareable. The game should feel like "one more try" every time, and a single run should last 3 to 12 minutes so people spend real leisure time in it.

Why this genre: it is proven at massive scale, runs are long, every run produces a different funny or satisfying moment (clip material for TikTok, Reels, Shorts, Facebook), and it is cheap to build with a 2D physics engine. The flip is what makes it ours.

### 2.2 Target Audience
- Casual mobile players, ages 14-35
- Primary market: Bangladesh and South Asia (low and mid-range Android phones, limited data)
- Secondary: global casual players
- Character theme is data-driven so the piece set can be swapped (neutral cute faces for global, a sweets set such as roshogolla to mishti for Bangladesh) without touching code

### 2.3 Core Gameplay
- **Single control:** touch and drag to aim the piece above the jar, release to drop it.
- Two identical pieces that touch merge into the next bigger piece (11 tiers). Merging scores points. Merging two of the largest tier clears them for a bonus.
- The jar overflows past the red line and the run ends.
- **The twist: 3 flips per run.** Tap FLIP and the jar turns upside down. The whole pile tumbles to the other end, pieces collide and chain-merge in chaos. The screen rotates with the jar so the player always drops from the top. Timing the flip is the core strategy and the core clip moment.
- Learnable in 3 seconds with no tutorial text, only one animated hint on the first run.

### 2.4 Daily Challenge (Viral Loop)
- A new seed is generated every day at 00:00 UTC. The seed drives the drop order, so every player plays the identical sequence that day. This turns luck into a shared puzzle ("how did you get 4000 with today's order?").
- Each player gets 3 attempts per day (the best score counts). An endless free-play mode with a random seed exists for leisure time, but only the daily mode has a leaderboard.
- After each run, show a **shareable result card** (image plus text), for example:
  `FLIP JAR #112 | 3,480 | Top 12% 🔥 | 2 flips used`
- A "Challenge a friend" button opens the Android share sheet (WhatsApp, Messenger, Facebook, etc.).

### 2.5 Retention Features (keep minimal)
- Daily streak counter
- Friends/global/country leaderboard
- 5-6 unlockable piece themes earned by streaks (not purchases)
- Daily local notification: "Today's jar is live"

### 2.6 Game Feel (highest priority)
- Instant response with no input lag
- Satisfying pop sound and haptic on every merge, a heavy thud and screen shake on every flip
- Screen shake and particles on big merges and on overflow
- Smooth restart in under 1 second
- Fair difficulty: every overflow should feel like the player's mistake
- Pieces have faces. They should look upside down after a flip; that is part of the charm

### 2.7 Visual and Audio Style
- Minimalist flat design, pieces drawn as colored circles with simple faces, 3 color themes
- High contrast, readable on small, low-brightness screens
- Short looping music track plus a small set of SFX (drop, merge pop per tier, flip, overflow, new high score)

### 2.8 Monetization (secondary, non-intrusive)
- Rewarded ad for one extra attempt or one extra flip
- Optional one-time "Remove ads" purchase
- No forced ads during a run

### 2.9 Success Metrics
| Metric | Target |
|---|---|
| Day-1 retention | ≥ 35-40% |
| Day-7 retention | ≥ 15% |
| Average session length | 8-15 minutes |
| Share rate | ≥ 10% of players share a result |
| Crash-free sessions | ≥ 99.5% |

### 2.10 Marketing (plan from day one)
The idea is about a third of the outcome. The rest is distribution: post 50-100 short gameplay clips (flips, chain merges, funny overflows) during the first two months, a share card people want to post, and a store icon and first screenshot that look clearly different from Suika clones.

---

## 3. Technical Brief

### 3.1 Recommended Stack
| Layer | Choice | Reason |
|---|---|---|
| Game engine | **Godot 4** | Small APK, free, built-in 2D physics |
| Language | GDScript | Fast iteration |
| Backend | **Go** (net/http or Gin) | Simple, fast, cheap to host |
| Database | PostgreSQL (or SQLite for MVP) | Scores and users |
| Cache | Redis (optional) | Leaderboard sorted sets |
| Auth | Anonymous device ID, with optional Google Sign-In later | Zero friction |
| Analytics | Firebase Analytics + Crashlytics | Retention and funnel tracking |
| Ads | AdMob (rewarded only) | Standard |

### 3.2 Performance and Compatibility Constraints
- APK/AAB size: **< 30 MB**
- Min Android version: API 24 (Android 7.0)
- Stable 60 FPS on a 2 GB RAM device; cap live physics bodies at about 80 (a full jar is 40-60)
- Fully playable **offline** (the daily seed falls back to a date-based local seed)
- Battery-friendly: cap FPS at 60, no heavy shaders

### 3.3 Game Architecture
- **Deterministic drop order:** `seed = hash("flipjar-" + YYYY-MM-DD)`. One seeded PRNG decides every spawned piece tier, so every player gets the same sequence. Physics itself is not deterministic across devices, and it does not need to be.
- Fixed physics timestep (60 Hz).
- Flip implementation: invert each piece's gravity scale, move the spawn point to the other end of the jar, and tween the camera rotation by 180 degrees over 0.5 s. The UI layer does not rotate.
- Overflow rule: a settled piece (speed below a threshold) that sits inside the danger zone on the drop side for 1 s ends the run. A 1.5 s grace period follows every flip.
- Separate modules: `Input`, `Piece`, `Tiers` (theme data), `Jar`, `Scoring`, `UI`, `Audio`, `Network`, `Share`.
- Save local state: best score, streak, unlocked themes, attempts left.

### 3.4 Backend API (Go)

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/v1/daily` | Returns today's seed, day number, and server time |
| `POST` | `/v1/scores` | Submit `{device_id, day, score, flips_used, replay_hash}` |
| `GET` | `/v1/leaderboard?day=&scope=global\|country\|friends` | Top scores plus the player's rank |
| `POST` | `/v1/users` | Register anonymous device ID and nickname |

Requirements:
- Rate limiting per device and IP
- Server-side validation of scores (basic anti-cheat: plausibility checks against merges possible from the seed, replay-input hash verification)
- Idempotent score submission (best score per user per day)
- Leaderboard served from Redis sorted sets, with Postgres as the source of truth
- Docker-based deployment on a low-cost VPS

### 3.5 Data Model (minimum)
```
users(id, device_id, nickname, country, created_at)
scores(id, user_id, day, score, flips_used, replay_hash, created_at)  -- unique(user_id, day)
streaks(user_id, current, best, last_played_day)
```

### 3.6 Share Card
- Generate the result image on-device (Viewport to PNG).
- Include: game logo, day number, score, percentile, flips used, streak, and a short store link.
- Use Android's native share intent.

### 3.7 Analytics Events
`session_start`, `run_start`, `run_end(score, duration, flips_used, max_tier)`, `flip_used`, `retry_clicked`, `share_clicked`, `daily_opened`, `ad_rewarded_watched`, `streak_updated`

### 3.8 Testing
- Unit tests for the drop-order generator (same seed must give the same sequence on every device)
- Playtest with 20-30 people without explaining the game
- Test on at least 3 low-end devices
- Load test the `/v1/scores` and leaderboard endpoints

---

## 4. Milestones

1. **Week 1-2: Prototype.** Jar, drop, merge, flip, overflow, score, restart. Daily-seeded drop order. *Gate:* do playtesters retry immediately, and do they talk about the flip?
2. **Week 3: Daily mode.** Attempts system, free-play mode, local best scores.
3. **Week 4: Backend + leaderboard.** Go API, Postgres, Redis.
4. **Week 5: Share card + streaks + notifications.**
5. **Week 6: Polish.** Juice, sound, particles, performance, APK size.
6. **Week 7: Closed beta.** 50-100 users and retention measurement.
7. **Week 8: Play Store launch.** Store listing, short gameplay clips, launch in Facebook groups and Reddit.

---

## 5. Deliverables I Expect From You

1. Final game design document (one page)
2. Project folder structure
3. Complete code for each module, in the milestone order above
4. Go backend with API, migrations, and Dockerfile
5. Test plan and analytics dashboard setup
6. Play Store listing text, icon brief, and screenshot plan

---

## 6. Rules for Your Responses

- Be precise and minimal. Do only what I ask, with no unrequested features.
- Do not over-engineer. Choose the simplest solution that meets the requirements.
- If something is ambiguous, ask me one clear question before proceeding.
- Explain trade-offs briefly when you make a technical choice.
- Start with **Milestone 1** and wait for my confirmation before moving on.

---

## 7. Status

- 2026-11-06: Brief changed from FLIP60 (gravity-flip runner) to FLIP JAR after analysis: the runner genre is crowded, produces identical clips and 3-minute sessions. Milestone 1 prototype started in `game/`.
- 2026-11-06: Milestone 1 prototype done in `game/` (Godot 4.4). Headless smoke test passes: 146 drops, merges up to tier 8, two flips (the second one chain-merged the pile from 31 to 26 pieces), overflow and restart. Not yet done: sound, particles, first-run hint, Android export, playtest gate.
- 2026-11-06: Milestones 2, 5 and most of 4 done in one pass at the user's request to finish fast. Shipped: daily mode with 3 attempts and seeded drop order, free play, local bests, streaks, three themes unlocked by streak (0/3/7 days), result screen with WhatsApp share and copy, "liquid" juice (droplet stretch in flight, squash and jelly wobble on impact, spawn pop, merge ring + confetti + floating score, drop guide line, screen shake, haptics), generated sound effects, first-run hints, Android back button, launcher icons and an Android export preset. Smoke test extended to cover save logic and effects. Still open: Go backend + leaderboard (Milestone 3), rewarded ads and remove-ads purchase, daily notification, closed beta, store listing.
