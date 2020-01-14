function [pesqmos,moslqo]=pesq_wrapper(fs,ref,deg)
%PESQ_WRAPPER wrapper function for pesq algorithm
%
%   [pesqmos,moslqo] = PESQ_WRAPPER(fs,ref,deg) compute the pesq scores for
%   audio that has been degraded by an audio channel. fs is the sample
%   frequency of the audio. ref is the uncorrupted audio and deg is the
%   audio that has passed through the channel. 
%
%   The data is resampled to 16 kHz and saved out to temporary .wav files
%   so that it can be fed to the PESQ executable.
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

    %resample vectors to 16kHz
    ref=resample(ref,1,fs/16e3);
    deg=resample(deg,1,fs/16e3);
    
    fs_new=16e3;

    %generate temporary file names
    ref_file=[tempname '.wav'];
    deg_file=[tempname '.wav'];
    
    %write out audio files
    audiowrite(ref_file,ref,fs_new);
    audiowrite(deg_file,deg,fs_new);
    
    %call pesq executable
    [stat,~]=system(sprintf('pesq +%i %s %s',fs_new,ref_file,deg_file));
    
    %check if the status was good
    if(stat~=0)
        error('pesq.exe returned %i',stat);
    end
    
    %open pesq_results.txt
    res=fopen('pesq_results.txt','rt');
    
    %read data from pesq_results.txt
    rstr=char(fread(res)');
    
    %close file
    fclose(res);
    
    %generate regexp to find our entry
    rx=[ deslash(ref_file) '\s+' deslash(deg_file) '+\s+(?<pesqmos>[0-9.]+)\s+(?<moslqo>[0-9.]+)'];
    
    %find in file
    mos=regexp(rstr,rx,'names');
    
    %check if MOS scores found
    if(isempty(mos))
        %No MOS scores found, return NaN
        pesqmos=NaN;
        moslqo=NaN;
    else
        %get MOS scores
        pesqmos=str2double(mos.pesqmos);
        moslqo=str2double(mos.moslqo);
    end
end

function ds=deslash(s)
    ds=regexprep(s,'\\','\\\\');
end


