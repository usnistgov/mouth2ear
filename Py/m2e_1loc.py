#!/usr/bin/env python
"""
***m2e_1loc.py runs a mouth-to-ear latency test. Without the optional arguments, this test 
will run 10 trials playing test.wav into the radio.***
"""
import argparse
import time

from radioInterface import RadioInterface

import sounddevice as sd
import scipy.io.wavfile
import scipy.signal
from fractions import Fraction
import os
import numpy
assert numpy


def find_device():
    
    devs=sd.query_devices()
    
    for d in devs:
        if(d['max_input_channels']>0 and d['max_output_channels']>0 and  'UMC' in d['name']):
            return d['name']
            
def audio_float(dat):
    if(dat.dtype is numpy.dtype('uint8')):
        return (dat.astype('float')-128)/128
    if(dat.dtype is numpy.dtype('int16')):
        return dat.astype('float')/(2**15)
    if(dat.dtype is numpy.dtype('int32')):
        return dat.astype('float')/(2**31)
    if(dat.dtype is numpy.dtype('float32')):
        return dat

#parse the command line arguments
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("-a", "--audiofile", default="test.wav" ,
                    help="Choose audiofile to use for test. Defaults to test.wav")
parser.add_argument("-t", "--trials", type=int, default=10,
                    help="Number of trials to use for test. Defaults to 10")
parser.add_argument("-r", "--radioport", default="",
                    help="Port to use for radio interface. Defaults to the first"+
                    " port where a radio interface is detected")
parser.add_argument("-bf", "--bgnoisefile", default="", help="If this is non empty then it is"+
                    " used to read in a noise file to be mixed with the test audio. "+
                    "Default is no background noise")
parser.add_argument("-bg", "--bgnoisevolume", type=float, default=0.1,
                    help="Scale factor for background noise. Defaults to 0.1")
parser.add_argument("-as", "--audioskip", type=float, default=0.0,
                    help="Number of seconds at the beginning of the audio clip"+
                    " to skip during playback. Defaults to 0.0")
parser.add_argument("-pw", "--pttwait", type=float, default=0.68,
                    help="The amount of time to wait in seconds between pushing the"+
                    " push to talk button and starting playback. This allows time "+
                    "for access to be granted on the system. Default value is 0.68 seconds")
parser.add_argument("-op", "--overplay", type=float, default=0.0, help="The number of"+
                    " seconds to play silence after the audio is complete. This allows"+
                    " for all of the audio to be recorded when there is delay in the system")
parser.add_argument("-od", "--outdir", default="", help="Directory that is added to the "+
                    "output path for all files")
args = parser.parse_args()


datadir=os.path.join(args.outdir,'data')

os.makedirs(datadir,exist_ok=True)

device_name=find_device()

print(device_name,flush=True)

sd.default.device=device_name

#sample rate for recording
fs=int(48e3)

#read in audio data
fs_file, audio_dat = scipy.io.wavfile.read(args.audiofile)

#convert to float sound array
audio_dat=audio_float(audio_dat)

#calculate resample factors
rs_factor=Fraction(fs/fs_file)

#resample audio
y=scipy.signal.resample_poly(audio_dat,rs_factor.numerator,rs_factor.denominator)

#Open Radio Interface
ri = RadioInterface(args.radioport)

ri.led(1, True)

#output channels 1, input channels 1
sd.default.channels = [1, 1]

for x in range(0, args.trials):
    
    #push the push to talk button
    ri.ptt(True)
    
    #pause the indicated amount to allow the radio to access the system
    time.sleep(args.pttwait)
    
    #play and record audio data
    try:

        myrec = sd.playrec(y, fs, blocking=True)
        
        filename = 'output' + str(x+1) + '.wav'
        filename = os.path.join(datadir,filename)
        scipy.io.wavfile.write(filename, fs, myrec)

    #if ctrl c is used within this loop
    except KeyboardInterrupt:
        ri.ptt(False)
        ri.led(1, False)
        parser.exit('\nInterrupted by user')
    except Exception as e:
        parser.exit(type(e).__name__ + ': ' + str(e))
    
    #release the push to talk button
    ri.ptt(False)
    
    #add a pause after play_record to remove run to run dependencies
    time.sleep(3.1)
    
ri.led(1, False)