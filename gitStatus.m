function [ stat] = gitStatus()
    %GITSTATUS return information on the git status as a structure
    
    
    %get hash of current commit
    [res,hash]=system('git rev-parse HEAD');

    %check for error
    if(res)
        hash='';
    else
        hash=strtrim(hash);
    end

    %get if there are local mods
    [dty,~]=system('git diff-index --quiet HEAD --');

    %check if there were local mods
    if(dty)
        %get diff of local mods
        [~,patch]=system('git diff HEAD');
    else
        patch='';
    end

    %make structure for git status
    stat=struct('Hash',hash,'Dirty',dty','Patch',patch);
end

