# <center>Mouth-to-Ear Latency Measurement</center>
## Purpose

The purpose of this software is to measure the mouth-to-ear (M2E) latency of a push-to-talk network. M2E latency characterizes the time between speech input into on communications device and its output through another. M2E latency has been identified as a key metric of quality of experience (QoE) in communications. NIST's PSCR group developed this software to measure and quantify the M2E latency of Push To Talk (PTT) devices.
## Hardware Requirements
* 2 computers able to run Python (only one needed for one location measurements)
* 2 audio interfaces (only one needed for one location measurements)
* 2 timecode generators with IRIG-B outputs (not needed for one location measurements)
* 2 communications devices for testing
* Cables to connect test devices and timecode generators (if used) to audio interfaces

## Installation and Software

### Python

First you'll need to install Python. There are many different distributions, but it's recommended that you download from [Python.org](https://www.python.org/downloads/).  
After a successful install of Python you'll need Matplotlib, SciPy, and pySerial. Each can be downloaded with "pip":
`python -m pip install -U matplotlib`  
`python -m pip install scipy`  
`pip install pyserial`

### PySoundFile

Software for reading/writing sound files for use in conjunction with "sounddevice."
[PySoundFile](https://pysoundfile.readthedocs.io/en/0.10.3post1/#)

### python-sounddevice

A Python module that provides bindings for the PortAudio library. For play/record interface.
[python-sounddevice](https://python-sounddevice.readthedocs.io/en/latest/index.html)

## Mouth to Ear 1 Location

To run the test, simply enter `python m2e_1loc.py` in a terminal opened to the top level directory. To learn about the defaults, and various arguments you can add to the test, please run `python m2e_1loc.py -h`

**ex:**
`python m2e_1loc.py -a testfile.wav -t 20 -bgf nightclub.wav -o 1.2`
* `-a testfile.wav` runs the program with "testfile.wav" as the test sound file (default is test.wav)
* `-t 20` runs 20 trials (default is 10)
* `-bgf nightclub.wav` adds "nightclub.wav" noise file to the test file (default is no noise)
* `-o 1.2` adds 1.2 seconds of silence after the audio is played (default is 0.1 seconds)
## Mouth to Ear 2 Location

### Transmitter side
To run the Tx portion of the test, simply use `python m2e_2loc_tx.py` in a terminal opened to the top level directory. Please enter `python m2e_2loc_tx.py -h` to learn more.

**ex:**
`python m2e_2loc_tx.py -t 50 -as 2.3 -b 1024 -q 30`
* `-t 50` runs 50 trials (default is 10)
* `-as 2.3` skips the first 2.3 seconds of audio per trial (default is 0.0)
* `-b 1024` uses a blocksize of 1024 for the audio transmitting (default is 512, use powers of 2)
* `-q 30` uses 30 blocks for buffering audio (default is 20)

### Receiver side
To run the Rx portion of the test, simply use `python m2e_2loc_rx.py` in a terminal opened to the top level directory. Please enter `python m2e_2loc_rx.py -h` to learn more.

**ex:**
`python m2e_2loc_rx.py -od mydata`
* `-od mydata` places the recording data into a directory named "mydata" (default is the top level directory)
* Press "ctrl+c" to end the recording once word is given by the transmit side
## Disclaimer

**Much of the included software was developed by NIST employees for that software the following disclaimer applies:**

This software was developed by employees of the National Institute of Standards and Technology (NIST), an agency of the Federal Government. Pursuant to title 17 United States Code Section 105, works of NIST employees are not subject to copyright protection in the United States and are considered to be in the public domain. Permission to freely use, copy, modify, and distribute this software and its documentation without fee is hereby granted, provided that this notice and disclaimer of warranty appears in all copies.

THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE, WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

**Some software included was developed by NTIA employees, for that software the following disclaimer applies:**

THE NATIONAL TELECOMMUNICATIONS AND INFORMATION ADMINISTRATION,
INSTITUTE FOR TELECOMMUNICATION SCIENCES ("NTIA/ITS") DOES NOT MAKE
ANY WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR STATUTORY, INCLUDING,
WITHOUT LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR
A PARTICULAR PURPOSE, NON-INFRINGEMENT AND DATA ACCURACY.  THIS SOFTWARE
IS PROVIDED "AS IS."  NTIA/ITS does not warrant or make any
representations regarding the use of the software or the results thereof,
including but not limited to the correctness, accuracy, reliability or
usefulness of the software or the results.

You can use, copy, modify, and redistribute the NTIA/ITS developed
software upon your acceptance of these terms and conditions and upon
your express agreement to provide appropriate acknowledgments of
NTIA's ownership of and development of the software by keeping this
exact text present in any copied or derivative works.

The user of this Software ("Collaborator") agrees to hold the U.S.
Government harmless and indemnifies the U.S. Government for all
liabilities, demands, damages, expenses, and losses arising out of
the use by the Collaborator, or any party acting on its behalf, of
NTIA/ITS' Software, or out of any use, sale, or other disposition by
the Collaborator, or others acting on its behalf, of products made
by the use of NTIA/ITS' Software.


**Some software included was developed by Texas Instruments, for that software the following disclaimer applies:**

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

*  Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

*  Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

*  Neither the name of Texas Instruments Incorporated nor the names of
   its contributors may be used to endorse or promote products derived
  from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

**Audio files included with this software were derived from ITU-T P Supplement 23.**