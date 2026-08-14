---
description: Submit the product to the directory catalog in ~/.darkflow/directories.csv through a real browser, and track what has already been submitted.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebFetch
---

Backlinks from product directories are the one off-page lever that does not need anyone else's
permission — a form, a description, a screenshot. The list of forms is fixed and versioned
(`~/.darkflow/directories.csv`); what changes per project is which of them fit and which are
already done.

This command walks that list in a real browser and submits. It is **not an audit**: it acts.

**Manual only.** No schedule, no catalog entry, no worker dispatch. Directory forms mean
accounts, captchas and email confirmations — a human is in the loop by definition.

**Money and identity are never spent silently.** Two hard rules, no exceptions:

- **Never pay.** A paid listing is reported as a recommendation with its price. Ask, never buy.
- **Never invent an identity.** Accounts are created with the project's real email only. No
  throwaway addresses, no made-up company details, no fabricated MRR, no invented reviews.

## Step 1 — Read project config

Load the project config (contract in `.darkflow.d/claude.md` → *Project config*). Uses:
`language`, `domain`.

No `domain` → nothing to submit. Say so and stop.

## Step 2 — Build the submission kit

Every form asks for the same eight things. Assemble them **once**, before opening a browser, so
the same words land everywhere:

| Field | Where it comes from |
|---|---|
| Name | project name |
| Tagline (≤60 chars) | `docs/state/product/positioning.md` |
| Short description (≤160) | positioning + the site's meta description |
| Long description (2–4 ¶) | `docs/state/product/product.md` |
| Categories / tags | the catalog's `category` column + what the form offers |
| Pricing | `docs/state/product/pricing.md` |
| Logo + 2–3 screenshots | `public/`, or take them from the live site with the browser |
| Submission URL | `domain` + UTM (below) |

Missing product docs → derive from the live site, and say in the report that the copy was
derived rather than read. **Never invent a claim the product does not make about itself.**

UTM on every submission, so the directories are separable in analytics later:

```
https://<domain>/?utm_source=<directory-slug>&utm_medium=referral&utm_campaign=directories
```

Print the kit before submitting anything. It goes into every form; a mistake in it is a mistake
repeated fifty times.

## Step 3 — Load the catalog and the state

```bash
cat ~/.darkflow/directories.csv          # the catalog — read-only, never edited here
cat docs/state/directories.md            # what this project already did (may not exist yet)
```

No catalog file → this Dark Flow install predates it; re-running the installer fixes it. Stop.

Drop from the candidate list:

- anything already `submitted`, `live` or `rejected` in the state file
- anything the project does not qualify for — `Open source` for a closed-source product,
  `AI` for a product with no AI in it, `Pre-launch` for a product that shipped two years ago.
  A submission to a directory the product does not belong in gets rejected, and rejections are
  remembered by the moderators.
- everything with a `price` other than free/freemium — unless `$ARGUMENTS` names it explicitly

Order what is left by `dr` descending. `$ARGUMENTS` overrides: a number sets the batch size, a
name submits exactly that one directory. Default batch: **5 per run**.

## Step 4 — Submit

Use the `ego-browser` skill (fall back to `agent-browser`). For each directory, in order:

1. Open the site, find the submit / "add product" path.
2. Sign up or log in with the project's email. Already logged in → carry on.
3. Fill the form from the kit. Upload the logo and screenshots when the form takes them.
4. Submit, then **verify**: a confirmation screen, a listing URL, or a "pending review" state.
   No confirmation seen means no submission — record it as `failed`, not `submitted`.
5. Capture the listing URL when the directory gives one immediately.

Stop and hand the directory to the human — `blocked`, with the reason — when it wants any of:

- payment, or a card on file
- a captcha you cannot pass, or an SMS / phone verification
- an OAuth login (Google, GitHub) you do not hold the session for
- an email confirmation whose mailbox you cannot read
- a badge installed on the product's own site before the link goes dofollow
  (`Smol Launch` — file that as a code change, do not fake it)

A blocked directory is not a failure. Moving on and reporting it precisely is the job.

## Step 5 — Record the state

Write `docs/state/directories.md`, one row per directory ever attempted. Update rows in place;
never rewrite the history of a row that already succeeded.

```markdown
# Directory submissions

**Last run:** <date> · submitted this run: <n> · blocked: <n>

| Directory | DR | Status | Date | Listing URL | Note |
|---|---|---|---|---|---|
| SourceForge | 92 | live | 2026-08-14 | https://… | |
| DevHunt | 62 | submitted | 2026-08-14 | | pending review |
| Uneed | 75 | blocked | 2026-08-14 | | $29 — needs approval |
| BetaList | 76 | rejected | 2026-08-12 | | product not pre-launch |

## Submission kit

<the eight fields from Step 2, verbatim — so the next run repeats the same copy>
```

Status values: `submitted` (form accepted, awaiting moderation) · `live` (listing is public) ·
`blocked` (needs a human — say what for) · `rejected` (moderator said no — say why) ·
`failed` (submission did not go through).

Re-check `submitted` rows on the next run: open the listing, and promote to `live` once it is
public. A row that has been `submitted` for more than 30 days is stale — say so in the report.

**Commit nothing and push nothing.** The file stays in the working copy; the next pull request
carries it, and `fix-issues` already stages `docs/state/`.

## Step 6 — Report

Print, in the `language` from the project config:

- one line per directory attempted: name → status → listing URL or the reason
- what is blocked and what unblocks it, **with the price when it is money**
- the next 5 candidates by DR, so the next run needs no thinking

**Files no tasks.** The one exception: a code change another directory depends on — the badge
`Smol Launch` wants, an open-source repo link, a comparison page a directory requires — is a
real change to the product. File that one with `~/.darkflow/df task create --source seo
--status proposed`.
