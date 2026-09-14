# ClockJoy overseas social drafts

Free, human-gated draft automation for **ClockJoy** (public EN brand only).  
Repo name `PayJoy` is internal — never use it as a public brand in posts, hashtags, or CTAs.

This folder is the **overseas / English** pipeline. Xiaohongshu (CN) is a **separate** routine under [`../xiaohongshu/`](../xiaohongshu/) and should be de-emphasized here.

## Hard rule: English only overseas

- **All overseas platforms are English-only:** X/Twitter, Instagram, Reddit, Threads, LinkedIn, Product Hunt, TikTok, and any other non-CN channel.
- **No Chinese characters** in overseas draft bodies, titles, captions, hashtags, alt text, or image overlays.
- Do not mix CN/EN in one overseas post. Do not paste Xiaohongshu copy onto X, Instagram, Reddit, LinkedIn, Threads, Product Hunt, or TikTok.
- Public brand in this folder: **ClockJoy** only.

## How drafts work (still free)

1. **Weekday mornings (alongside SEO):** the agent opens `QUEUE.md`, picks a `[next]` idea (or continues an open draft), and writes **one** markdown draft under `marketing/posts/`.
2. **Do not post automatically.** Drafts sit at `status: draft` or `status: ready` until the user asks to publish.
3. **When the user says to post:** the agent publishes via browser (logged-in sessions), then sets `status: posted` and fills `posted_at` plus a one-line note in `LOG.md`.
4. **Xiaohongshu is the exception:** do not treat XHS as part of this overseas queue. CN notes are handled by other auto routines in `marketing/xiaohongshu/`.

## Primary platforms (overseas)

| Platform | Lang | Account / notes |
|----------|------|-----------------|
| X / Twitter | EN only | `@ycbhsz` — short posts or threads |
| Instagram | EN only | Caption + hashtags; EN screenshots / marketing assets |
| Reddit | EN only | Soft value posts; follow each sub’s rules; no spammy affiliate tone |
| Threads | EN only | Short posts; same brand and disclaimer rules as X |
| LinkedIn | EN only | Professional, boundary-friendly tone; no hustle-bro spam |
| Product Hunt | EN only | Only when launching / a hunt is planned — do not fake a launch |

TikTok and similar overseas apps follow the same EN-only + ClockJoy rules if a draft is requested.

## Draft file format

Filename: `YYYY-MM-DD-<platform>-<slug>.md`

YAML frontmatter:

```yaml
---
platform: x | instagram | reddit | threads | linkedin | producthunt | tiktok
lang: en
status: draft | ready | posted | skipped
target_url: # subreddit, compose URL, or live post URL once posted
created: YYYY-MM-DD
posted_at: # ISO datetime when posted, else empty
notes: # subreddit name, thread id, image order, reason skipped, etc.
---
```

Body = the copy ready to paste (thread beats for X; caption + hashtags for Instagram; title + text for Reddit; short post for Threads / LinkedIn).

## Links (always prefer these in public copy)

- US App Store: https://apps.apple.com/us/app/id6771261514
- Product site (EN): https://sunzhengnj.github.io/PayJoy/en/

Do not lead overseas posts with the CN site. Never use `PayJoy` as the app name.

## Voice & compliance

- **Soft promotion:** helpful first, product mention light and optional.
- No spammy claims, fake urgency, or invented competitor smears.
- When earnings / pay estimates appear: **payroll disclaimer** — estimates only; not payroll, timesheet, tax, or attendance.
- Public brand: **ClockJoy** only.

## Image notes (overseas)

- Prefer **English screenshots / marketing assets** when available, e.g. `docs/assets/home.jpg`, `docs/assets/lockscreen.jpg`, `docs/assets/widgets.jpg`, `docs/assets/afterwork.jpg`, `docs/assets/wish.jpg`, `docs/assets/og.jpg`.
- **No Chinese UI, CN copy, or Xiaohongshu cards** in overseas posts (`marketing/xiaohongshu/` is CN-only).
- Hide real salary amounts on share-oriented images. Fictional estimates are OK if clearly personal.
- If an EN asset is missing, post copy-only or crop to a brand-safe detail rather than using a Chinese screenshot.

## Files in this folder

| File | Role |
|------|------|
| `README.md` | This overseas EN manual |
| `QUEUE.md` | EN channel / angle backlog (X, Instagram, Reddit, Threads, LinkedIn) |
| `LOG.md` | Post / skip / pack log |
| `YYYY-MM-DD-*.md` | Individual drafts |

## Related

- SEO weekday pipeline: [`../seo-geo/PIPELINE.md`](../seo-geo/PIPELINE.md) — after the SEO page step, also write one **overseas EN** social draft when capacity allows.
- Xiaohongshu (CN, separate): [`../xiaohongshu/`](../xiaohongshu/) — not part of this queue.
