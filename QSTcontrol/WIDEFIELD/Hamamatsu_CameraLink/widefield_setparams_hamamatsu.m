clear;
imaqreset;

%% SET PARAMETERS
% animalid = 'nan';
% % animalid = '001754';
% animalid = '8286';%cjw
% animalid = '8288';%cjw\
% animalid = '10272';
animalid='10274';

% animalid = '5999';%cjw


% % % stimid = 'cold_interleaved_warm';
stimid = 'cold1brightlight';            
TMAX = 5; %trial duration (10 seconds)  
NTRIAL =1;                                                                                                         
tstim =2;      %seconds of rec before stim onset
% % % 
% % % stimid = 'expb';     
% % % TMAX = 10; %trial duration (10 seconds)  
% % % NTRIAL =30;                                                                                                         
% % % tstim =5;      %seconds of rec before stim onset


% file directory
filesavedir = 'C:\Users\2P_Resonant\Data\WidefieldRig\';
yy =num2str(year(datetime));
mm = num2str(month(datetime));
dd = num2str(day(datetime));
if numel(mm)<2
    mm = ['0' mm];
end
if numel(dd)<2
    dd = ['0' dd];
end
expdate = [yy mm dd];
filesaveloc = [filesavedir animalid filesep expdate filesep];
if ~isfolder(filesaveloc)
    mkdir(filesaveloc);
end

% ADD TIFF CAPABILITIES
addpath(genpath('TIFF'));

% basler_widefield_triggered;
hamamatsu_widefield_triggered_16bit;
% % % % basler_widefield_triggered_12bit;

% basler_widefield_triggered_tiff;