function out = estimateTime(obj)

out = sum(([obj.p.tPre]+[obj.p.tPost]).*[obj.p.nRepetitions])/1000 + ...
    (length(obj.p)-1)*obj.g.dPause;