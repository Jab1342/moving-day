"""Offline animation operation/replay tests; never reads .env or sends HTTP."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/upload"))
import animations


class AnimationUploadTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "assets/anim").mkdir(parents=True)
        (self.root / "assets/registry.json").write_text("[]")
        self.file = self.root / "assets/anim/MD_Strap.rbxm"
        self.file.write_bytes(b"<roblox!offline-fixture")
        self.env = {"ROBLOX_API_KEY": "offline-fixture", "ROBLOX_CREATOR_GROUP_ID": "485719152"}
        self.patch = patch.object(animations, "ROOT", self.root)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        network = patch.object(animations.smoke, "request", side_effect=AssertionError("Unexpected HTTP"))
        self.http = network.start()
        self.addCleanup(network.stop)
        generator = patch.object(animations.runpy, "run_path")
        self.generated = generator.start()
        self.addCleanup(generator.stop)

    def upload(self, env=None):
        return animations.upload("ANIM_Strap", "MD_Strap.rbxm", self.env if env is None else env)

    def test_target_and_source_guards(self):
        self.assertEqual(self.upload({})["status"], "MISSING_KEY_OR_GROUP")
        with self.assertRaises(ValueError):
            self.upload({**self.env, "ROBLOX_PLACE_ID": "1"})
        with self.assertRaises(ValueError):
            animations.upload("ANIM_Strap", "../other.rbxm", self.env)
        self.file.write_bytes(b"invalid")
        with self.assertRaises(ValueError):
            self.upload()
        self.http.assert_not_called()

    def test_unknown_submission_never_duplicates(self):
        self.http.side_effect = [(0, {})]
        self.assertEqual(self.upload()["status"], "HTTP_0")
        self.assertEqual(self.upload()["status"], "PRIOR_SUBMISSION_REQUIRES_RECONCILIATION")
        self.assertEqual(self.http.call_count, 1)

    def test_resume_checks_source_and_registers_once(self):
        self.http.side_effect = [(200, {"path": "operations/original"}), (503, {})]
        self.assertEqual(self.upload()["status"], "POLL_HTTP_503")
        original = self.file.read_bytes()
        self.file.write_bytes(original + b"changed")
        self.assertEqual(self.upload()["status"], "SOURCE_CHANGED_REQUIRES_RECONCILIATION")
        self.assertEqual(self.http.call_count, 2)
        self.file.write_bytes(original)
        self.http.side_effect = [(200, {"done": True, "response": {"assetId": "123"}})]
        self.assertEqual(self.upload()["status"], "UPLOAD_PASS")
        self.assertEqual(self.http.call_args.args[0], "/assets/v1/operations/original")
        self.assertEqual(self.upload()["status"], "ALREADY_REGISTERED")
        self.assertEqual(self.http.call_count, 3)
        registry = json.loads((self.root / "assets/registry.json").read_text())
        self.assertEqual(registry, [{"name": "ANIM_Strap", "type": "Animation", "assetId": "123", "uploadedBy": "Codex", "file": "assets/anim/MD_Strap.rbxm"}])
        self.generated.assert_called_once()


if __name__ == "__main__":
    unittest.main()
