---
name: r-crop-trial-stats
description: Statistical analysis of crop field and pot trials in R (soybean, sorghum and other crops) for a thesis or paper. Use when the user has experiment data (yield, plant height, 100-seed weight, maturity, protein, etc.) from a CRD, RCBD, factorial, split-plot or multi-year / multi-location trial and wants ANOVA, mean separation with letters (LSD, Duncan, Tukey), CV, assumption checks, regression on fertilizer or seeding rates, trait correlations, publication figures or Word tables, or a results paragraph in Korean or English. Also use for "분산분석", "사후검정", "던컨", "최소유의차", "난괴법", "분할구", "R로 통계".
---

# Crop trial statistics in R

The user is an agricultural researcher (soybean and sorghum breeding and cultivation) writing a
master's thesis. They analyse in **R**. Write R code, run it, and explain the output in plain
Korean. Never invent data, p-values or letters: every number in a write-up comes from output you
ran on their file.

## 1. Before any test: read the data and the design

1. Open the file and print `str()` and the first rows. Korean Excel saves CSV as **CP949**: read
   with `read.csv(p, fileEncoding = "UTF-8-BOM")`, fall back to `"CP949"`; Excel files with
   `readxl::read_excel()`.
2. Ask or infer from the columns, and state back in one line before analysing:
   - the **design**: CRD (no block column), RCBD (반복/block column), factorial, split-plot
     (main plot and subplot factors), years or locations;
   - the **experimental unit**: plot means, not individual plants. Several plants per plot are
     subsamples: average them per plot first (or model plot as a random effect). Analysing plants
     as replicates is pseudoreplication.
3. Make treatment, block, year and location `factor()`s (a nitrogen rate stays numeric only for
   regression).

## 2. One- or two-factor RCBD: use the tested script

`scripts/rcbd_analysis.R` runs the whole standard analysis and was tested on CP949 CSV with Korean
column names:

```bash
Rscript <skill>/scripts/rcbd_analysis.R data.csv 수량 품종 반복 "" results duncan     # one factor
Rscript <skill>/scripts/rcbd_analysis.R data.csv 수량 품종 반복 질소 results lsd      # two factors
```

It writes `report.txt` (ANOVA, CV, Shapiro-Wilk, Levene, mean separation with letters; for two
factors the interaction p and both main effects), `means_letters.csv`, `means_plot.png` (mean ±
SE with letters, 300 dpi), `residual_check.png` and `means_table.docx`. Read `report.txt` back and
explain it. Copy the script into the user's project rather than editing it in the skill folder.

## 3. Other designs (write the model yourself)

| Design | Model |
|---|---|
| CRD | `aov(y ~ trt)` |
| RCBD | `aov(y ~ block + trt)` |
| Factorial RCBD | `aov(y ~ block + A * B)` |
| Split-plot (A main plot, B subplot) | `agricolae::sp.plot(block, A, B, y)`, or `lmerTest::lmer(y ~ A * B + (1 | block) + (1 | block:A))` |
| Years or locations, blocks within each | `lmerTest::lmer(y ~ trt * year + (1 | year:block))`; treat year as random when the years sample weather, as fixed when there are only two or three and they are of interest |
| Rate response (N, seeding rate) | `lm(y ~ rate + I(rate^2))`, compare with the linear fit by `anova()`, report the optimum `-b1 / (2 * b2)` only inside the tested range |
| Trait correlations | `cor.test()` per pair, or `psych::corr.test()` for the matrix; Pearson on plot means |

For mixed models report `anova(fit)` from lmerTest (Satterthwaite df) and separate means with
`emmeans::emmeans()` + `multcomp::cld(..., Letters = letters)`.

## 4. Checks and choices to state in the methods

- **Assumptions:** residuals vs fitted and a Q-Q plot; Shapiro-Wilk on residuals; Levene. If they
  fail: log or square-root for counts and skewed traits, arcsine-square-root or a GLM for
  percentages (germination, lodging), or Kruskal-Wallis as a last resort. Say what was done.
- **Mean separation:** use the test the lab or journal uses (Korean crop journals commonly use
  Duncan's multiple range test or LSD at 5%). Fisher's LSD only after a significant F. Tukey when
  comparing all pairs conservatively. Name the test and alpha in every table footnote.
- **Interaction first:** in a factorial, read the A x B line before the main effects. Significant:
  compare A within each level of B. Not significant: report the main effects.
- **CV** (`agricolae::cv.model`) goes in every ANOVA table; flag a CV above about 20% for yield.
- Report **mean ± SE (or SD)** and say which.

## 5. Figures and tables

- ggplot2, `theme_classic()`, 300 dpi PNG or TIFF (`ggsave(..., dpi = 300)`), width 8 to 17 cm
  for a journal column. Letters above the error bars.
- Korean labels on Windows: `theme(text = element_text(family = "Malgun Gothic"))`; on a Mac
  `"AppleGothic"`; or `showtext` with Noto Sans KR. Check the PNG for empty boxes.
- Tables to Word with `flextable::save_as_docx()`; the thesis usually wants the letters attached
  to the means ("285.3 a").
- Keep units in labels: 수량 (kg/10a), 백립중 (g), 경장 (cm).

## 6. The results paragraph

Write it only from the output, in the user's language, numbers with units:

> 품종 간 수량은 고도로 유의한 차이를 보였으며(F = 13.43, p < 0.01), 청자3호가 288.4 kg/10a로
> 가장 많았고 풍산나물과는 유의한 차이가 없었다(Duncan, p < 0.05).

English for the abstract: "Yield differed among cultivars (F3,9 = 13.43, p = 0.001); ..."

## 7. Reproducibility

Save every analysis as an `.R` script beside the data (never only console work), set
`set.seed()` before anything random, and end with `sessionInfo()` in the report so the thesis
methods can cite R and package versions (`citation("agricolae")`).

## Requirements

R 4.x with `agricolae`, `ggplot2`, `car`, `emmeans`, `multcomp`, `lme4`, `lmerTest`, `flextable`,
`officer`, `readxl`:
`install.packages(c("agricolae","ggplot2","car","emmeans","multcomp","lme4","lmerTest","flextable","officer","readxl"))`.
