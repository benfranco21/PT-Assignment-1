%[text] # STA4028Z Portfolio Theory — Assignment 1
%[text] ## Part II, Experiment 2: Out-Of-Sample Backtesting using a Rolling Window
%[text] **Author:** My Name : 0000000
%[text] **File:** STA4028Z-A1-2026-ZZZYYY001-v1.0
%[text] This script computes a sequence of Sharpe-Ratio-maximising (Tangency)
%[text] Portfolios using rolling, fixed-length, monthly-incremented data
%[text] windows, generates the resulting out-of-sample performance
%[text] time-series, and compares it to the static in-sample estimate and
%[text] the Buy-and-Hold strategy from Experiment 1.

%[text] ### Clear environment
clc
close all
clear

%[text] ### Date and time stamp (proves this script was executed)
executionTimestamp = datetime('now')

%[text] ### Resolve the project root
scriptFile = mfilename('fullpath');
scriptsDir = fileparts(scriptFile);
projectRoot = fileparts(scriptsDir);

%[text] ## 1. Load the raw data
%[text] Identical pipeline to Experiment 1, reproduced here so this script
%[text] runs standalone from a cold start.
fileName = fullfile(projectRoot,'data','raw', ...
    'PT-DATA-ALBI-JIBAR-JSEIND-Daily-1994-2017.xlsx');

excelSheetNames = sheetnames(fileName);
data{numel(excelSheetNames)} = [];
for sheet = 1:numel(excelSheetNames)
    data{sheet} = readtimetable(fileName,'Sheet',excelSheetNames{sheet}, ...
        VariableNamingRule='preserve', VariableNamesRange='A1', ...
        VariableDescriptionsRange='A2', Range='A5');
end

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

allDataTable = synchronize(data{1},data{2},data{3},data{4});
allDataTable = renamevars(allDataTable,{'RATESTEFI','J203'}, ...
    {'STEFI','ALSI'});

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

allDataReturnsTable = allDataTable(2:end,:);
allDataReturnsTable{:,:} = ...
    allDataTable{2:end,:}./allDataTable{1:end-1,:}-1;

%[text] ## 2. Define the asset universe (identical to Experiment 1)
riskyTickers = {'ALBI','J510','J520','J530','J540','J550','J560', ...
    'J580','J590'};
riskFreeTicker = 'STEFI';

riskyReturns = allDataReturnsTable(:,riskyTickers);
riskFreeReturns = allDataReturnsTable(:,{riskFreeTicker});

numberOfAssets = width(riskyReturns);
numberOfPeriods = height(riskyReturns);
periodsPerYear = 12;

%[text] ## 3. Recompute the Experiment 1 Buy-and-Hold baseline
%[text] Reproduced here so the two experiments' out-of-sample performance
%[text] can be compared directly on one set of axes.
splitFraction = 0.6;
splitIndex = floor(splitFraction*numberOfPeriods);

trainReturns = riskyReturns(1:splitIndex,:);
testReturns = riskyReturns(splitIndex+1:end,:);
trainRFR = riskFreeReturns(1:splitIndex,:);
testRFR = riskFreeReturns(splitIndex+1:end,:);

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

[numberOfTestPeriods,~] = size(testReturns);
testReturnsMatrix = testReturns{:,:};
bhWeights = zeros(numberOfTestPeriods,numberOfAssets);
bhPortfolioReturns = zeros(numberOfTestPeriods,1);
bhWeights(1,:) = tangencyWeights;
for t = 1:numberOfTestPeriods-1
    bhPortfolioReturns(t+1,:) = bhWeights(t,:)*transpose(testReturnsMatrix(t+1,:));
    bhWeights(t+1,:) = bhWeights(t,:).*(testReturnsMatrix(t+1,:)+1);
    bhWeights(t+1,:) = bhWeights(t+1,:)/sum(bhWeights(t+1,:));
end
bhOutSampleReturns = bhPortfolioReturns(2:end);
bhOutSampleExcessReturns = bhOutSampleReturns - testRFR{2:end,1};
bhMean = mean(bhOutSampleReturns);
bhVariance = var(bhOutSampleReturns);
bhAnnualisedSharpe = sqrt(periodsPerYear)* ...
    mean(bhOutSampleExcessReturns)/std(bhOutSampleExcessReturns);

inSamplePortfolioReturns = trainReturns{:,:}*tangencyWeights';
inSampleExcessReturns = inSamplePortfolioReturns - trainRFR{:,1};
inSampleMean = mean(inSamplePortfolioReturns);
inSampleVariance = var(inSamplePortfolioReturns);
inSampleAnnualisedSharpe = sqrt(periodsPerYear)* ...
    mean(inSampleExcessReturns)/std(inSampleExcessReturns);

%[text] ## 4. Rolling-window Tangency Portfolio backtest
%[text] A fixed-length window of $h$ months (matching the size of the
%[text] Experiment 1 training set, so the first rolling estimate uses the
%[text] same information as Experiment 1's static estimate) is rolled
%[text] forward one month at a time. At each step, the Tangency Portfolio
%[text] is re-estimated from the trailing window and applied to compute
%[text] the realised return of the *next* month only (true one-month-ahead
%[text] out-of-sample performance), following the lecturer's rolling
%[text] historic backtest loop convention (Lecture 004).
h = splitIndex; % fixed window length, months (= Experiment 1 training size)

riskyReturnsMatrix = riskyReturns{:,:};
riskFreeReturnsVector = riskFreeReturns{:,1};

rollingWeights = nan(numberOfPeriods,numberOfAssets);
rollingInSampleSharpe = nan(numberOfPeriods,1);
rollingOutSampleReturns = zeros(numberOfPeriods,1);

for t = h:numberOfPeriods-1
    % 1. Data window: trailing h months up to and including time t
    windowReturns = riskyReturnsMatrix(t-h+1:t,:);
    windowRFR = mean(riskFreeReturnsVector(t-h+1:t));
    muWindow = mean(windowReturns);
    SigmaWindow = cov(windowReturns);

    % 2. Estimate the Tangency Portfolio on the window (in-sample)
    x0 = ones(size(muWindow))/length(muWindow);
    fn0 = @(x) (-(x*muWindow' - windowRFR)/sqrt(x*SigmaWindow*x'));
    options = optimoptions(@fmincon,'Algorithm','sqp', ...
        'OptimalityTolerance',1e-8,'Display','off');
    wStar = fmincon(fn0,x0,[],[],Aeq,beq,lb,ub,[],options);
    rollingWeights(t,:) = wStar;

    % 3. In-sample Sharpe Ratio achieved on the estimation window
    windowPortfolioReturns = windowReturns*wStar';
    windowExcessReturns = windowPortfolioReturns - ...
        riskFreeReturnsVector(t-h+1:t);
    rollingInSampleSharpe(t) = sqrt(periodsPerYear)* ...
        mean(windowExcessReturns)/std(windowExcessReturns);

    % 4. Apply the estimated weights out-of-sample to the NEXT month only
    rollingOutSampleReturns(t+1) = wStar*riskyReturnsMatrix(t+1,:)';
end

%[text] ### Extract the out-of-sample rolling strategy performance
%[text] Covers the same 58-month test period as Experiment 1's Buy-and-Hold
%[text] strategy, since the window length was chosen to align the two.
rollingOutSample = rollingOutSampleReturns(h+1:end);
rollingOutSampleRFR = riskFreeReturnsVector(h+1:end);
rollingOutSampleExcess = rollingOutSample - rollingOutSampleRFR;

rollingMean = mean(rollingOutSample);
rollingVariance = var(rollingOutSample);
rollingAnnualisedSharpe = sqrt(periodsPerYear)* ...
    mean(rollingOutSampleExcess)/std(rollingOutSampleExcess);

rollingDates = riskyReturns.Time(h+1:end);

%[text] ## 5. Results table (required by the assignment brief)
strategy = ["In-sample (Experiment 1, static)"; ...
    "Out-of-sample Buy-and-Hold (Experiment 1)"; ...
    "Out-of-sample Rolling-Window (Experiment 2)"];
meanReturn = [inSampleMean; bhMean; rollingMean];
variance = [inSampleVariance; bhVariance; rollingVariance];
annualisedSharpe = [inSampleAnnualisedSharpe; bhAnnualisedSharpe; ...
    rollingAnnualisedSharpe];

comparisonTable = table(strategy,meanReturn,variance,annualisedSharpe, ...
    'VariableNames',{'Strategy','MeanReturn','Variance','AnnualisedSharpe'})

%[text] ## 6. Time-series comparison plot (required by the assignment brief)
%[text] Out-of-sample cumulative wealth: Buy-and-Hold (Experiment 1) vs.
%[text] the incrementally rebalanced Rolling-Window strategy (Experiment 2),
%[text] over the identical out-of-sample period.
figure
bhWealth = cumprod(1+bhOutSampleReturns);
rollingWealth = cumprod(1+rollingOutSample);
plot(testReturns.Time(2:end),bhWealth,'LineWidth',1.5)
hold on
plot(rollingDates,rollingWealth,'LineWidth',1.5)
title('Out-of-Sample Cumulative Wealth: Buy-and-Hold vs. Rolling-Window Tangency Portfolio')
xlabel('Date')
ylabel('Cumulative wealth')
legend('Buy-and-Hold (Experiment 1)', ...
    'Rolling-Window Rebalanced (Experiment 2)','Location','northwest')
grid on
hold off

%[text] ### In-sample Sharpe Ratio at each rebalancing point
figure
plot(riskyReturns.Time(h:end-1),rollingInSampleSharpe(h:end-1), ...
    'LineWidth',1.2)
title('Rolling-Window In-Sample Annualised Sharpe Ratio at Each Rebalancing Date')
xlabel('Date')
ylabel('Annualised Sharpe Ratio (estimation window)')
grid on

%[text] ### Rolling portfolio weights over time
figure
plot(riskyReturns.Time(h:end-1),rollingWeights(h:end-1,:),'LineWidth',1)
title('Rolling-Window Tangency Portfolio Weights')
xlabel('Date')
ylabel('Weight')
legend(riskyTickers,'Location','eastoutside')
grid on

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":32}
%---

