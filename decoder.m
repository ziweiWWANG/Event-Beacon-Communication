close all
clear

%% Load Data
% provided data: 504hz_30m, 504hz_50m, 504hz_100m, 3125hz_30m, 3125hz_100m
base_frequency = 504; % hz
distance = 100; % m
dataAds = sprintf(['./data/bright-led-outdoor/' + string(base_frequency) + 'hz_' + string(distance) + 'm.mat']);
load(dataAds);

%% Parameters
% 1 start bit + 7-bit ASCII code + 1 parity bit + 2 end bits
bit_per_letter = 11;
% Event camera contrast threshold ct
ct = 0.1;
% High and low threshold for high-pass filter binarization
if (base_frequency == 504)
    ct_tresh_on = 8;
    ct_tresh_off = -5;
   
elseif (base_frequency == 3125)
    ct_tresh_on = 1.5;
    ct_tresh_off = -1;
end 
% Cut-off frequency for high-pass filter
cut_freq = (base_frequency)/3*2*pi;
% Unit t for one letter
unit_t = 1/base_frequency;

%% Event-based High Pass Filter
t_pre = event_t(1);
event_high_pass = zeros(1,length(event));
event_high_pass(1) = ct * event(1);

for i = 2:length(event)
    delta_t = event_t(i) - t_pre;
    t_pre = event_t(i);
    if event(i) > 0
        event_high_pass(i) = exp(-cut_freq * delta_t) * event_high_pass(i-1) + ct;
    else
        event_high_pass(i) = exp(-cut_freq * delta_t) * event_high_pass(i-1) - ct;
    end
end

%% Decoding
demod = event_high_pass;
demod(event_high_pass > (ct_tresh_on)) = 1;
demod(event_high_pass < (ct_tresh_off)) = -1;
mask_remove = (event_high_pass > ct_tresh_off) & (event_high_pass < ct_tresh_on);
demod(mask_remove) = [];
demod_t = event_t;
demod_t(mask_remove) = [];
demod_t_prev = demod_t(1);
demod_prev = 1;
start_id = [];
end_id = -1;
for i = 1:length(demod_t)
    % Find rising edge
    if (demod(i) == 1 && demod_prev == -1)
        demod_prev = 1;
        demod_t_prev = demod_t(i); 

    % Find failing edge    
    elseif (demod(i) == -1 && demod_prev == 1)
        dt = demod_t(i) - demod_t_prev; 
        if (dt > unit_t*12)
            start_id =[start_id i];
        end
        
        % Find ending bit
        if ((demod_t(i) - demod_t_prev) > (unit_t*30)) && (end_id < 0)
            end_id = find(demod_t <= demod_t_prev, 1 ,'last')-1; 
        end
        demod_prev = -1;
        demod_t_prev = demod_t(i); 
    end    
end

t_start = demod_t(start_id(1));
t2 = t_start + unit_t * bit_per_letter;

% Find end of the message
if end_id <= 0 
    end_msg = demod_t(end);
else
    end_msg = demod_t(end_id); 
end

%% End Bit Detection and Synchronisation
output_bin = [];
while t2 < end_msg
    t2_right_lim = t2 + unit_t/2;
    t2_left_lim = t2 - unit_t*2;
    t2_right_lim_i = find(demod_t <= t2_right_lim, 1 ,'last'); 
    t2_left_lim_i = find(demod_t <= t2_left_lim, 1 ,'last'); 
    for i = t2_right_lim_i:-1:t2_left_lim_i
        % Find failing edge (see figure 4 in the paper)
        if (demod(i) == 1 && demod(i+1) == -1)
            t_end = demod_t(i+1);
            break;
        end

        % If cannot find failing edge
        if i == t2_left_lim_i  
            t_end = t2;
        end
    end

    % Discretization
    intervel = (t_end - t_start) / bit_per_letter;
    for t_sample = (t_start+intervel/2):intervel:(t_end-intervel/2)
        t_sample_i = find(demod_t >= t_sample, 1 ,'first')-1;   
        output_bin = [output_bin (1+demod(t_sample_i))/2];
    end
    t_start = t_end;
    t2 = t_start + unit_t * bit_per_letter;
end

%% Binacry to Message
output_msg = [];
for i = 1:bit_per_letter:length(output_bin)-1
    letter_i = output_bin(i:i+7);
    output_msg = [output_msg, char(bin2dec(char('0' + letter_i)))];
end

%% Accuarcy
acc_msg = 0;
acc_bin = 0;

% Load ground truth message
[msg, msg_bin] = load_msg();

% Compute and display accuarcy
if length(output_msg) < 100 
    acc_msg_rate = 0;
    acc_bin_rate = 0.5;
    fprintf('Lost starting or ending bits \n')
else
    if length(output_msg) > length(msg)
        output_msg(length(msg)+1:end) = []; 
        output_bin(length(msg_bin)+1:end) = [];
    end
    
    if length(output_msg) < length(msg)
        output_msg(end) = []; 
        output_bin(end-bit_per_letter:end) = [];
        fprintf('Only part of the poem is transmitted \n')
    end
    
    for i = 1:length(output_msg)
        acc_msg = acc_msg + (output_msg(i) == msg(i));
    end
    acc_msg_rate = acc_msg / length(output_msg);

    for i = 1:length(output_bin)
        acc_bin = acc_bin + (output_bin(i) == msg_bin(i));
    end
    acc_bin_rate = acc_bin / length(output_bin);
    
    fprintf('Message ccuracy rate: %0.3f\n', acc_msg_rate)
    fprintf('Bit accuracy rate: %0.3f\n', acc_bin_rate)
    fprintf('Decoded message: \n%s\n', output_msg)
end