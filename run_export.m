function run_export( in_name,out_name,varargin)
%RUN_EXPORT export a run to an audio file
%   RUN_EXPORT is used to generate an audio file for use with
%   sliding_delay_estimates.m

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
addRequired(p,'in_name',@(l)validateattributes(l,{'char'},{'vector'}));
%add output audio argument
addRequired(p,'out_name',@(l)validateattributes(l,{'char'},{'vector'}));
%add number of runs argument
addOptional(p,'runs',-1,@(l)validateattributes(l,{'numeric'},{'scalar','positive'}));
%add padding time parameter 
addParameter(p,'Pad',0,@(l)validateattributes(l,{'numeric'},{'scalar','nonnegative'}));

%set parameter names to be case sensitive
p.CaseSensitive= true;

%parse inputs
parse(p,in_name,out_name,varargin{:});

%load in data
dat=load(p.Results.in_name,'recordings','y','fs');
    
%check if sample rate exists
if(~exist('dat.fs','var'))
    %default sample rate
    fs=48e3;
else
    %get sample rate
    fs=dat.fs;
end

%check if we are using only one run
if(p.Results.runs>0)
    %get run
    x=dat.recordings{p.Results.runs};
    y=dat.y;
else
    %get lengths of recordings
    lens=cellfun(@length,dat.recordings);
    %add padding
    lens=lens+p.Results.Pad*fs;
    %calculate ineicies of end of array
    end_i=cumsum(lens);
    %calculate indicies of start of array
    start_i=end_i-lens+1;
    %subtract padding from end
    end_i=end_i-p.Results.Pad*fs;
    %preallocate x
    x=zeros(sum(lens),1);
    %preallocate y
    y=zeros(sum(lens),1);
    %write data into array
    for k=1:length(start_i)
        %write data between start and end indicies
        x(start_i(k):end_i(k))=dat.recordings{k};
        %write data starting at start_i
        y(start_i(k)+(1:length(dat.y))-1)=dat.y;
    end
end
    
%get maximum length
len=max(length(x),length(y));

%allocate space for combined data
c=zeros(len,2);

%assemble data
c(1:length(y),1)=y;
c(1:length(x),2)=x;

%write file
audiowrite(p.Results.out_name,c,fs);

end

