function [y,underRun,overRun]=play_record(apr,x,varargin)
%PLAY_RECORD play and record audio simultaneously    
%   [y,underRun,overRun]=PLAY_RECORD(apr,x) Play the audio x using the
%    audioPlayerRecorder object apr. The recorded audio is returned in y.
%    underRun and overRun are the number of buffer under and over runs
%    during the playback/recording.
%
%   PLAY_RECORD(_,name,value) specifies properties using one or more Name, 
%   Value pair arguments. Possible Name, Value pairs are shown below:
%
%   NAME        TYPE            Description
%
%   OverPlay    double          The number of seconds to play silence after
%                               the audio is complete. This allows for all
%                               of the audio to be recorded when there is
%                               delay in the system.
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

    %create new input parser
    p=inputParser();

    %add audio object argument
    addRequired(p,'apr',@(l)validateattributes(l,{'audioPlayerRecorder'},{'scalar'}));
    %add output audio argument
    addRequired(p,'x',@(l)validateattributes(l,{'numeric'},{'real','finite'}));
    %add overplay parameter
    addParameter(p,'OverPlay',0.1,@(l)validateattributes(l,{'numeric'},{'real','finite','scalar','nonnegative'}));

    %add window length argument
    addOptional(p,'winLength',4,@(l)validateattributes(l,{'numeric'},{'scalar','positive'}));

    %set parameter names to be case sensitive
    p.CaseSensitive= true;

    %parse inputs
    parse(p,apr,x,varargin{:});

    %reshape x into a column vector
    x=reshape(p.Results.x,[],1);

    %get buffer size
    bsz=p.Results.apr.BufferSize;
    
    %get sample rate
    fs=p.Results.apr.SampleRate;

    %calculate the number of loops needed
    runs=ceil((length(x)+p.Results.OverPlay*fs)/bsz);
    
    %initialize recive audio buffer
    y=zeros((runs-1)*bsz,size(x,2));
    
    %zerro under and over runs
    underRun=0;
    overRun=0;
    
    for k=1:runs
        
        if(k*bsz<=length(x))
            %get a chunk of data
            datin=x((bsz*(k-1)+1):(bsz*k));
        elseif(k*bsz>=length(x))
            %get data to end of file
            datin=x((bsz*(k-1)+1):end);
            %add zeros to buffer size
            datin(end+1:bsz)=zeros(bsz-length(datin),1);
        else
            %no data to send, just send zeros
            datin=zeros(bsz,1);
        end
        
        %play/record audio
        [datout,ur,or]=apr(datin);

        %check if this is not the first run
        if(k>1)
            %add data to array
            y((bsz*(k-2)+1):(bsz*(k-1)))=datout;
        end

        %add under and over runs
        underRun=underRun+ur;
        overRun=overRun+or;

    end
    
    %release the audio object
    release(apr);
    
    