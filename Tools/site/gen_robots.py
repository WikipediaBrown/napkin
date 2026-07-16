#!/usr/bin/env python3
"""Generate robots.txt for getnapkin.to.

Usage: python3 gen_robots.py --disallow [ref ...]   # prints to stdout

Welcomes the AI crawlers by name (we WANT AI assistants to read this site)
and blocks the versioned documentation copies (/main/, /2.0.8/, ...) so only
the latest docs get indexed. Each named group repeats the full rule body
because a crawler obeys only the most specific User-agent group that
matches it — a bare "Allow: /" group would override the * group's
Disallow rules for that bot.
"""
import argparse

# AI crawlers we explicitly welcome. robots.txt allows unlisted bots anyway;
# naming them is a deliberate "yes, index us" signal.
AI_BOTS = [
    "GPTBot",            # OpenAI: training
    "OAI-SearchBot",     # OpenAI: ChatGPT search citations
    "ChatGPT-User",      # OpenAI: on-demand fetches for a user
    "ClaudeBot",         # Anthropic: indexing
    "Claude-SearchBot",  # Anthropic: search citations
    "PerplexityBot",     # Perplexity
    "Google-Extended",   # Google: Gemini training opt-in
    "Applebot-Extended", # Apple: Apple Intelligence opt-in
]


def group(agent, disallows):
    lines = [f"User-agent: {agent}", "Allow: /"]
    lines += [f"Disallow: /{ref}/" for ref in disallows]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--disallow", nargs="*", default=[],
                        help="versioned-docs path prefixes to block")
    refs = parser.parse_args().disallow
    groups = [group("*", refs)] + [group(bot, refs) for bot in AI_BOTS]
    print("\n\n".join(groups))
    print("\nSitemap: https://getnapkin.to/sitemap.xml")


if __name__ == "__main__":
    main()
