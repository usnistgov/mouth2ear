function run_stats( name )
%RUN_STATS generate statistics for a run
% 
%   RUN_STATS(name) generate statistics for the run given by name

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

