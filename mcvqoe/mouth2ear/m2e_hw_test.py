#!/usr/bin/env python

import argparse
import mcvqoe.hardware
import mcvqoe.gui
import os

from .m2e import measure

import matplotlib.pyplot as plt
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
                        help="M2E test to perform. Options are: 'm2e_1loc', 'm2e_2loc_tx', and "+
                        "'m2e_2loc_rx'. Defaults to 1 location ('m2e_1loc')")
    parser.add_argument('-a', '--audiofile', dest="audio_file", default=test_obj.audio_file,
                        metavar="FILENAME", help="Choose audiofile to use for test. Defaults to test.wav")
    parser.add_argument('-t', '--trials', type=int, default=test_obj.trials, metavar="T",
                        help="Number of trials to use for test. Defaults to 100")
    parser.add_argument('-r', '--radioport', default='', metavar="PORT",
                        help="Port to use for radio interface. Defaults to the first"+
                        " port where a radio interface is detected")
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
    parser.add_argument('--plot',dest='show_plot',action='store_true',default=True,
                        help='Don\'t plot data after test')
    parser.add_argument('--no-plot',dest='show_plot',action='store_false',
                        help='Don\'t plot data after test')
    
    args = parser.parse_args()
    
    # Set M2E object variables to terminal arguments
    for k, v in vars(args).items():
        if hasattr(test_obj, k):
            setattr(test_obj, k, v)
    
    # Check for value errors with M2E instance variables
    test_obj.param_check()
    
    #---------------------[Set audio interface properties]---------------------
    test_obj.audio_interface.blocksize=args.blocksize
    test_obj.audio_interface.buffersize=args.buffersize
    test_obj.audio_interface.overplay=args.overplay
    
    #set correct channels    
    if(test_obj.test == "m2e_1loc"):
        test_obj.audio_interface.playback_chans={'tx_voice':0}
        test_obj.audio_interface.rec_chans={'rx_voice':0}
    elif(test_obj.test == "m2e_2loc_tx"):
        test_obj.audio_interface.playback_chans={'tx_voice':0}
        test_obj.audio_interface.rec_chans={'timecode':1}
    elif(test_obj.test == "m2e_2loc_rx"):
        test_obj.audio_interface.playback_chans={}
        test_obj.audio_interface.rec_chans={'rx_voice':0,'timecode':1}
    
    #---------------------------[Open RadioInterface]---------------------------
    
    with mcvqoe.hardware.RadioInterface(args.radioport) as test_obj.ri:

        #------------------------------[Get test info]------------------------------
        test_obj.info=mcvqoe.gui.pretest(args.outdir,
                    check_function=lambda : mcvqoe.hardware.single_play(
                                                    test_obj.ri,test_obj.audio_interface,
                                                    ptt_wait=test_obj.ptt_wait))
        #------------------------------[Run Test]------------------------------
        test_obj.run()
        print(f'Test complete, data saved in \'{test_obj.data_filename}\'')
    
    #------------------------------[Plot Data]------------------------------
    if(args.show_plot):
        test_obj.plot()


    
if __name__ == "__main__":
    
    main()