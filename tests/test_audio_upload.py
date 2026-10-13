"""Offline upload safety regressions. No credentials or HTTP requests are used."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import wave

UPLOAD = Path(__file__).resolve().parents[1] / "tools/upload"
sys.path.insert(0, str(UPLOAD))
spec = importlib.util.spec_from_file_location("moving_day_audio", UPLOAD / "audio.py")
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


class AudioUploadTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        self.patch_root = patch.object(audio, "ROOT", self.root)
        self.patch_root.start()
        (self.root / "assets/audio").mkdir(parents=True)
        (self.root / "assets/registry.json").write_text("[]", encoding="utf-8")
        self.file = self.root / "assets/audio/test.wav"
        with wave.open(str(self.file), "wb") as stream:
            stream.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
            stream.writeframes(b"\0\0" * 2205)
        self.env = {"ROBLOX_API_KEY": "offline-fixture", "ROBLOX_CREATOR_GROUP_ID": "485719152"}
        self.request = patch.object(audio.smoke, "request", side_effect=AssertionError("Unexpected HTTP"))
        self.http = self.request.start()
        self.generate = patch.object(audio.runpy, "run_path")
        self.generated = self.generate.start()

    def tearDown(self):
        self.generate.stop()
        self.request.stop()
        self.patch_root.stop()
        self.temporary.cleanup()

    def test_preflight_and_rejections_never_send(self):
        self.assertEqual(audio.upload("SFX_Test", self.file, {})["status"], "LOCAL_PREFLIGHT_PASS")
        self.assertEqual(audio.upload("SFX_Test", self.file, {}, submit=True)["status"], "MISSING_KEY_OR_MOVING_DAY_GROUP")
        for name, file in [("../escape", self.file), ("SFX_Test", self.root / "outside.wav")]:
            with self.assertRaises(ValueError):
                audio.upload(name, file, {})
        with self.assertRaises(ValueError):
            audio.upload("SFX_Test", self.file, {**self.env, "ROBLOX_UNIVERSE_ID": "1"}, submit=True)
        self.file.write_bytes(self.file.read_bytes()[:-20])
        with self.assertRaises(ValueError):
            audio.upload("SFX_Test", self.file, {})
        self.http.assert_not_called()

    def test_success_registers_once_and_disallows_fee(self):
        def respond(path, _key, data=None, _content_type=None):
            if data is not None:
                self.assertEqual(path, "/assets/v1/assets")
                self.assertIn(b'"expectedPrice": 0', data)
                self.assertIn(b'"assetType": "Audio"', data)
                self.assertIn(b"Content-Type: audio/wav", data)
                return 200, {"path": "operations/test"}
            return 200, {"done": True, "response": {"assetId": "123"}}
        self.http.side_effect = respond
        self.assertEqual(audio.upload("SFX_Test", self.file, self.env, submit=True)["status"], "UPLOAD_PASS")
        self.assertEqual(audio.upload("SFX_Test", self.file, self.env, submit=True)["status"], "ALREADY_REGISTERED")
        self.assertEqual(self.http.call_count, 2)
        registry = json.loads((self.root / "assets/registry.json").read_text())
        self.assertEqual(len(registry), 1)
        self.assertEqual(registry[0]["file"], "assets/audio/test.wav")
        self.generated.assert_called_once()

    def test_unknown_submission_cannot_duplicate(self):
        self.http.side_effect = None
        self.http.return_value = (0, {})
        self.assertEqual(audio.upload("SFX_Test", self.file, self.env, submit=True)["status"], "HTTP_0")
        self.assertEqual(audio.upload("SFX_Test", self.file, self.env, submit=True)["status"], "PRIOR_SUBMISSION_REQUIRES_RECONCILIATION")
        self.assertEqual(self.http.call_count, 1)
        self.assertEqual(json.loads((self.root / "assets/registry.json").read_text()), [])

    def test_resume_polls_original_and_checks_source_digest(self):
        self.http.side_effect = [(200, {"path": "operations/existing"}), (503, {})]
        self.assertEqual(audio.upload("SFX_Test", self.file, self.env, submit=True)["status"], "POLL_HTTP_503")
        content = self.file.read_bytes()
        self.file.write_bytes(content[:-2] + b"\1\0")
        with self.assertRaises(ValueError):
            audio.upload("SFX_Test", self.file, self.env, submit=True)
        self.file.write_bytes(content)
        self.http.side_effect = [(200, {"done": True, "response": {"assetId": "456"}})]
        result = audio.upload("SFX_Test", self.file, self.env, submit=True)
        self.assertEqual(result["assetId"], "456")
        self.assertEqual(self.http.call_args.args, ("/assets/v1/operations/existing", "offline-fixture"))
        self.assertEqual(self.http.call_count, 3)


if __name__ == "__main__":
    unittest.main()
