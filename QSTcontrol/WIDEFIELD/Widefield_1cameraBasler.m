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
animalid='JPCM5670';

% stimulus id
stimnum =1;

switch stimnum
    case 1
        stimid = 'CTX_12SECSTIM';
        TMAX = 12; %trial duration 
        NTRIAL =55;
        tstim =5;      %seconds of rec before stim onset
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

end

%% set up file directory

filesavedir = 'C:\Users\poulet_lab\Desktop\basler';
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
baslerCameraAcquire;
