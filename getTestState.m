function state=getTestState(prompt,resp)

%names of fields in file
names={'Test Type','System','Tx Device','Transmit Device','Rx Device','Recive Device','3rd Device'};

%names of fields in structure
fields={'testType','System','TxDevice','TxDevice','RxDevice','RxDevice','ThirdDevice'};

%create struct to keep data
state=struct();

for k=1:length(prompt)
    %check for match
    match=strcmp(names,strtrim(prompt{k}));
    
    %check if there was a match
    if(any(match))
        %found correct name, set value
        state.(fields{match})=resp{k};
    else
        %field not found
        error('Invalid prompt ''%s''',strtrim(prompt{k}));
    end
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