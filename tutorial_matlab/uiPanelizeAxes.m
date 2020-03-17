function ax = uiPanelizeAxes(parent,nAxes,varargin)
%UIPANELIZEAXES Returns axes cell array, with panelized axes objects
%
%  ax = uiPanelizeAxes(nAxes);
%  ax = uiPanelizeAxes(parent,nAxes,'Name',value,...);
%  ax = uiPanelizeAxes(parent,nRow,nCol,'Name',value,...);
%
%  --------
%   INPUTS
%  --------
%   parent     :     Handle to container object to panelize (such as
%                    uipanel)
%
%    nAxes     :     Number of axes objects (scalar integer)
%
%	nRow, nCol :     Can be given in place of nAxes (scalar integers)
%
%  varargin    :     (Optional) 'NAME', value input argument pairs.
%
%  --------
%   OUTPUT
%  --------
%    ax        :     Cell array of axes object handles.

%DEFAULT PARAMETERS
pars = struct;
pars.Top = 0.175; % Offset from TOP border ([0 1])
pars.Bot = 0.225; % Offset from BOTTOM border ([0 1])
pars.Left = 0.225;  % Offset from LEFT border ([0 1])
pars.Right = 0.15; % Offset from RIGHT border ([0 1])
pars.Position = [0 0 1 1]; % Default position (within parent container; assumes normalized)
pars.HorizontalAlignment = 'left';
pars.VerticalAlignment = 'bottom';

% For varargin
pars.Axes = {'FontName','Arial','FontSize',12,...
   'NextPlot','add','Color','w','XColor','k','YColor','k',...
   'LineWidth',1,'Units','Normalized'};

% Give option for no object input
if isnumeric(parent)
   varargin = [nAxes, varargin];
   nAxes = parent;
   parent = gcf;
end

% Parse inputs
if numel(varargin) >= 1
   if isnumeric(varargin{1})
      nRow = nAxes;
      nCol = varargin{1};
      varargin(1) = [];
   else
      nRow = floor(sqrt(nAxes));
      nCol = ceil(nAxes/nRow);
   end
else
   nRow = floor(sqrt(nAxes));
   nCol = ceil(nAxes/nRow);
end

% Parse parameters
if numel(varargin) == 1
   if isstruct(varargin{1})
      pars = varargin{1};
      varargin(1) = [];
   end
else
   for iV = 1:2:numel(varargin)
      pars = getopt(pars,1,varargin{:});
   end
end

% Based on input dimensions, get grid for [x,y,w,h] coordinates
[x,y,w,h] = uiGetGrid(nRow,nCol,pars);

% Build axes array
ax = gobjects(nRow,nCol);
for iRow = 1:nRow
   for iCol = 1:nCol
      pos = [x(iRow,iCol) y(iRow,iCol) w h];
      ax(iRow,iCol) = axes(parent,pars.Axes{:},...
         'Position',pos,...
         'UserData',[iRow iCol]);
   end
end

end