load('chirp.mat','y','fs');

%list of sound device names to use
device_names={'UH-7000','M-Track','Focusrite','UMC204HD','Scarlett'};

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%get a list of the audio devices
ad=aPR.getAudioDevices();

%get the first match
devIdx=find(contains(ad,device_names),1);

%set device
aPR.Device=ad{devIdx};

[dat,underRun,overRun]=aPR(y.');
[dat,underRun,overRun]=aPR(y.');



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

plot(yu)

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
