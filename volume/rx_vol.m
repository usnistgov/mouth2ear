function rx_vol()
%RX_VOL show a volume meter for input audio.
%
%   RX_VOL() display a volume meter for input audio.
%

%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

%use a sample rate of 48 kHz
fs=48e3;

%create an object for playback and recording
RecObj=audioDeviceReader(fs,'NumChannels',1,'BitDepth','24-bit integer');

%create a loudness meter object
lm=loudnessMeter();

%chose which device to use
dev_name=choose_device(RecObj);

%print the device used
fprintf('Using "%s" for audio test\n',dev_name);


%set number of channesl to one
RecObj.NumChannels=1;

%zerro  over runs
overRun=0;

%visualize loudness
lm.visualize();

%get graphics root object
r=groot;

%save hidden figures property
hf=r.ShowHiddenHandles;

%show hidden figures
r.ShowHiddenHandles='on';

%find loudness figure
lf=findobj('Name',getString(message('audio:loudness:Title')));

%restore hidden figures property
r.ShowHiddenHandles=hf;

%loop while loudness meter is open
while(isgraphics(lf))
    %read audio data
    [datout,or]=RecObj();
   
    lm(datout);
    
    %force drawing
    drawnow();
    
    %add over runs
    overRun=overRun+or;
end


%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(overRun));
else
    fprintf('There were no buffer over runs\n');
end

end
