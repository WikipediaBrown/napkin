# Cross-post checklist for blog posts

Each blog post in this directory is ready to share on external developer channels.
Always cross-post with a `<canonical>` link pointing back to getnapkin.to/blog/...
so search engines credit the original.

## dev.to

1. Sign in at https://dev.to/.
2. **Create Post** → paste the post's body content as Markdown. dev.to renders
   the same Markdown conventions our posts already use (headings, code fences,
   links).
3. **Add tags**: `swift`, `ios`, `architecture`, plus 1–2 post-specific tags
   (e.g. `concurrency`, `testing`).
4. **Canonical URL field**: set to the post's getnapkin.to URL.
5. Publish.

## Hacker News

1. Submit at https://news.ycombinator.com/submit.
2. **Title**: the post's H1 verbatim (under 80 chars).
3. **URL**: the post's getnapkin.to URL — *not* a dev.to mirror.
4. No body (HN deduplicates by URL; a body would be a duplicate submission).
5. First comment (optional): a one-sentence summary plus context if the title
   needs framing.

## Swift Forums

1. https://forums.swift.org/ → **Related Projects** → **New Topic**.
2. **Title**: the post's H1.
3. **Body**: lede + a one-paragraph summary + the canonical link. Avoid pasting
   the full post — Discourse rewards conversation over content dumps.
4. **Tags**: `swift-concurrency`, `architecture`, `tools`.

## What to cross-post

| Post | dev.to | HN | Swift Forums |
|------|--------|-----|--------------|
| swift-6-ribs-replacement | ✓ | ✓ | ✓ (high signal) |
| swift-6-actor-isolation-architecture | ✓ | ✓ | ✓ |
| swiftui-dependency-injection-without-libraries | ✓ | ✓ |  |
| testing-swift-actors-guide | ✓ | ✓ | ✓ |
| modular-ios-apps-swift-concurrency | ✓ | ✓ |  |

## Notes

- Space cross-posts out by at least 24 hours. HN's "we've seen this before"
  flag will throw self-submissions if you batch them.
- HN tends to do better with substantive analysis posts (RIBs alternative,
  actor isolation, modularity). dev.to and Swift Forums are better fits for
  the testing / DI / how-to ones.
- Authors should self-disclose maintainer status in HN comments if asked.
