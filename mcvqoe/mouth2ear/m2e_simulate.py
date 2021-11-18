#!/usr/bin/env python

import argparse
import mcvqoe.simulation
import mcvqoe.hardware
import mcvqoe.gui
import os
import sys

from .m2e import measure

import numpy as np


def main():

    # Create M2E object
    test_obj = measure()
    # only get test notes on error
    test_obj.get_post_notes = lambda: mcvqoe.gui.post_test(error_only=True)
    # set wait times to zero for simulation
    test_obj.ptt_wait = 0
    test_obj.ptt_gap = 0
    #don't save audio for simulation
    test_obj.save_tx_audio = False
    test_obj.save_audio = False

    # ------------------------[Create simulation object]------------------------

    sim_obj = mcvqoe.simulation.QoEsim()

    test_obj.audio_interface = sim_obj
    test_obj.ri = sim_obj
    
    #--------------------[Parse the command line arguments]--------------------
    
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-a', '--audio-files', default=[], action="extend", nargs="+", type=str, metavar='FILENAME',
                        help='Path to audio files to use for test. Cutpoint files must also be present')
    parser.add_argument('-f', '--audio-path', default=test_obj.audio_path, type=str,
                        help='Path to look for audio files in. All audio file paths are relative to this unless they are absolute')
    parser.add_argument('-t', '--trials', type=int, default=test_obj.trials, metavar="T",
                        help="Number of trials to use for test. Defaults to 100")
    parser.add_argument('-z', '--bgnoisefile', dest="bgnoise_file", default='', help="If this is"+
                        " non empty then it is used to read in a noise file to be mixed with the "+
                        "test audio. Default is no background noise")
    parser.add_argument('-v', '--bgnoisevolume', dest="bgnoise_volume", type=float,
                        default=test_obj.bgnoise_volume, help="Scale factor for background"+
                        " noise. Defaults to 0.1")
    parser.add_argument('-w', '--pttwait', dest="ptt_wait", type=float, default=test_obj.ptt_wait,
                        metavar="T", help="The amount of time to wait in seconds between pushing the"+
                        " push to talk button and starting playback. This allows time "+
                        "for access to be granted on the system. Default value is 0.68 seconds")
    parser.add_argument('-o', '--overplay', type=float, default=test_obj.audio_interface.overplay, metavar="DUR",
                        help="The number of seconds to play silence after the audio is complete"+
                        ". This allows for all of the audio to be recorded when there is delay"+
                        " in the system")
    parser.add_argument('-d', '--outdir', default=test_obj.outdir, metavar="DIR",
                        help="Directory that is added to the output path for all files")
    parser.add_argument('-c', '--channel-tech', default=sim_obj.channel_tech, metavar='TECH', dest='channel_tech',
                        help='Channel technology to simulate (default: %(default)s)')
    parser.add_argument('--channel-rate', default=sim_obj.channel_rate, metavar='RATE', dest='channel_rate',
                        help='Channel technology rate to simulate. Passing \'None\' will use the technology default. (default: %(default)s)')
    parser.add_argument('--channel-m2e', type=float, default=sim_obj.m2e_latency, metavar='L',dest='m2e_latency',
                        help='Channel mouth to ear latency, in seconds, to simulate. (default: %(default)s)')
    parser.add_argument('-F', '--full-audio-dir', dest='full_audio_dir', action='store_true', default=False,
                        help='ignore --audioFiles and use all files in --audioPath')
    parser.add_argument('--no-full-audio-dir', dest='full_audio_dir', action='store_false',
                        help='use --audioFiles to determine which audio clips to read')
    parser.add_argument('--save-tx-audio', dest='save_tx_audio',
                        action='store_true',
                        help='Save transmit audio in wav directory')
    parser.add_argument('--no-save-tx-audio', dest='save_tx_audio',
                        action='store_false',
                        help='Don\'t save transmit audio in wav directory')
    parser.add_argument('--save-audio', dest='save_audio', action='store_true',
                        help='Save audio in the wav directory')
    parser.add_argument('--no-save-audio', dest='save_audio', action='store_false',
                        help='Don\'t save audio in the wav directory, implies'+
                        '--no-save-tx-audio')
                        
    args = parser.parse_args()

    # check if audio files were given
    if not args.audio_files:
        # remove audio_files (keep default value)
        delattr(args, "audio_files")

    # Set M2E object variables to terminal arguments
    for k, v in vars(args).items():
        if hasattr(test_obj, k):
            setattr(test_obj, k, v)

    # Check for value errors with M2E instance variables
    test_obj.param_check()

    # -------------------------[Set simulation settings]-------------------------

    sim_obj.channel_tech = args.channel_tech

    # set channel rate, check for None
    if args.channel_rate == "None":
        sim_obj.channel_rate = None
    else:
        sim_obj.channel_rate = args.channel_rate

    sim_obj.m2e_latency = args.m2e_latency
    test_obj.audio_interface.overplay = args.overplay

    # set correct channels
    test_obj.audio_interface.playback_chans = {"tx_voice": 0}
    test_obj.audio_interface.rec_chans = {"rx_voice": 0}

    # ------------------------------[Get test info]------------------------------

    gui = mcvqoe.gui.TestInfoGui(write_test_info=False)

    gui.chk_audio_function = lambda: mcvqoe.hardware.single_play(
        sim_obj, sim_obj, playback=True, ptt_wait=test_obj.ptt_wait
    )

    # construct string for system name
    system = sim_obj.channel_tech
    if sim_obj.channel_rate is not None:
        system += " at " + str(sim_obj.channel_rate)

    gui.info_in["test_type"] = "simulation"
    gui.info_in["tx_dev"] = "none"
    gui.info_in["rx_dev"] = "none"
    gui.info_in["system"] = system
    gui.info_in["test_loc"] = "N/A"
    test_obj.info = gui.show()

    # check if the user canceled
    if test_obj.info is None:
        print(f"\n\tExited by user")
        sys.exit(1)

    # ------------------------------[Run Test]------------------------------
    
    test_obj.run()
    print(f'Test complete, data saved in \'{test_obj.data_filename}\'')


if __name__ == "__main__":

    main()