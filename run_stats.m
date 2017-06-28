function run_stats( name )
%run_stats generate statistics for a run
%   Detailed explanation goes here

%maximum number of runs in a file
max_size=2e3;

%split filename into parts
[fold,nm,ext]=fileparts(name);

%find the last three underscores
sp=find(nm=='_',3,'last');

%get number of runs
runs=str2double(nm(sp(3)+1:end));

%get base filename
base_filename=nm(1:(sp(1)-1));

%preallocate arrays
st_dly=zeros(1,runs*max_size);
underRun=zeros(1,runs*max_size);
overRun=zeros(1,runs*max_size);

pos=1;

for k=1:runs
    %print out which file is being read
    fprintf('Reading file %i of %i\n',k,runs);
    
    %get run data
    run_dat=load(fullfile(fold,sprintf('%s_%i_of_%i%s',base_filename,k,runs,ext)),'st_dly','underRun','overRun');

    %get run length
    run_length=length(run_dat.st_dly);

    %get range of values that are being set
    rng=pos+(0:(run_length-1));

    %put data in larger array
    st_dly(rng)    =run_dat.st_dly;
    underRun(rng)  =run_dat.underRun;
    overRun(rng)   =run_dat.overRun;

    %add run length to position
    pos=pos+run_length;

end

%range of valid values
rng=1:pos-1;

%limit array sizes to valid values
st_dly=st_dly(rng);
underRun=underRun(rng);
overRun=overRun(rng);

%check for buffer over runs
if(any(overRun))
    fprintf('There were %i buffer over runs\n',sum(overRun));
else
    fprintf('There were no buffer over runs\n');
end

%check for buffer over runs
if(any(underRun))
    fprintf('There were %i buffer under runs\n',sum(underRun));
else
    fprintf('There were no buffer under runs\n');
end

%new figure
figure;

%split window into subplots
subplot(1,2,1);

%plot histogram
histogram(st_dly,'Normalization','probability');

%calculate delay mean
dly_m=mean(st_dly);

%get engineering units
[dly_m_e,~,dly_u]=engunits(dly_m,'time');

%add mean in title
title(sprintf('Mean : %.2f %s',dly_m_e,dly_u));

%switch to second subplot
subplot(1,2,2);
%plot histogram
histogram(st_dly,300,'Normalization','probability');

%calculate standard deviation
st_dev=std(st_dly);

%get engineering units
[st_dev_e,~,st_u]=engunits(st_dev,'time');

%add Standard Deveation in title
title(sprintf('StD : %.1f %s',st_dev_e,st_u));

%print plot to .png
print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');

figure;
plot(st_dly);

end

