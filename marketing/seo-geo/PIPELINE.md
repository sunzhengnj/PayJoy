# ClockJoy SEO / GEO daily pipeline

Operating manual for the daily agent that owns the GitHub Pages site end-to-end.

## Scope

- **Own:** `docs/` on `sunzhengnj/PayJoy` (GitHub Pages at https://sunzhengnj.github.io/PayJoy/).
- **Public brands only:** 开薪 (CN) / **ClockJoy** (EN). Never use `PayJoy` as a public brand in new copy — it is the internal repo name only.
- **Do not:** invent App Store Connect live-metadata changes unless the agent has ASC access. Repo paste files under `docs/app-store/` may be updated; live ASC is separate.
- **Product truth:** workday countdown + estimated earnings + Lock Screen / Dynamic Island widgets. Estimates only — **not** payroll, timesheet, tax, or attendance.

## Monday / Friday routine (EN + CN)

Cadence is **Monday and Friday ~21:15 Asia/Shanghai**: publish **both** an English guide and a Chinese twin for the **same** new theme angle.

1. Open `QUEUE.md` and take the top item marked `[next]` (rotate themes; do not repeat the last few angles).
2. Write **one** substantial EN guide under `docs/en/guides/` (~600–900 words equivalent HTML). Match style of recent EN guides (`../../site.css`, header, `article`, App Store CTA to `id6771261514`). Public brand: **ClockJoy**. Product truth: **Estimates ≠ paycheck**.
3. **Required:** write the CN twin under `docs/guides/` the same run. Public brand: **开薪**. Product truth: **估算≠工资条**. Wire `hreflang` both ways and add “中文版 / English version” links.
4. Update `docs/sitemap.xml` with **both** locale URLs and today’s `lastmod` (ISO date).
5. Update `docs/en/guides/index.html` **and** `docs/guides/index.html`.
6. Mark the topic `[done YYYY-MM-DD]` in `QUEUE.md`; keep at least three `[next]` items.
7. Append an entry to `LOG.md`.
8. Open a PR (or push) and merge to `main` so GitHub Pages picks up both locales.
9. Write **one overseas EN social draft only** under `marketing/posts/` (manual phone post). Do **not** auto-post Xiaohongshu; do **not** change live App Store Connect metadata.

**Cadence:** one paired EN+CN theme per Mon/Fri fire. Do not spam thin pages. Never use PayJoy/FoodLogApp as public brand in copy.

## Also write one social draft

After the SEO page steps (or when the SEO queue is blocked), write **one** social draft under [`../posts/`](../posts/) using [`../posts/QUEUE.md`](../posts/QUEUE.md). Do not publish until the user asks — drafts stay `draft`/`ready`; posting is browser + human-gated. See [`../posts/README.md`](../posts/README.md).

## GEO rules (generative engine optimization)

- Lead with a clear definition in the first 2–3 sentences (quotable by AI engines).
- Prefer FAQ blocks with short, self-contained answers; add FAQ JSON-LD when useful.
- Use comparison tables when the query implies “vs timesheet / payroll / calculator.”
- Explicit payroll disclaimer on every earnings-related page.
- Internal-link to related EN guides and the App Store.
- Canonical URLs under `https://sunzhengnj.github.io/PayJoy/en/guides/…`.

## Quality bar

- Accurate product claims only (estimates, widgets, Live Activity / Dynamic Island, privacy-safe share cards).
- No competitor smears; no invented legal overtime math.
- No `PayJoy` in titles, descriptions, body, or CTAs of new public pages.
- English for US/EN search intent; keep CN and EN in sync when both exist.

## Files in this folder

| File | Role |
|------|------|
| `PIPELINE.md` | This manual |
| `QUEUE.md` | Ordered topic backlog |
| `LOG.md` | Ship log |

## URLs after Pages deploy

- Site: https://sunzhengnj.github.io/PayJoy/
- EN home: https://sunzhengnj.github.io/PayJoy/en/
- EN guides index: https://sunzhengnj.github.io/PayJoy/en/guides/
- US App Store: https://apps.apple.com/us/app/id6771261514
