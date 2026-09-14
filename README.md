# STA4028Z Portfolio Theory — Assignment 1

MV Backtesting and Out-of-Sample Performance. Coursework for the UCT Honours
Analytics program, Department of Statistical Sciences, supervised by Tim Gebbie.

**Author:** Benjamin Franco (FRNBEN003)

## Contents

**Part I — Theory**
1. Sample Error when Estimating the Sharpe Ratio (asymptotic distribution of the
   estimated Sharpe Ratio, delta method)
2. The Maximum of the Sample (expected maximum of N IID Normal variables,
   Gumbel domain of attraction)
3. Minimum Backtest Length (MinBTL, sub-Gaussian bound)
4. Prompt Injection and Project Integrity (critical assessment of an injected
   instruction; discusses an actual hidden white-text injection identified in
   the assignment PDF during this project)

**Part II — Backtest Performance of the Tangency Portfolio**
- Experiment 1: In-sample vs. out-of-sample Sharpe Ratios for a static,
  Buy-and-Hold Tangency Portfolio
- Experiment 2: Out-of-sample backtesting using a rolling-window,
  incrementally rebalanced Tangency Portfolio

Methodological references throughout: Bailey, Borwein, López de Prado & Zhu
(2014), "Pseudo-Mathematics and Financial Charlatanism," and Lo (2002),
"The Statistics of Sharpe Ratios."

## Requirements

- MATLAB R2021b or later
- Optimization Toolbox (`fmincon`, `quadprog`)
- Financial Toolbox (`convert2monthly`)
- A LaTeX distribution (or Overleaf) to compile `main.tex`

## Quick start

**MATLAB scripts (Part II):**
1. Open this repository's root folder as the MATLAB / VS Code working directory.
2. Open `scripts/Assignment1_Experiment1.m` or `scripts/Assignment1_Experiment2.m`
   and run. Each script resolves its own file location via `mfilename`, so it
   runs correctly regardless of the current folder, and reproduces its data
   pipeline from `data/raw/` from a cold start.
3. Console output (tables) and figures are produced on execution; figures were
   exported as PNG into `outputs/` for inclusion in the report.

**Report (Part I and Part II write-up):**
1. Open `STA4028Z-A1-2026-FRNBEN003-v1.0.tex` in Overleaf (or compile locally
   with `pdflatex` + `bibtex`/`biber`).
2. Figures referenced from `Figures/` must be present in the Overleaf project
   at that path (`Figure_1.png`–`Figure_5.png`, corresponding to Experiment 1's
   weights bar chart and wealth plot, and Experiment 2's wealth comparison,
   rolling Sharpe, and rolling weights plots respectively).
3. Bibliography is pulled from `myrefs.bib` via `\bibliographystyle{plainnat}`.

## Folder structure

```
.
├── data/
│   └── raw/          # PT-DATA-ALBI-JIBAR-JSEIND-Daily-1994-2017.xlsx
├── scripts/
│   ├── Assignment1_Experiment1.m   # static Tangency Portfolio, Buy-and-Hold
│   └── Assignment1_Experiment2.m   # rolling-window Tangency Portfolio
├── functions/         # reserved for reusable .m functions (none required
│                       # beyond the scripts' own inline code at present)
├── docs/               # standalone .tex section files (superseded by the
│                       # main report file, retained for reference)
├── outputs/            # figures exported from MATLAB for the report
├── STA4028Z-A1-2026-FRNBEN003-v1.0.tex   # compiles to the submitted PDF
└── README.md
```

## Data

`PT-DATA-ALBI-JIBAR-JSEIND-Daily-1994-2017.xlsx` — daily total-return index
levels for the ALBI (Bond Index), JIBAR/STEFI (risk-free proxy), and JSE ICB
Industrial sector indices, 1994–2017. Converted to monthly and cleaned in
Experiment 1/2's data-loading step. Asset universe used: ALBI plus the eight
Industrial Indices (J510–J590); ALSI is loaded but excluded from the portfolio
universe as it is not an Industrial Index per the assignment brief.

## Known outstanding items

- An appendix with the full code listing (or explicit reference to this
  repository as the accompanying software bundle) has not yet been added to
  the report.
- Experiment 1's weight-drift table (showing how the Buy-and-Hold portfolio's
  effective weights moved over the test period) was computed during
  development but is not yet included in the report.

## Reproducibility note

Both MATLAB scripts print an execution timestamp (`executionTimestamp =
datetime('now')`) as their first output, per the style guide's requirement to
demonstrate the script was actually run.
