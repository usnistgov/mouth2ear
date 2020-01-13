function writeTestState(fname,state)

%names of fields in file
names={'Test Type','System','Tx Device','Rx Device','3rd Device','Location'};

%names of fields in structure
fields={'testType','System','TxDevice','RxDevice','ThirdDevice','Location'};

%open file
f=fopen(fname,'w');

%write fields with data
for k=1:length(names)
    %check if field is present and nonempty
    if(isfield(state,fields{k}) && ~isempty(state.(fields{k})))
        %write to file
        fprintf(f,'%s : "%s"\n',names{k},state.(fields{k}));
    end
end

%close file
fclose(f);

end