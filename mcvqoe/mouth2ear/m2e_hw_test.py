#!/usr/bin/env python

import argparse
import mcvqoe.hardware
import mcvqoe.gui
import os

from contextlib import nullcontext
from .m2e import measure

import numpy as np   

def main():
    
    # Create M2E object
    test_obj = measure()
    #set end notes function
    test_obj.get_post_notes=mcvqoe.gui.post_test

    #-------------------------[Create audio interface]-------------------------
    
    test_obj.audio_interface=mcvqoe.hardware.AudioPlayer()
    
    #--------------------[Parse the command line arguments]--------------------
    
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-y', '--testtype', dest="test", default=test_obj.test, metavar="TEST",
                        help="M2E test to perform. Options are: '1loc', '2loc_tx', and "+
                        "'2loc_rx'. Defaults to 1 location ('1loc')")
    parser.add_argument(
                        '-a', '--audio-files', default=[], action="extend", nargs="+", type=str, metavar='FILENAME',
                        help='Path to audio files to use for test. Cutpoint files must also be present')
    parser.add_argument(
                        '-f', '--audio-path', default=test_obj.audio_path, type=str,
                        help='Path to look for audio files in. All audio file paths are relative to this unless they are absolute')
    parser.add_argument('-t', '--trials', type=int, default=test_obj.trials, metavar="T",
                        help="Number of trials to use for test. Defaults to 100")
    parser.add_argument('-r', '--radioport', default='', metavar="PORT",
                        help="Port to use for radio interface. Defaults to the first"+
                        " port where a radio interface is detected")
    parser.add_argument('-z', '--bgnoisefile', dest="bgnoise_file", default='', help="If this is"+
                        " non empty then it is used to read in a noise file to be mixed with the "+
                        "test audio. Default is no background noise")
    parser.add_argument('-N', '--bgnois-snr', dest="bgnoise_snr", type=float,
                        default=test_obj.bgnoise_snr,
                        help="Signal to noise ratio for background noise. "
                        "Defaults to %(default) dB."
                        )
    parser.add_argument('-w', '--pttwait', dest="ptt_wait", type=float, default=test_obj.ptt_wait,
                        metavar="T", help="The amount of time to wait in seconds between pushing the"+
                        " push to talk button and starting playback. This allows time "+
                        "for access to be granted on the system. Default value is 0.68 seconds")
    parser.add_argument('-b', '--blocksize', type=int, default=test_obj.audio_interface.blocksize, metavar="SZ",
                        help="Block size for transmitting audio, must be a power of 2 "+
                        "(default: %(default)s)")
    parser.add_argument('-q', '--buffersize', type=int, default=test_obj.audio_interface.buffersize, metavar="SZ",
                        help="Number of blocks used for buffering audio (default: %(default)s)")
    parser.add_argument('-o', '--overplay', type=float, default=test_obj.audio_interface.overplay, metavar="DUR",
                        help="The number of seconds to play silence after the audio is complete"+
                        ". This allows for all of the audio to be recorded when there is delay"+
                        " in the system")
    parser.add_argument('-d', '--outdir', default=test_obj.outdir, metavar="DIR",
                        help="Directory that is added to the output path for all files")
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

    # ---------------------[Set audio interface properties]---------------------

    test_obj.audio_interface.blocksize = args.blocksize
    test_obj.audio_interface.buffersize = args.buffersize
    test_obj.audio_interface.overplay = args.overplay

    # set correct channels
    if test_obj.test == "1loc":
        test_obj.audio_interface.playback_chans = {"tx_voice": 0}
        test_obj.audio_interface.rec_chans = {"rx_voice": 0}
    elif test_obj.test == "2loc_tx":
        test_obj.audio_interface.playback_chans = {"tx_voice": 0}
        test_obj.audio_interface.rec_chans = {"IRIGB_timecode": 1}
    elif test_obj.test == "2loc_rx":
        test_obj.audio_interface.playback_chans = {}
        test_obj.audio_interface.rec_chans = {"rx_voice": 0, "IRIGB_timecode": 1}

    # ---------------------------[Open RadioInterface]---------------------------

    with mcvqoe.hardware.RadioInterface(args.radioport) \
        if test_obj.test != "2loc_rx" else nullcontext() as test_obj.ri:

        # ------------------------------[Get test info]------------------------------

        if(test_obj.test != "2loc_rx"):
            #Check function, test play through the system
            chk_fun=lambda: mcvqoe.hardware.single_play(
                                                    test_obj.ri,
                                                    test_obj.audio_interface,
                                                    ptt_wait=test_obj.ptt_wait
                                                )
        else:
            #no check function, will need to rely on the transmit side for check
            chk_fun = None

        test_obj.info = mcvqoe.gui.pretest(
            args.outdir,
            check_function=chk_fun,
        )

        # ------------------------------[Run Test]------------------------------

        test_obj.run()
        print(f"Test complete, data saved in '{test_obj.data_filename}'")

if __name__ == "__main__":

    main()