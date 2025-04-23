function receiveFrame(src, obj)
    %TODO https://au.mathworks.com/help/imaq/acquire-images-using-parallel-worker.html
    disp("trigger received!");
    imgs = getdata(src,src.FramesAvailable);
    disp("images")
end