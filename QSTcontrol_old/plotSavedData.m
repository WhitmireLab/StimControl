[fn,dn] = uigetfile(fullfile(getenv('UserProfile'),'Desktop','logs','*.bin;*.dbl'));
fid = fopen(fullfile(dn,fn));

ncol = 24;
% ncol = 27;
[data,count] = fread(fid,[ncol,inf],'double');
fclose(fid);

% figure
% subplot(2,2,1)
% plot(data(1,:),data(2:6,:))
% xlabel('time (s)')
% ylabel('temperature (°C)')
% 
% subplot(2,2,2)
% % plot(data(1,:),data(7,:))
% % xlabel('time (s)')
% % ylabel('body temperature (°C)')
% plot(data(1,:),data(19,:))
% xlabel('time (s)')
% ylabel('thermode trigger')
% 
% 
% subplot(2,2,3)
% plot(data(1,:),data(20,:))
% xlabel('time (s)')
% ylabel('basler frame trigger')
% 
% subplot(2,2,4)
% plot(data(1,:),data([16 18],:))
% xlabel('time (s)')
% ylabel('blue led, thermode trigger')
% 

figure; hold on;
subplot(311)
plot(data(1,:),data(end,:))
title('command')
subplot(312)
% plot(data(1,:),data(7,:))
% title('Force')
plot(data(1,:),data(4,:))
title('Force')

subplot(313)
plot(data(1,:),data(5,:))
xlabel('time')
title('length')

%% 
ncol = 24;
filedir = 'C:\Users\labadmin\Desktop\logs\debug\241126\241126_122043_TactileSweep_tap';
% filedir = 'C:\Users\labadmin\Desktop\logs\debug\241126\241126_112455_TactileSweep_holdTEST';
a = dir(fullfile(filedir,'*.dbl'));

data2save = 5;
datasave = cell(numel(data2save),numel(a));

for jj = 1:numel(a)
    fn2load = fullfile(a(jj).folder,a(jj).name);
    fid = fopen(fn2load);

    % ncol = 27;
    [data,count] = fread(fid,[ncol,inf],'double');
    fclose(fid);
    
    datasave{1,jj} = data(data2save,:);


end

b = cell2mat(datasave);

figure; plot(b)


