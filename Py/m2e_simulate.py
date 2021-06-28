#!/usr/bin/env python

import argparse
import m2e
import mcvqoe.simulation
import mcvqoe.hardware
import mcvqoe.gui
import os

import matplotlib.pyplot as plt
import numpy as np   

def main():
    
    # Create M2E object
    test_obj = m2e.measure()
    #only get test notes on error
    test_obj.get_post_notes=lambda : mcvqoe.gui.post_test(error_only=True)
    #set wait times to zero for simulation
    test_obj.ptt_wait=0
    test_obj.ptt_gap=0

    #------------------------[Create simulation object]------------------------
    sim_obj=mcvqoe.simulation.QoEsim()
    
    test_obj.audio_interface=sim_obj
    test_obj.ri=sim_obj
    
    #--------------------[Parse the command line arguments]--------------------
    
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('-a', '--audiofile', dest="audio_file", default=test_obj.audio_file,
                        metavar="FILENAME", help="Choose audiofile to use for test. Defaults to test.wav")
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
    parser.add_argument('-c','--channel-tech', default=sim_obj.channel_tech, metavar='TECH',dest='channel_tech',
                        help='Channel technology to simulate (default: %(default)s)')
    parser.add_argument('--channel-rate', default=sim_obj.channel_rate, metavar='RATE',dest='channel_rate',
                        help='Channel technology rate to simulate. Passing \'None\' will use the technology default. (default: %(default)s)')
    parser.add_argument('--channel-m2e', type=float, default=sim_obj.m2e_latency, metavar='L',dest='m2e_latency',
                        help='Channel mouth to ear latency, in seconds, to simulate. (default: %(default)s)')
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
    
    #-------------------------[Set simulation settings]-------------------------

    sim_obj.channel_tech=args.channel_tech
    
    #set channel rate, check for None
    if(args.channel_rate=='None'):
        sim_obj.channel_rate=None
    else:
        sim_obj.channel_rate=args.channel_rate
        
    sim_obj.m2e_latency=args.m2e_latency
    test_obj.audio_interface.overplay=args.overplay
    
    #set correct channels    
    test_obj.audio_interface.playback_chans={'tx_voice':0}
    test_obj.audio_interface.rec_chans={'rx_voice':0}

#------------------------------[Get test info]------------------------------
    
    gui=mcvqoe.gui.TestInfoGui(write_test_info=False)
    
    gui.chk_audio_function=lambda : mcvqoe.hardware.single_play(sim_obj,sim_obj,
                                                    playback=True,
                                                    ptt_wait=test_obj.ptt_wait)

    #construct string for system name
    system=sim_obj.channel_tech
    if(sim_obj.channel_rate is not None):
        system+=' at '+str(sim_obj.channel_rate)

    gui.info_in['test_type'] = "simulation"
    gui.info_in['tx_dev'] = "none"
    gui.info_in['rx_dev'] = "none"
    gui.info_in['system'] = system
    gui.info_in['test_loc'] = "N/A"
    test_obj.info=gui.show()

    #check if the user canceled
    if(test_obj.info is None):
        print(f"\n\tExited by user")
        sys.exit(1)
        
    #------------------------------[Run Test]------------------------------
    test_obj.run()
    print(f'Test complete, data saved in \'{test_obj.data_filename}\'')
    
    #------------------------------[Plot Data]------------------------------
    if(args.show_plot):
        test_obj.plot()


    
if __name__ == "__main__":
    
    main()