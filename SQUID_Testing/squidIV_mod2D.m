function [ptable, Vsquid] = squidIV_mod2D()

clear all % MATLAB is complaining but this function will only be run like a script
close all

%% Add paths and define file locations
addpath('C:\Users\root\Nowack_Lab\Equipment_Drivers');
addpath('C:\Users\root\Nowack_Lab\Utilities');

dropbox = 'C:\Users\root\Dropbox\TeamData\';
time = char(datetime('now','TimeZone','local','Format', 'yyyyMMdd_HHmmss'));

paramsavepath = strcat(dropbox, 'Montana\squid_testing\'); % Where the parameters will be saved
paramsavefile = strcat('squidIV_params_', time, '.csv'); % What the parameters will be called

datapath = strcat(dropbox, 'Montana\squid_testing\'); % Where the data will be saved
datafile = strcat('squidIV_data_', time, '.csv'); % What the data will be called

plotpath = strcat(dropbox, 'Montana\squid_testing\');
plotfile = strcat('squidIV_plot_IV_', time, '.pdf');
plotfile2 = strcat('squidIV_plot_IV_', time, '.png');

%% Edit before running

% If testing without a squid, for wiring, etc
no_squid = false;

% Choose parameter file
paramfile = 'mod2D_params.csv';
parampath = strcat('./Parameters/',paramfile);
[p, ptable] = param_parse(parampath); % use ptable to see parameters in table form

% Git dump? Uncomment if you want a cluttered git.
% git_dump();

%% Ask the user for information
% Check parameters
param_prompt = input(strcat('Parameter file is: ',paramfile,'\nContinue? y/n [y]: '),'s');
if ~(isempty(param_prompt) || param_prompt=='y' || param_prompt=='Y')
    error('Check those params');
end

% Double check no squid
if no_squid
    squid_prompt = input('No SQUID present. Correct? y/n [y]: ','s');
    if ~(isempty(squid_prompt) || squid_prompt=='y' || squid_prompt=='Y')
        error('Edit the no_squid=true line!');
    end
end

% Ask for notes
notes = input('Notes about this run: ','s');

%% Some initial checks

% Check for potential SQUIDicide
if ~no_squid
    check_currents(max(abs(p.squid.Irampmax), abs(p.squid.Irampmin)), abs(p.squid.Imod));
end

% Check to make sure preamp doesn't filter out your signal
if p.preamp.rolloff_high < p.daq.rate
    error('You''re filtering out your signal -____-');
end


%% Send and collect data
nidaq = NI_DAQ(p.daq); % Initializes DAQ parameters
nidaq.set_io('squid'); % For setting input/output channels for measurements done on a SQUID

% Set output data
IsquidR = IVramp(p.squid);
Vmod = IVramp(p.mod);
    
% Set up input variables
Vsquid = zeros(length(Vmod), length(IsquidR));

% Set up figures
figure('units','normalized','position',[.1 .1 .5 .5]);

IVplot = subplot(121);
axis square

twoDplot = subplot(122);
axis square
colormap(hot)

% prep and send output to the daq
for i = 1:length(Vmod) % cycles over all mod currents
    Vmodstep = Vmod(i); 
    output = [IsquidR; Vmodstep]; % puts Vsquid into first row and Vmod into second row
    [Vsquidstep, ~] = nidaq.run(output); % Sends a signal to the daq and gets data back
    Vsquid(i,:) = Vsquidstep/p.preamp.gain; % corrects for gain of preamp and saves data into master array
    
    % Make plots
    plot_squidIV(IVplot, IsquidR/p.squid.Rbias, Vsquidstep);
    plot_mod2D(twoDplot, IsquidR/p.squid.Rbias, Vsquid, Vmodstep/p.mod.Rbias);
    
end

%% Save data, parameters, and notes
data_dump(datafile, datapath,[IsquidR' Vmod' Vsquid'],['IsquidR (V)', 'Vmod (V)', 'Vsquid (A)']); % 10 is for testing multiple columns
copyfile(parampath, strcat(paramsavepath,paramsavefile)); %copies parameter file to permanent location 
fid = fopen(strcat(paramsavepath,paramsavefile), 'a+');
fprintf(fid, '%s', notes);
fclose(fid);

%% Finalize plots
close all
plot_mod2D(twoDplot, IsquidR/p.squid.Rbias, Vsquid, Vmodstep/p.mod.Rbias); %No subplot this time
title({['Parameter file: ' paramsavefile];['Data file: ' datafile];['Rate: ' num2str(p.daq.rate) ' Hz']},'Interpreter','none');
print('-dpdf', strcat(plotpath, plotfile));
print('-dpng', strcat(plotpath, plotfile2));
% plot_modIV(data)
% plot_mod2D(data) % different plotting functions for different types of plots

end

%% Sub-functions used in this function/script

% Check currents function - prevents accidental SQUIDicide
function check_currents(Isquid, Imod)
    if Isquid > 100e-6 || Imod > 300e-6
        error('Current too high! Don''t kill the squid!')
    end
end

function ramped = IVramp(param)         
    half = param.Irampmin:param.Irampstep:param.Irampmax;
    ramped = [half flip(half)] * param.Rbias; % ramp up then down
end