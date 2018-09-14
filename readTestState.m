function state=readTestState(fname)

%names of fields in file
names={'Test Type','System','Tx Device','Rx Device','3rd Device','Location'};

%names of fields in structure
fields={'testType','System','TxDevice','RxDevice','ThirdDevice','Location'};

%open file
f=fopen(fname,'r');

%create struct to keep data
state=struct();

%check if file was opened correctly
if(f>=0)

    %parse file
    dat=textscan(f,'%s %q','Delimiter',{':'});

    for k=1:length(dat{1})
        %check for match
        match=strcmp(names,strtrim(dat{1}{k}));

        %check if there was a match
        if(any(match))
            %found correct name, set value
            state.(fields{match})=dat{2}{k};
        else
            %field not found
            error('Invalid field ''%s'' found in state file',strtrim(dat{1}{k}));
        end
    end

    %close file
    fclose(f);
end

%make sure all feilds are present
for k=1:length(names)
    %check if field is present
    if(~isfield(state,fields{k}))
        %not present, set to empty string
        state.(fields{k})='';
    end
end

end