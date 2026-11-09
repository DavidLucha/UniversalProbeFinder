function PH_ConsolePrompt(strAction,strWhat,strStartPath,strHint)
	%PH_ConsolePrompt Echo what a file/folder dialog is asking for to the Command Window
	%   PH_ConsolePrompt(strAction,strWhat,strStartPath,strHint)
	%
	%macOS file dialogs don't show their title, so the request is printed here
	%just before each uigetfile / uigetdir / uiputfile opens. (DLH fork addition)
	
	if ~exist('strStartPath','var') || isempty(strStartPath) || ~(ischar(strStartPath) || isstring(strStartPath))
		strStartPath = cd();
	end
	fprintf('\n[UPF] %s: %s\n      dialog opens in: %s\n',strAction,char(strWhat),char(strStartPath));
	if exist('strHint','var') && ~isempty(strHint)
		fprintf('      %s\n',strHint);
	end
	drawnow; %flush to the Command Window before the modal dialog takes focus
end
