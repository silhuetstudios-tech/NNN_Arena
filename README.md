# NNN — The Unbroken Club

**Aryan · Andrew · Adnan · Aman**

Four contenders. Thirty days. One unbroken November.

A mobile-friendly game with PIN profiles, daily check-ins, XP, shared ranks, a streak calendar, milestone trophies, a squad activity feed, confetti, and live countdowns. Built with HTML, CSS and JavaScript. **No build or installation is needed to host it.**

## 1. Put it on GitHub

1. Unzip this download.
2. Create a GitHub repository (for example, `nnn-arena`).
3. Upload the **contents** of the `nnn-arena` folder into your repository. `index.html` must be at the repository root, not inside another folder.
4. Open the repository’s **Settings → Pages**.
5. Under Source choose **Deploy from a branch**, then choose **main** and **/(root)**. Save.
6. Open the published URL shown on that page after deployment finishes. Open that URL on your phones.

The site works immediately in **local mode**. Local mode stores all four profiles in that browser only. It does **not** share scores between phones. Complete step 2 for your actual four-phone squad.

## 2. Connect all four phones

Do this once for your group:

1. Create a project at [Supabase](https://supabase.com/dashboard).
2. Open its **SQL Editor → New query**.
3. Paste the entire contents of **supabase.sql** and run it. Use a new project; this script adds only the `nnn_private` schema and the `public.nnn_api` function.
4. Find your **Project URL** and **public publishable key** (or legacy **anon** key) in the project’s Connect dialog / API settings. API keys are under **Settings → API Keys**.
5. Open your deployed game. Tap **LOCAL MODE** at the top, or **Squad settings** on desktop.
6. Paste the Project URL and public key, then tap **Create our shared squad**.
7. Tap **Copy squad invite** and share that generated link in your group. **Everyone must use that same invite; do not create four separate squads.**
8. Each person opens the invite, taps **Join this squad**, chooses their own name, and creates a **6–12 digit PIN**.

Done. Scores refresh every 20 seconds and when you return to the tab. The shared game uses the database’s clock for day validation. Internet access is required to save shared progress; failed requests do not silently become local check-ins.

The invite contains the squad’s private access code. Keep it in your group. Anyone with it can view the squad and claim any still-unclaimed profile; claim only your own profile. Profile edits require that player’s session/PIN. PINs are not included in invites or public game responses. Never put a service-role or secret key into this game or a GitHub repository.

Optional: put the two **public** project values in `config.js` before uploading, so you do not have to type them into settings. The shared squad still has to be created once and joined through its invite.

## How the game works

- **Season:** November 1–30, **2026**, in **India Standard Time (UTC+05:30)**. It starts November 1 at 00:00 IST and ends December 1 at 00:00 IST.
- **Daily reset:** midnight IST for every player, even if a phone is in another timezone.
- **100 XP** per daily check-in. Only today and yesterday are open. Future dates, duplicate entries and older backfills are blocked.
- **Streaks:** consecutive daily check-ins. Yesterday’s streak stays visible while today is still open. A missed full day breaks the chain. Missing a check-in does not automatically mark you out.
- **250 bonus XP** when your best streak first reaches each milestone: 3, 7, 14, 21 and 30 days. Bonuses are awarded once per milestone; restarting a streak cannot farm them.
- **Ranks:** players still in the challenge rank above players who are out, then by total XP. Equal scores share a rank.
- **“I’m out”:** freezes new check-ins, preserves earned XP and records the day your run ended. An accidental report can be undone for five minutes.
- **After the finish:** new check-ins are locked; the final record remains available.
- **Rules:** agree on the challenge’s boundaries together. Keep the competition voluntary and respectful.

The game starts with genuine empty records. There are no sample scores or fabricated check-ins.

## Phone tips

Use the published HTTPS URL rather than opening files directly from your phone’s file manager. On iPhone, Safari’s Share menu → **Add to Home Screen** gives it an app-like shortcut. Browser storage must be enabled. Keep your squad invite so you can rejoin on a new browser or device. Your PIN can unlock your profile again; closing a tab may end its unlocked session.

If you forget a PIN, there is no public reset button. The Supabase project owner can reset only the affected player’s `pin_hash` to `null` in `nnn_private.players` and remove that player’s rows from `nnn_private.sessions`, then let the player reclaim their profile. This requires the project owner’s database access; never expose it in the game.

## Local preview and verification

To preview on a computer:

```bash
python3 -m http.server 8000
```

Open `http://localhost:8000`. The production game is buildless and has no runtime package dependencies. Google Fonts is optional; system font fallbacks are included.

Game logic tests (Node.js):

```bash
npm test
```

Optional database tests (installs a development-only PostgreSQL engine; no Supabase account or network requests are used by the tests):

```bash
npm install
npm run test:backend
```

The database test runs the supplied SQL in an isolated PGlite database with a fixed test date. It checks profile claiming, hashed PINs, session protection, cross-profile write rejection, duplicate and future check-in rejection, yesterday backfill, fail/undo, PIN lockouts, and denial of direct table access. It does not connect to a live Supabase project.

## Files

- `index.html` — app shell
- `style.css` — responsive arcade design
- `app.js` — screens, interactions and shared-squad connection
- `game.js` — scoring, streak and date rules
- `config.js` — optional public backend configuration
- `supabase.sql` — shared-squad database and protected API
- `icon.svg`, `manifest.webmanifest` — icon and home-screen metadata
- `tests/` — game and database verification

Setup references: [GitHub Pages publishing](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys), [Supabase database functions](https://supabase.com/docs/guides/database/functions).
