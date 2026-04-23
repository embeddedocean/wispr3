function [psd] = pam_psd(data, fs, fft_size, overlap, t0, preamp)

% Define fft window and multiply window by energy correction
window = hamming(fft_size)*1.59;
%window = hann(fft_size)*1.63;

psd.db = [];
psd.freq = [];


% remove the mean
data = data - mean(data(:));

% Calc spectrum of data
[spec, freq, time] = my_spec(data(:), fs, window, overlap, t0);

sig_var = var(data(:));

% if no preamp gain given
if( isempty( preamp ) )
    % then use db V^2/Hz 
    psd.units = 'dB re: 1 V^2/hz';
    psd.db = 10*log10(mean(spec,2));
    psd.spectrogram = 10*log10(spec);
    psd.hydro_sensitivity = 0;
    psd.gain = [];
else
    % else convert to db uPa^2/Hz and remove gain, 
    gain = interp1(preamp.freq, preamp.gain, freq, 'pchip'); %interpolate
    psd.units = 'dB re: 1 uPa^2/Hz';
    psd.db = 10*log10(mean(spec,2)) - (preamp.hydro_sensitivity + gain);
    psd.spectrogram = 10*log10(spec) - (preamp.hydro_sensitivity + gain)*ones(1,size(spec,2));
    psd.hydro_sensitivity = preamp.hydro_sensitivity;
    psd.gain = gain;
end

psd.freq = freq;
psd.time = time;
psd.fft_size = fft_size;
bandwidth = fs / fft_size;
psd.total_energy = bandwidth * sum(mean(spec,2));


%--------------------------------------------------------------------------
% PSD Power Spectral Density estimate.
% based on original matlab psd function and this app note:
%    http://www.mathworks.com/help/signal/ug/psd-estimate-using-fft.html
% Returns the average spectrum using ffts as a vector mSpec[nfft] 
% and the unaveraged periodogram as a matrix Spec[nfft,navg].
% cjones
% Energy is adjusted for the frequency bin size- H. Matsumoto 6/21/2021
% units V^2/hz
function [spec, freq, time] = my_spec(x, fs, win, noverlap, t0)

% Make sure inputs are column vectors
x = x(:);		
win = win(:);

n = length(x);		  % Number of data points
nfft = length(win);   % length of window
bandwidth = fs / nfft;

if n < nfft           % zero-pad x if it has length less than the window length
    x((n+1):nfft)=0;  
    n=nfft;
end

% Number of windows
navg = fix((n-noverlap)/(nfft-noverlap));
dt = n/fs/navg;
time = t0 + dt*(0:(navg-1));

% Obtain the averaged periodogram using fft. 
% The signal is real-valued and has even length. 
spec = zeros(nfft,navg); 
index = 1:nfft;
for i=1:navg
    xw = win.*(x(index));
    index = index + (nfft - noverlap);
    spec(:,i) = abs(fft(xw,nfft)).^2;
end

% Because the signal is real-valued, you only need power estimates for the positive or negative frequencies. 
% Select first half
select = (1:nfft/2+1)';
freq = (select - 1)*fs/nfft;

% In order to conserve the total power, multiply all frequencies
% by a factor of 2. Zero frequency (DC) and the Nyquist frequency do not occur twice.
spec = 2*spec(select,:);

% window already has energy correction
%winpow = norm(win)^2; 

% normalization
spec = spec / (nfft *nfft * bandwidth);

%plot(freq_vector,10*log10(abs(P))), grid on
%xlabel('Frequency'), 
%ylabel('Power Spectrum Magnitude (dB)');



