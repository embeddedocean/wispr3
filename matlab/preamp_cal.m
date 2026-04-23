%
% Matlab script to calculate and plot wispr pre-amp calibration gain curve.
% The script takes as input a calibration data file generated using a signal generator input to the preamp board. 
% The script produces a text gain file that can be read by wispr.
% The calibration input signal is a constant voltage frequency sweep over the range of interest, 
% typically a sweep from 0 to 200 kHz over at least 10 or 20 seconds, but the longer the better.
% This is called the input voltage (vin).
% The gain is recorded voltage / input voltage (vout/vin) expressed in dB 
% for each frequency bin over the range of interest. 
% The data recorded in the data file is called the output voltage because
% it's the output of the preamp and adc, Vout includes all the preamp gain stages and
% the filter, including the HP and LP analog filters and the digital
% anti-aliasing filters of the adc.
% EOS cjones, 2/2025

clear all;

% SN of the preamp/adc board - must be a string less than 16 chars
sn = 'EOS01';

% prompt for SN
str = sprintf('Enter SN [%s]: ', sn);
in = input(str, 's');
if(~isempty(in))
    sn = in;
end

% define name of output gain files
mat_file = sprintf('%s_preamp_gain.mat', sn);
txt_file = sprintf('%s_preamp_gain.txt', sn);
png_file = sprintf('%s_preamp_gain.png', sn);

% pick a data file for the data recorded using the signal generator
[file, dpath, filterindex] = uigetfile('*.dat', 'Pick a data file');
name = fullfile(dpath,file);

% define hydropgone sensitivity, not used for the calibration 
% but saved in the calibration file for use later
hydro_sens = -176.0;

% define the amplitude of sine wave sweep
amp = 0.010;
str = sprintf('Enter input amplitude [%f]: ', amp);
in =  input(str);
if(~isempty(in))
    amp = in;
end

R = 1;
%str = sprintf('Enter decimation factor [%d]: ', R);
%in =  input(str);
%if(~isempty(in))
%    R = in;
%end

% Define input voltage if a voltage divider is used for the input
%R2 = 47;
%R1 = 4700;
% The 2 is because amp half of the differenceial signal
%vin = 2 * amp * (R2/(R2+R1)); % voltage divider
%vin = sqrt(2) * vin / 2; % RMS

% Define input voltage if a 20db attenuator (20 dB)
% The 2 is because amp is half of the differenceial signal
% Need to check that the attenuator 20db include the rms factor of sqrt(2)/2
vin = 2 * amp / 10; 

% Read the calibration data file collected with a signal generator input
[hdr, vout, time] = read_wispr_file(name, 2, 1024);

%vout = sqrt(mean(data(:).^2)); % RMS
vout = vout(:);
time = time(:);

% decimate vout
if ( R > 1 )
    vout = decimate(vout,R);
    time = time(1:R:end);
end

% plot data buffers 
figure(1); clf;
d = 50/R;
%plot(time(1:d:end,:), vout(1:d:end,:),'.-');
plot(vout(1:d:end),'-');
ylabel('Volts');
xlabel('Sample');
grid on;
%axis([min(min(time)) max(max(time)) -5.1 5.1]);

% pick a segment of the input data to use for calibration
% This should be at a minimul one complete sweep pulse
bound = ginput(2);
start = floor(d * bound(1));
stop = floor(d * bound(2)) + 1;
vout = vout(start:stop);
time = time(start:stop);
time = time - time(1);

% remove mean
vout = vout - mean(vout);

figure(1); %clf;
plot(time, vout,'.-');
ylabel('Volts');
xlabel('Sample');
grid on;
%axis([min(min(time)) max(max(time)) -5.1 5.1]);

% Calc spectrum of vout/vin
fft_size = 256;
str = sprintf('Enter fft size [%d]: ', fft_size);
in =  input(str);
if(~isempty(in))
    fft_size = in;
end
overlap = fft_size-64;
%window = rectwin(fft_size);
window = hamming(fft_size)*1.59; %multiply energy correction
%window = hann(fft_size)*1.63;
fs = hdr.sampling_rate;
[spec, f] = cal_spec(vout/vin, fs, window, overlap, time(1));

preamp_gain = 10*log10(spec);
preamp_freq = f;

% plot spectrum
ind = (1:(length(preamp_gain)-13));
fig2 = figure(2); clf;  
set(fig2, 'Position', [50 50 950 450]);
%hold on;
plot(preamp_freq(ind)/1000, preamp_gain(ind),'.-'); %normalize the power spec 
grid(gca,'minor');
grid on;
xlabel('Frequency [kHz]'),
ylabel('20*log_{10}( V_{out} \\ V_{in} )');
%axis([0 f(end)/1000 -185 -135]);
title(sn);

% save the plot
print(fig2, '-dpng', png_file);
    
%save the data as mat file
save(mat_file, 'vout', 'vin', 'fs', 'preamp_freq', 'preamp_gain');

nbins = length(preamp_freq);

fp = fopen(txt_file, 'w');
fprintf(fp, 'PREAMP GAIN\r\n');
fprintf(fp, 'SN: %s\r\n', sn);
fprintf(fp, 'sensitivity: %.2f\r\n', hydro_sens);
fprintf(fp, 'nbins: %d\r\n', nbins);
fprintf(fp, 'dfreq: %.3f\r\n', preamp_freq(3) - preamp_freq(2));
for n=1:nbins
    fprintf(fp, '%.2f, %.2f\n', preamp_freq(n), preamp_gain(n));
end
fclose(fp);



