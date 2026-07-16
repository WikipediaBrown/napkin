import os, subprocess, sys, unittest

SCRIPT = os.path.join(os.path.dirname(__file__), "..", "gen_robots.py")
BOTS = ["GPTBot", "OAI-SearchBot", "ChatGPT-User", "ClaudeBot",
        "Claude-SearchBot", "PerplexityBot", "Google-Extended",
        "Applebot-Extended"]


def run(*args):
    out = subprocess.run([sys.executable, SCRIPT, *args],
                         capture_output=True, text=True)
    assert out.returncode == 0, out.stderr
    return out.stdout


class TestGenRobots(unittest.TestCase):
    def test_named_groups_each_carry_disallows(self):
        txt = run("--disallow", "main", "2.0.8")
        for bot in ["*"] + BOTS:
            self.assertIn(f"User-agent: {bot}", txt, bot)
        # every group must repeat the disallows (most-specific-group rule)
        self.assertEqual(txt.count("Disallow: /main/"), len(BOTS) + 1)
        self.assertEqual(txt.count("Disallow: /2.0.8/"), len(BOTS) + 1)
        self.assertEqual(txt.count("Allow: /"), len(BOTS) + 1)

    def test_sitemap_line(self):
        self.assertIn("Sitemap: https://getnapkin.to/sitemap.xml",
                      run("--disallow", "main"))

    def test_no_refs_means_no_disallows(self):
        txt = run("--disallow")
        self.assertNotIn("Disallow:", txt)
        self.assertIn("User-agent: GPTBot", txt)


if __name__ == "__main__":
    unittest.main()
