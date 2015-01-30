function LoadTcspc(~,~,Update_Data,Update_Display,Calibrate_Detector,Caller,FileName,Type)
global UserValues TcspcData FileInfo

if nargin<7 %%% Opens Dialog box for selecting new files to be loaded
    %%% following code is for remembering the last used FileType
    LSUserValues(0);    
    %%% Loads all possible file types
    Filetypes = UserValues.File.SPC_FileTypes;
    %%% Finds last used file type
    Lastfile = UserValues.File.OpenTCSPC_FilterIndex;
    %%% Puts last uses file type to front
    Fileorder = 1:size(Filetypes,1);
    Fileorder = [Lastfile, Fileorder(Fileorder~=Lastfile)];
    Filetypes = Filetypes(Fileorder,:);   
    %%% Choose filey to be loaded
    [FileName, Path, Type] = uigetfile(Filetypes, 'Choose a TCSPC data file',UserValues.File.Path,'MultiSelect', 'on');   
    %%% Determines actually selected file type
    if Type~=0
        Type = Fileorder(Type);
    end

else %%% Loads predifined Files
    Path = UserValues.File.Path;
end
%%% Only execues if any file was selected
if ~iscell(FileName) && all(FileName==0)
    return
end
%%% Save the selected file type
UserValues.File.OpenTCSPC_FilterIndex = Type;
%%% Transforms FileName into cell, if it is not already
%%%(e.g. when only one file was selected)
if ~iscell(FileName)
    FileName = {FileName};
end
%%% Saves Path
UserValues.File.Path = Path;
LSUserValues(1);
%%% Sorts FileName by alphabetical order
FileName=sort(FileName);
%%% Clears previously loaded data
FileInfo=[];
TcspcData.MT=cell(1,1);
TcspcData.MI=cell(1,1);

%%% Findes handles for progress axes and text
h=guidata(Caller);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Checks which file type was selected
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch (Type)
    case 1 %%% 1: .spc Files generated with Fabsurf
        FileInfo.FileType = 'FabsurfSPC';
        %%% Reads info file generated by Fabsurf
        FileInfo.Fabsurf=FabsurfInfo(fullfile(Path,FileName{1}));
        %%% General FileInfo
        FileInfo.NumberOfFiles=numel(FileName);
        FileInfo.Type=Type;
        FileInfo.MI_Bins=4096;
        FileInfo.MeasurementTime=FileInfo.Fabsurf.Imagetime/1000;
        FileInfo.SyncPeriod=FileInfo.Fabsurf.RepRate/1000;
        FileInfo.Lines=FileInfo.Fabsurf.Imagelines;
        FileInfo.LineTimes=zeros(FileInfo.Lines+1,numel(FileName));
        FileInfo.Pixels=FileInfo.Fabsurf.Imagelines^2;
        FileInfo.ScanFreq=FileInfo.Fabsurf.ScanFreqCorrected;
        FileInfo.FileName=FileName;
        FileInfo.Path=Path;
        %%% Initializes microtime and macotime arrays
        TcspcData.MT=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        TcspcData.MI=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        
        Totaltime=0;
        %%% Reads all selected files
        for i=1:numel(FileName)
            %%% Calculates Imagetime in clock ticks for concaternating
            %%% files
            Info=FabsurfInfo(fullfile(Path,FileName{i}),1);
            Imagetime=round(Info.Imagetime/1000/FileInfo.SyncPeriod);
            %%% Checks, which cards to load
            card = unique(UserValues.Detector.Det);
            
            %%% Checks, which and how many card exist for each file
            for j=card;
                if ~exist(fullfile(Path,[FileName{i}(1:end-5) num2str(j-1) '.spc']),'file')
                    card(card==j)=[];
                end
            end
            
            Linetimes=[];
            %%% Reads data for each tcspc card
            for j = card
                %%% Update Progress
                Progress((i-1)/numel(FileName)+(j-1)/numel(card)/numel(FileName),h.Progress_Axes, h.Progress_Text,['Loading File ' num2str((i-1)*numel(card)+j) ' of ' num2str(numel(FileName)*numel(card))]);
                %%% Reads Macrotime (MT, as double) and Microtime (MI, as uint 16) from .spc file
                [MT, MI, PLF,~] = Read_BH(fullfile(Path, [FileName{i}(1:end-5) num2str(j-1) '.spc']),Inf,[0 0 0], 'SPC-140/150');
                %%% Finds, which routing bits to use
                Rout = unique(UserValues.Detector.Rout(UserValues.Detector.Det==j))';
                Rout(Rout>numel(MI)) = [];
                %%% Concatenates data to previous files and adds Imagetime
                %%% to consecutive files
                if any(~cellfun(@isempty,MI))
                    for k = Rout
                        %%% Removes photons detected after "official"
                        %%% end of file are discarded
                        MI{k}(MT{k}>Imagetime)=[];
                        MT{k}(MT{k}>Imagetime)=[];
                        TcspcData.MT{j,k}=[TcspcData.MT{j,k}; Totaltime + MT{k}];   MT{k}=[];
                        TcspcData.MI{j,k}=[TcspcData.MI{j,k}; MI{k}];   MI{k}=[];
                    end
                end
                %%% Determines last photon for each file
                for k=find(~cellfun(@isempty,TcspcData.MT(j,:)));
                    FileInfo.LastPhoton{j,k}(i)=numel(TcspcData.MT{j,k});
                end
                
                %%% Determines, if linesync was used
                if isempty(Linetimes) && ~isempty(PLF{1})
                    Linetimes=[0 PLF{1}];
                elseif isempty(Linetimes) && ~isempty(PLF{2})
                    Linetimes=[0 PLF{2}];
                elseif isempty(Linetimes) && ~isempty(PLF{3})
                    Linetimes=[0 PLF{3}];
                end
            end
            %%% Creates linebreak entries
            if isempty(Linetimes)
                FileInfo.LineTimes(:,i)=linspace(0,FileInfo.MeasurementTime/FileInfo.SyncPeriod,FileInfo.Lines+1)+Totaltime;
            elseif numel(Linetimes)==FileInfo.Lines+1
                FileInfo.LineTimes(:,i)=Linetimes+Totaltime;
            elseif numel(Linetimes)<FileInfo.Lines+1
                %%% I was to lazy to program this case out yet
            end
            %%% Calculates total time to get one trace from several
            %%% files
            Totaltime=Totaltime + Imagetime;
            
        end
    case {2, 3} %%% .spc Files generated with native B&H program
        %%% 2: '*_m1.spc', 'Multi-card B&H SPC files recorded with B&H-Software (*_m1.spc)'
        %%% 3: '*.spc',    'Single card B&H SPC files recorded with B&H-Software (*.spc)'
        %%% Usually, here no Imaging Information is needed
        FileInfo.FileType = 'SPC';
        %%% General FileInfo
        FileInfo.NumberOfFiles = numel(FileName);
        FileInfo.Type = Type;
        
        %%% Read .set file
        fid = fopen(fullfile(Path, [FileName{1}(1:end-3) 'set']), 'r');
        if fid~=-1 %%% .set fiole exists
            MI_Bins = [];
            Card = [];
            TACRange = [];
            TACGain = [];
            Corrupt = false;           
            %%% Reads file line by line till all parameters are found
            while (isempty(MI_Bins) || isempty(Card) || isempty(TACRange) || isempty(TACGain)) && ~Corrupt
                Line = fgetl(fid);
                %%% Determines SPC card type
                if isempty(Card)
                    Card = strfind(Line, 'with module SPC-');
                    if ~isempty(Card)
                        Card = Line(18:20);
                    end
                end
                %%% Determines number of microtime bin
                if isempty(MI_Bins)
                    MI_Bins = strfind(Line, 'SP_ADC_RE');
                    if ~isempty(MI_Bins)
                        MI_Bins = str2double(Line(20:end-1));
                    end
                end
                %%% Determines TAC range
                if isempty(TACRange)
                    TACRange = strfind(Line, 'SP_TAC_R');
                    if ~isempty(TACRange)
                        TACRange = str2double(Line(19:end-1));
                    end
                end
                %%% Determines TAC gain
                if isempty(TACGain)
                    TACGain = strfind(Line, 'SP_TAC_G');
                    if ~isempty(TACGain)
                        TACGain = str2double(Line(19:end-1));
                    end
                end
                %%% Stops, if end of file is reached
                if ~isempty(Line) && all(Line==-1)
                    Corrupt = true;
                end
            end
            fclose(fid);
            if ~Corrupt %%% .set file was complete
                %%% Determines exact .spc filetype to read
                if (strcmp(Card,'140') || strcmp(Card,'150'))
                    Card = 'SPC-140/150';
                elseif strcmp(Card,'630')
                    if MI_Bins == 256
                        Card = 'SPC-630 256chs';
                    elseif MI_Bins == 4096
                        Card = 'SPC-630 4096chs';
                    end
                end
                %%% Determines real TAC range
                TACRange = TACRange/TACGain;
            else %%% No .set file was found; use standard settings
                h = msgbox('Setup (.set) file not found!');
                Card = 'SPC-140/150';
                MI_Bins = 4096;
                TACRange = [];
                pause(1)
                close(h)
            end            
            
        else %if there is no set file, the B&H software was likely not used
            h = msgbox('Setup (.set) file not found!');
            Card = 'SPC-140/150';
            MI_Bins = 4096;
            TACRange = [];
            pause(1)
            close(h)
        end        
        FileInfo.Card = Card;
        FileInfo.MI_Bins = MI_Bins;
        FileInfo.MeasurementTime = [];
        FileInfo.SyncPeriod = [];
        FileInfo.TACRange = TACRange; %in seconds
        FileInfo.Lines = 1;
        FileInfo.LineTimes = [];
        FileInfo.Pixels = 1;
        FileInfo.ScanFreq = 1000;
        FileInfo.FileName = FileName;
        FileInfo.Path = Path;
        
        %%% Initializes microtime and macotime arrays
        TcspcData.MT=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        TcspcData.MI=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        
        %%% Reads all selected files
        for i=1:numel(FileName)
            %%% there are a number of *_m(i).spc files associated with the
            %%% *_m1.spc file
            
            %%% Checks, which cards to load
            card = unique(UserValues.Detector.Det);
            
            %%% Checks, which and how many card exist for each file
            if Type == 2
                for j = card;
                    if ~exist(fullfile(Path,[FileName{i}(1:end-5) num2str(j) '.spc']),'file')
                        card(card==j)=[];
                    end
                end
            else
                card = 1;
            end
            
            Progress((i-1)/numel(FileName),h.Progress_Axes, h.Progress_Text,'Loading:');
            
            %%% if multiple files are loaded, consecutive files need to
            %%% be offset in time with respect to the previous file
            MaxMT = 0;
            if any(~cellfun(@isempty,TcspcData.MT))
                MaxMT = max(cellfun(@max,TcspcData.MT(~cellfun(@isempty,TcspcData.MT))));
            end
            %%% Reads data for each tcspc card
            for j = card
                %%% Update Progress
                Progress((i-1)/numel(FileName)+(j-1)/numel(card)/numel(FileName),h.Progress_Axes, h.Progress_Text,['Loading File ' num2str((i-1)*numel(card)+j) ' of ' num2str(numel(FileName)*numel(card))]);
                %%% Reads Macrotime (MT, as double) and Microtime (MI, as uint 16) from .spc file
                if Type == 2
                    FileName{i} = [FileName{i}(1:end-5) num2str(j) '.spc'];
                end
                [MT, MI, ~, ClockRate] = Read_BH(fullfile(Path,FileName{i}), Inf, [0 0 0], Card);
                if isempty(FileInfo.SyncPeriod)
                    FileInfo.SyncPeriod = 1/ClockRate;
                end
                %%% Finds, which routing bits to use
                Rout=unique(UserValues.Detector.Rout(UserValues.Detector.Det==j))';
                Rout(Rout>numel(MI))=[];
                %%% Concaternates data to previous files and adds Imagetime
                %%% to consecutive files
                if any(~cellfun(@isempty,MI))
                    for k=Rout'
                        TcspcData.MT{j,k}=[TcspcData.MT{j,k}; MaxMT + MT{k}];   MT{k}=[];
                        TcspcData.MI{j,k}=[TcspcData.MI{j,k}; MI{k}];   MI{k}=[];
                    end
                end
                %%% Determines last photon for each file
                for k=find(~cellfun(@isempty,TcspcData.MT(j,:)));
                    FileInfo.LastPhoton{j,k}(i)=numel(TcspcData.MT{j,k});
                end
            end
        end
        FileInfo.MeasurementTime = max(cellfun(@max,TcspcData.MT(~cellfun(@isempty,TcspcData.MT))))*FileInfo.SyncPeriod;
        FileInfo.LineTimes = [0 FileInfo.MeasurementTime];
    case 4
        %%4 : *.ht3 files from HydraHarp400
        %%% Usually, here no Imaging Information is needed
        FileInfo.FileType = 'HydraHarp';
        %%% General FileInfo
        FileInfo.NumberOfFiles=numel(FileName);
        FileInfo.Type=Type;
        FileInfo.MI_Bins=[];
        FileInfo.MeasurementTime=[];
        FileInfo.SyncPeriod= [];
        FileInfo.Resolution = [];
        FileInfo.TACRange = [];
        FileInfo.Lines=1;
        FileInfo.LineTimes=[];
        FileInfo.Pixels=1;
        FileInfo.ScanFreq=1000;
        FileInfo.FileName=FileName;
        FileInfo.Path=Path;
        
        %%% Initializes microtime and macotime arrays
        TcspcData.MT=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        TcspcData.MI=cell(max(UserValues.Detector.Det),max(UserValues.Detector.Rout));
        
        %%% Reads all selected files
        for i=1:numel(FileName)
            Progress((i-1)/numel(FileName),h.Progress_Axes, h.Progress_Text,['Loading File ' num2str(i) ' of ' num2str(numel(FileName))]);
            
            %%% if multiple files are loaded, consecutive files need to
            %%% be offset in time with respect to the previous file
            MaxMT = 0;
            if any(~cellfun(@isempty,TcspcData.MT))
                MaxMT = max(cellfun(@max,TcspcData.MT(~cellfun(@isempty,TcspcData.MT))));
            end
            
            %%% Update Progress
            Progress((i-1)/numel(FileName),h.Progress_Axes, h.Progress_Text,['Loading File ' num2str(i-1) ' of ' num2str(numel(FileName))]);
            %%% Reads Macrotime (MT, as double) and Microtime (MI, as uint 16) from .spc file
            [MT, MI, ClockRate,Resolution] = Read_HT3(fullfile(Path,FileName{i}),Inf,h.Progress_Axes,h.Progress_Text,i,numel(FileName));
            
            if isempty(FileInfo.SyncPeriod)
                FileInfo.SyncPeriod = 1/ClockRate;
            end
            if isempty(FileInfo.Resolution)
                FileInfo.Resolution = Resolution;
            end
            %%% Finds, which routing bits to use
            Rout=unique(UserValues.Detector.Rout(UserValues.Detector.Det))';
            Rout(Rout>numel(MI))=[];
            %%% Concaternates data to previous files and adds Imagetime
            %%% to consecutive files
            if any(~cellfun(@isempty,MI))
                for j = 1:size(MT,1)
                    for k=Rout
                        TcspcData.MT{j,k}=[TcspcData.MT{j,k}; MaxMT + MT{j,k}];   MT{j,k}=[];
                        TcspcData.MI{j,k}=[TcspcData.MI{j,k}; MI{j,k}];   MI{j,k}=[];
                    end
                end
            end
            %%% Determines last photon for each file
            for k=find(~cellfun(@isempty,TcspcData.MT(j,:)));
                FileInfo.LastPhoton{j,k}(i)=numel(TcspcData.MT{j,k});
            end
            
        end
        FileInfo.MeasurementTime = max(cellfun(@max,TcspcData.MT(~cellfun(@isempty,TcspcData.MT))))*FileInfo.SyncPeriod;
        FileInfo.LineTimes = [0 FileInfo.MeasurementTime];
        FileInfo.MI_Bins = max(cellfun(@max,TcspcData.MI(~cellfun(@isempty,TcspcData.MI))));
        FileInfo.TACRange = FileInfo.SyncPeriod;
end
Progress(1,h.Progress_Axes, h.Progress_Text);
%%% Applies detector shift immediately after loading data
Calibrate_Detector([],[],0)
%%% Updates the Pam meta Data; needs inputs 3 and 4 to be zero
Update_Data([],[],0,0);
Update_Display([],[],0);



