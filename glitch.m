load('chirp.mat','y','fs');

%create an object for playback and recording
aPR=audioPlayerRecorder(fs);

%chose which device to use
name=choose_device(aPR);

%print the device used
fprintf('Using "%s" for audio test\n',name);

[dat,underRun,overRun]=play_record(aPR,y.');


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

%get the threshold 90% of the lower edge of the most comon bin
env_th=0.9*env_edg(idx);

%threshold envalope
yu_th=yu>env_th;

%find the start of the envalope
env_st=find(yu_th,1);

%find glitches
g_idx=find(~yu_th);

%eliminate start of sample
g_idx=g_idx(g_idx>env_st);

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
