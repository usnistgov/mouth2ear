

PURPOSE
================================================================================

 The purpose of this software is to measure the mouth-to-ear (M2E) 
latency of a push-to-talk network. M2E latency characterizes the time 
between speech input into one communications device and its output 
through another. M2E latency has been identified as a key metric of 
quality of experience (QoE) in communications. NIST’s PSCR group 
developed this software to measure and quantify the M2E latency of Push 
To Talk (PTT) devices. 

OBTAINING SOFTWARE
================================================================================

Code available at: https://github.com/usnistgov/mouth2ear

Data available at: https://doi.org/10.18434/T4/1422492

Paper available at https://doi.org/10.6028/NIST.IR.8206

HARDWARE REQUIREMENTS
================================================================================

* 2 computers able to run MATLAB (only one needed for one location 
measurements) 
* 2 audio interfaces (only one needed for one location measurements) 
* 2 timecode generators with IRIG-B outputs (not needed for one location 
measurements) 
* 2 communications devices for testing 
* cables to connect test devices and timecode generators (if used) to 
audio interfaces 

SOFTWARE REQUIREMENTS
================================================================================

* MATLAB R2017a or newer with the following toolboxes:
	* Audio System Toolbox
	* DSP System Toolbox
	* Signal Processing Toolbox
* R version 3.4.X
	* RStudio (recommended)
	* metRology, ggplot2, and devtools packages

RUNNING SOFTWARE
================================================================================
	
The software is divided into subfolders for the type of test that is 
being performed. Some functions are repeated across the directories as 
they are used for multiple tests. 


	
one location test
--------------------------------------------------------------------------------

The code for the one location test is stored in the folder 1loc. To run 
the test, run the test.m script speech will be played and recorded using 
the connected audio device. The raw and processed audio data is stored 
in a subfolder named *data/*. 


two location transmitter side
--------------------------------------------------------------------------------

The two location code is stored in the folder 2loc. For the transmitter 
tx_script.m is run. The tx_script plays audio out of the audio interface 
on channel 1 and records timecode audio on channel 2. Raw data from the 
script is stored in a subfolder named *tx-data/*. 



two location receiver side
--------------------------------------------------------------------------------

The two location code is stored in the folder 2loc. For the receiver 
rx_script.m is run. The rx_script records incoming speech audio on 
channel 1 and timecode audio on channel 2. Raw data from the script is 
stored in a subfolder named *rx-data/*. 



two location post processing
--------------------------------------------------------------------------------

The two location code is stored in the folder 2loc. To process the data 
from a two location session and get out delay values process.m is run. 
The process script takes in the name of the transmit file, and 
optionally the name of the receive file and lines them up and computes 
delays. If the receive file name is not given, then the script searches 
for one that matches the tx file in the rx-data file. 



session aggregation post processing (one and two location)
--------------------------------------------------------------------------------

To process the data from all sessions of a test and aggregate them into 
one mat file loadData.m is run. loadData() takes in the path where the 
single location or transmit (for two location tests) data is stored, the 
folder where the received data is stored (for two location tests), and a 
descriptor that uniquely identifies the name of all session data files 
for the particular test. loadData then processes all sessions and stores 
them in a mat file containing only delay values, and in a mat file with 
delay values as well as all received audio for the test. 



converting data to csv and wav files
--------------------------------------------------------------------------------

 The code for converting raw mat file data into csv and wav files is 
stored in the folder 2loc. To convert the data the function 
splice_data.m is run. It relies on data previously being processed with 
the loadData function and takes in a structure detailing the test type 
and the appropriate paths where the raw data is stored and where the 
spliced data should be stored. 

calculating M2E latency and uncertainty
--------------------------------------------------------------------------------

The code to calculate M2E latency values and their associated 
uncertainties is in the folder uncertainty. To install and use the 
mouth2ear package perform the following: 
* Input in the console: install.packages("metRology", "ggplot2", "devtools")
* Installing the mouth2ear package, 2 options
	* No local copy of package: Input in the console: devtools::install_git(url="git://github.com/usnistgov/mouth2ear", subdir = "uncertainty/mouth2ear")
	* Local copy of package: Use install.packages() function, providing the
      path where mouth2ear_X.X.zip is stored. Alternatively, if using 
      RStudio, click on Install Packages under Tools, change Install 
      from: to Package Archive File (.zip; .tar.gz) and select 
      mouth2ear_X.X.zip. 

* Input in the console: library(mouth2ear)

The function process.sessions() returns M2E latency values and 
information relating to their uncertainties via the function GUM from 
the metRology package. The function takes in a list containing the type 
of test setup, directory where the data is stored, the tests performed, 
and the degree to which data must be thinned to eliminate significant 
autocorrelation in the data. 

 ?mouth2ear will yield general information on the package, functions, 
and included example data. 

?process.sessions() gives documentation on the process.sessions() 
function, as well as an example using included example data. 

Microcontroller code
--------------------------------------------------------------------------------

The code for the radio interface microcontroller is in the 
radio-interface/ directory. This code was designed to run on the 
MSP-EXP430F5529LP "Launch Pad" development board and compiled for the 
MSP430 using TI Code Composer Studio. The microcontroller code sets up a 
virtual COM port over USB and provides a simple command line interface. 

The code uses the standard TI USB library and serial drivers. On Windows 
10 no driver installation is necessary. On other systems the appropriate 
driver may need to be downloaded from TI. 

### Commands

The command line interface implemented by the software is primarily 
intended to be used with the radioInterface MATLAB class. It can, 
however, be easily used manually with a serial terminal program. 
Commands are case sensitive. The commands are listed below: 

* **help** If help is called with no arguments, it displays a list of 
all possible commands. If the name of a command is passed to help, then 
it gives a short description of what the command does and what arguments 
to pass to it. 

* **ptt** The ptt command activates or deactivates the push to talk 
signal. If no arguments are given, it will display the ptt status. If 
the first argument is *on* or *off*, then the ptt signal is activated or 
deactivated respectively. If the first argument is *delay* then the 
second argument is the delay in seconds and the ptt signal will be 
activated after that number of seconds. The number of seconds is 
adjustable with about 1 ms resolution and can be up to 64 seconds. The 
actual delay is printed by the ptt command when the delay argument is 
given. 

* **devtype** The devtype command is for identification of the device. 
It is mainly so the MATLAB class can search for a usable device on one 
of the available serial ports. 

* **LED** The LED command will turn on or off one of the LEDs on the 
board. 

* **closeout** The closeout command is primarily meant to be called when 
the radioInterface class is deleted. It deactivates the ptt signal and 
turns off all of the LEDs. It takes no arguments. 

* **analog** The analog command is used to read analog channels on the 
MSP430. Channels are passed to the command in the form of Ax where x is 
the channel number. Alternatively Tint can be passed to read the 
internal temperature. The command can read up to 16 channels. 

* **temp** The temp command is used to measure both the MSP430 
temperature and an optional external thermistor. The thermistor connects 
to analog channel 5 on P6.5. The code was used with a Cantherm 
MF52A2103J3470 thermistor as the bottom leg (connected to ground) of a 
voltage divider with the other resistor, connected to 3.3V, being a 10 k 
ohm. The internal temperature measures the die temperature of the MSP430 
which is generally a bit higher than ambient due to the internal voltage 
regulator. 


TECHNICAL SUPPORT
================================================================================

 For more information or assistance on M2E latency measurements please 
contact: 

Tim Thompson  
Public Safety Communications Research Division  
National Institute of Standards and Technology  
325 Broadway  
Boulder, CO 80305  
(303) 497-6613; tim.thompson@nist.gov

DISCLAIMER
================================================================================
 
**Much of the included software was developed by NIST employees for that 
software the following disclaimer applies:** 

This software was developed by employees of the National Institute of 
Standards and Technology (NIST), an agency of the Federal Government. 
Pursuant to title 17 United States Code Section 105, works of NIST 
employees are not subject to copyright protection in the United States 
and are considered to be in the public domain. Permission to freely use, 
copy, modify, and distribute this software and its documentation without 
fee is hereby granted, provided that this notice and disclaimer of 
warranty appears in all copies. 

THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, 
EITHER EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, 
ANY WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY 
IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, 
AND FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION 
WILL CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE 
ERROR FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, 
BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, 
ARISING OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS 
SOFTWARE, WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR 
OTHERWISE, WHETHER OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR 
OTHERWISE, AND WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF 
THE RESULTS OF, OR USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER. 

**Some software included was developed by NTIA employees, for that 
software the following disclaimer applies:** 

 THE NATIONAL TELECOMMUNICATIONS AND INFORMATION ADMINISTRATION, 
INSTITUTE FOR TELECOMMUNICATION SCIENCES ("NTIA/ITS") DOES NOT MAKE ANY 
WARRANTY OF ANY KIND, EXPRESS, IMPLIED OR STATUTORY, INCLUDING, WITHOUT 
LIMITATION, THE IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE, NON-INFRINGEMENT AND DATA ACCURACY. THIS SOFTWARE IS 
PROVIDED "AS IS." NTIA/ITS does not warrant or make any representations 
regarding the use of the software or the results thereof, including but 
not limited to the correctness, accuracy, reliability or usefulness of 
the software or the results. 

You can use, copy, modify, and redistribute the NTIA/ITS developed 
software upon your acceptance of these terms and conditions and upon 
your express agreement to provide appropriate acknowledgments of NTIA's 
ownership of and development of the software by keeping this exact text 
present in any copied or derivative works. 

The user of this Software ("Collaborator") agrees to hold the U.S. 
Government harmless and indemnifies the U.S. Government for all 
liabilities, demands, damages, expenses, and losses arising out of the 
use by the Collaborator, or any party acting on its behalf, of NTIA/ITS' 
Software, or out of any use, sale, or other disposition by the 
Collaborator, or others acting on its behalf, of products made by the 
use of NTIA/ITS' Software. 

**Some software included was developed by Texas Instruments, for that 
software the following disclaimer applies:** 

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are 
met: 

* Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer. 

* Redistributions in binary form must reproduce the above copyright 
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution. 

* Neither the name of Texas Instruments Incorporated nor the names of 
its contributors may be used to endorse or promote products derived from 
this software without specific prior written permission. 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS 
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED 
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER 
OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR 
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 

**Audio files included with this software were derived from ITU-T P 
Supplement 23.** 
