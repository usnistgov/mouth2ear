function ensureCSV(datadir)

    mat_dir=fullfile(datadir,'data');
    csv_dir=fullfile(datadir,'post-processed data','csv');

    mat_names=cellstr(ls(fullfile(mat_dir,'*.mat')));
    csv_names=cellstr(ls(fullfile(csv_dir,'*.csv')));
    
    
    for k = 1:length(mat_names)
        [~,basename,~]=fileparts(mat_names{k});
        
        csv_out=[basename '.csv'];
        
        if(any(strcmp(csv_names,csv_out)))
            fprintf('File %s exists, skipping\n',csv_out);
        else
            out_path=fullfile(csv_dir,csv_out);
            mat_path=fullfile(mat_dir,mat_names{k});
            fprintf('Creating %s from %s\n',out_path,mat_path);
            try
                mat2csv(mat_path,out_path);
            catch e
                fprintf('Could not save file ''%s''\n',e.message);
            end
        end
    end
    
end