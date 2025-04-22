function receiveFrame(src, obj)
    %TODO https://au.mathworks.com/help/imaq/acquire-images-using-parallel-worker.html
    imgs = getdata(src,src.FramesAvailable);
    
end