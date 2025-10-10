clear; clc; rng default;

%% ----- MASTER PARAMETERS -----
signal_length = 2000;    % bits per trial
Ntrials       = 200;     % Monte-Carlo trials per SNR point

% (A) Sweep M with fixed Pn
Pn_Mlist  = [8 4 2 1 0.5 ];                      % uniform noise power (Pn = a^2/3)
M_list   = [1 2 4 8 16 32 64];

% (B) Sweep Pn with fixed M
M_fixed  = 16;
Pn_list  = [8 4 2 1 0.5 0.25 0.125];

%% ----- RUN SWEEPS (reusing your functions) -----
% Storage
BER_all   = cell(length(Pn_Mlist),1);
SNRdB_all = cell(length(Pn_Mlist),1);

% ----- RUN SWEEPS -----
for iPn = 1:length(Pn_Mlist)
    Pn_fixed = Pn_Mlist(iPn);  % pick current noise power
    [BER_A, SNRdB_A] = sweep_vary_M_with_your_funcs(M_list, Pn_fixed, signal_length, Ntrials);
    BER_all{iPn}   = BER_A;
    SNRdB_all{iPn} = SNRdB_A;
end
[BER_B, SNRdB_B] = sweep_vary_Pn_with_your_funcs(Pn_list, M_fixed, signal_length, Ntrials);

% ----- PLOTS -----
figure; hold on; grid on;
for iPn = 1:length(Pn_Mlist)
    semilogy(SNRdB_all{iPn}, BER_all{iPn}, '-o','LineWidth',1.5);
end
set(gca, 'YScale', 'log');       % logarithmic BER axis
xlabel('SNR = 10log_{10}(M/P_n) [dB]');
ylabel('Bit Error Rate (BER)');
ylim([1e-5 1]);                  % typical BER range
legend(arrayfun(@(x) sprintf('P_n=%.3g', x), Pn_Mlist, 'UniformOutput', false), 'Location','southwest');
title(sprintf('BER vs SNR (vary M, %d trials, %d bits/trial)', Ntrials, signal_length));

figure; semilogy(SNRdB_B, BER_B, '-s','LineWidth',1.5); grid on;
xlabel('SNR = 10log_{10}(M/P_n) [dB]'); ylabel('BER');
title(sprintf('BER vs SNR (vary P_n, M=%d, %d trials, %d bits/trial)', M_fixed, Ntrials, signal_length));


%% ----- ONE TEST CASE: show all intermediate signals -----
do_demo = true;
if do_demo
    rng(42);                 % reproducible demo
    Ld = 12;                 % small so we can see everything
    Md = 10;                 % chips per bit
    Pn_demo = 2;             % noise power (uniform)

    % 1) Binary input
    bits_d = binary_data_gen(Ld);        % 0/1

    % 2) NRZ mapping (±1), repeated M times
    s_d = modulator(Md, bits_d);         % length = Ld*Md

    % 3) Noise sequence (uniform with Pn = a^2/3)
    a = sqrt(3*Pn_demo);
    noise_d = (2*rand(size(s_d)) - 1).*a;

    % 4) Received (no PN in 12.7): NRZ + noise
    r_d = s_d + noise_d;

    % 5) Integrate & dump (sum M chips per bit)
    sums_d = demodulator(Md, r_d);       % 1×Ld

    % 6) Hard decision and error count
    [det_bits_d, err_d] = detector(bits_d, sums_d);

    % ----- Print key vectors (transpose for tidy columns) -----
    fprintf('\n=== DEMO RUN ===\n');
    fprintf('bits (0/1):\n');           disp(bits_d.');
    fprintf('NRZ (±1) first 30 samples:\n'); disp(s_d(1:min(30,numel(s_d))).');
    fprintf('noise first 30 samples:\n');    disp(noise_d(1:min(30,numel(noise_d))).');
    fprintf('received = NRZ + noise, first 30 samples:\n');
    disp(r_d(1:min(30,numel(r_d))).');
    fprintf('integrate&dump sums (per bit):\n'); disp(sums_d.');
    fprintf('detected bits:\n');             disp(det_bits_d.');
    fprintf('errors = %d (BER = %.4g)\n', err_d, err_d/numel(bits_d));

    % ----- Plots -----
    tb = 0:Ld;         % bit index for stairs
    ts = 0:numel(s_d); % sample index

    figure('Name','12.7 Demo: signal chain');
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

    % (1) Binary input
    nexttile;
    stairs(tb, [bits_d, bits_d(end)], 'LineWidth',1.2);
    ylim([-0.2 1.2]); grid on; title('Binary input (bits)'); xlabel('bit'); ylabel('0/1');

    % (2) NRZ (±1)
    nexttile;
    stairs(ts, [s_d s_d(end)], 'LineWidth',1.2);
    ylim([-1.2 1.2]); grid on; title('NRZ (±1, repeated M)'); xlabel('sample'); ylabel('amp');

    % (3) Noise sequence
    nexttile;
    plot(ts(1:end-1), noise_d, 'LineWidth',1);
    grid on; title(sprintf('Noise w[n] ~ U[-a,a], P_n=%.3g', Pn_demo)); xlabel('sample'); ylabel('amp');

    % (4) Received r = s + w
    nexttile;
    plot(ts(1:end-1), r_d, 'LineWidth',1);
    grid on; title('Received r[n] = s[n] + w[n]'); xlabel('sample'); ylabel('amp');

    % (5) Integrate & dump (block sums)
    nexttile;
    stem(0:Ld-1, sums_d, 'filled');
    grid on; title('Integrate & dump (sum over M samples)'); xlabel('bit'); ylabel('sum');

    % (6) Detected bits
    nexttile;
    stairs(tb, [det_bits_d, det_bits_d(end)], 'LineWidth',1.2);
    ylim([-0.2 1.2]); grid on; 
    title(sprintf('Detected bits (errors = %d)', err_d));
    xlabel('bit'); ylabel('0/1');
end


% TEST CASES TO ANALYSIS IN DEPTH %
do_three_cases = true;
if do_three_cases
    rng(123);                     % reproducible
    Ms_demo    = [10 100 1000];   % "significant" increases in M
    Ld         = 12;              % bits to visualize per panel (keeps plots readable)
    Pn_demo    = 2;               % same noise power across cases

    % also compute a stabler BER estimate per M (more bits/trials than the panel)
    L_eval     = 2000;            % bits per trial for BER estimate
    Ntr_eval   = 200;             % trials per point

    fprintf('\n=== 3-CASE SUMMARY (uniform noise) ===\n');
    fprintf('%6s %10s %10s %10s\n','M','SNR(dB)','BER(panel)','BER(est.)');

    for k = 1:numel(Ms_demo)
        Md = Ms_demo(k);
        [ber_panel, err_panel] = demo_panel_chain(Md, Pn_demo, Ld);  % shows the 6 plots

        % Monte-Carlo BER estimate using your full chain
        ber_est = monte_ber_with_your_funcs(Md, Pn_demo, L_eval, Ntr_eval);
        SNRdB   = 10*log10(Md/Pn_demo);

        fprintf('%6d %10.2f %10.3g %10.3g\n', Md, SNRdB, ber_panel, ber_est);
    end
end


function [BER, err] = demo_panel_chain(Md, Pn_demo, Ld)
    % 1) Bits and NRZ (±1, repeated M)
    bits   = binary_data_gen(Ld);          % 0/1
    s_d    = modulator(Md, bits);          % ±1, length = Ld*Md

    % 2) Noise (uniform with Pn = a^2/3) and received r = s + w
    a        = sqrt(3*Pn_demo);
    noise_d  = (2*rand(size(s_d)) - 1).*a;
    r_d      = s_d + noise_d;

    % 3) Integrate & dump, detect, errors
    sums_d       = demodulator(Md, r_d);
    [det_bits_d, err] = detector(bits, sums_d);
    BER          = err/numel(bits);

    % -------- Plots (6 panels) --------
    tb = 0:Ld;                 % bit edges for stairs
    ts = 0:numel(s_d);         % sample index
    % show at most ~1200 samples so big M doesn't blow up the figure
    visN = min(numel(s_d), 1200);
    vs   = 0:visN;             % visible samples

    figure('Name',sprintf('Signal chain, M=%d (SNR=%.2f dB, BER=%.3g)', Md, 10*log10(Md/Pn_demo), BER));
    tiledlayout(3,2,'TileSpacing','compact','Padding','compact');

    % (1) Binary input
    nexttile;
    stairs(tb, [bits bits(end)], 'LineWidth',1.2);
    ylim([-0.2 1.2]); grid on;
    title('Binary input (bits)'); xlabel('bit'); ylabel('0/1');

    % (2) NRZ (±1)
    nexttile;
    stairs(vs, [s_d(1:visN) s_d(min(end,visN))], 'LineWidth',1.2);
    ylim([-1.2 1.2]); grid on;
    title(sprintf('NRZ (±1, repeated M=%d)', Md)); xlabel('sample'); ylabel('amp');

    % (3) Noise
    nexttile;
    plot(0:visN-1, noise_d(1:visN), 'LineWidth',1);
    grid on; title(sprintf('Noise ~ U[-a,a], P_n=%.3g', Pn_demo)); xlabel('sample'); ylabel('amp');

    % (4) Received
    nexttile;
    plot(0:visN-1, r_d(1:visN), 'LineWidth',1);
    grid on; title('Received r[n] = s[n] + w[n]'); xlabel('sample'); ylabel('amp');

    % (5) Integrate & dump (sums)
    nexttile;
    stem(0:Lb(bits)-1, sums_d, 'filled'); % helper to get length
    grid on; title('Integrate & dump (sum over M samples)'); xlabel('bit'); ylabel('sum');

    % (6) Detected bits
    nexttile;
    stairs(tb, [det_bits_d det_bits_d(end)], 'LineWidth',1.2);
    ylim([-0.2 1.2]); grid on;
    title(sprintf('Detected bits (errors = %d)', err)); xlabel('bit'); ylabel('0/1');
end

function n = Lb(bits); n = numel(bits); end



function [BER, SNRdB] = sweep_vary_M_with_your_funcs(M_list, Pn_fixed, L, Ntrials)
    BER   = zeros(size(M_list));
    SNRdB = zeros(size(M_list));
    for k = 1:numel(M_list)
        M = M_list(k);
        BER(k)   = monte_ber_with_your_funcs(M, Pn_fixed, L, Ntrials);
        SNRdB(k) = 10*log10(M/Pn_fixed);  % SNR = Eb/Pn with Eb=M (M chips of ±1)
    end
end

function [BER, SNRdB] = sweep_vary_Pn_with_your_funcs(Pn_list, M_fixed, L, Ntrials)
    BER   = zeros(size(Pn_list));
    SNRdB = zeros(size(Pn_list));
    for k = 1:numel(Pn_list)
        Pn = Pn_list(k);
        BER(k)   = monte_ber_with_your_funcs(M_fixed, Pn, L, Ntrials);
        SNRdB(k) = 10*log10(M_fixed/Pn);  % same SNR definition
    end
end

function BER = monte_ber_with_your_funcs(M, Pn, L, Ntrials)
    total_err  = 0;
    total_bits = L * Ntrials;
    for t = 1:Ntrials

        bits            = binary_data_gen(L);               % 0/1
        mod_sig         = modulator(M, bits);               % ±1 repeated M
        noisy_mod_sig   = noise_generator(Pn, mod_sig);     % add uniform noise
        demod_sig       = demodulator(M, noisy_mod_sig);    % integrate & dump
        [~, err]        = detector(bits, demod_sig);        % threshold & count
        total_err       = total_err + err;
    end
    BER = total_err / total_bits;
end



function binary_signal = binary_data_gen(signal_length)
    binary_signal = randi([0, 1], 1, signal_length);
end

function mod_signal = modulator(M, binary_signal)
    y_bin = (2*binary_signal - 1);
    mod_signal = repelem(y_bin, M);
end

function noisy_mod_signal = noise_generator(noise_power, mod_signal)
    a = sqrt(noise_power*3);                  % since Pn = a^2/3 for U[-a,a]
    noisy_mod_signal = mod_signal + (2*rand(size(mod_signal)) - 1).*a;
end

function demod_signal = demodulator(M, noisy_mod_signal)
    num_parts    = ceil(length(noisy_mod_signal)/M);
    demod_signal = zeros(1, num_parts);
    for i = 1:num_parts
        start_idx = (i-1)*M + 1;
        end_idx   = min(i*M, length(noisy_mod_signal));
        demod_signal(i) = sum(noisy_mod_signal(start_idx:end_idx));
    end
end

function [detected_bin, err] = detector(binary_signal, demod_signal)
    detected_bin = (demod_signal >= 0);       % 1 if ≥0, else 0
    err = sum(abs(binary_signal - detected_bin));
end
