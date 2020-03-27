% Essentially similar to rm_raincloud, but didn't want to alter that one
% too much in order to get different parameterization.
% Use like: h = batch_raincloud(data, colours, 'Name',value,...)
% Where 'data' is an M x N cell array of N data series and M measurements
% And 'colours' is an N x 3 array defining the colour to plot each data series
%
% varargin: ('name',value,...) input pair syntax
% --> 'plot_top_to_bottom' : Default plots left-to-right, set to 1 to rotate.
% --> 'density_type' : 'ks' (default) or 'RASH'. 'ks' uses matlab's inbuilt 'ksdensity' to
%                       determine the shape of the rainclouds. 'RASH' will use the 'rst_RASH'
%                       method from Cyril Pernet's Robust Stats toolbox, if that function is on
%                       your matlab path.
% --> 'bandwidth' : If density_type == 'ks', determines bandwidth of density estimate
% --> 'ax' : {} (default); specify as cell array of 'name',value,... pairs
%              for Matlab Axes
% --> 'plot_connections' : false  (set as true to connect lines between
%                                groups)
% --> 'plot_means' : true (set as false to not plot mean scatter)
%
% h is a cell array containing handles of the various figure parts:
% h.p{i,j} is the handle to the density plot from data{i,j}
% h.s{i,j} is the handle to the 'raindrops' (individual datapoints) from data{i,j}
% h.m(i,j) is the handle to the single, large dot that represents mean(data{i,j})
% h.l(i,j) is the handle for the line connecting h.m(i,j) and h.m(i+1,j)
%
%	-- Changes --
%	2020-03-02 : m053m716 : Added option for first argument to be parent axes (similar to other Matlab graphics functions)

%% TO-DO:
% Patch can create colour gradients using the 'interp' option to 'FaceColor'. Allow this?

function h = batch_raincloud(data,varargin)
%BATCH_RAINCLOUD  Create `RainCloudPlot` style graphic for grouped cells
%
%  h = batch_raincloud(data,'Name',value,...);
%  h = batch_raincloud(ax,data,'Name',value,...);
%
%  h : Graphics struct
%  data : Cell array of grouped data
%  ax : (Optional) axes to plot on

%% default arguments
pars = struct;
pars.nbins = 200;
pars.raindrop_size = 100;
pars.jitter_factor = 0.125;
pars.raindrop_alpha = 0.5;
pars.plot_top_to_bottom = 0;
pars.density_type = 'ks';
pars.bandwidth = [];
pars.ax = {}; % Can be passed as 'Name',value pair cell array for axes props
pars.plot_connections = false;
pars.plot_means = true;
pars.plot_raindrop = true;
pars.text_x_offset = 0.5;
pars.text_tagx_offset = -1;
pars.text_y_offset = 1;
pars.text_tagy_offset = 1;
pars.text_num_format = '%5.3f';
pars.text_fontsize = 10;
pars.text_tagalign = 'center';
pars.text_align = 'center';
pars.text_font = 'Arial';
pars.text_tag = '';
pars.ytick_lab = '';
pars.ks_offsets = []; % Can specify this manually if desired

if isa(data,'matlab.graphics.axis.Axes')
   ax = data;
   % "Shift" the other input arguments accordingly
   data = varargin{1};
   varargin(1) = [];
else
   ax = gca;
end
[n_plots_per_series, n_series] = size(data);
pars.colours = cbrewer('qual','Dark2',max(n_series,3));

% make sure we have correct number of colours
nCol = size(pars.colours,1);
assert(nCol >= n_series, ...
   sprintf('Too few colors (%g) to plot series (%g)',nCol,n_series));

% Parse input parameter struct from varargin
for i = 1:2:numel(varargin)
   pars.(varargin{i}) = varargin{i+1};
end

% Set the axes property for 'NextPlot' as well as any optional axes settings we want
for i = 1:2:numel(pars.ax)
   ax.(pars.ax{i}) = pars.ax{i+1};
end
ax.NextPlot = 'add'; % Enforce this

%% Calculate properties of density plots
n_bins = repmat(pars.nbins, n_plots_per_series, n_series);

% calculate kernel densities
for i = 1:n_plots_per_series
   for j = 1:n_series
      if isempty(data{i,j})
         ks{i,j} = nan;
         x{i,j} = nan;
         q{i,j} = nan(1,4);
         faces{i,j} = nan(1,4);
         continue;
      end
      
      switch pars.density_type
         
         case 'ks'
            
            % compute density using 'ksdensity'
            [ks{i, j}, x{i, j}] = ksdensity(data{i, j}, 'NumPoints', n_bins(i, j), 'bandwidth', pars.bandwidth);
            
         case 'rash'
            
            % check for rst_RASH function (from Robust stats toolbox) in path, fail if not found
            assert(exist('rst_RASH', 'file') == 2, ...
               'Could not compute density using RASH method. Do you have the Robust Stats toolbox on your path?');
            
            % compute density using RASH
            [x{i, j}, ks{i, j}] = rst_RASH(data{i, j});
            
            % override default 'n_bins' as rst_RASH determines number of bins
            n_bins(i, j) = size(ks{i, j}, 2);
      end
      
      % Define the faces to connect each adjacent f(x) and the corresponding points at y = 0.
      q{i, j}     = (1:n_bins(i, j) - 1)';
      faces{i, j} = [q{i, j}, q{i, j} + 1, q{i, j} + n_bins(i, j) + 1, q{i, j} + n_bins(i, j)];
      
   end
end

% determine spacing between plots
spacing     = 2 * nanmean(nanmean(cellfun(@nanmax, ks)));

if isempty(pars.ks_offsets)
   ks_offsets  = (0:n_plots_per_series-1) .* spacing;
else
   ks_offsets = pars.ks_offsets;
end

% flip so first plot in series is plotted on the *top*
ks_offsets  = fliplr(ks_offsets);

if ~iscell(pars.text_tag)
   pars.text_tag = repmat({pars.text_tag},n_plots_per_series,n_series);
end

% calculate patch vertices from kernel density
for i = 1:n_plots_per_series
   for j = 1:n_series
      if isempty(data{i,j})
         continue;
      end
      verts{i, j} = [x{i, j}', ks{i, j}' + ks_offsets(i); x{i, j}', ones(n_bins(i, j), 1) * ks_offsets(i)];
      verts{i, j} = [x{i, j}', ks{i, j}' + ks_offsets(i); x{i, j}', ones(n_bins(i, j), 1) * ks_offsets(i)];
   end
end


%% jitter for the raindrops

jit_width = spacing * pars.jitter_factor;
for i = 1:n_plots_per_series
   for j = 1:n_series
      if isempty(data{i,j})
         continue;
      end
      jit{i,j} = jit_width + rand(1, length(data{i,j})) * jit_width;
   end
end

%% means (for mean dots)

cell_means = cellfun(@nanmean, data);

%% plot
% note - we *could* plot everything here in one big loop, but then
% different figure parts would overlay each other in a silly way.

% hold on % m053m716 2020-03-02: Changed this so axes property is set at beginning

% patches
for i = 1:n_plots_per_series
   for j = 1:n_series
      if isempty(data{i,j})
         continue;
      end
      % plot patches
      h.p{i, j} = patch(ax,'Faces', faces{i, j}, 'Vertices', verts{i, j}, 'FaceVertexCData', pars.colours(j, :), 'FaceColor', 'flat', 'EdgeColor', 'none', 'FaceAlpha', 0.5);
      
      if pars.plot_raindrop
         % scatter rainclouds
         h.s{i, j} = scatter(ax,data{i, j}, -jit{i, j} + ks_offsets(i), ...
            'MarkerFaceColor', pars.colours(j, :), ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', pars.raindrop_alpha, ...
            'SizeData', pars.raindrop_size);
      else
         h.s = [];
      end
   end
end

if isscalar(pars.plot_connections)
   if pars.plot_connections
      connectionMode = 'standard';
   else
      connectionMode = 'off';
   end
else
   if numel(pars.plot_connections) > 1
      connectionMode = 'multi';
   else
      connectionMode = 'off';
   end
end

switch connectionMode
   case 'standard'
      % plot mean lines
      for i = 1:n_plots_per_series - 1 % We have n_plots_per_series-1 lines because lines connect pairs of points
         for j = 1:n_series
            if isempty(data{i,j})
               continue;
            end
            h.l(i, j) = line(ax,cell_means([i i+1], j), ks_offsets([i i+1]), 'LineWidth', 4, 'Color', pars.colours(j, :));

         end
      end
   case 'multi'
      if pars.plot_top_to_bottom
         marker = 'v';
      else
         marker = '>';
      end
      cm = diag(cell_means);
      
      % plot mean lines, with matrix determining connections between lines
      for i = 1:n_plots_per_series - 1 % We have n_plots_per_series-1 lines because lines connect pairs of points
         for j = 1:n_series
            if isempty(data{i,j})
               continue;
            else
               idx = find(pars.plot_connections(i,:));
               idx = idx(idx ~= i);
            end
            hg = hggroup(ax);
            h.l{i, j} = hg;
            for ik = 1:numel(idx)
               k = idx(ik);
               line(hg,cm([i k]), ks_offsets([i k]), ...
                  'MarkerIndices',2,'Marker',marker,'MarkerSize',5,...
                  'LineWidth', 2, 'Color', pars.colours(j, :),...
                  'LineStyle','-');
            end
            

         end
      end
   case 'off'
      % Does nothing (no connection lines to plot)
      h.l = [];
end

ax.YTick = sort(ks_offsets,'ascend');
if ~isempty(pars.ytick_lab)
   tmp = reshape(pars.ytick_lab,numel(pars.text_tag),1);
   ax.YTickLabels = flipud(tmp);
end

if pars.plot_means   
   % plot mean dots
   for i = 1:n_plots_per_series
      for j = 1:n_series
         if isempty(data{i,j})
            continue;
         end
         h.m(i, j) = scatter(ax,cell_means(i, j), ks_offsets(i), ...
            'MarkerFaceColor', pars.colours(j, :), 'MarkerEdgeColor', [0 0 0], ...
            'MarkerFaceAlpha', 1, 'SizeData', pars.raindrop_size * 2, 'LineWidth', 2);
         h.tmu(i, j) = text(ax,cell_means(i, j)+pars.text_x_offset, ks_offsets(i)+pars.text_y_offset,...
            sprintf(['\\mu = ' pars.text_num_format],cell_means(i,j)),...
            'FontName',pars.text_font,'FontSize',pars.text_fontsize,'Color','k','HorizontalAlignment',pars.text_align);
         
         if isempty(pars.text_tag{i,j})
            h.ttag = [];
            continue;
         end
         h.ttag(i,j) = text(ax,pars.text_tagx_offset, ks_offsets(i)+pars.text_tagy_offset,...
            pars.text_tag{i,j},'FontName',pars.text_font,'FontSize',pars.text_fontsize,'Color','k','HorizontalAlignment',pars.text_tagalign);
      end
   end
else
   h.m = [];
   h.tmu = [];
%    h.ttag = [];
end

%% clear up axis labels

% 'YTick', likes values that *increase* as you go up the Y-axis, but we plot the first
% raincloud at the top. So flip the vector around
set(gca, 'YTick', fliplr(ks_offsets));
set(gca, 'YTickLabel', n_plots_per_series:-1:1);

%% determine plot rotation
% default option is left-to-right
% pars.plot_top_to_bottom can be set to 1
% NOTE: Because it's easier, we actually prepare everything plotted
% top-to-bottom, then - by default - we rotate it here. That's why the
% logical is constructed the way it is.

% rotate and flip
if ~pars.plot_top_to_bottom
   view([90 -90]);
   axis ij
end
