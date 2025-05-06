% Image Acquisition 
% Hamamatsu Camera for calcium imaging
% Basler camera for paw tracking


% Start image acquisition

% in this script, the file directories and naming format for each data
% acquisition is saved. It is important that the animal id and the details
% about the stimulus are saved here. This is linked back to the stimulus
% control after the end of the experiment


%% RESET connections.

clear;
imaqreset;

%% SET PARAMETERS
% animal id
animalid='15491';

% stimulus id
stimnum =14;

switch stimnum
    case 1
        stimid = 'simpletest_cold';
        TMAX = 5; %trial duration 
        NTRIAL =1;
        tstim =2;      %seconds of rec before stim onset
    case 2
        stimid = 'simpletest_touch';
        TMAX = 5; %trial duration (10 seconds)
        NTRIAL =1;
        tstim =2;      %seconds of rec before stim onset
    case 3 
        stimid = 'exp';
        TMAX = 14; %trial duration 
        NTRIAL = 60;
        tstim =5;      %seconds of rec before stim onset
    case 4
        stimid = 'expB';
        TMAX = 10; %trial duration 
        NTRIAL =60;
        tstim =5;      %seconds of rec before stim onset
           
    case 5 
        stimid = 'expTsweep';
        TMAX = 14; %trial duration 
        NTRIAL = 70;
        tstim =5;      %seconds of rec before stim onset
        
    case 6
        stimid = 'exp2paw';
        TMAX = 14; %trial duration 
        NTRIAL = 100;
        tstim =5;      %seconds of rec before stim onset
  
    case 7
        stimid = 'AU_CW_2degsweep';
        TMAX = 14; %trial duration 
        NTRIAL = 88;
        tstim =5;      %seconds of rec before stim onset
     case 8
        stimid = 'exp_auditorytactiletouch';
        TMAX = 14; %trial duration 
        NTRIAL = 70;
        tstim =5;      %seconds of rec before stim onset   
    case 9
        stimid = 'exp_pawunrestrained';
        TMAX = 25; %trial duration 
        NTRIAL = 32;
        tstim =5;      %seconds of rec before stim onset 
    case 10
        stimid = 'simpletest_coldlong';
        TMAX = 15; %trial duration 
        NTRIAL = 1;
        tstim =2;      %seconds of rec before stim onset 
    case 11
        stimid = 'expESYS_2stimulators';
        TMAX = 25;
        NTRIAL = 80;
        tstim = 5;
    case 12
        stimid = 'expESYS_2stimulatorsAC';
        TMAX = 11;
        NTRIAL = 56;
        tstim = 3;
    case 13
        stimid = 'expESYS_Astimwithdrawal';
        TMAX = 11;
        NTRIAL = 40;
        tstim = 3;
    case 14
        stimid = 'expESYS_4stimulators';
        TMAX = 11;
        NTRIAL = 96;
        tstim = 3;
end

%% set up file directory

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

filesaveloc2= [filesavedir animalid filesep expdate filesep 'basler' filesep];
if ~isfolder(filesaveloc2)
    mkdir(filesaveloc2);
end
% ADD TIFF CAPABILITIES
addpath(genpath('TIFF'));

%% Start Data Acquisition
test2camerascriptCameraAcquire;
