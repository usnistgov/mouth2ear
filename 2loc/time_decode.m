function [dates,fsamp,frames,fbits]=time_decode(tca,fs,varargin)
%TIME_DECODE decode an IRIG-B timecode
%
%   [dates,fsamp]=TIME_DECODE(tca,fs) decodes timecode audio from tca into
%   a datetime vector given by dates. fs is the audio sample rate for tca.
%   fsamp is an array the same size as dates containing the audio sample
%   number corosponding to each decoded timecode.
%
%   [dates,fsamp,frames]=TIME_DECODE(tca,fs) same as above but, also
%   returns the decoded IRIG-B frames as a Nx9 matrix, where N is the
%   length of the dates vector.
%
%   [dates,fsamp,frames,fbits]=TIME_DECODE(tca,fs) same as above but, also
%   returns the decoded IRIG-B frame bits in a Nx100 matrix. The values in
%   the matrix are -1, 0, 1, 2 for error, zero, one and frame marker bits
%
%   [__]=TIME_DECODE(__,name,value) specify decoding parameters with name
%   value pairs. Possible parameters are shown below:
%
%   NAME        TYPE            Description
%
%   TcTol       double          Time code tollerence. This changes the
%                               thresholds for what bit periods are
%                               considered a one, zero and frame marker.
%                               For example a TcTol value of 0.05 would
%                               consider a bit period that is within +/- 5%
%                               of the nominal value to be a valid bit. The
%                               default value for TcTol is 0.2
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

    %add timecode audio argument
    addRequired(p,'tca',@(l)validateattributes(l,{'numeric'},{'real','vector'}));
    %add sample rate argument
    addRequired(p,'fs',@(l)validateattributes(l,{'numeric'},{'positive','real','scalar'}));
    %add timecode tollerence option
    addParameter(p,'TcTol',0.05,@(l)validateattributes(l,{'numeric'},{'positive','real','scalar','<=',0.5}));

    %set parameter names to be case sensitive
    p.CaseSensitive= true;

    %parse inputs
    parse(p,tca,fs,varargin{:});

    %calculate the envelope
    env=envelope(p.Results.tca,40,'analytic');

    %use kmeans to threshold the envalope
    env_th=kmeans_mcv(env,2)-1;

    %find edges assume that signal starts high so that we see the first real
    %rising edge
    edges=find(diff([1;env_th]));

    %get rising edges
    r_edg=edges(env_th(edges)==1);

    %get falling edges
    f_edg=edges(env_th(edges)==0);

    %get the first rising edge
    start=r_edg(1);

    %get the last rising edge
    endtc=r_edg(end);

    %remove falling edges that happen before the first rising edge and after
    %the last
    f_edg=f_edg(f_edg>start & f_edg<endtc);

    %calculate period
    T=diff(r_edg)/p.Results.fs;

    %figure;
    %t=(1:length(env_th))*1e3/p.Results.fs;
    %plot(r_edg(1:end-1)*1e3/p.Results.fs,T*1e3,t,env_th*10);

    %calculate the pulse width there is one more rising edge than falling edge
    pw=(f_edg-r_edg(1:end-1))/p.Results.fs;

    bits=pw_to_bits(pw,10e-3,p.Results.TcTol);
    
    Tbit=10e-3;
    
    %find invalid periods
    invalid=T<(Tbit*(1-p.Results.TcTol)) | T>(Tbit*(1+p.Results.TcTol));
    
    %mark bits with invalid periods as invalid
    bits(invalid)=-2;

    %figure;
    %plot(r_edg(1:end-1)*1e3/p.Results.fs,bits,r_edg(1:end-1)*1e3/p.Results.fs,pw*1e3);

    %index within a frame -1 means invalid frame
    frame_idx=-1;

    weight=[  1,  2,  4,  8,  0, 10, 20, 40, -1,  1,  2,  4,  8,  0, 10, 20, 40,  0, -1,...
          1,  2,  4,  8,  0, 10, 20,  0,  0, -1,  1,  2,  4,  8,  0, 10, 20, 40, 80, -1,...
        100,200,  0,  0,  0,0.1,0.2,0.4,0.8, -1,  1,  2,  4,  8,  0, 10, 20, 40, 80, -1,...
          1,  2,  4,  8, 16, 32, 64,128,256, -1,  1,  2,  4,  8, 16, 32, 64,128,256, -1,...
          1,  2,  4,  8, 16, 32, 64,128,256, -1,512,1024,2048,4096,8192,16384,32768,65536,0,-1];

    value=[  1,1,1,1,1,1,1,1,-1,2,2,2,2,2,2,2,2,2,-1,...
           3,3,3,3,3,3,3,3,3,-1,4,4,4,4,4,4,4,4,4,-1,...
           4,4,4,4,4,5,5,5,5,-1,6,6,6,6,6,6,6,6,6,-1,...
           7,7,7,7,7,7,7,7,7,-1,8,8,8,8,8,8,8,8,8,-1,...
           9,9,9,9,9,9,9,9,9,-1,9,9,9,9,9,9,9,9,9,-1];
       
    %preallocate frames to hold the maximum number of frames
    frames=zeros(floor(length(bits)/100),max(value));
    %preallocate frame bits
    fbits=zeros(floor(length(bits)/100),100);
    %sample number of the first rising edge in the frame
    fsamp=zeros(floor(length(bits)/100),1);
    
    %frame number
    fnum=1;

    for k=2:length(bits)
        %check if we are not a valid frame
        if(frame_idx==-1)
            %check for a frame start
            if(bits(k)==2 && bits(k-1)==2)
                %set new frame index
                frame_idx=1;
                %zero frame data
                frame=zeros(1,max(value));
            end
        else
            %check if this should be a marker bit
            if(mod(frame_idx,10)==9)
                %check if marker is found
                if(bits(k)~=2)
                    %give warning for missing marker
                    warning('Marker not found at frame index %i',frame_idx);
                    %reset frame index
                    frame_idx=-1;
                    %restart loop
                    continue;
                end
            else
                %check that bit is a 1 or zero
                if(bits(k)~=1 && bits(k)~=0)
                    %give warning based on bit value
                    switch bits(k)
                        case -2
                            %give warning for invalid period
                            warning('Invalid bit period at frame index %i',frame_idx);
                        case -1
                            %give warning for invalid bit value
                            warning('Invalid bit at frame index %i',frame_idx);
                            
                        case 2
                            %give warning for unexpected marker
                            warning('Unexpected marker at frame index %i',frame_idx);
                        otherwise
                            %give warning for invalid bit value
                            warning('Unexpected bit value %i at frame index %i',bits(k),frame_idx);
                    end
                    %reset frame index
                    frame_idx=-1;
                    %restart loop
                    continue;
                end
                %get value idx
                vi=value(frame_idx);
                %otherwise get bit value
                frame(vi)=frame(vi)+bits(k)*weight(frame_idx);
            end
            %increment frame index
            frame_idx=frame_idx+1;
            %check if frame is complete
            if(frame_idx>=100)
                %store decoded frame data
                frames(fnum,:)=frame;
                %store decoded frame bits
                fbits(fnum,:)=bits((k-99):k);
                %get sample number of the first rising edge after frame marker
                fsamp(fnum,:)=r_edg(k-98);
                %search for next frame
                frame_idx=-1;
                %increment frame number
                fnum=fnum+1;
            end
        end
    end

    %remove extra data
    frames=frames(1:(fnum-1),:);
    fbits = fbits(1:(fnum-1),:);
    fsamp = fsamp(1:(fnum-1),:);
    
    %create date vectors
    %IRIG B does not give month or day of month so use a empty part of the
    %frame for month and fix it to 1 later. Day of year will wrap to the
    %correct month
    dvec=frames(:,[6,5,4,3,2,1]);
    
    %add in year digits from current year
    dvec(:,1)=dvec(:,1)+floor(year(datetime)/100)*100;
    
    %set month to 1. Day of year will wrap to the correct month
    dvec(:,2)=1;
    
    %convert to datetimes
    dates=datetime(dvec);
    
end

function [t1,t2]=fix_overlap(t1,t2)
    %check if thresholds overlap    
    if(t1>t2)
        %set thresholds to average
        t1=mean([t1,t2]);
        t2=t1+eps;
    end
end

function [valid]=is_valid_pw(val,th)
    valid=val>th(1) & val<th(2);
end

function bits=pw_to_bits(pw,Tb,tol)
    %thresholds for ones
    Th1=0.5*Tb+Tb*[-tol,tol];
    %thresholds for zeros
    Th0=0.2*Tb+Tb*[-tol,tol];
    %thresholds for marker
    Thm=0.8*Tb+Tb*[-tol,tol];
    %make sure thresholds don't overlap
    [Th0(2),Th1(1)]=fix_overlap(Th0(2),Th1(1));
    [Th1(2),Thm(1)]=fix_overlap(Th1(2),Thm(1));
    %check for valid pulse width for a one
    valid1 =is_valid_pw(pw,Th1);
    %check for valid pulse width for a zero
    valid0 =is_valid_pw(pw,Th0);
    %check for valid marker pulse width
    validmk=is_valid_pw(pw,Thm);
    
    %return 0 for zero 1 for one 2 for mark and -1 for invalid
    bits=valid1+validmk*2 - (~(validmk | valid1 | valid0 ));
end