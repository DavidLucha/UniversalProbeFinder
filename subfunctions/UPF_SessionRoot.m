function strRoot = UPF_SessionRoot(boolAsk)
	%UPF_SessionRoot Data folder that holds <mouse>/histology and <mouse>/<rec>/kilosort (DLH fork)
	%   strRoot = UPF_SessionRoot()       saved folder; asks once if none is saved yet
	%   strRoot = UPF_SessionRoot(true)   always asks (to change it)
	%
	%Saved in configPF.ini as SessionRoot. Returns '' if the user cancels.

	if ~exist('boolAsk','var') || isempty(boolAsk)
		boolAsk = false;
	end

	%read without triggering PF_getIniVar's input dialog for a missing variable
	strRoot = '';
	strIni = fullfile(SH_getIniPath(),'configPF.ini');
	if exist(strIni,'file') && contains(fileread(strIni),'SessionRoot=')
		strRoot = PF_getIniVar('SessionRoot');
	end

	if boolAsk || isempty(strRoot) || ~ischar(strRoot) || ~exist(strRoot,'dir')
		strDefault = fullfile(char(java.lang.System.getProperty('user.home')),'Data','probe_recon');
		if ~exist(strDefault,'dir'),strDefault = cd();end
		strNew = uigetdir(strDefault,'Select the data folder (holds <mouse>/histology and <mouse>/rec*/kilosort)');
		if isempty(strNew) || isequal(strNew,0)
			if boolAsk && ischar(strRoot) && exist(strRoot,'dir'),return;end %keep the old one
			strRoot = '';
			return;
		end
		strRoot = strNew;
		PF_getIniVar('SessionRoot',true,strRoot);
	end
end
