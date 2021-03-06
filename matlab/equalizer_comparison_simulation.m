% equalizer_comparison_simulation.m
%
% Compare the BER results of 3 receivers: L1, L2, MF with pilots
% Calls run_one_trial for most of the work
%
% Adam Gannon - SUNY Buffalo - 2018.


clear 
close all
clc

addpath(genpath('functions/'))
addpath(genpath('complex_l1_pca/'))

%% Settings

debug = 0;                                                                  %debug (0/1) variable for printouts

estChan = true;                                                            % Use SMI to calculate RIN                                              % Use underwater simulator to create channel vectors

useAmbientNoise = true;                                                  % Use underwater noise 
useShrimpNoise = true;

useIdealAutocorrMatrix = true;


%% Parameters 

% Number of bits and pilots (for MF) per packet
N_packet = 500;
N_pilot = N_packet/4;

% Number of snapshots used to calculate RN 
N_shapshots = 50;

%samples per symbol
sps = 4;                            

% Channel assumptions.
% M models the number of taps for the channel filter.
% Mrec is how many paths we assume in the receiver. 
% L is the code length, ideally greater than twice Mrec
M=200;                                
Mrec = 14;               
L=Mrec*2+1;                                


% Multi-user interference
K = 0;                              % Number of interferers
interfSnr = 0;

%number of packets per iteration
% Figures in paper were generated with 5000 packets, but that had to run
% overnight. 
nPackets=50;                      

% Set the SNR
snrVec = [150:5:180];  % For alpha = 1.8



% Parameters for noise generation 
% 100kHz center freq, 97.6kHz bandwidth
Params = struct;
Params.fstart = 51.2e3;
Params.fstop = 148.8e3;
Params.plotPsd = false;

% Set the alpha value of our alpha-stable distribution 
shrimpAlpha = 1.8;


% Load the matrix generated by the channel simulator 
load acoustic_channel_simulator/channels/chan_wide_0.mat
hmat = hmat(1:M,:);


% PN sequence for synch. Generated offline
load data/pn_seq.mat


%%  Storage Vectors

berMfStore = zeros(1,length(snrVec));
berL2Store = zeros(1,length(snrVec));
berL1Store = zeros(1,length(snrVec));

hVecStore = zeros(M,nPackets);


%% Sim over multiple SNRs


for iSnr = 1:length(snrVec)
    
currentSnr = snrVec(iSnr)

    %% Setup 

    % Generate the RRC filter
    alpha=0.35;
    gT = rcosdesign(alpha,6,sps,'sqrt');

 
    L_M = L+Mrec-1;

    % Storage 
    berMf = zeros(nPackets,1);
    berL2 = zeros(nPackets,1);
    berL1 = zeros(nPackets,1);


    %% Run simulation

    iPkt = 1;
    while(iPkt < nPackets)
        
        %% Generate the channel for this iteration
        
        % Read in a channel from simulator
        hVec = hmat(:,mod(iPkt,size(hmat,2))+1);
        hVecStore(:,iPkt) = hVec;
        
        
        %% Pack parameters into Params
        %Params = struct;
        
        Params.nPacket = N_packet;
        Params.L = L;
        Params.Mrec = Mrec;
        Params.M = M;
        Params.L_M = L_M;
        Params.K = K;
        Params.currentSnr = currentSnr;
        Params.psfAlpha = alpha;
        Params.sps = sps;
        Params.shrimpAlpha = shrimpAlpha;
        Params.nPilot = N_pilot;
        
        Params.useAmbientNoise = useAmbientNoise;
        Params.useShrimpNoise = useShrimpNoise;
        Params.enableDebug = debug;
        Params.estChan = estChan;
        Params.useIdealAutocorrMatrix = useIdealAutocorrMatrix;
        
        berVecTest = run_one_trial(hVec,pnSeq,gT,Params);

        
        %% Unpack BERs
        
        berMf(iPkt) = berVecTest('MF_PILOT');
        berL1(iPkt) = berVecTest('L1');
        berL2(iPkt) = berVecTest('L2');
        
        
        
        
        %% Advance simulation index by 1
        iPkt = iPkt + 1;
        if (mod(iPkt,100)==0)
            iPkt
        end
        

    end
    %% Average the BERs for this run
    
    berMfStore(iSnr) = mean(berMf);
    berL2Store(iSnr) = mean(berL2);
    berL1Store(iSnr) = mean(berL1);
  

end


%% Plot Data

colorMat=get_color_spec;

figure;
lineH(1) = semilogy(snrVec,berL2Store,'-o','color',colorMat(2,:));
hold on
lineH(2) = semilogy(snrVec,berL1Store,'-s','color',colorMat(1,:));
lineH(3) = semilogy(snrVec,berMfStore,'d-','color',colorMat(4,:));
hold off




if ((K == 0) && (~useAmbientNoise))
% if (0)
    theoryLine = 0.5.*erfc(sqrt(10.^(snrVec/10)));
    semilogy(snrVec,theoryLine,'k--')
    hL = legend('MF (Pilots)','MF (Blind)','L2','L1','Theory','location','SouthWest')
else
    hL = legend('L2-PCA','L1-PCA (Proposed)','Pilot-Based','location','SouthWest')
end

if (shrimpAlpha < 2)
    xlim([150 175])
else
    xlim([145 160])
end

hX = xlabel('Transmit Symbol Energy ($\mathrm{dB\:re\ \mu Pa}$)')
hY = ylabel('Bit Error Rate')

% Formatting 
grid on
set(hL,'Interpreter','latex','Fontsize',12)
set(hX,'Interpreter','latex','Fontsize',14)
set(hY,'Interpreter','latex','Fontsize',14)

for ii=1:length(lineH)
    set(lineH(ii),'LineWidth',1,'MarkerFaceColor','None','MarkerSize',9);
end

