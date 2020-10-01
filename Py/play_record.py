import scipy.io.wavfile
import scipy.signal
import threading
import queue
import math
import sys
import os

from fractions import Fraction

import sounddevice as sd
import soundfile as sf
import numpy as np

def callback(indata, outdata, frames, time, status):
    """ Callback function for the stream.
        Will run as long as there is audio data to play.
        Currently setup to play mono audio files """
    
    # Record the output
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
        # One column for mono output
        outdata[:,0] = data

def play_record(audio, buffersize=20, blocksize=512,
                capture_dir='', wav_name='', itr=0):
    
    try:
        
        fs = int(48e3)

        # Queue for recording input
        global qr
        qr = queue.Queue()
        # Queue for output WAVE file
        global q
        q = queue.Queue(maxsize=buffersize)
        
        # Thread for callback function
        event = threading.Event()
        
        # NumPy audio array placeholder
        arr_place = 0

        for x in range(buffersize):
            
            data_slice = audio[blocksize*x:(blocksize*x)+blocksize]
            
            if data_slice.size == 0:
                break
            
            # Save place of NumPy array slice for next loop
            arr_place += blocksize
            
            # Pre-fill queue
            q.put_nowait(data_slice)  
        
        # Output and input stream in one
        # Latency of zero to try and cut down delay    
        stream = sd.Stream(   
            blocksize=blocksize, samplerate=fs,
            dtype='float32', callback=callback, finished_callback=event.set,
            latency=0)
        
        filename = wav_name+str(itr)+'.wav'
        filename = os.path.join(capture_dir, filename)
        
        with sf.SoundFile(filename, mode='x', samplerate=fs,
                          channels=1) as rec_file:
            with stream:
                timeout = blocksize * buffersize / fs

                # For grabbing next blocksize slice of the NumPy audio array
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
        
        return filename
    # Catch errors or test cancelation
    except KeyboardInterrupt:
        sys.exit('\nInterrupted by user')
    except queue.Full:
        # A timeout occurred, i.e. there was an error in the callback
        sys.exit(1)
    except Exception as e:
        sys.exit(type(e).__name__+': '+str(e))