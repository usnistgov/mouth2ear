function mat2csv(fname,outname)
% Simple function to extract data from mouth2ear data in fname to a csv

dat = load(fname);

dly_vals = cellfun(@mean,dat.dly_its);

try
    fid= fopen(outname,'w');
    fprintf(fid,'Mean Delay Per Trial (ms)\n');
    fprintf(fid,'%d\n',dly_vals);
    fclose(fid);
catch ME
    if(exist('fid','var'))
        fclose(fid);
    end
    rethrow(ME);
end

end