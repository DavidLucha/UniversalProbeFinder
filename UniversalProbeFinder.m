function UniversalProbeFinder(varargin)
	%The Universal Probe Finder consists of three independent programs:
	% - SlicePrepper: pre-process your images & annotate traces
	% - SliceFinder: align each slice to a brain atlas
	% - ProbeFinder: use ephys data to fine-tune your probe's location & export the brain at each
	%		contact point or cluster
	%
	%To use any program, simply type the name of the program in the matlab prompt, e.g.:
	%ProbeFinder
	%
	%Please read the manual for more detailed instructions.
	%
	%The Universal Probe Finder can use multiple atlases and ephys data formats, and calculates the
	%stimulus responsiveness of your clusters with the zetatest using only an array of event-onset
	%times. Using these neurophysiological markers will allow a more reliable alignment of your probe's
	%contact points to specific brain areas.
	%
	%At this time, can use the following atlases:
	%a.	Sprague Dawley rat brain atlas, downloadable at: https://www.nitrc.org/projects/whs-sd-atlas
	%b.	Allen CCF mouse brain atlas, downloadable at: http://data.cortexlab.net/allenCCF/
	%c. CHARM/SARM macaque brain atlas: https://afni.nimh.nih.gov/pub/dist/doc/htmldoc/nonhuman/macaque_tempatl/atlas_charm.html
	%It is also possible to add your own Atlas by editing the configAtlas.ini file that is created
	%when you first run the ProbeFinder (see manual).
	%
	%Please reach out to us (for example here: https://github.com/JorritMontijn/UniversalProbeFinder)
	%if you wish to have a different atlas added with out-of-the-box support. Adding an atlas is
	%very easy, and we're happy to extend the usefulness of our program for all its users.
	%
	%Acknowledgements
	%This work is based on earlier work by people from the cortex lab, most notably Philip Shamash
	%and Andy Peters. See for example this paper: https://www.biorxiv.org/content/10.1101/447995v1
	%
	%This repository includes various functions that come from other repositories, credit for these
	%functions go to their creators:
	%https://github.com/petersaj/AP_histology
	%https://github.com/JorritMontijn/Acquipix
	%https://github.com/JorritMontijn/GeneralAnalysis
	%https://github.com/kwikteam/npy-matlab
	%https://github.com/cortex-lab/spikes
	%https://github.com/JorritMontijn/zetatest
	%
	%License
	%This repository is licensed under the GNU General Public License v3.0, meaning you are free to
	%use, edit, and redistribute any part of this code, as long as you refer to the source (this
	%repository) and apply the same non-restrictive license to any derivative work (GNU GPL v3).
	%
	%The logo for the Universal Probe Finder uses this image as background (CC licensed):
	%https://upload.wikimedia.org/wikipedia/commons/7/75/Massive_galaxies_discovered_in_the_early_Universe.jpg 
	%
	%Created by Jorrit Montijn at the Cortical Structure and Function laboratory (KNAW-NIN)
	%
	%Rev:20240221 - v1.1.0
	
	%DLH fork: UniversalProbeFinder 810830 rec1 (or just 810830) opens that recording directly,
	%with no file dialogs - see UPF_OpenSession
	if nargin > 0
		UPF_OpenSession(varargin{:});
		return;
	end
	
	%ask which program to run
	
	%set disable/enable global
	global sUPF_ChooseGui
	if isfield(sUPF_ChooseGui,'hMain') && ishandle(sUPF_ChooseGui.hMain),return;end
	
	%create GUI
	hChooseGui = figure('WindowStyle','Normal','Name','Universal Probe Finder',...
		'Menubar','none','NumberTitle','off','Position',[500 500 400 300],'CloseRequestFcn',@UPF_DeleteFcn);
	hChooseGui.Units = 'normalized';
	
	%add paths
	if ~isdeployed
		strFullpath = mfilename('fullpath');
		strPath = fileparts(strFullpath);
		sDir=dir([strPath filesep '**' filesep]);
		%remove git folders
		sDir(contains({sDir.folder},[filesep '.git'])) = [];
		cellFolders = unique({sDir.folder});
		for intFolder=1:numel(cellFolders)
			addpath(cellFolders{intFolder});
		end
	end
	
	%change icon
	try
		warning('off','MATLAB:ui:javaframe:PropertyToBeRemoved');
		warning('off','MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
		jframe=get(hChooseGui,'javaframe');
		jIcon=javax.swing.ImageIcon(fullpath(SH_getIniPath(),'icon.png'));
		jframe.setFigureIcon(jIcon);
	catch
	end
	
	%create gui
	%DLH fork: layout for a 300 px tall window (was 200): the three programs, then a recording list
	ptrTextPrepper = uicontrol(hChooseGui,'Style','text','String','Select the program you wish to run:',...
		'Units','normalized','FontSize',12,'Position',[0.1 0.87 0.8 0.1],'backgroundcolor',[1 1 1]);
	
	ptrButtonPrepper = uicontrol(hChooseGui,'Style','pushbutton','String','Slice Prepper',...
		'Units','normalized','FontSize',12,'Position',[0.2 0.75 0.6 0.1],...
		'Callback',@SlicePrepper);
	
	ptrButtonFinder = uicontrol(hChooseGui,'Style','pushbutton','String','Slice Finder',...
		'Units','normalized','FontSize',12,'Position',[0.2 0.63 0.6 0.1],...
		'Callback',@SliceFinder);
	
	ptrButtonProber = uicontrol(hChooseGui,'Style','pushbutton','String','Probe Finder',...
		'Units','normalized','FontSize',12,'Position',[0.2 0.51 0.6 0.1],...
		'Callback',@ProbeFinder);
	
	%DLH fork: open one recording of the data folder in Probe Finder, no file dialogs
	ptrTextSession = uicontrol(hChooseGui,'Style','text','String','Or open a recording:',...
		'Units','normalized','FontSize',11,'Position',[0.05 0.39 0.9 0.07],'backgroundcolor',[1 1 1],...
		'HorizontalAlignment','left');
	ptrListSession = uicontrol(hChooseGui,'Style','popupmenu','String',{'(loading...)'},...
		'Units','normalized','FontSize',11,'Position',[0.05 0.28 0.62 0.1],...
		'Callback',@local_session_pick);
	ptrButtonSession = uicontrol(hChooseGui,'Style','pushbutton','String','Open',...
		'Units','normalized','FontSize',12,'Position',[0.7 0.28 0.25 0.1],...
		'Callback',@local_session_open);
	
	%check for ini file
	strIni = strcat(SH_getIniPath(),filesep,'configPF.ini');
	
	%load ini
	ptrButtonSetter = uicontrol(hChooseGui,'Style','pushbutton','String','Settings',...
			'Units','normalized','FontSize',12,'Position',[0.3 0.05 0.4 0.1],...
			'Callback',@SetVariablesUPF);
	if exist(strIni,'file')
		ptrButtonSetter.Visible = 'on';
	else
		ptrButtonSetter.Visible = 'off';
	end
	
	%add handles to global
	sUPF_ChooseGui = struct;
	sUPF_ChooseGui.hMain = hChooseGui;
	sUPF_ChooseGui.handles.ptrTextPrepper = ptrTextPrepper;
	sUPF_ChooseGui.handles.ptrButtonPrepper = ptrButtonPrepper;
	sUPF_ChooseGui.handles.ptrButtonFinder = ptrButtonFinder;
	sUPF_ChooseGui.handles.ptrButtonProber = ptrButtonProber;
	sUPF_ChooseGui.handles.ptrButtonSetter = ptrButtonSetter;
	sUPF_ChooseGui.handles.ptrTextSession = ptrTextSession;
	sUPF_ChooseGui.handles.ptrListSession = ptrListSession;
	sUPF_ChooseGui.handles.ptrButtonSession = ptrButtonSession;
	
	%move
	movegui(hChooseGui,'center');
	
	%fill the recording list (only reads the saved data folder; asks for one only when picked)
	local_session_fill(ptrListSession,false);
end

function local_session_fill(ptrList,boolAsk)
	%DLH fork: list <mouse>/<rec> recordings under the data folder; last entry changes the folder
	strIni = fullfile(SH_getIniPath(),'configPF.ini');
	if ~boolAsk && ~(exist(strIni,'file') && contains(fileread(strIni),'SessionRoot='))
		ptrList.String = {'(choose data folder...)'};
		ptrList.UserData = struct('mouse',{},'rec',{});
		ptrList.Value = 1;
		return;
	end
	strRoot = UPF_SessionRoot(boolAsk);
	sSessions = UPF_ListSessions(strRoot);
	if isempty(sSessions)
		ptrList.String = {sprintf('(none under %s)',strRoot),'(choose data folder...)'};
	else
		ptrList.String = [{sSessions.label},{'(choose data folder...)'}];
	end
	ptrList.UserData = sSessions;
	ptrList.Value = 1;
end

function local_session_pick(ptrList,varargin)
	%picking the last entry changes the data folder and refreshes the list
	if ptrList.Value == numel(ptrList.String)
		local_session_fill(ptrList,true);
	end
end

function local_session_open(varargin)
	global sUPF_ChooseGui
	ptrList = sUPF_ChooseGui.handles.ptrListSession;
	sSessions = ptrList.UserData;
	if isempty(sSessions) || ptrList.Value > numel(sSessions)
		local_session_fill(ptrList,true);
		return;
	end
	s = sSessions(ptrList.Value);
	UPF_OpenSession(s.mouse,s.rec);
end