% Script to copy m2e files for access time tests off network and run
% loadData
clear all
% close all

% Path where log-search repository stored
log_search_path = fullfile('..','..','log-search');
% Add log-search to path
addpath(log_search_path);

clipname = {
    'F1_b39_w4_hook.wav';
    'F3_b15_w5_west.wav';
    'M4_b18_w4_pay.wav';
    'M3_b22_w3_cop.wav';
    };
local_searchpath = '';
network_searchpath = '\\cfs2w.nist.gov\671\Projects\MCV\mouth2ear';

current_path = pwd();
cd(log_search_path)
log = log_search(network_searchpath,'LogParseAction','Ignore');
cd(current_path)
log.updateMode = 'AND';
log.stringSearchMode = 'AND';

testTypes = {
%     'PTT', 'Gate';
%     'Analog','Direct';
%     'Analog','Conventional';
%     '700','Direct';
'700','Conventional';
%     '700','Phase1';
%     '700','Phase2';
    };
for k = 1:size(testTypes,1)
    clear('search')
    log.clear();
    
    clip_search.post_notes = 'clipping';
    log.MfSearch(clip_search);
    
    clip_ix = log.found;
    
    log.clear();
    
%     if(strcmp(testTypes(k,:),{'gate','test'}) | strcmp(testTypes(k,:),{'PTT','Gate'}))
%         log.ArgSearch('AudioFile',clipname);
%     else
        log.updateMode = 'OR';
        for clip = 1:length(clipname)
            log.ArgSearch('AudioFile',clipname{clip});
        end
%     end
    
    log.updateMode = 'AND';
    log.stringSearchMode='AND';
    search.TestType = testTypes(k,:);
    search.operation = 'Test';
    search.date_after =  datetime('01-Apr-2019');
    log.MfSearch(search);
    
    if(all(strcmp(testTypes(k,:),{'Analog','Repeater'})) ||...
            all(strcmp(testTypes(k,:), {'Analog', 'Direct'})))
        clear('search');
        log.stringSearchMode = 'OR';
        search.TxDevice = {'783','784'};
        log.MfSearch(search);
    end
    
    
    log.stringSearchMode = 'OR';
%     log.ArgSearch('PTTrep',30);
    
    
    
    log.found = setdiff(log.found,clip_ix);
    
    grantNames_raw = log.findFiles(local_searchpath);
    [grantNames,grantDirs] = formatFileNames(grantNames_raw);
    
    grantNames = grantNames(cellfun(@(x) ~contains(x,'ERROR'),grantNames));
    if(all(strcmp(testTypes(k,:),{'PTT', 'Gate'})))
        fname = [strjoin(testTypes(k,:)) '-characterization.csv'];
    else
        fname = [strjoin(testTypes(k,:)) '.csv'];
    end
    
    fid = fopen(fname,'w');
    for clip=1:length(grantNames)
        fprintf(fid,'%s\n',fullfile(local_searchpath,'data',grantNames{clip}));
    end
    fclose(fid);
    
    rx_fold = 'recs';
    datType = '1loc';
    saveDir = fullfile(local_searchpath,'post-processed data','mat');
    [data,rx_list] = loadData('datFile',fname,...
        'rx_fold',rx_fold,...
        'datType','1loc',...
        'saveDir',saveDir);
    
    Test_info.Type = '1loc';
    Test_info.procPath = saveDir;
    Test_info.procRxPath = fullfile(local_searchpath,'post-processed data','wav');
    Test_info.csvPath = fullfile(local_searchpath,'post-processed data','csv');
    Test_info.fileList= {fname};
    
    splice_data(Test_info,'outputs','csv');
end

rmpath(log_search_path);