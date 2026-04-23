%
% matlab script to plot wispr pam data
%
% chris@embeddedocean - 7/2024
%

clear all;

% Pick a .dat file to display
dpath = '.\*.dat';
[file, dpath, filterindex] = uigetfile(dpath, 'Pick a data file');
name = fullfile(dpath,file);
if file == 0
    return;
end

% read the file header
[hdr, vout, time] = read_wispr_file(name, 0, 0);

% number of seconds of data to plot
str = sprintf('Enter number of seconds to plot [%f]: ', hdr.file_duration);
num_secs_to_display =  input(str);
if(isempty(num_secs_to_display))
    num_secs_to_display = hdr.file_duration;
end

nsamps = hdr.samples_per_buffer/hdr.channels; % num samps per chan per buffer
num_bufs_to_display = round(num_secs_to_display * hdr.sampling_rate / nsamps);

%R = input('Enter data decimation factor [1]: ');
%if(isempty(R))
%    R = 1;
%end
%sampling_rate = sampling_rate / R;

plot_psd = input('Plot PSD [0]: ');
plot_timestamp = input('Plot data timestamp [0]: ');

if( plot_psd )
    
    fft_size = input('Enter FFT size [1024]: ');
    if(isempty(fft_size))
        fft_size = 1024;
    end

    % fft overlap 
    overlap = fft_size / 2;
    str = sprintf('Enter FFT overlap [%d]: ', overlap); 
    in = input(str);
    if(~isempty(in))
        overlap = in;
    end

    % read preamp gain file if available
    preamp = [];
    gain_file = 0;
    use_preamp_gain = input('Use a pre-amp calibration [0]: ');
    if use_preamp_gain
        gpath = '.\*.txt';
        [gfile, gpath, filterindex] = uigetfile(gpath, 'Pick a pre-amp calibration data file');
        if( gfile )
            gain_file = fullfile(gpath,gfile);
            preamp = read_preamp_gain_file(gain_file);
            % add adjustable gain (in 6db increments) using gain setting in the file header 
            preamp.gain = preamp.gain + (6.0 * hdr.gain); 
        end
        % prompt for sensitivity because a different hydrophones may be used
        str = sprintf('Enter hydrophone sensitivity [%f]: ', preamp.hydro_sensitivity);            
        q = input(str);
        if( q ) 
            preamp.hydro_sensitivity = q;
        end
    end

end

% file start time
t0 = hdr.second;
%t0 = hdr.second + hdr.usec * 0.000001;

start = 1;
go = 1;
flip = 1;

while( go )

    data = [];
    time = [];

    % read the data buffers
    [hdr, raw, time, timestamp] = read_wispr_file(name, start, start + num_bufs_to_display);
    if(isempty(raw))
        break;
    end;
    
    % increment the buffer read start
    start = start + num_bufs_to_display;
    
    % remove the start time because the numbers are too big for plot zoom
    t0 = time(1,1);
    time = time(:) - t0;
    
    % reshape data matrix 
    nchans = hdr.channels;
    nsamps = length(raw(:)) / nchans;
    data = transpose(reshape(raw(:), nchans, nsamps));
    
    % remove the mean
    %data = data - mean(data(:));

%    for n = 1:size(raw,2)
%        raw(:,n) = flip * raw(:,n);
%        flip = -1 * flip;
%    end
    
    % plot data buffers
    fig1 = figure(1); clf;
    %subplot(2,1,1);
    plot(time, data,'.-');
    ylabel('Volts');
    xlabel('Seconds');
    grid on;
    axis([min(time(:)) max(time(:)) min(data(:))-0.1 max(data(:))+0.1 ]);
    str = sprintf('%s', file(1:end-4));
    str = strrep(str, '_', '\_');
    title(str);
    
    if plot_psd
        
        for chan = 1:nchans

            % Calc spectrum of data
            fs = hdr.sampling_rate;
            psd = pam_psd(data(:,chan), fs, fft_size, overlap, t0, preamp);

            % plot noise spectrum
            fig2 = figure(chan+1); clf;
            subplot(2,1,2);
            %hold on;
            semilogx(psd.freq/1000, psd.db, 'k.-');
            %grid(gca,'minor');
            grid on;
            xlabel('Frequency [kHz]'),
            sig_var = var(data(:));
            title('Averaged Power Spectral Density Estimate');
            %title(['Averaged Power Spectral Density Estimate: Total Energy ' num2str(psd.total_energy) ', Variance ' num2str(sig_var)]);
            if use_preamp_gain
                ylabel('dB re: 1 uPa^2/Hz');
                plot_wenz(2);
                axis([0 psd.freq(end)/1000 0 100]);
                %legend('SPL','Wenz SS-0', 'Wenz SS-1', 'Wenz SS-6');
            else
                ylabel('dB re: 1 V^2/Hz');
            end
            subplot(2,1,1);
            hold on;
            %surf(T, freq/1000, 10*log10(abs(spec)),'EdgeColor','none');
            surf(psd.time-psd.time(1), psd.freq/1000, psd.spectrogram,'EdgeColor','none');
            axis xy; axis tight; view(0,90);
            xlabel('Seconds');
            ylabel('Frequency (kHz)');
            if use_preamp_gain
                str = sprintf('%s Spectrogram: Channel %d', file(1:end-4), chan);
                colormap(gray); caxis([20 80]);
            else
                str = sprintf('%s Spectrogram: Channel %d', file(1:end-4), chan);
                colormap(bone); caxis([-120 -80]);
            end
            colorbar();
            str = strrep(str, '_', '\_');
            title(str);
        end

    end

    if plot_timestamp 
        fig3 = figure(3); clf;
        bufs = start+(0:(length(timestamp)-1));
        plot(bufs, timestamp-t0, '.-');
        title('Data buffer timestamps');
        ylabel('Seconds');
        xlabel('Buffer number');
        grid on;
        axis([min(bufs) max(bufs)+1 min(timestamp-t0)-0.1 max(timestamp-t0)+0.1 ]);    
    end

    while 1
        chan = 0;
        str = sprintf('Play sound channel [%d]: ', chan); 
        in = input(str);
        if(~isempty(in)) 
            chan = in; 
            if( chan >= 1 && chan <= nchans )
                sound(data(:,chan)/max(data(:,chan)),hdr.sampling_rate);
            end;
        else
            break;
        end
    end

    if(start >= hdr.number_buffers)
        go = 0;
        break;
    end

    if(input('quit [0]: ') == 1)
        go = 0;
        break;
    end;

end

in = input('Save plot [0]:');
if( in == 1 )
    print(fig1, '-dpng', [file(1:end-4) '']);
    if(fig2)
        print(fig2, '-dpng', [file(1:end-4) '_psd']);
    end
end

return;

