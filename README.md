# <center>Mouth-to-Ear Latency Measurement</center>

## Purpose

The purpose of this software is to measure the mouth-to-ear (M2E) latency of a 
push-to-talk network. M2E latency characterizes the time between speech input 
into on communications device and its output through another. M2E latency has 
been identified as a key metric of quality of experience (QoE) in communications. 
NIST's PSCR group developed this software to measure and quantify the M2E latency 
of Push To Talk (PTT) devices.

## Hardware Requirements
* 2 computers able to run Python (only one needed for one location measurements)
* 2 audio interfaces (only one needed for one location measurements)
* 2 timecode generators with IRIG-B outputs (not needed for one location measurements)
* QoE hardware
* 2 push-to-talk communications devices for testing
* Cables to connect test devices and timecode generators (if used) to audio interfaces

## Installation and Software

To install the `mcvqoe-mouth2ear` package, clone this repository and run the 
following from the root of the git repository:

```
pip install .
```

The `mcvqoe-base` package is required for install, it can be found at https://github.com/usnistgov/mcvqoe-base.

It is also recommended to install the `mcvqoe` package which has the measurement GUI to make measurements easier and more intuitive to run. It can be found at https://github.com/usnistgov/mcvqoe.

## Mouth-to-Ear 1 Location

To run the test, simply enter `m2e-measure` in a terminal opened to the top level directory. To learn about the defaults, and various arguments you can add to the test, please run `m2e-measure --help`

### Example

```
m2e-measure --audio-files testfile.wav --trials 120 --overplay 1.2
```

* `-a testfile.wav` runs the program with "testfile.wav" as the test sound file 
* `--trials 120` runs 120 trials (default is 100)
* `--overplay 1.2` adds 1.2 seconds of silence after the audio is played (default is 0.1 seconds)

#### Simulation

One location tests can also be simulated using the `m2e-simulate` entry point.
For example, the following is a simulation of the above example :

```
m2e-simulate --audio-files testfile.wav --trials 120 --overplay 1.2
```

## Mouth-to-Ear 2 Location

### Transmitter side
To run the Tx portion of the test, simply use `m2e-measure --testtype m2e_2loc_tx` in a terminal opened to the top level directory. Please enter `m2e-measure --help` to learn more. Once the side is started, the test will begin imminently, so start the Rx side before the Tx side to make sure that all the data gets captured.

### Example

```
m2e-measure --testtype m2e_2loc_tx
```

* `--testtype m2e_2loc_tx` runs the Mouth to Ear 2 location transmitter side test (default is m2e_1loc)

### Receiver side
To run the Rx portion of the test, simply use `m2e-measure --testtype m2e_2loc_rx` in a terminal opened to the top level directory. Please enter `m2e-measure --help` to learn more.

### Example

```
m2e-measure --testtype m2e_2loc_rx
```

* Press any key on the receiving side to stop the recording when the test finishes on the transmit side.

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
