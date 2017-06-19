function run_export( in_name,out_name,run )
%RUN_EXPORT export a run to an audio file
%   RUN_EXPORT is used to generate an audio file for use with
%   sliding_delay_estimates.m

%sample rate
fs=48e3;

if(~exist('run','var') || isempty(run))
    %use the first run
    run=1;
end

%load in data
dat=load(in_name,'recordings','y');
    
%get run
x=dat.recordings{run};

%get maximum length
len=max(length(x),length(dat.y));

%allocate space for combined data
c=zeros(len,2);

%assemble data
c(1:length(dat.y),1)=dat.y;
c(1:length(x),2)=x;

%write file
audiowrite(out_name,c,fs);

end

