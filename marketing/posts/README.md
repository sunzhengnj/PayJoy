# ClockJoy social posting drafts

Free, human-gated draft automation for **ClockJoy** (EN) / **开薪** (CN).  
Repo name `PayJoy` is internal only — never use it as a public brand in posts or CTAs.

## How drafts work

1. **Weekday mornings (alongside SEO):** the agent opens `QUEUE.md`, picks a `[next]` idea (or continues an open draft), and writes **one** markdown draft under `marketing/posts/`.
2. **Do not post automatically.** Drafts sit at `status: draft` or `status: ready` until the user asks to publish.
3. **When the user says to post:** the agent publishes via browser (logged-in sessions), then sets `status: posted` and fills `posted_at` + a one-line note in `LOG.md`.
4. **Capacity:** Reddit (EN) and X/Twitter (EN, `@ycbhsz`) are primary. Xiaohongshu (CN / 开薪) when time allows.

## Platforms

| Platform | Lang | Account / notes |
|----------|------|-----------------|
| Reddit | EN | Soft value posts; follow each sub’s rules; no spammy affiliate tone |
| X / Twitter | EN | `@ycbhsz` — short posts or threads |
| Xiaohongshu | CN | 开薪 hooks when capacity allows |

## Draft file format

Filename: `YYYY-MM-DD-<platform>-<slug>.md`

YAML frontmatter:

```yaml
---
platform: reddit | x | xiaohongshu
status: draft | ready | posted | skipped
target_url: # subreddit, X compose intent, or XHS note URL once posted
created: YYYY-MM-DD
posted_at: # ISO datetime when posted, else empty
notes: # subreddit name, thread id, reason skipped, etc.
---
```

Body = the copy ready to paste (title + text for Reddit; thread beats for X; CN copy for Xiaohongshu).

## Links (always prefer these in public copy)

- Product site (EN): https://sunzhengnj.github.io/PayJoy/en/
- Product site (CN): https://sunzhengnj.github.io/PayJoy/
- US App Store: https://apps.apple.com/us/app/id6771261514

## Voice & compliance

- Soft promotion: helpful first, product mention light and optional.
- No spammy claims, fake urgency, or invented competitor smears.
- When earnings / pay estimates appear: **payroll disclaimer** — estimates only; not payroll, timesheet, tax, or attendance.
- Public brand: **ClockJoy** (EN) / **开薪** (CN) only.

## Files in this folder

| File | Role |
|------|------|
| `README.md` | This manual |
| `QUEUE.md` | Channel / angle backlog |
| `LOG.md` | Post / skip log |
| `YYYY-MM-DD-*.md` | Individual drafts |

## Related

SEO weekday pipeline: [`../seo-geo/PIPELINE.md`](../seo-geo/PIPELINE.md) — after the SEO page step, also write one social draft when capacity allows.
