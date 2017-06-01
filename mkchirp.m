fs=48e3;
c_len=1;
rep=1;
chan=1;
t = 0:1/fs:c_len;
fo = 200;
f1 = 800;
y0 = 0.01*chirp(t,fo,c_len,f1,'logarithmic',90);

%find last zero in the waveform
idx=find(abs(y0)<1e-3,1,'last');

y=repmat(y0(1:idx),chan,rep);

save('chirp.mat','y','fs');