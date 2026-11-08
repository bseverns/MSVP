from pathlib import Path
import unittest


class FrZoneAnalysisInputContractTest(unittest.TestCase):
    def test_canonical_frzone_ccs_are_additive_analysis_inputs(self):
        source = (Path(__file__).parents[1] / "MidiVideoSyphonBeats" / "RigMapping.pde").read_text()
        self.assertIn("applyFrZoneAnalysisMapping(number, value)", source)
        for cc, target in ((20, "linesPerFrame"), (22, "maxLineSize"), (23, "opacityMin"), (24, "effectBias")):
            self.assertIn(f'number == {cc}', source)
            self.assertIn(f'biasParam("{target}", normalized)', source)


if __name__ == "__main__":
    unittest.main()
