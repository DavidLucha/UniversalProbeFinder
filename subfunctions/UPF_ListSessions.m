function sSessions = UPF_ListSessions(strRoot,strMouse)
	%UPF_ListSessions Recordings under the data folder that UPF_OpenSession can open (DLH fork)
	%   sSessions = UPF_ListSessions(strRoot)          every <mouse>/<rec>/kilosort with params.py
	%   sSessions = UPF_ListSessions(strRoot,strMouse) one mouse only
	%
	%sSessions(i) has .mouse .rec .label and the flags .hasHistology .hasSaved .hasAutofit;
	%.label is what the launcher list shows, e.g. '810830  rec1   [saved] [autofit]'.

	sSessions = struct('mouse',{},'rec',{},'label',{},'hasHistology',{},'hasSaved',{},'hasAutofit',{});
	if ~exist('strRoot','var') || isempty(strRoot) || ~exist(strRoot,'dir'),return;end
	if ~exist('strMouse','var'),strMouse = '';end
	strMouse = char(string(strMouse));

	sParams = dir(fullfile(strRoot,'*','*','kilosort','params.py'));
	for intS=1:numel(sParams)
		strRecDir = fileparts(sParams(intS).folder);
		[strMouseDir,strRec] = fileparts(strRecDir);
		[~,strM] = fileparts(strMouseDir);
		if ~isempty(strMouse) && ~strcmp(strM,strMouse),continue;end

		%same field order as the empty template above, so the struct array can grow
		s = struct('mouse',strM,'rec',strRec,'label','','hasHistology',false,'hasSaved',false,'hasAutofit',false);
		s.hasHistology = ~isempty(dir(fullfile(strMouseDir,'histology','**','AP_histology_processing.mat')));
		s.hasSaved = ~isempty(dir(fullfile(strRecDir,'upf','*_probe.mat'))) || ...
			~isempty(dir(fullfile(strRecDir,'upf','ProbeLocationFile*.mat')));
		s.hasAutofit = ~isempty(dir(fullfile(strRecDir,'upf','*_autofit.json')));
		strTags = '';
		if s.hasSaved,strTags = [strTags ' [saved]'];end %#ok<AGROW>
		if s.hasAutofit,strTags = [strTags ' [autofit]'];end %#ok<AGROW>
		if ~s.hasHistology,strTags = [strTags ' [no histology]'];end %#ok<AGROW>
		s.label = sprintf('%s  %s %s',strM,strRec,strTags);
		sSessions(end+1) = s; %#ok<AGROW>
	end

	%sort by mouse, then recording
	if ~isempty(sSessions)
		[~,vecOrd] = sort(strcat({sSessions.mouse},'/',{sSessions.rec}));
		sSessions = sSessions(vecOrd);
	end
end
