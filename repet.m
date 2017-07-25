% REpeating Pattern Extraction Technique (REPET) class
%   
%   Repetition is a fundamental element in generating and perceiving 
%   structure. In audio, mixtures are often composed of structures where a 
%   repeating background signal is superimposed with a varying foreground 
%   signal (e.g., a singer overlaying varying vocals on a repeating 
%   accompaniment or a varying speech signal mixed up with a repeating 
%   background noise). On this basis, we present the REpeating Pattern 
%   Extraction Technique (REPET), a simple approach for separating the 
%   repeating background from the non-repeating foreground in an audio 
%   mixture. The basic idea is to find the repeating elements in the 
%   mixture, derive the underlying repeating models, and extract the 
%   repeating  background by comparing the models to the mixture. Unlike 
%   other separation approaches, REPET does not depend on special 
%   parameterizations, does not rely on complex frameworks, and does not 
%   require external information. Because it is only based on repetition, 
%   it has the advantage of being simple, fast, blind, and therefore 
%   completely and easily automatable.
%   
%   
%   REPET (original)
%       
%       The original REPET aims at identifying and extracting the repeating 
%       patterns in an audio mixture, by estimating a period of the 
%       underlying repeating structure and modeling a segment of the 
%       periodically repeating background.
%       
%       background_signal = repet.original(audio_signal,sample_rate);
%       
%
%   REPET extended
%       
%       The original REPET can be easily extended to handle varying 
%       repeating structures, by simply applying the method along time, on 
%       individual segments or via a sliding window.
%       
%       background_signal = repet.extended(audio_signal,sample_rate);
%
%   
%   Adaptive REPET
%   
%       The original REPET works well when the repeating background is 
%       relatively stable (e.g., a verse or the chorus in a song); however, 
%       the repeating background can also vary over time (e.g., a verse 
%       followed by the chorus in the song). The adaptive REPET is an 
%       extension of the original REPET that can handle varying repeating 
%       structures, by estimating the time-varying repeating periods and 
%       extracting the repeating background locally, without the need for 
%       segmentation or windowing.
%       
%       background_signal = repet.adaptive(audio_signal)
%       
%   
%   REPET-SIM (with self-similarity matrix)
%       
%       The REPET methods work well when the repeating background has 
%       periodically repeating patterns (e.g., jackhammer noise); however, 
%       the repeating patterns can also happen intermittently or without a 
%       global or local periodicity (e.g., frogs by a pond). REPET-SIM is a 
%       generalization of REPET that can also handle non-periodically 
%       repeating structures, by using a similarity matrix to identify the 
%       repeating elements.
%       
%       background_signal = repet.sim(audio_signal)
%   
%   
%   See also http://zafarrafii.com/repet.html
%   
%   
%   Author
%       Zafar Rafii
%
%   Date
%       07/25/17
%
%   
%   References
%       Zafar Rafii, Antoine Liutkus, and Bryan Pardo. "REPET for 
%       Background/Foreground Separation in Audio," Blind Source 
%       Separation, chapter 14, pages 395-411, Springer Berlin Heidelberg, 
%       2014.
%       
%       Zafar Rafii and Bryan Pardo. "Audio Separation System and Method," 
%       US20130064379 A1, US 13/612,413, March 14, 2013.
%       
%       Zafar Rafii and Bryan Pardo. "REpeating Pattern Extraction 
%       Technique (REPET): A Simple Method for Music/Voice Separation," 
%       IEEE Transactions on Audio, Speech, and Language Processing, volume 
%       21, number 1, pages 71-82, January, 2013.
%       
%       Zafar Rafii and Bryan Pardo. "Music/Voice Separation using the 
%       Similarity Matrix," 13th International Society on Music Information 
%       Retrieval, Porto, Portugal, October 8-12, 2012.
%       
%       Antoine Liutkus, Zafar Rafii, Roland Badeau, Bryan Pardo, and Ga�l 
%       Richard. "Adaptive Filtering for Music/Voice Separation Exploiting 
%       the Repeating Musical Structure," 37th International Conference on 
%       Acoustics, Speech and Signal Processing,Kyoto, Japan, March 25-30, 
%       2012.
%       
%       Zafar Rafii and Bryan Pardo. "A Simple Music/Voice Separation 
%       Method based on the Extraction of the Repeating Musical Structure," 
%       36th International Conference on Acoustics, Speech and Signal 
%       Processing, Prague, Czech Republic, May 22-27, 2011.

classdef repet
    
    % Methods (unresctricted access and does not depend on a object of the
    % class)
    methods (Access = public, Static = true)
        
        % REPET (original)
        function background_signal = original(audio_signal,sample_rate)               
        % REPET (original) (see repet)
        
            %%% Defined parameters (can be redefined)
            % Window length in seconds for the STFT (audio stationary 
            % around 40 milliseconds)
            window_duration = 0.040;
            
            % Period range in seconds for the beat spectrum 
            period_range = [1,10];
            
            % Cutoff frequency in Hz for the dual high-pass filter of the
            % foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = 100;
            
            %%% Fourier analysis
            % STFT parameters
            [window_length,window_function,step_length] = repet.stftparameters(window_duration,sample_rate);
            
            % Number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Initialize the STFT
            audio_stft = [];
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % STFT of one channel
                audio_stft1 = repet.stft(audio_signal(:,channel_index),window_function,step_length);
                
                % Concatenate the STFTs
                audio_stft = cat(3,audio_stft,audio_stft1);
            end
            
            % Magnitude spectrogram (with DC component and without mirrored 
            % frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            %%% Beat spectrum and repeating period
            % Beat spectrum of the mean power spectrograms (squared to 
            % emphasize peaks of periodicitiy)
            beat_spectrum = repet.beatspectrum(mean(audio_spectrogram.^2,3));
            
            % Period range in time frames for the beat spectrum
            period_range = round(period_range*sample_rate/step_length);
            
            % Repeating period in time frames given the period range
            repeating_period = repet.periods(beat_spectrum,period_range);
            
            %%% Background signal
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filter of the foreground
            cutoff_frequency = ceil(cutoff_frequency*(window_length-1)/sample_rate);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % Repeating mask for one channel
                repeating_mask = repet.mask(audio_spectrogram(:,:,channel_index),repeating_period);
                
                % High-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency+1,:) = 1;
                
                % Mirror the frequency channels
                repeating_mask = cat(1,repeating_mask,flipud(repeating_mask(2:end-1,:)));
                
                % Estimated repeating background for one channel
                background_signal1 = repet.istft(repeating_mask.*audio_stft(:,:,channel_index),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,channel_index) = background_signal1(1:number_samples);
            end
            
        end
        
        % REPET extended
        function background_signal = extended(audio_signal,sample_rate)
        % REPET extended (see repet)
            
            %%% Defined parameters (can be redefined)
            % Segmentation length and step in seconds
            segment_length = 10;
            segment_step = 5;
            
            % Window length in seconds for the STFT (audio stationary 
            % around 40 milliseconds)
            window_duration = 0.040;
            
            % Period range in seconds for the beat spectrum 
            period_range = [1,10];
            
            % Cutoff frequency in Hz for the dual high-pass filter of the
            % foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = 100;
            
            %%% Derived parameters
            % Segmentation length, step, and overlap in samples
            segment_length = round(segment_length*sample_rate);
            segment_step = round(segment_step*sample_rate);
            segment_overlap = segment_length-segment_step;
            
            % Number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % One segment if the signal is too short
            if number_samples < segment_length+segment_step
                number_segments = 1;
            else
                % Number of segments (the last one could be longer)
                number_segments = 1+floor((number_samples-segment_length)/segment_step);
                
                % Triangular window for the overlapping parts
                segment_window = triang(2*segment_overlap);
            end
            
            % STFT parameters
            [window_length,window_function,step_length] = repet.stftparameters(window_duration,sample_rate);
            
            % Period range in time frames for the beat spectrum
            period_range = round(period_range*sample_rate/step_length);
            
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filter of the foreground
            cutoff_frequency = ceil(cutoff_frequency*(window_length-1)/sample_rate);
            
            %%% Segmentation
            % Initialize background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Wait bar
            wait_bar = waitbar(0,'REPET-WIN');
            
            % Loop over the segments
            for segment_index = 1:number_segments
                
                % Case one segment
                if number_segments == 1
                    audio_segment = audio_signal;
                    segment_length = number_samples;
                else
                    % Sample index for the segment
                    sample_index = (segment_index-1)*segment_step;
                    
                    % Case first segments (same length)
                    if segment_index < number_segments
                        audio_segment = audio_signal(sample_index+1:sample_index+segment_length,:);
                    
                    % Case last segment (could be longer)
                    elseif segment_index == number_segments
                        audio_segment = audio_signal(sample_index+1:number_samples,:);
                        segment_length = length(audio_segment);
                    end
                end
                
                %%% Fourier analysis
                % Initialize STFT
                audio_stft = [];
                
                % Loop over the channels
                for channel_index = 1:number_channels
                    
                    % STFT of one channel
                    audio_stft1 = repet.stft(audio_segment(:,channel_index),window_function,step_length);
                    
                    % Concatenate the STFTs
                    audio_stft = cat(3,audio_stft,audio_stft1);
                end
                
                % Magnitude spectrogram (with DC component and without 
                % mirrored frequencies)
                audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
                
                %%% Beat spectrum and repeating period
                % Beat spectrum of the mean power spectrograms (squared to 
                % emphasize peaks of periodicitiy)
                beat_spectrum = repet.beatspectrum(mean(audio_spectrogram.^2,3));
                
                % Repeating period in time frames given the period range
                repeating_period = repet.period(beat_spectrum,period_range);
                
                %%% Process
                % Initialize background segment
                background_segment = zeros(segment_length,number_channels);
                
                % Loop over the channels
                for channel_index = 1:number_channels
                    
                    % Repeating mask for one channel
                    repeating_mask = repet.mask(audio_spectrogram(:,:,channel_index),repeating_period);
                    
                    % High-pass filtering of the dual foreground
                    repeating_mask(2:cutoff_frequency+1,:) = 1;
                    
                    % Mirror the frequency channels
                    repeating_mask = cat(1,repeating_mask,flipud(repeating_mask(2:end-1,:)));
                    
                    % Estimated repeating background for one channel
                    background_segment1 = repet.istft(repeating_mask.*audio_stft(:,:,channel_index),window_function,step_length);
                    
                    % Truncate to the original number of samples
                    background_segment(:,channel_index) = background_segment1(1:segment_length);
                end
                
                %%% Combination
                % Case one segment
                if number_segments == 1
                    background_signal = background_segment;
                else
                    
                    % Case first segment
                    if segment_index == 1
                        background_signal(1:segment_length,:) ...
                            = background_signal(1:segment_length,:) + background_segment;
                        
                    % Case last segments
                    elseif segment_index <= number_segments
                        
                        % Half windowing of the overlap part of the background signal on the right
                        background_signal(sample_index+1:sample_index+segment_overlap,:) ...
                            = bsxfun(@times,background_signal(sample_index+1:sample_index+segment_overlap,:),segment_window(segment_overlap+1:2*segment_overlap));
                        
                        % Half windowing of the overlap part of the background segment on the left
                        background_segment(1:segment_overlap,:) ...
                            = bsxfun(@times,background_segment(1:segment_overlap,:),segment_window(1:segment_overlap));
                        background_signal(sample_index+1:sample_index+segment_length,:) ...
                            = background_signal(sample_index+1:sample_index+segment_length,:) + background_segment;
                    end
                end
                
                % Update wait bar
                waitbar(segment_index/number_segments,wait_bar);
            end
            
            % Close wait bar
            close(wait_bar)
        end
        
        % Adaptive REPET
        function background_signal = adaptive(audio_signal,sample_rate)
        % Adaptive REPET (see repet)
            
            %%% Defined parameters (can be redefined)
            % Window length in seconds for the STFT (audio stationary 
            % around 40 milliseconds)
            window_duration = 0.040;
            
            % Segment length and step in seconds for the beat spectrogram
            segment_length = 10;
            segment_step = 5;
            
            % Period range in seconds for the beat spectrum 
            period_range = [1,10];
            
            % Number of points for the median filter
            number_points = 5;
            
            % Cutoff frequency in Hz for the dual high-pass filter of the
            % foreground (vocals are rarely below 100 Hz)
            cutoff_frequency = 100;
            
            %%% Fourier analysis
            % STFT parameters
            [window_length,window_function,step_length] = repet.stftparameters(window_duration,sample_rate);
            
            % Number of samples and channels
            [number_samples,number_channels] = size(audio_signal);
            
            % Initialize the STFT
            audio_stft = [];
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % STFT of one channel
                audio_stft1 = repet.stft(audio_signal(:,channel_index),window_function,step_length);
                
                % Concatenate the STFTs
                audio_stft = cat(3,audio_stft,audio_stft1);
            end
            
            % Magnitude spectrogram (with DC component and without mirrored 
            % frequencies)
            audio_spectrogram = abs(audio_stft(1:window_length/2+1,:,:));
            
            %%% Beat spectrogram and repeating periods
            % Segment length and step in time frames for the beat 
            % spectrogram
            segment_length = round(segment_length*sample_rate/step_length);
            segment_step = round(segment_step*sample_rate/step_length);
            
            % Beat spectrogram of the mean power spectrograms (squared to 
            % emphasize peaks of periodicitiy)
            beat_spectrogram = repet.beatspectrogram(mean(audio_spectrogram.^2,3),segment_length,segment_step);
            
            % Period range in time frames for the beat spectrogram 
            period_range = round(period_range*sample_rate/step_length);
            
            % Repeating period in time frames given the period range
            repeating_periods = repet.periods(beat_spectrogram,period_range);
            
            %%% Background signal
            % Cutoff frequency in frequency channels for the dual high-pass 
            % filter of the foreground
            cutoff_frequency = ceil(cutoff_frequency*(window_length-1)/sample_rate);
            
            % Initialize the background signal
            background_signal = zeros(number_samples,number_channels);
            
            % Loop over the channels
            for channel_index = 1:number_channels
                
                % Repeating mask for one channel
                repeating_mask = repet.maskadaptive(audio_spectrogram(:,:,channel_index),repeating_periods,number_points);
                
                % High-pass filtering of the dual foreground
                repeating_mask(2:cutoff_frequency+1,:) = 1;
                
                % Mirror the frequency channels
                repeating_mask = cat(1,repeating_mask,flipud(repeating_mask(2:end-1,:)));
                
                % Estimated repeating background for one channel
                background_signal1 = repet.istft(repeating_mask.*audio_stft(:,:,channel_index),window_function,step_length);
                
                % Truncate to the original number of samples
                background_signal(:,channel_index) = background_signal1(1:number_samples);
            end
            
        end
        
        % REPET-SIM (with self-similarity matrix)
        function background_signal = sim(audio_signal,sample_rate)
            
            background_signal = 0*audio_signal*sample_rate;
            
        end
        
    end
    
    % Methods (access from methods in class of subclasses and does not 
    % depend on a object of the class)
    methods (Access = protected, Hidden = true, Static = true)
        
        % STFT parameters
        function [window_length,window_function,step_length] = stftparameters(window_duration,sample_rate)
            
            % Window length in samples (power of 2 for fast FFT)
            window_length = 2.^nextpow2(window_duration*sample_rate);
            
            % Window function (even window length and 'periodic' Hamming 
            % window for constant overlap-add)
            window_function = hamming(window_length,'periodic');
            
            % Step length (half the window length for constant overlap-add)
            step_length = window_length/2;
            
        end
        
        % Short-Time Fourier Transform (STFT) (with zero-padding at the 
        % edges)
        function audio_stft = stft(audio_signal,window_function,step_length)
            
            % Number of samples
            number_samples = length(audio_signal);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of time frames
            number_times = ceil((window_length-step_length+number_samples)/step_length);
            
            % Zero-padding at the start and end to center the windows 
            audio_signal = [zeros(window_length-step_length,1);audio_signal; ...
                zeros(number_times*step_length-number_samples,1)];
            
            % Initialize the STFT
            audio_stft = zeros(window_length,number_times);
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Window the signal
                sample_index = step_length*(time_index-1);
                audio_stft(:,time_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index).*window_function;
                
            end
            
            % Fourier transform of the frames
            audio_stft = fft(audio_stft);
            
        end
        
        % Inverse Short-Time Fourier Transform (ISTFT)
        function audio_signal = istft(audio_stft,window_function,step_length)
            
            % Number of time frames
            [~,number_times] = size(audio_stft);
            
            % Window length in samples
            window_length = length(window_function);
            
            % Number of samples for the signal
            number_samples = (number_times-1)*step_length+window_length;
            
            % Initialize the signal
            audio_signal = zeros(number_samples,1);
            
            % Inverse Fourier transform of the frames and real part to 
            % ensure real values
            audio_stft = real(ifft(audio_stft));
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Inverse Fourier transform of the signal (normalized 
                % overlap-add if proper window and step)
                sample_index = step_length*(time_index-1);
                audio_signal(1+sample_index:window_length+sample_index) ...
                    = audio_signal(1+sample_index:window_length+sample_index)+audio_stft(:,time_index); 
            end
            
            % Remove the zero-padding at the start and the end
            audio_signal = audio_signal(window_length-step_length+1:number_samples-(window_length-step_length));
            
            % Un-window the signal (just in case)
            audio_signal = audio_signal/sum(window_function(1:step_length:window_length));  
            
        end
        
        % Autocorrelation using the Wiener�Khinchin theorem (faster than 
        % using xcorr)
        function autocorrelation_matrix = acorr(data_matrix)
            
            % Each column represents a data vector
            [number_points,number_frames] = size(data_matrix);
            
            % Zero-padding to twice the length for a proper autocorrelation
            data_matrix = [data_matrix;zeros(number_points,number_frames)];
            
            % Power Spectral Density (PSD): PSD(X) = fft(X).*conj(fft(X))
            data_matrix = abs(fft(data_matrix)).^2;
            
            % Wiener�Khinchin theorem: PSD(X) = fft(acorr(X))
            autocorrelation_matrix = ifft(data_matrix); 
            
            % Discarde the symmetric part
            autocorrelation_matrix = autocorrelation_matrix(1:number_points,:);
            
            % Unbiased autocorrelation (lag 0 to number_points-1)
            autocorrelation_matrix = bsxfun(@rdivide,autocorrelation_matrix,(number_points:-1:1)');
        end
        
        % Beat spectrum using the autocorrelation
        function beat_spectrum = beatspectrum(audio_spectrogram)
            
            % Autocorrelation of the frequency channels
            beat_spectrum = repet.acorr(audio_spectrogram');
            
            % Mean over the frequency channels
            beat_spectrum = mean(beat_spectrum,2);
            
        end
        
        % Beat spectrogram using the beat spectrum for the Adaptive REPET
        function beat_spectrogram = beatspectrogram(audio_spectrogram,segment_length,segment_step)

            % Number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Zero-padding the audio spectrogram to center the segments
            audio_spectrogram = [zeros(number_frequencies,ceil((segment_length-1)/2)),audio_spectrogram,zeros(number_frequencies,floor((segment_length-1)/2))];
            
            % Initialize beat spectrogram
            beat_spectrogram = zeros(segment_length,number_times);
            
            % Wait bar
            wait_bar = waitbar(0,'Adaptive REPET 1/2');
            
            % Loop over the time frames (including the last one)
            for time_index = [1:segment_step:number_times-1,number_times]
                
                % Beat spectrum of the centered audio spectrogram segment
                beat_spectrogram(:,time_index) = repet.beatspectrum(audio_spectrogram(:,time_index:time_index+segment_length-1));
                
                % Update wait bar
                waitbar(time_index/number_times,wait_bar);
            end
            
            % Close wait bar
            close(wait_bar)

        end
        
        % Repeating periods from the beat spectra (spectrum or spectrogram)
        function repeating_periods = periods(beat_spectra,period_range)
            
            % The repeating periods are the indices of the maximum values 
            % in the beat spectra given the period range (they do not count 
            % lag 0 and should be shorter than one third of the signal 
            % length since the median needs at least three segments)
            [~,repeating_periods] = max(beat_spectra(period_range(1)+1:min(period_range(2),floor(size(beat_spectra,1)/3)),:),[],1);
            
            % Re-adjust the index or indices
            repeating_periods = repeating_periods+period_range(1);
            
        end
        
        % Repeating mask for REPET
        function repeating_mask = mask(audio_spectrogram,repeating_period)
            
            % Number of frequency channels and time frames
            [number_frequencies,number_times] = size(audio_spectrogram);
            
            % Number of repeating segments, including the last partial one
            number_segments = ceil(number_times/repeating_period);
            
            % Pad the audio spectrogram to have an integer number of 
            % segments
            audio_spectrogram = [audio_spectrogram,nan(number_frequencies,number_segments*repeating_period-number_times)];
            
            % Reshape the audio spectrogram for the columns to represent 
            % the segments
            audio_spectrogram = reshape(audio_spectrogram,[number_frequencies*repeating_period,number_segments]);
            
            % Derive the repeating segment by taking the median over the 
            % segments, ignoring the nan parts
            repeating_segment = [median(audio_spectrogram(1:number_frequencies*(number_times-(number_segments-1)*repeating_period),1:number_segments),2); ... 
                median(audio_spectrogram(number_frequencies*(number_times-(number_segments-1)*repeating_period)+1:number_frequencies*repeating_period,1:number_segments-1),2)];
            
            % Derive the repeating spectrogram by making sure it has less 
            % energy than the audio spectrogram
            repeating_spectrogram = bsxfun(@min,audio_spectrogram,repeating_segment);
            
            % Derive the repeating mask by normalizing the repeating 
            % spectrogram by the audio spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);
            
            % Reshape the repeating mask
            repeating_mask = reshape(repeating_mask,[number_frequencies,number_segments*repeating_period]);
            
            % Truncate the repeating mask to the orignal number of time 
            % frames
            repeating_mask = repeating_mask(:,1:number_times);
            
        end
        
        % Repeating mask for the Adaptive REPET
        function repeating_mask = maskadaptive(audio_spectrogram,repeating_periods,number_points)
            
            % Number of frequency channels and time frames
            [number_channels,number_times] = size(audio_spectrogram);
            
            % Indices of the points for the median filtering centered on 0 
            % (e.g., 3 => [-1,0,1], 4 => [-1,0,1,2], etc.)
            point_indices = (1:number_points)-ceil(number_points/2);
            
            % Initialize the repeating spectrogram
            repeating_spectrogram = zeros(number_channels,number_times);
            
            % Wait bar
            wait_bar = waitbar(0,'Adaptive REPET 2/2');
            
            % Loop over the time frames
            for time_index = 1:number_times
                
                % Indices of the frames for the median filtering
                time_indices = time_index+point_indices*repeating_periods(time_index);
                
                % Discard out-of-range indices
                time_indices(time_indices<1 | time_indices>number_times) = [];
                
                % Median filter centered on the current time frame
                repeating_spectrogram(:,time_index) = median(audio_spectrogram(:,time_indices),2);
                
                % Update wait bar
                waitbar(time_index/number_times,wait_bar);
            end
            
            % Close wait bar
            close(wait_bar)
            
            % Make sure the energy in the repeating spectrogram is smaller 
            % than in the audio spectrogram, for every time-frequency bins
            repeating_spectrogram = min(audio_spectrogram,repeating_spectrogram);
            
            % Derive the repeating mask by normalizing the repeating
            % spectrogram by the audio spectrogram
            repeating_mask = (repeating_spectrogram+eps)./(audio_spectrogram+eps);

        end
    
    end
    
end
