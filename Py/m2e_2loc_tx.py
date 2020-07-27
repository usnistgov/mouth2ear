#!/usr/bin/env python
'''
M2E_2LOC_TX runs the transmit side of a two location mouth to ear latency test
This test will run 100 trials playing test.wav into the radio

See also m2e_2loc_rx and m2e_2loc_process
'''

'''
This software was developed by employees of the National Institute of Standards 
Technology (NIST), an agency of the Federal Government. Pursuant to title 17
United States Code Section 105, works of NIST employees are not subject to 
copyright protection in the United States and are considered to be in the public 
domain. Permission to freely use, copy, modify, and distribute this software and
its documentation without fee is hereby granted, provided that this notice and
disclaimer of warranty appears in all copies.

THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
FREDDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
OUT OF, RESULTING FROM , OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
USE OF, THE SOFTWARE OR SERVICE PROVIDED HEREUNDER.
'''

import scipy.io.wavfile
import scipy.signal
import threading
import argparse
import datetime
import queue
import time
import sys
import os

from radioInterface import RadioInterface
from tkinter import scrolledtext
from fractions import Fraction

import sounddevice as sd
import soundfile as sf
import tkinter as tk
import numpy as np

#============================[Helper Functions]============================

def find_device():
    
    devs=sd.query_devices()
    
    for d in devs:
        if(d['max_input_channels']>0 and d['max_output_channels']>0 and  'UMC' in d['name']):
            return d['name']
            
def coll_vars():
    """Collect user input from Tkinter input window"""
    
    global test_type
    global tran_dev
    global rec_dev
    global system
    global test_loc
    global test_notes
    
    test_type = e1.get()
    tran_dev = e2.get()
    rec_dev = e3.get()
    system = e4.get()
    test_loc = e5.get()
    test_notes = e6.get(1.0, tk.END)
    
    # Delete window 
    root.destroy()
    
def post_test_notes():
    """Collect user's post-test notes"""
    
    global post_test
    
    post_test = entry.get(1.0, tk.END)
    
    # Delete window
    root.destroy()

def exit_prog():
    """Exit if user presses 'cancel' in Tkinter prompt"""
    
    sys.exit(1)

def audio_float(dat):
    """Function to convert sound array to a float sound array"""
    
    if(dat.dtype is np.dtype('uint8')):
        return (dat.astype('float')-128)/128
    if(dat.dtype is np.dtype('int16')):
        return dat.astype('float')/(2**15)
    if(dat.dtype is np.dtype('int32')):
        return dat.astype('float')/(2**31)
    if(dat.dtype is np.dtype('float32')):
        return dat        

def callback(indata, outdata, frames, time, status):
    """Callback function for playing/recording audio
       Plays entire audio file piece by piece
    """
    
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

#====================[Parse the command line arguments]====================

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("-a", "--audiofile", default="test.wav" ,
                    help="Audiofile to use for test. Defaults to test.wav")
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
parser.add_argument("-od", "--outdir", default="", help="Directory that is added to the "+
                    "output path for all files")
args = parser.parse_args()

#=========================[Setup Playback Device]==========================

device_name=find_device()

print('\n'+device_name,flush=True)

sd.default.device=device_name

#=======================[Initialize tx-data folder]========================   

# Create tx-data folder
tx_dat_fold = os.path.join(args.outdir,'tx-data')
os.makedirs(tx_dat_fold, exist_ok=True)

#==========================[Get Test Start Time]===========================

# Get start time, deleting microseconds
time_n_date = datetime.datetime.now().replace(microsecond=0)

#===================[Get Test Info and Notes From User]====================

# Window creation
root = tk.Tk()
root.title("Test Information")

# Test type prompt
l1 = tk.Label(root, text="Test Type")
l1.grid(row=0, column=0, padx=10, pady=5)
e1 = tk.Entry(root, bd=2, width=50)
e1.grid(row=1, column=0, padx=10, pady=5)
e1.focus()

# Transmit device prompt
l2 = tk.Label(root, text="Transmit Device")
l2.grid(row=2, column=0, padx=10, pady=5)
e2 = tk.Entry(root, bd=2)
e2.grid(row=3, column=0, padx=10, pady=5)

# Receive device prompt
l3 = tk.Label(root, text="Receive Device")
l3.grid(row=4, column=0, padx=10, pady=5)
e3 = tk.Entry(root, bd=2)
e3.grid(row=5, column=0, padx=10, pady=5)

# System prompt
l4 = tk.Label(root, text="System")
l4.grid(row=6, column=0, padx=10, pady=5)
e4 = tk.Entry(root, bd=2, width=60)
e4.grid(row=7, column=0, padx=10, pady=5)

# Test location prompt
l5 = tk.Label(root, text="Test Location")
l5.grid(row=8, column=0, padx=10, pady=5)
e5 = tk.Entry(root, bd=2, width=100)
e5.grid(row=9, column=0, padx=10, pady=5)

# Pre-test notes prompt
l6 = tk.Label(root, text="Please enter notes on pre-test conditions")
l6.grid(row=10, column=0, padx=10, pady=5)
e6 = scrolledtext.ScrolledText(root, bd=2, width=100, height=15)
e6.grid(row=11, column=0, padx=10, pady=5)

# 'Submit' and 'Cancel' buttons
button_frame = tk.Frame(root)
button_frame.grid(row=12, column=0)

button = tk.Button(button_frame, text="Submit", command=coll_vars)
button.grid(row=0, column=0, padx=10, pady=10)

button = tk.Button(button_frame, text="Cancel", command=exit_prog)
button.grid(row=0, column=1, padx=10, pady=10)

# Run Tkinter window
root.mainloop()

#====================[Print Test Type and Test Notes]======================

# Print info to screen
print('\nTest type: %s\n' % test_type, flush=True)
print('Pre test notes:\n%s' % test_notes, flush=True)

# Write info to .txt file
datadir = os.path.join(args.outdir,'test-type.txt')
with open(datadir, 'w') as file:
    file.write('Test Type : "%s"\n' % test_type)
    file.write('System    : "%s"\n' % system)
    file.write('Tx Device : "%s"\n' % tran_dev)
    file.write('Rx Device : "%s"\n' % rec_dev) 
    

#====================[Write Log Entry With User Input]=====================

# Add 'outdir' to path
log_datadir = os.path.join(args.outdir, 'tests.log')

# Open test.log and append with current test information
with open(log_datadir, 'a') as file:
    file.write('>>Tx Two Loc Test started at %s\n' % time_n_date)
    file.write('\tTest Type   : %s\n' % test_type)
    file.write('\tFilename    : m2e_2loc_tx.py\n')
    file.write('\tTx Device   : %s\n' % tran_dev)
    file.write('\tRx Device   : %s\n' % rec_dev)
    file.write('\tSystem      : %s\n' % system)
    file.write("\tArguments   : 'Audiofile','%s'," % args.audiofile)
    file.write("'AudioSkip','%s'," % args.audioskip)
    file.write("'BGNoiseFile','%s'," % args.bgnoisefile)
    file.write("'BGNoiseVolume','%s'," % args.bgnoisevolume)
    file.write("'OutDir','%s'," % args.outdir)
    file.write("'PTTWait','%s'," % args.pttwait)
    file.write("'RadioPort','%s'," % args.radioport)
    file.write("'Trials','%s'\n" % args.trials)
    # Add tabs for each newline in test_notes string
    file.write("===Pre-Test Notes===%s" % '\t'.join(('\n'+test_notes.lstrip()).splitlines(True)))
    
#========================[Open Radio Interface]============================

ri = RadioInterface(args.radioport)

#========================[Notify User of Start]============================

#print('Storing data in\n\t"%s"\n' % mat_file)

ri.led(1, True)

#========================[Compute Check Trials]============================

# if (args.trials>10):
#     check_trials = np.linspace(0, args.trials, 10)
# else:
#     check_trials = np.array([0, (args.trials/2)])
#     if (check_trials[1]==0):
#         check_trials[1] = 1

#=======================[Play/Rec Initializations]=========================

# Create audio recording directory
audio_dir = os.path.join(tx_dat_fold, 'recorded_audio')
td = str(time_n_date).replace(" ", "_")
td = td.replace(":", "-")
audio_dir = os.path.join(audio_dir, td)
os.makedirs(audio_dir, exist_ok=True)

# Set for mono play/rec
sd.default.channels = [1, 1]

# Desired samplerate
fs = int(48e3)

# Buffersize and blocksize for parsing through audio
buffersize = 20
blocksize = 512

#=========================[Play/Record Loop]===============================

for itr in range(1, args.trials+1):
    try:
         
        # Queue for recording input
        qr = queue.Queue()
        # Queue for output WAVE file
        q = queue.Queue(maxsize=buffersize)
         
        # Gather audio data in numpy array and audio samplerate
        fs_file, audio_dat = scipy.io.wavfile.read(args.audiofile)
        # Calculate resample factors
        rs_factor = Fraction(fs/fs_file)
        # Convert to float sound array
        audio_dat = audio_float(audio_dat)
        # Resample audio
        audio = scipy.signal.resample_poly(audio_dat, rs_factor.numerator, rs_factor.denominator)
         
        event = threading.Event()
         
        # NumPy audio array placeholder
        arr_place = 0
         
        # Press the push to talk button
        ri.ptt(True)
         
        # Pause the indicated amount to allow the radio to access the system
        time.sleep(args.pttwait)
         
        for x in range(buffersize):
             
            data_slice = audio[blocksize*x:(blocksize*x)+blocksize]
             
            if data_slice.size == 0:
                break
             
            # Save place of NumPy array slice for next loop
            arr_place += blocksize
             
            # Pre-fill queue
            q.put_nowait(data_slice)
             
        # Output and input stream in one
        # Latency of 0 to cut down on delay
        stream = sd.Stream(
            blocksize=blocksize, samplerate=fs, dtype='float32',
            callback=callback, finished_callback=event.set, latency=0)
         
        filename = 'output'+str(itr)+'.wav'
        filename = os.path.join(audio_dir, filename)
         
        with sf.SoundFile(filename, mode='x', samplerate=fs, channels=1) as rec_file:
             
            with stream:
                 
                timeout = blocksize * buffersize / fs
                 
                # For grabbing the next blocksize slice of the NumPy audio array
                itrr = 0
                 
                while data_slice.size != 0:
                     
                    data_slice = audio[arr_place+(blocksize*itrr):arr_place+(blocksize*itrr)+blocksize]
                    itrr += 1
                     
                    q.put(data_slice, timeout=timeout)
                    rec_file.write(qr.get())
                 
                # Wait until playback is finished    
                event.wait()
                 
            # Make sure to write any audio data still left in the recording queue
            while (qr.empty() != True):
                rec_file.write(qr.get())
                 
            # Release the PTT button
            ri.ptt(False)
             
            # Add a pause after playing/recording to remove any run to run dependencies
            time.sleep(3.1)
                 
    except KeyboardInterrupt:
        parser.exit('\nInterrupted by user')
    except queue.Full:
        # A timeout occurred, i.e. there was an error in the callback
        parser.exit(1)
    except Exception as e:
        parser.exit(type(e).__name__ + ': ' + str(e))
        
#=======================[Notify User of Completion]======================== 

# Turn off LED on radiointerface
ri.led(1, False)

print('\nData collection complete, you may now stop data collection on the receiving end\n', flush=True)

#====================[Obtain Post Test Notes From User]====================

# Window creation
root = tk.Tk()
root.title("Test Information")
root.after(1, lambda: root.focus_force())

# Pre-test notes prompt
label = tk.Label(root, text="Please enter post-test notes")
label.grid(row=0, column=0, padx=10, pady=5)
entry = scrolledtext.ScrolledText(root, bd=2, width=100, height=15)
entry.grid(row=1, column=0, padx=10, pady=5)
entry.focus()

# 'Submit' and 'Cancel' buttons
button_frame = tk.Frame(root)
button_frame.grid(row=2, column=0)

button = tk.Button(button_frame, text="Submit", command=post_test_notes)
button.grid(row=0, column=0, padx=10, pady=10)

button = tk.Button(button_frame, text="Cancel", command=exit_prog)
button.grid(row=0, column=1, padx=10, pady=10)

# Run Tkinter window
root.mainloop()

#======================[Write Post-Test Notes to File]=====================

with open(log_datadir, 'a') as file:
    # Add tabs for each newline in post_test string
    file.write("===Post-Test Notes===%s" % '\t'.join(('\n'+post_test.lstrip()).splitlines(True)))
    file.write("===End Test===\n\n\n")