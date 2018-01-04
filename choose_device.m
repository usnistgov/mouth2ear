function name=choose_device(apr)
%CHOOSE_DEVICE choose a suitable audio device for test
%   name=CHOOSE_DEVICE(apr) finds and selects a suitable audio device
%
%   CHOOSE_DEVICE uses the audioPlayerRecorder object apr to find a list of
%   possible audio devices. CHOOSE_DEVICE then searches the list for one
%   that matches devices in the allowed list and selects that as the audio
%   device for apr. CHOOSE_DEVICE returns the name of the audio device that
%   was selected

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

    %list of sound device names to use
    device_names={'UMC'};

    %get a list of the audio devices
    ad=apr.getAudioDevices();

    %get matches
    idx=find(contains(ad,device_names));

    %check if there were more than one matching device
    if(length(idx)>1)
        %print out devices found
        fprintf('Multiple devices found :\n');
        fprintf('\t%s\n',ad{idx});
        %use the last
        idx=idx(end);
    end

    if(isempty(idx))
        error('Could not find a sutable output device')
    end
    
    %return name
    name=ad{idx};

    %set device
    apr.Device=name;
    
end