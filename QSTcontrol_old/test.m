asd = fopen('log_180827_155532.bin');
[data,count] = fread(asd,[16,inf],'double');
fclose(asd);

time = data(1,:);
figure; plot(time,data(2:end,:))


figure; plot(time,data(15:16,:))