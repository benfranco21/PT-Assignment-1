%[text] # STA4028Z Portfolio Theory — Assignment 1
%[text] ## Part II, Experiment 1: In-Sample and Out-Of-Sample Sharpe Ratios
%[text] **Author:** My Name : 0000000
%[text] **File:** STA4028Z-A1-2026-ZZZYYY001-v1.0
%[text] This script computes the fully-invested, no-short-selling Tangency
%[text] (Sharpe-Ratio-maximising) Portfolio on a training (in-sample) period,
%[text] implements it as a Buy-and-Hold strategy over a test (out-of-sample)
%[text] period, and compares in-sample and out-of-sample portfolio means,
%[text] variances, and Sharpe Ratios.

%[text] ### Clear environment
clc
close all
clear

%[text] ### Date and time stamp (proves this script was executed)
executionTimestamp = datetime('now')

%[text] ### Resolve the project root
%[text] Following the same convention as the lecturer's `sta4028zProject`
%[text] function: derive every path from this script's own installed
%[text] location, not from MATLAB's current folder. Since this is a plain
%[text] .m file (not a binary .mlx), `mfilename` reliably resolves to this
%[text] file's actual location, so the script runs correctly whether it is
%[text] launched from the repository root or from inside scripts/.
scriptFile = mfilename('fullpath');
scriptsDir = fileparts(scriptFile);
projectRoot = fileparts(scriptsDir);

%[text] ## 1. Load the raw data
%[text] Reproduces the Lecture 001 data-wrangling pipeline directly from the
%[text] controlled raw workbook, so this script runs from a cold start using
%[text] only the supplied Excel file.
fileName = fullfile(projectRoot,'data','raw', ...
    'PT-DATA-ALBI-JIBAR-JSEIND-Daily-1994-2017.xlsx');

excelSheetNames = sheetnames(fileName);
data{numel(excelSheetNames)} = [];
for sheet = 1:numel(excelSheetNames)
    data{sheet} = readtimetable(fileName,'Sheet',excelSheetNames{sheet}, ...
        VariableNamingRule='preserve', VariableNamesRange='A1', ...
        VariableDescriptionsRange='A2', Range='A5');
end

%[text] ### Keep only the required tickers (TRI columns only)
variableTickers = string("J5" + (10 : 10 : 90));
entities = {'RATESTEFI', 'ALBI', 'J203', 'J500', variableTickers{:}};

for i = 1:numel(data)
    if i == 3
        allVarTable = data{i};
        TRITable = allVarTable(:,(3:3:27));
        data{i} = TRITable;
    elseif i == 4
        allVarTable = data{i};
        allVarTable = removevars(allVarTable,["SOURCE68779","Var2"]);
        TRITable = allVarTable(:,(4:4:19));
        data{i} = TRITable;
    end
    opts = data{i}.Properties;
    variableMatch = zeros(size(opts.VariableNames));
    if i == 2
        for k = 1:numel(entities)
            variableMatch(strncmp(opts.VariableNames,entities{k},8)) = k;
        end
    else
        for k = 1:numel(entities)
            variableMatch(strncmp(opts.VariableNames,entities{k},4)) = k;
        end
    end
    idx = find(variableMatch==0);
    tickersToBeRemoved = opts.VariableNames(idx);
    data{i} = removevars(data{i}, tickersToBeRemoved);
    hasColon = contains(data{i}.Properties.VariableNames, ':');
    data{i}.Properties.VariableNames(hasColon) = ...
        extractBefore(data{i}.Properties.VariableNames(hasColon),':');
end

%[text] ### Synchronise into a single timetable and rename
allDataTable = synchronize(data{1},data{2},data{3},data{4});
allDataTable = renamevars(allDataTable,{'RATESTEFI','J203'}, ...
    {'STEFI','ALSI'});

%[text] ### Down-sample to monthly and handle missing data
allDataTable = convert2monthly(allDataTable);

[minNans,idx] = min(sum(isnan(allDataTable{:,:}),1));
rmmissingProxy = allDataTable.Properties.VariableNames{idx};
allDataTable = rmmissing(allDataTable,"DataVariables",rmmissingProxy);

idxJ500 = contains(allDataTable.Properties.VariableNames,'J500');
idx = 1:width(allDataTable);
allDataTable = allDataTable(:,idx(~idxJ500));

idx = isnan(allDataTable{:,:});
allDataTable = allDataTable(max(find(idx,max(max(cumsum(idx)))))+1:end,:);

countNans = max(max(cumsum(isnan(allDataTable{:,:}))));
allDataTable = allDataTable(1:end-countNans+1,:);

allDataTable = fillmissing(allDataTable,'previous');

%[text] ### Compute simple monthly returns
allDataReturnsTable = allDataTable(2:end,:);
allDataReturnsTable{:,:} = ...
    allDataTable{2:end,:}./allDataTable{1:end-1,:}-1;

fprintf('Loaded %d monthly observations from %s to %s.\n', ...
    height(allDataReturnsTable), ...
    datestr(allDataReturnsTable.Time(1)), ...
    datestr(allDataReturnsTable.Time(end)));

%[text] ## 2. Define the asset universe
%[text] Per the assignment brief: the Bond Index (ALBI) and the Industrial
%[text] Indices (ICB Industrial classification), with STEFI as the
%[text] risk-free proxy. ALSI is excluded as it is not an Industrial Index.
riskyTickers = {'ALBI','J510','J520','J530','J540','J550','J560', ...
    'J580','J590'};
riskFreeTicker = 'STEFI';

riskyReturns = allDataReturnsTable(:,riskyTickers);
riskFreeReturns = allDataReturnsTable(:,{riskFreeTicker});

numberOfAssets = width(riskyReturns);
numberOfPeriods = height(riskyReturns);
periodsPerYear = 12;

%[text] ## 3. Split into training (in-sample) and test (out-of-sample) sets
%[text] A 60/40 split by month count.
splitFraction = 0.6;
splitIndex = floor(splitFraction*numberOfPeriods);

trainReturns = riskyReturns(1:splitIndex,:);
testReturns = riskyReturns(splitIndex+1:end,:);
trainRFR = riskFreeReturns(1:splitIndex,:);
testRFR = riskFreeReturns(splitIndex+1:end,:);

fprintf(['Training set: %d months (%s to %s).\n' ...
    'Test set: %d months (%s to %s).\n'], ...
    height(trainReturns),datestr(trainReturns.Time(1)), ...
    datestr(trainReturns.Time(end)),height(testReturns), ...
    datestr(testReturns.Time(1)),datestr(testReturns.Time(end)));

%[text] ## 4. Compute the Tangency (Sharpe-Ratio-maximising) Portfolio
%[text] Fully invested, no short selling, solved by Sequential Quadratic
%[text] Programming, exactly as in Lecture 001:
%[text] $\max_{\omega} \left\{ {\frac{(\omega'\mu - R_{\mathrm{rfr}})}{\omega' \Sigma \omega}} \right\} s.t. ~~\omega' {\bf 1} = 1 \mbox{ and } \omega \geq 0$.
mu = mean(trainReturns{:,:});
ERFR = mean(trainRFR{:,1});
Sigma = cov(trainReturns{:,:});

x0 = ones(size(mu))/length(mu);
fn0 = @(x) (-(x*mu' - ERFR)/sqrt(x*Sigma*x'));
ub = ones(length(mu),1);
lb = zeros(length(mu),1);
Aeq = ones(1,length(mu));
beq = 1;

options = optimoptions(@fmincon,'Algorithm','sqp', ...
    'OptimalityTolerance',1e-8,'Display','off');
tangencyWeights = fmincon(fn0,x0,[],[],Aeq,beq,lb,ub,[],options);

%[text] ## 5. In-sample performance (training set)
%[text] Apply the tangency weights to every month of the training set to
%[text] obtain the in-sample portfolio return series.
inSamplePortfolioReturns = trainReturns{:,:}*tangencyWeights';
inSampleExcessReturns = inSamplePortfolioReturns - trainRFR{:,1};

inSampleMean = mean(inSamplePortfolioReturns);
inSampleVariance = var(inSamplePortfolioReturns);
inSampleAnnualisedSharpe = sqrt(periodsPerYear)* ...
    mean(inSampleExcessReturns)/std(inSampleExcessReturns);

%[text] ## 6. Out-of-sample performance (Buy-and-Hold on the test set)
%[text] Following the lecturer's Buy-Hold loop convention (Lecture 003,
%[text] "Buy-Hold (BH) portfolio"): the portfolio is bought once, at the
%[text] tangency weights, and never rebalanced. Portfolio returns use the
%[text] weight at the START of each interval; weights then drift with
%[text] realised price changes and are renormalised (no new capital added
%[text] or removed), but are never reset back to the tangency weights.
[numberOfTestPeriods,~] = size(testReturns);
testReturnsMatrix = testReturns{:,:};

% initialise weights matrix at the start of each interval
bhWeights = zeros(numberOfTestPeriods,numberOfAssets);
% T-1 portfolio returns
bhPortfolioReturns = zeros(numberOfTestPeriods,1);
% initialise the weights at the start of the first interval
bhWeights(1,:) = tangencyWeights;

for t = 1:numberOfTestPeriods-1
    % 1. Compute portfolio returns (weight at start times returns
    %    recorded at end)
    bhPortfolioReturns(t+1,:) = bhWeights(t,:)*transpose(testReturnsMatrix(t+1,:));
    % 2. Drift weights due to price changes (Buy-Hold (BH))
    bhWeights(t+1,:) = bhWeights(t,:).*(testReturnsMatrix(t+1,:)+1);
    % 3. renormalise the weights
    bhWeights(t+1,:) = bhWeights(t+1,:)/sum(bhWeights(t+1,:));
end

%[text] The first row is the initialisation point (no return realised
%[text] yet), so it is excluded from the summary statistics, matching the
%[text] lecturer's own treatment of the padded first observation.
outSamplePortfolioReturns = bhPortfolioReturns(2:end);
outSampleExcessReturns = outSamplePortfolioReturns - testRFR{2:end,1};

%[text] ### Drifted weights at the end of the test period (for discussion)
%[text] Shows how far the realised holdings moved away from the original
%[text] tangency weights by the end of the Buy-and-Hold period.
driftedWeights = bhWeights(end,:);
weightDriftTable = table(string(riskyTickers)',tangencyWeights', ...
    driftedWeights','VariableNames', ...
    {'Asset','InitialWeight','FinalDriftedWeight'})

outSampleMean = mean(outSamplePortfolioReturns);
outSampleVariance = var(outSamplePortfolioReturns);
outSampleAnnualisedSharpe = sqrt(periodsPerYear)* ...
    mean(outSampleExcessReturns)/std(outSampleExcessReturns);

%[text] ## 7. Results tables (required by the assignment brief)
%[text] ### Table 1: In-sample vs out-of-sample comparison
period = ["In-sample (training)"; "Out-of-sample (Buy-and-Hold test)"];
meanReturn = [inSampleMean; outSampleMean];
variance = [inSampleVariance; outSampleVariance];
annualisedSharpe = [inSampleAnnualisedSharpe; outSampleAnnualisedSharpe];

performanceTable = table(period,meanReturn,variance,annualisedSharpe, ...
    'VariableNames',{'Period','MeanReturn','Variance','AnnualisedSharpe'})

%[text] ### Table 2: Buy-and-Hold portfolio weights
assetName = string(riskyTickers)';
weight = tangencyWeights';

weightsTable = table(assetName,weight, ...
    'VariableNames',{'Asset','Weight'})

%[text] ## 8. Visualise
figure
bar(categorical(riskyTickers),tangencyWeights)
title('Tangency Portfolio Weights (Training Set)')
xlabel('Asset')
ylabel('Weight')
grid on

figure
inSampleWealth = cumprod(1+inSamplePortfolioReturns);
outSampleWealth = cumprod(1+outSamplePortfolioReturns)*inSampleWealth(end);
plot(trainReturns.Time,inSampleWealth,'LineWidth',1.5)
hold on
plot(testReturns.Time(2:end),outSampleWealth,'LineWidth',1.5)
xline(trainReturns.Time(end),'--','Train/Test split')
title('Tangency Portfolio: In-Sample vs Buy-and-Hold Out-of-Sample')
xlabel('Date')
ylabel('Cumulative wealth')
legend('In-sample (training)','Out-of-sample (Buy-and-Hold)', ...
    'Location','northwest')
grid on
hold off

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":32}
%---
