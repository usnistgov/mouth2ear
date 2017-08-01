function run_export( in_name,out_name,run )
%RUN_EXPORT export a run to an audio file
%   RUN_EXPORT is used to generate an audio file for use with
%   sliding_delay_estimates.m


if(~exist('run','var') || isempty(run))
    %use the first run
    all_runs=true;
else
    all_runs=false;
end

%add 2s of padding between runs
pad=2;

%load in data
dat=load(in_name,'recordings','y','fs');
    
%check if sample rate exists
if(~exist('dat.fs','var'))
    %default sample rate
    fs=48e3;
else
    %get sample rate
    fs=dat.fs;
end

%check if we are using only one run
if(~all_runs)
    %get run
    x=dat.recordings{run};
    y=dat.y;
else
    %get lengths of recordings
    lens=cellfun(@length,dat.recordings);
    %add padding
    lens=lens+pad*fs;
    %calculate ineicies of end of array
    end_i=cumsum(lens);
    %calculate indicies of start of array
    start_i=end_i-lens+1;
    %subtract padding from end
    end_i=end_i-pad*fs;
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
audiowrite(out_name,c,fs);

end

