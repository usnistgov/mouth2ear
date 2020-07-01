#!/usr/bin/env python3

"""
***m2e_buffer_test.py runs a mouth-to-ear latency test. Without the optional arguments, this test
will run 10 trials playing test.wav into the radio.***
"""


import argparse
import queue
import sys
import threading
import time

from radioInterface import RadioInterface
import sounddevice as sd
import soundfile as sf
from fractions import Fraction
import scipy.signal
import scipy.io.wavfile
import numpy
import os


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

parser = argparse.ArgumentParser(
    description=__doc__)
parser.add_argument(
                    '-a', '--audiofile', default='test.wav',
                    help='Choose audiofile to use for test. Defaults to test.wav')
parser.add_argument(
                    '-t', '--trials', type=int, default=10,
                    help='NUmber of trials to use for test. Defaults to 10')
parser.add_argument("-r", "--radioport", default="",
                    help="Port to use for radio interface. Defaults to the first"+
                    " port where a radio interface is detected")
parser.add_argument("-pw", "--pttwait", type=float, default=0.68,
                    help="The amount of time to wait in seconds between pushing the"+
                    " push to talk button and starting playback. This allows time "+
                    "for access to be granted on the system. Default value is 0.68 seconds")
parser.add_argument(
                    '-b', '--blocksize', type=int, default=512,
                    help='block size (default: %(default)s)')
parser.add_argument(
                    '-q', '--buffersize', type=int, default=20,
                    help='number of blocks used for buffering (default: %(default)s)')
parser.add_argument(
                    "-od", "--outdir", default="", help="Directory that is added to the "+
                    "output path for all files")
args = parser.parse_args()
if args.blocksize == 0:
    parser.error('blocksize must not be zero')
if args.buffersize < 1:
    parser.error('buffersize must be at least 1')

#Create output WAVE file directory
datadir = os.path.join(args.outdir,'data')
os.makedirs(datadir,exist_ok=True)

device_name=find_device()
print(device_name,flush=True)
sd.default.device=device_name

#Set for mono play/rec
sd.default.channels = [1, 1]

#Desired samplerate
fs=int(48e3)

#Open Radio Interface
ri = RadioInterface(args.radioport)
ri.led(1, True)

#Callback function for the stream
#Will run as long as there is audio data to play
#Currently setup to play mono audio files
def callback(indata, outdata, frames, time, status):
    
    #Record the output
    qr.put_nowait(indata.copy())
    
    if status.output_underflow:
        print('Output underflow: increase blocksize?', file=sys.stderr)
        raise sd.CallbackAbort
    assert not status
    try:
        data = q.get_nowait()
    except queue.Empty:
        print('Buffer is empty: increase buffersize?', file=sys.stderr)
        raise sd.CallbackAbort
    if data.size < outdata.size:
        outdata[:len(data),0] = data
        outdata[len(data):] = 0
        raise sd.CallbackStop
    else:
        #One column for mono output
        outdata[:,0] = data

for itr in range(1, args.trials+1):
    try:
        
        #Queue for recording input
        qr = queue.Queue()
        #Queue for output WAVE file
        q = queue.Queue(maxsize=args.buffersize)
        
        #Gather audio data in numpy array and audio samplerate
        fs_file, audio_dat = scipy.io.wavfile.read(args.audiofile)
        #Calculate resample factors
        rs_factor = Fraction(fs/fs_file)
        #Convert to float sound array
        audio_dat = audio_float(audio_dat)
        #Resample audio
        audio = scipy.signal.resample_poly(audio_dat,rs_factor.numerator,rs_factor.denominator)
        
        event = threading.Event()
        
        #NumPy audio array placeholder
        arr_place = 0
        
        #Press the push to talk button
        ri.ptt(True)
        
        #Pause the indicated amount to allow the radio to access the system
        time.sleep(args.pttwait)
        
        for x in range(args.buffersize):
            
            data_slice = audio[args.blocksize*x:(args.blocksize*x)+args.blocksize]
            
            if data_slice.size == 0:
                break
            
            #Save place of NumPy array slice for next loop
            arr_place += args.blocksize
            
            #Pre-fill queue
            q.put_nowait(data_slice)  
        
        #Output and input stream in one
        #Latency of zero to try and cut down delay    
        stream = sd.Stream(   
            blocksize=args.blocksize, samplerate=fs,
            dtype='float32', callback=callback, finished_callback=event.set,
            latency=0)
        
        filename = 'output'+str(itr)+'.wav'
        filename = os.path.join(datadir,filename)
        
        with sf.SoundFile(filename, mode='x', samplerate=fs,
                          channels=1) as rec_file:
            with stream:
                timeout = args.blocksize * args.buffersize / fs
                
                #For grabbing next blocksize slice of the NumPy audio array
                itrr = 0
                
                while data_slice.size != 0:
                    
                    data_slice = audio[arr_place+(args.blocksize*itrr):arr_place+(args.blocksize*itrr)+args.blocksize]
                    itrr += 1
                    
                    q.put(data_slice, timeout=timeout)
                    rec_file.write(qr.get())
                #Wait until playback is finished
                event.wait()  
                
            #Make sure to write any audio data still left in the recording queue
            while (qr.empty() != True):
                rec_file.write(qr.get())
            
            #Release the push to talk button
            ri.ptt(False)
            
            #add a pause after playing/recording to remove run to run dependencies
            time.sleep(3.1)
            
    except KeyboardInterrupt:
        parser.exit('\nInterrupted by user')
    except queue.Full:
        #A timeout occurred, i.e. there was an error in the callback
        parser.exit(1)
    except Exception as e:
        parser.exit(type(e).__name__ + ': ' + str(e))

ri.led(1, False)