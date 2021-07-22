import csv
import os
import unittest

import mcvqoe.mouth2ear
import mcvqoe.simulation
import pkg_resources

try:
    # try to import importlib.metadata
    from importlib.metadata import entry_points
except ModuleNotFoundError:
    # fall back to importlib_metadata
    from importlib_metadata import entry_points


class MeasureTest(unittest.TestCase):
    def assert_tol(self, x, y, tol=0, msg=None):
        self.assertGreaterEqual(x, y - tol, msg)
        self.assertLessEqual(x, y + tol, msg)

    def test_basic(self):
        test_obj = mcvqoe.mouth2ear.measure()
        test_obj.ptt_wait = 0
        test_obj.ptt_gap = 0
        test_obj.param_check()
        sim_obj = mcvqoe.simulation.QoEsim()

        test_obj.audio_interface = sim_obj
        test_obj.ri = sim_obj

        techs = [e.name for e in entry_points()["mcvqoe.channel"]]
        for dly in [0.030, 0.3, 0.6]:
            sim_obj.m2e_latency = dly
            for tech in techs:
                sim_obj.channel_tech = tech
                # construct string for system name
                system = sim_obj.channel_tech
                if sim_obj.channel_rate is not None:
                    system += " at " + str(sim_obj.channel_rate)
                test_obj.info = {}
                test_obj.info["Test Type"] = "simulation"
                test_obj.info["tx_dev"] = "none"
                test_obj.info["rx_dev"] = "none"
                test_obj.info["system"] = system
                test_obj.info["test_loc"] = "N/A"

                test_obj.run()
                with open(test_obj.data_filename, newline="") as f:
                    reader = csv.reader(f)
                    next(reader)

                    clip_names = os.listdir(
                        pkg_resources.resource_filename("mcvqoe.mouth2ear", "audio_clips/")
                    )
                    clip_names = list(map(lambda x: x.split(".")[0], clip_names))

                    for row in reader:
                        self.assertIn(row[1], clip_names)
                        self.assert_tol(float(row[2]), dly, 0.01)
                        self.assertEqual(row[3], "(rx_voice)")


if __name__ == "__main__":
    unittest.main()
