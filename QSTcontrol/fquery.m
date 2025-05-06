function out = fquery(s,query)

fprintf(s,query);
out = fread(s)';
out = strsplit(char([out(2:end)]),'\r');


end