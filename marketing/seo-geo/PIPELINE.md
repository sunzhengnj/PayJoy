# ClockJoy SEO / GEO daily pipeline

Operating manual for the daily agent that owns the GitHub Pages site end-to-end.

## Scope

- **Own:** `docs/` on `sunzhengnj/PayJoy` (GitHub Pages at https://sunzhengnj.github.io/PayJoy/).
- **Public brands only:** 开薪 (CN) / **ClockJoy** (EN). Never use `PayJoy` as a public brand in new copy — it is the internal repo name only.
- **Do not:** invent App Store Connect live-metadata changes unless the agent has ASC access. Repo paste files under `docs/app-store/` may be updated; live ASC is separate.
- **Product truth:** workday countdown + estimated earnings + Lock Screen / Dynamic Island widgets. Estimates only — **not** payroll, timesheet, tax, or attendance.

## Weekday routine

1. Open `QUEUE.md` and take the top item marked `[next]`.
2. Write **one** substantial EN guide under `docs/en/guides/` (~600–900 words equivalent HTML). Match style of `docs/en/guides/countdown.html` (`../../site.css`, header, `article`, App Store CTA to `id6771261514`).
3. When capacity allows, add a CN twin under `docs/guides/` and wire `hreflang` both ways.
4. Update `docs/sitemap.xml` with the new URL(s) and today’s `lastmod` (ISO date).
5. Update `docs/en/guides/index.html` (and CN guides index if a twin shipped).
6. Mark the topic `[done YYYY-MM-DD]` in `QUEUE.md`; promote the next three open topics to `[next]` if fewer than three remain marked next.
7. Append an entry to `LOG.md`.
8. Commit to `main` with a clear message, e.g. `seo: add EN guide <slug> for ClockJoy`.

**Cadence:** one substantial page per weekday. Do not spam thin pages.

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
