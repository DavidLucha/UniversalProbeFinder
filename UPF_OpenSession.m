function hMain = UPF_OpenSession(strMouse,strRec)
	%UPF_OpenSession Open ProbeFinder on one recording of a standard data folder, no file dialogs (DLH fork)
	%   UPF_OpenSession                  pick a recording from a list
	%   UPF_OpenSession 810830           pick one of mouse 810830's recordings
	%   UPF_OpenSession 810830 rec1      open it directly (UniversalProbeFinder 810830 rec1 does the same)
	%
	%Folder layout under the data folder (asked once, saved as SessionRoot in configPF.ini;
	%change it with UPF_SessionRoot(true) or from the launcher list):
	%   <root>/<mouse>/histology/**/AP_histology_processing.mat   probe tracks; 'Probe N' = recN
	%   <root>/<mouse>/<rec>/kilosort/                            ephys; every cluster*.tsv is loaded
	%   <root>/<mouse>/<rec>/upf/                                 saved probe files + upf_autofit.py output
	%
	%Starting position (asked when more than one is available):
	%   Resume    the newest saved probe file in <rec>/upf/ (<mouse>_<rec>_probe.mat or ProbeLocationFile*)
	%   Autofit   upf_autofit.py's suggestion (<rec>/upf/<mouse>_<rec>_probe*_autofit.json): UPF probe depth + length
	%One histology track only: it is used for every recording, with a warning in the console and title.
	%   Histology the AP_histology track as UPF places it by default
	%No ZETA / event file is asked for. Save probe file defaults to <rec>/upf/<mouse>_<rec>_probe.mat.
	%The Allen atlas is loaded once per MATLAB session and reused (clear global gUPF_AtlasCache to reload).

	hMain = [];

	%% paths: every subfolder of this repo (as UniversalProbeFinder/ProbeFinder do)
	strRepo = fileparts(mfilename('fullpath'));
	sDir = dir([strRepo filesep '**' filesep]);
	sDir(contains({sDir.folder},[filesep '.git'])) = [];
	cellFolders = unique({sDir.folder});
	for intFolder=1:numel(cellFolders)
		addpath(cellFolders{intFolder});
	end

	%% which recording
	strRoot = UPF_SessionRoot();
	if isempty(strRoot),return;end
	if ~exist('strMouse','var'),strMouse = '';end
	if ~exist('strRec','var'),strRec = '';end
	strMouse = char(string(strMouse));
	strRec = char(string(strRec));
	if isempty(strMouse) || isempty(strRec)
		sSessions = UPF_ListSessions(strRoot,strMouse);
		if isempty(sSessions)
			errordlg(sprintf('No <mouse>/<rec>/kilosort/params.py found under %s%s', strRoot, ...
				local_iff(isempty(strMouse),'',[' for mouse ' strMouse])),'UPF_OpenSession');
			return;
		elseif numel(sSessions) == 1
			intPick = 1;
		else
			[intPick,boolOk] = listdlg('Name','Open recording','PromptString','Select a recording:', ...
				'SelectionMode','single','ListString',{sSessions.label},'ListSize',[320 300]);
			if ~boolOk,return;end
		end
		strMouse = sSessions(intPick).mouse;
		strRec = sSessions(intPick).rec;
	end

	strMouseDir = fullfile(strRoot,strMouse);
	strRecDir = fullfile(strMouseDir,strRec);
	strKsDir = fullfile(strRecDir,'kilosort');
	strUpfDir = fullfile(strRecDir,'upf');
	if ~exist(fullfile(strKsDir,'params.py'),'file')
		errordlg(sprintf('No Kilosort folder at %s',strKsDir),'UPF_OpenSession');
		return;
	end
	intProbe = str2double(regexp(strRec,'\d+','match','once')); %'Probe N' = recN
	if isnan(intProbe)
		errordlg(sprintf('Cannot get a probe number from recording name "%s" (expected rec1, rec2, ...)',strRec),'UPF_OpenSession');
		return;
	end
	fprintf('\n[UPF] %s %s  (Probe %d)\n',strMouse,strRec,intProbe);

	%% starting position: what is available
	sSaved = [dir(fullfile(strUpfDir,'*_probe.mat')); dir(fullfile(strUpfDir,'ProbeLocationFile*.mat'))];
	%<mouse>_<rec>_probe*_autofit.json: the probe number in the name is the track used (probe1 when
	%the histology has one track for both recordings)
	sFit = dir(fullfile(strUpfDir,sprintf('%s_%s_probe*_autofit.json',strMouse,strRec)));
	sAph = dir(fullfile(strMouseDir,'histology','**','AP_histology_processing.mat'));
	cellStarts = {};
	if ~isempty(sSaved),cellStarts{end+1} = 'Resume saved';end
	if ~isempty(sFit) && ~isempty(sAph),cellStarts{end+1} = 'Autofit';end
	if ~isempty(sAph),cellStarts{end+1} = 'Histology';end
	if isempty(cellStarts)
		errordlg(sprintf('No AP_histology_processing.mat under %s and no saved probe file in %s', ...
			fullfile(strMouseDir,'histology'),strUpfDir),'UPF_OpenSession');
		return;
	elseif numel(cellStarts) == 1
		strStart = cellStarts{1};
	else
		strStart = questdlg(sprintf('%s %s: start from?',strMouse,strRec),'Starting position', ...
			cellStarts{:},cellStarts{1});
		if isempty(strStart),return;end
	end

	%% atlas (Allen CCF; cached for the MATLAB session)
	sAtlas = local_atlas();
	if isempty(sAtlas),return;end
	dblVoxel = mean(sAtlas.VoxelSize);

	%% ephys + every cluster*.tsv, no dialogs
	hMsg = msgbox(sprintf('Loading %s %s ephys + TSVs...',strMouse,strRec),'UPF');
	sClusters = EL_PrepEphys_KS(strKsDir,[],true);
	try,close(hMsg);end
	if isempty(sClusters),errordlg('Kilosort loading failed','UPF_OpenSession');return;end
	for i=1:numel(sClusters.Clust)
		sClusters.Clust(i).ShowMaskPF = true;
	end
	fprintf('[UPF] %d clusters, probe length %.0f um (contact span)\n',numel(sClusters.Clust),sClusters.ProbeLength);

	%% probe coordinates
	switch strStart
		case 'Resume saved'
			[~,intNewest] = max([sSaved.datenum]);
			strFile = fullfile(sSaved(intNewest).folder,sSaved(intNewest).name);
			sLoad = load(strFile);
			sProbeCoords = sLoad.sProbeCoords;
			sProbeCoords.folder = [sSaved(intNewest).folder filesep];
			sProbeCoords.name = sSaved(intNewest).name;
			fprintf('[UPF] resuming %s\n',strFile);
		otherwise
			strAph = local_pick_aph(sAph);
			sProbeCoords = PH_LoadProbeFile(sAtlas,'','',strAph,intProbe);
			%UPF's length convention for this data: the contact span from Kilosort (3820 um for
			%ONIX NP1), as PH_GenGUI would set it; set here because a supplied start skips that step
			sProbeCoords.ProbeLengthMicrons = sClusters.ProbeLength;
			sProbeCoords.ProbeLengthOriginal = sClusters.ProbeLength/dblVoxel;
			sProbeCoords.ProbeLength = sProbeCoords.ProbeLengthOriginal;
			fprintf('[UPF] histology: %s, Probe %d\n',strAph,intProbe);
			if strcmp(strStart,'Autofit')
				sProbeCoords = local_apply_autofit(sProbeCoords,sAtlas,sFit,dblVoxel);
			end
	end

	%% GUI
	hMain = PH_GenGUI(sAtlas,sProbeCoords,sClusters);
	sGUI = guidata(hMain);
	sGUI.sSession = struct('mouse',strMouse,'rec',strRec,'root',strRoot,'recDir',strRecDir, ...
		'ksDir',strKsDir,'upfDir',strUpfDir,'start',strStart);
	guidata(hMain,sGUI);
	strShared = '';
	if isfield(sProbeCoords,'boolSharedTrack') && sProbeCoords.boolSharedTrack
		strShared = ' - ONE TRACK, shared with the other recording(s)';
	end
	hMain.Name = sprintf('UPF: Probe Finder - %s %s (start: %s)%s',strMouse,strRec,strStart,strShared);

	%report what UPF actually shows, to compare with the autofit numbers
	try
		pvb = sGUI.sProbeCoords.sProbeAdjusted.probe_vector_bregma;
		fprintf('[UPF] UPF shows: probe depth %.0f um, length %.0f um\n',pvb(5),pvb(6));
	catch
	end
end

function sAtlas = local_atlas()
	%Allen CCF via the atlas loader UPF is configured with; loaded once, then reused
	global gUPF_AtlasCache
	if ~isempty(gUPF_AtlasCache)
		sAtlas = gUPF_AtlasCache;
		return;
	end
	sAtlasParams = PF_getAtlasIni();
	intA = find(strcmp({sAtlasParams.pathvar},'strAllenCCFPath'),1);
	if isempty(intA),intA = 1;end
	strAtlasPath = PF_getIniVar(sAtlasParams(intA).pathvar);
	hMsg = msgbox('Loading the Allen CCF atlas (once per MATLAB session)...','UPF');
	sAtlas = feval(sAtlasParams(intA).loader,strAtlasPath);
	try,close(hMsg);end
	if isempty(sAtlas),return;end
	if isfield(sAtlasParams(intA),'downsample') && ~isempty(sAtlasParams(intA).downsample)
		sAtlas.Downsample = round(sAtlasParams(intA).downsample);
	else
		sAtlas.Downsample = 1;
	end
	gUPF_AtlasCache = sAtlas;
end

function strAph = local_pick_aph(sAph)
	%one AP_histology_processing.mat per mouse is expected; if there are more, use the newest
	[~,intNewest] = max([sAph.datenum]);
	strAph = fullfile(sAph(intNewest).folder,sAph(intNewest).name);
	if numel(sAph) > 1
		warning('UPF_OpenSession:SeveralHistology','%d AP_histology_processing.mat files; using the newest, %s',numel(sAph),strAph);
	end
end

function sProbeCoords = local_apply_autofit(sProbeCoords,sAtlas,sFit,dblVoxel)
	%Place the probe at upf_autofit.py's suggested UPF probe depth and length, on the histology line.
	%Depth is measured exactly as UPF's coordinates text does: from where the line enters the brain
	%to the tip. The line (entry point, angles) is UPF's own fit to the histology points.
	[~,intNewest] = max([sFit.datenum]);
	strJson = fullfile(sFit(intNewest).folder,sFit(intNewest).name);
	sJ = jsondecode(fileread(strJson));
	[vecSph,vecEntry] = PH_Points2vec(sProbeCoords,sAtlas);
	matCart = PH_SphVec2CartVec(vecSph);                    %[tip; top]
	vecUp = diff(matCart,[],1); vecUp = vecUp/norm(vecUp);  %unit vector tip -> top
	vecSph(1:3) = vecEntry(:)' - vecUp*(sJ.upf_probe_depth_um/dblVoxel);
	vecSph(6) = sJ.upf_probe_length_um/dblVoxel;
	sProbeCoords.sProbeAdjusted.probe_vector_sph = vecSph;

	fprintf('[UPF] autofit %s (%s): depth %.0f um, length %.0f um (stretch %.3f, shift %+.0f um)\n', ...
		sFit(intNewest).name,datestr(sFit(intNewest).datenum,'dd-mmm HH:MM'), ...
		sJ.upf_probe_depth_um,sJ.upf_probe_length_um,sJ.stretch,sJ.shift_um);
	if ~isfield(sJ,'verdict') && isfield(sJ,'tip_robust') && ~sJ.tip_robust %older json without a verdict
		fprintf(2,'[UPF] autofit: TIP NOT ROBUST (tip moves %.0f um when the array ends are ignored) - check ZI / internal capsule\n',sJ.tip_disagreement_um);
	end
	if isfield(sJ,'verdict') && strcmp(sJ.verdict,'CHECK')
		fprintf(2,'[UPF] autofit verdict CHECK:\n');
		cellChecks = cellstr(sJ.checks);
		for i=1:numel(cellChecks),fprintf(2,'        ! %s\n',cellChecks{i});end
	end
	if ~isfield(sJ,'verdict') && isfield(sJ,'stretch_identified') && ~sJ.stretch_identified
		fprintf(2,'[UPF] autofit: stretch not identified - consider the same-mouse stretch (--fix-stretch)\n');
	end
	sInfo = dir(fullfile(sProbeCoords.folder,sProbeCoords.name));
	if ~isempty(sInfo) && sInfo(1).datenum > sFit(intNewest).datenum
		fprintf(2,'[UPF] autofit json is older than the histology file - rerun upf_autofit.py if the track changed\n');
	end
end

function out = local_iff(b,a,c)
	if b,out = a;else,out = c;end
end
