"""Exercise snapshot publication against a local bare Git repository; no network or tokens needed."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "codecharta-publish.sh"


class PublishTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="codecharta-publish-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.remote = self.root / "remote.git"
        self.seed = self.root / "seed"
        self.git("init", "--bare", "--initial-branch=main", str(self.remote))
        self.git("clone", str(self.remote), str(self.seed))
        self.git("-C", str(self.seed), "config", "user.email", "test@example.invalid")
        self.git("-C", str(self.seed), "config", "user.name", "Test")
        for path in ["history/latest", "history/2026-11-05-merge-1234567", "previews/pr-42"]:
            for suffix in ["cc.json.gz", "cg.json", "meta.json"]:
                target = self.seed / "projects/example" / f"{path}.{suffix}"
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"old")
        self.git("-C", str(self.seed), "add", ".")
        self.git("-C", str(self.seed), "-c", "commit.gpgsign=false", "commit", "-m", "Seed")
        self.git("-C", str(self.seed), "push", "origin", "main")
        self.source = self.root / "new.cc.json.gz"
        self.source.write_bytes(b"new-map")

    def git(self, *args):
        return subprocess.run(["git", *args], check=True, capture_output=True, text=True)

    def publish(self, mode, **values):
        env = os.environ | {
            "CODECHARTA_PUBLISH_MODE": mode,
            "PROJECT_NAME": "example", "DATA_REPO": "example/maps",
            "CODEBASE_ARCHITECTURES_TOKEN": "test-token",
            "SOURCE_CC_PATH": str(self.source), "SOURCE_CG_PATH": "", "SOURCE_META_PATH": "",
            "PR_NUMBER": "42", "DATE": "2026-11-06", "STEM": "merge-7654321",
            # Rewrite the script's HTTPS clone and push to this test's local repository.
            "GIT_CONFIG_COUNT": "3",
            "GIT_CONFIG_KEY_0": f"url.{self.remote.as_uri()}.insteadOf",
            "GIT_CONFIG_VALUE_0": "https://x-access-token:test-token@github.com/example/maps.git",
            "GIT_CONFIG_KEY_1": "protocol.file.allow", "GIT_CONFIG_VALUE_1": "always",
            "GIT_CONFIG_KEY_2": "commit.gpgsign", "GIT_CONFIG_VALUE_2": "false",
        } | values
        result = subprocess.run(["bash", str(SCRIPT)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def contents(self, path):
        result = subprocess.run(
            ["git", "--git-dir", str(self.remote), "show", f"main:projects/example/{path}"],
            capture_output=True,
        )
        return result.stdout if result.returncode == 0 else None

    def test_preview_without_graph_removes_old_graph_and_metadata(self):
        self.publish("preview")
        self.assertEqual(self.contents("previews/pr-42.cc.json.gz"), b"new-map")
        self.assertIsNone(self.contents("previews/pr-42.cg.json"))
        self.assertIsNone(self.contents("previews/pr-42.meta.json"))
        self.assertEqual(self.contents("history/latest.cg.json"), b"old")

    def test_history_without_graph_aligns_all_latest_pointers(self):
        self.publish("history")
        self.assertEqual(self.contents("history/latest.cc.json.gz"), b"new-map")
        self.assertIsNone(self.contents("history/latest.cg.json"))
        self.assertIsNone(self.contents("history/latest.meta.json"))
        self.assertIsNone(self.contents("history/2026-11-06-merge-7654321.cg.json"))
        self.assertEqual(self.contents("history/2026-11-05-merge-1234567.cg.json"), b"old")

    def test_legacy_history_still_copies_graph_and_metadata(self):
        graph = self.root / "new.cg.json"
        graph.write_bytes(b"new-graph")
        meta = self.root / "new.meta.json"
        meta.write_bytes(b"new-meta")
        self.publish("history", SOURCE_CG_PATH=str(graph), SOURCE_META_PATH=str(meta))
        self.assertEqual(self.contents("history/latest.cg.json"), b"new-graph")
        self.assertEqual(self.contents("history/latest.meta.json"), b"new-meta")
        self.assertEqual(self.contents("history/2026-11-06-merge-7654321.cg.json"), b"new-graph")

    def test_set_latest_does_not_retain_another_snapshots_sidecars(self):
        new = self.seed / "projects/example/history/2026-11-06-merge-7654321.cc.json.gz"
        new.write_bytes(b"newest-map")
        self.git("-C", str(self.seed), "add", ".")
        self.git("-C", str(self.seed), "-c", "commit.gpgsign=false", "commit", "-m", "New map")
        self.git("-C", str(self.seed), "push", "origin", "main")
        self.publish("set-latest")
        self.assertEqual(self.contents("history/latest.cc.json.gz"), b"newest-map")
        self.assertIsNone(self.contents("history/latest.cg.json"))
        self.assertIsNone(self.contents("history/latest.meta.json"))


if __name__ == "__main__":
    unittest.main()
