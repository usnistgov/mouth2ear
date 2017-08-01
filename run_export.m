function run_export( in_name,out_name,varargin)
%RUN_EXPORT export a run to an audio file
%   RUN_EXPORT is used to generate an audio file for use with
%   sliding_delay_estimates.m

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

