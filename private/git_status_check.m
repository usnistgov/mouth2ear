function match=git_status_check(stat1,stat2)
% GIT_STATUS_CHECK - check if two git statuses are matching
%
%   GIT_STATUS_CHECK(stat1,stat2) compares sta1 to stat2 and returns true
%   if they are the same and false otherwise. The dirty flags of each
%   status are checked and GIT_STATUS_CHECK will return compare the
%   uncommitted changes for each and only return true if the changes are
%   identical.

%This software was developed by employees of the National Institute of
%Standards and Technology (NIST), an agency of the Federal Government.
%Pursuant to title 17 United States Code Section 105, works of NIST
%employees are not subject to copyright protection in the United States and
%are considered to be in the public domain. Permission to freely use, copy,
%modify, and distribute this software and its documentation without fee is
%hereby granted, provided that this notice and disclaimer of warranty
%appears in all copies.
%
%THE SOFTWARE IS PROVIDED 'AS IS' WITHOUT ANY WARRANTY OF ANY KIND, EITHER
%EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING, BUT NOT LIMITED TO, ANY
%WARRANTY THAT THE SOFTWARE WILL CONFORM TO SPECIFICATIONS, ANY IMPLIED
%WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
%FREEDOM FROM INFRINGEMENT, AND ANY WARRANTY THAT THE DOCUMENTATION WILL
%CONFORM TO THE SOFTWARE, OR ANY WARRANTY THAT THE SOFTWARE WILL BE ERROR
%FREE. IN NO EVENT SHALL NIST BE LIABLE FOR ANY DAMAGES, INCLUDING, BUT NOT
%LIMITED TO, DIRECT, INDIRECT, SPECIAL OR CONSEQUENTIAL DAMAGES, ARISING
%OUT OF, RESULTING FROM, OR IN ANY WAY CONNECTED WITH THIS SOFTWARE,
%WHETHER OR NOT BASED UPON WARRANTY, CONTRACT, TORT, OR OTHERWISE, WHETHER
%OR NOT INJURY WAS SUSTAINED BY PERSONS OR PROPERTY OR OTHERWISE, AND
%WHETHER OR NOT LOSS WAS SUSTAINED FROM, OR AROSE OUT OF THE RESULTS OF, OR
%USE OF, THE SOFTWARE OR SERVICES PROVIDED HEREUNDER.

    %compare hashes first
    if(strcmp(stat1.Hash,stat2.Hash))
        %hashes are same check dirty flag
        if(stat1.Dirty || stat2.Dirty)
            if(stat1.Dirty~=stat2.Dirty)
                %dirty flags don't match
                match=false;
                %not a match, exit
                return;
            end
            %compare patches
            match=strcmp(stat1.Patch,stat2.Patch);
        else
            match=true;
        end
    else
        %hashes aren't the same, not a match
        match=false;
    end
end
                