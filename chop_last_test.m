clear all
close all
audio_path = fullfile('..','..','word-database-gen','T_2000ms-AllFilled');

clip_name = 'M3_b22_w3_cop.wav';

clip_full = fullfile(audio_path,clip_name);
[y,fs] = audioread(clip_full);

cp_full = strrep(clip_full,'wav','csv');
cp = csvread(cp_full,1,0);

t = @(x) (1:length(x))/fs;


% 500 ms delay
dly_act = fs/2;

sig = 0.01;
noise = sig*randn(length(y)+dly_act,1);


% Impose delay
rx_nocut = noise+[zeros(dly_act,1); y];

p2_start = cp(4,2);
p2_end = cp(4,3);
p2_mid = p2_start+round((cp(4,3)-cp(4,2))/2);
rx_fullcut = rx_nocut(cp(1,2):(dly_act+p2_start));

rx_halfcut = rx_nocut(cp(1,2):(dly_act+p2_mid));

dly_nocut = ITS_delay_wrapper(rx_nocut,y,fs);
dly_halfcut = ITS_delay_wrapper(rx_halfcut,y,fs);
dly_fullcut = ITS_delay_wrapper(rx_fullcut,y,fs);

disp(['No cut: ' num2str(dly_nocut) ' ms'])
disp(['Half cut: ' num2str(dly_halfcut) ' ms'])
disp(['Full cut: ' num2str(dly_fullcut) ' ms'])
