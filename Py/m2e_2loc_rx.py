#!/usr/bin/env python
'''
M2E_2LOC_RX runs the receive side of a two location mouth to ear latency test

m2e_2loc_rx() records the test audio and timecode audio on the receive end.
The audio is saved to a timestamped file in the rx-dat folder. Additional
test parameters such as the device used, git revision hash and the number 
of buffer over runs are stored in a .mat file.

'OutDir', 'some\other\place\' same as above but the audio file is saved
to a timestamped file in the some\other\place\rx-dat folder

The audio file is saved as a 24-bit stereo WAV file sampled at 48 kHz. The
receive audio is in channel one and the receive timecode audio is in channel
2.

M2E_2LOC_RX decides to terminate recordings based on timecode audio levels.
Input average audio levels of more than 4% full scale are considered active.
The audio levels are not checked for the first 3 seconds of the recording.
The average is taken over sections of 1024 samples, or at a 48 kHz sample rate,
about 20 ms.

See also m2e_2loc_tx and m2e_2loc_process
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
FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
OUT OF, RESULTING FROM , OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
USE OF, THE SOFTWARE OR SERVICE PROVIDED HEREUNDER.
'''

import argparse
import datetime
import queue
import sys
import os

from tkinter import scrolledtext

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

def callback(indata, frames, time, status):
    """This is called (from a separate thread) for each audio block."""
    
    if status:
        print(status, file=sys.stderr)
    q.put(indata.copy())

#====================[Parse the command line argument]====================

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("-od", "--outdir", default="", help="Directory that is "+
                    "added to the output path for all files.")
args = parser.parse_args()

#=========================[Setup Playback Device]==========================

device_name=find_device()

print('\n'+device_name,flush=True)

sd.default.device=device_name

#=======================[Initialize Rx-Data Folder]========================    

# Create rx-data folder
rx_dat_fold = os.path.join(args.outdir,'rx-data')
os.makedirs(rx_dat_fold, exist_ok=True)

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

#====================[Print Test Type and Test Notes]=======================

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
    
#====================[Write Log Entry With User Input]======================

# Add 'outdir' to path
log_datadir = os.path.join(args.outdir, 'tests.log')

# Open test.log and append with current test information
with open(log_datadir, 'a') as file:
    file.write('>>Rx Two Loc Test started at %s\n' % time_n_date)
    file.write('\tTest Type   : %s\n' % test_type)
    file.write('\tFilename    : m2e_2loc_tx.py\n')
    file.write('\tTx Device   : %s\n' % tran_dev)
    file.write('\tRx Device   : %s\n' % rec_dev)
    file.write('\tSystem      : %s\n' % system)
    file.write("\tArguments   : 'OutDir','%s'\n" % args.outdir)
    # Add tabs for each newline in test_notes string
    file.write("===Pre-Test Notes===%s" % '\t'.join(('\n'+test_notes.lstrip()).splitlines(True)))
    
#==================[Initialize variables for recording]=====================
    
# queue for recording
q = queue.Queue()

# Desired samplerate
fs = int(48e3)

# Create proper time/date syntax
td = str(time_n_date).replace(" ", "_")
td = td.replace(":", "-")

# Create file for recording audio
filename = td+'.wav'
filename = os.path.join(rx_dat_fold, filename)

#=============================[Recording Loop]==============================

try:

    # Make sure the file is opened before recording anything:
    with sf.SoundFile(filename, mode='x', samplerate=fs,
                      channels=2) as file:
        with sd.InputStream(samplerate=fs, device=sd.default.device,
                            channels=2, callback=callback):
            
            print('#' * 80, flush=True)
            print('Recording started, please press Ctrl+C to stop the recording', flush=True)
            print('#' * 80, flush=True)
            while True:
                file.write(q.get())
                
except KeyboardInterrupt:
    print('\nRecording finished: ' + repr(filename))
except Exception as e:
    parser.exit(type(e).__name__ + ': ' + str(e))


#====================[Obtain Post Test Notes From User]=====================

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

#======================[Write Post-Test Notes to File]======================

with open(log_datadir, 'a') as file:
    # Add tabs for each newline in post_test string
    file.write("===Post-Test Notes===%s" % '\t'.join(('\n'+post_test.lstrip()).splitlines(True)))
    file.write("===End Test===\n\n\n")