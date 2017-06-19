function dly_stats(name)
%DLY_STATS generate delay statistics for data
%   for long runs all data may not fit into memory so DLY_STATS only reads
%   the needed information to do statistics on the delay
    
    %split name into parts
    [fpath,n,ext]=fileparts(name);

    %find the last three underscores
    usc=find(n=='_',3,'last');

    %generate base_filename
    base_filename=n(1:(usc(1)-1));
    
    %get runs from filename
    runs=str2double(n(usc(3)+1:end));
  
    %initialize the position
    pos=1;
    
    for k=1:runs

        %get run data
        run_dat=load(fullfile(fpath,sprintf('%s_%i_of_%i%s',base_filename,k,runs,ext)),'st_dly','underRun','overRun');

        %get run length
        run_length=length(run_dat.st_dly);
        
        %if this is the first run, preallocate
        if(k==1)
            %preallocate arrays
            st_dly=zeros(1,run_length*runs);
            underRun=zeros(1,run_length*runs);
            overRun=zeros(1,run_length*runs);
        end
        
        %get range of values that are being set
        rng=pos+(0:(run_length-1));

        %put data in larger array
        st_dly(rng)    =run_dat.st_dly;
        underRun(rng)  =run_dat.underRun;
        overRun(rng)   =run_dat.overRun;
        
        %add run length to position
        pos=pos+run_length;

    end

    %shrink arrays down at the end
    st_dly=st_dly(1:pos-1);
    underRun=underRun(1:pos-1);
    overRun=overRun(1:pos-1);
    
    %check for buffer over runs
    if(any(overRun))
        fprintf('There were %i buffer over runs\n',sum(overRun));
    else
        fprintf('There were no buffer over runs\n');
    end

    %check for buffer over runs
    if(any(underRun))
        fprintf('There were %i buffer under runs\n',sum(underRun));
    else
        fprintf('There were no buffer under runs\n');
    end

    %new figure
    figure;

    %split window into subplots
    subplot(1,2,1);

    %plot histogram
    histogram(st_dly,'Normalization','probability');

    %calculate delay mean
    dly_m=mean(st_dly);

    %get engineering units
    [dly_m_e,~,dly_u]=engunits(dly_m,'time');

    %add mean in title
    title(sprintf('Mean : %.2f %s',dly_m_e,dly_u));

    %switch to second subplot
    subplot(1,2,2);
    %plot histogram
    histogram(st_dly,300,'Normalization','probability');

    %calculate standard deviation
    st_dev=std(st_dly);

    %get engineering units
    [st_dev_e,~,st_u]=engunits(st_dev,'time');

    %add Standard Deveation in title
    title(sprintf('StD : %.1f %s',st_dev_e,st_u));

    %print plot to .png
    print(fullfile('plots',[base_filename '.png']),'-dpng','-r600');


end

