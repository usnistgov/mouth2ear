load('chirp.mat','y','fs');

%get audio device info
ad=audiodevinfo;

%list of sound device names to use
device_names={'UH-7000','M-Track','Focusrite','UMC','Scarlett'};

input_dev_idx=0;
%find input device
for k=1:length(ad.input)
    %check if device name is what we are looking for
    if(contains(ad.input(k).Name,device_names))
        %get ID of device
        input_dev_idx=k;
        %done
        break;
    end
end

%check that input device was found
if(input_dev_idx==0)
    error('Could not find sutable input device');
end


output_dev_idx=0;
%find matching output device
for k=1:length(ad.output)
    %check if device name is what we are looking for
    if(strcmp(ad.output(k).Name,ad.input(input_dev_idx).Name))
        %get ID of device
        output_dev_idx=k;
        %done
        break;
    end
end

%check that input device was found
if(output_dev_idx==0)
    error('Could not find sutable output device');
end

%get input device id's from index
input_dev=ad.input(input_dev_idx).ID;
%get output device id's from index
output_dev=ad.output(output_dev_idx).ID;

%create audio device objects to use
p=audioplayer(y,fs,24,output_dev);
r=audiorecorder(fs,24,size(y,1),input_dev);


%start recording
record(r);
%play waveform
playblocking(p);
%pause to get all data
pause(0.5);
%stop recording
stop(r)

%get recorded data
dat=getaudiodata(r);


st_idx=finddelay(y',dat);

st_dly=1/fs*st_idx;

%check if delay is positive or negative
if(st_idx>0)
    a=y;
    b=dat(st_idx:end);
else
    a=y((-st_idx):end);
    b=dat;
end

%reshape vectors so they are uniform
a=a(:);
b=b(:);

%get the length of each vector
l1=length(a);
l2=length(b);

%git minimum length
l=min(l1,l2);

%generate range of elements to use
rng=1:l;

%find DC value
amp_a=mean(abs(a(rng)));
amp_b=mean(abs(b(rng)));

%compute scaled diffrence between signals
d=a(rng)-(amp_a/amp_b)*b(rng);

figure;

%plot diffrence
plot(rng*1/fs,d,rng*1/fs,a(rng),rng*1/fs,(amp_a/amp_b)*b(rng));

legend('diffrence','Transmit','Recieve');

figure;

[yu,yl]=envelope(dat,round(fs/100));

%bin envalope
[env_n,env_edg]=histcounts(yu);

%find the most common bin
[~,idx]=max(env_n);

%get the threshold 80% of the lower edge of the most comon bin
env_th=0.8*env_edg(idx);

%threshold envalope
yu_th=yu>env_th;

%find the start of the envalope
env_st=find(yu_th,1);

%find the end of the envalope
env_end=find(yu_th,1,'last');

%find glitches
g_idx=find(~yu_th);

%eliminate start and end of sample
g_idx=g_idx(g_idx>env_st & g_idx<env_end);

fprintf('There were %i glitches\n',length(g_idx))

%generate time vector
t=(1:length(dat))*1/fs;

%plot envalope and detected glitch samples
plot(t,yu,t,yl,t,dat,t(g_idx),yu(g_idx),'ro')

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
