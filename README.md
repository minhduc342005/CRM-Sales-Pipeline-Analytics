# 📊 CRM & Sales Pipeline Analytics

> End-to-end data analytics project using **Python**, **SQL Server (SSMS)**, and **Power BI** to analyze 3,000 B2B sales deals across 9 European countries — uncovering pipeline bottlenecks, agent performance gaps, revenue forecast accuracy, and lost opportunity patterns.

---

## 🔍 What This Project Does

A B2B SaaS company operating across Western Europe needs to understand:

- Where is the sales pipeline losing deals — and at which stage?
- Which agents are top performers and which need coaching?
- How much revenue can realistically be forecasted from open deals?
- Which industries and countries are worth investing more Sales resources?

This project answers all of these through a full analytics pipeline from raw Excel data to interactive dashboard.

---

## 💡 Key Results

| Finding | Detail |
|---|---|
| Overall conversion | Only **2.77%** of leads become customers — bottleneck at Opportunity → Closed (16.6%) |
| Win rate | **57.6%** on closed deals — healthy for B2B SaaS |
| Revenue forecast | **$1.10M** from $1.91M open pipeline (Method 1 — flat win rate) |
| Top industry | **IT & IT Services: 81% win rate** (n=21) — most reliable segment |
| Avoid | **Agriculture & Mining: 22% win rate** — confirmed across 4 separate analyses |
| Top agent | **Sarah Davis: 72.7% win rate** — highest closer in team |
| Revenue leader | **Laura Thompson: $48,693** — high-value deal specialist |
| Underperformer | **David Wilson: 33.3% win rate** — 24pp below team average |
| Forecast accuracy | **88.5% of deals close early** — avg 131 days ahead of expected date |
| At-risk pipeline | **$358K** in deals with risk score 4-5 needs immediate attention |

---

## 🔄 Analysis Pipeline

```
Raw Excel (3,000 rows · 17 columns)
    ↓
Python — EDA + Cleaning + Feature Engineering + 7-section analysis
    ↓
SQL Server / SSMS — 19 analytical queries across 7 dimensions
    ↓
Power BI — 4-page interactive dashboard · 18 DAX measures
```

---

## 🐍 Python Analysis

**File:** `notebook/CRM_Analytics.ipynb`

**Libraries:** pandas · numpy · matplotlib · seaborn

### Section 0 — Setup & Libraries
Dark theme configuration, color palette definition, library imports.

### Section 1 — Load Data & EDA
- 3,000 rows × 17 columns; `Stage` has 71.1% null (leads not yet in active pipeline — expected)
- `Actual close date` has 88.4% null — only closed deals have this
- `Deal Value` range: $200–$19,997, no negatives or zeros

### Section 2 — Data Cleaning & Feature Engineering

| Feature | Formula | Purpose |
|---|---|---|
| `is_won` | `Stage == 'Won'` | Boolean win flag |
| `is_lost` | `Stage == 'Lost'` | Boolean loss flag |
| `is_closed` | `Stage in ['Won','Lost']` | Closed deals filter |
| `is_open` | `Stage not null & not closed` | Active pipeline |
| `deal_duration_days` | `Expected close - Lead acquisition` | Sales cycle length |
| `close_delay_days` | `Actual close - Expected close` | Forecast accuracy |
| `lead_month` | `Period('M')` from acquisition date | Time-series grouping |
| `org_size_cat` | `Ordered Categorical` | Correct size ordering |

### Section 3 — Pipeline Health
- **3.1 Sales Funnel** — Status waterfall + Stage donut
- **3.2 Conversion Rates** — Step-by-step bottleneck analysis
- **3.3 Lead Distribution** — Country and Industry volume
- **3.4 Industry Win Rate** — Color-coded threshold bars + benchmark line
- **3.5 Monthly Trend** — Bar + line combo (volume + win rate)

### Section 4 — Agent Performance
- **4.1 Win Rate & Revenue** — Dual bar charts, different sort orders to reveal disconnect
- **4.2 Deal Duration** — Histogram overlay (Won vs Lost) + boxplot by stage
- **4.3 Agent × Industry Matrix** — Heatmap for skill-based routing
- **4.4 Probability Calibration** — Expected vs actual win rate by bucket

### Section 5 — Revenue Forecasting
- **5.1 Three-method forecast** — Flat win rate vs Probability-weighted vs Stage-based
- **5.2 Close Date Accuracy** — Agent boxplot showing conservative vs optimistic estimators

### Section 6 — Lost Opportunity Analysis
- **6.1 Lost by Industry/Product/Country** — Three-panel chart
- **6.2 Win Rate Heatmap** — Industry × Product pivot (RdYlGn scale)
- **6.3 Org Size Analysis** — Win rate + avg deal value by company size

### Section 7 — Executive Summary
Printed summary of all key findings and 5 strategic recommendations.

### Section 8 — Export to CSV
Cleaned and renamed dataset exported for SQL Server import.

### Section 9 — Import to SQL Server
Python script using SQLAlchemy + pyodbc to load data into SSMS (Windows Authentication).

---

## 🗄️ SQL Analysis

**File:** `sql/crm_ssms_final.sql` · **Tool:** SQL Server / SSMS · **Total:** 19 queries

### Query Groups

| Group | Queries | Key Questions |
|---|---|---|
| **0 — Setup** | Verify load | Row counts, basic sanity check |
| **1 — EDA** | 1.1–1.3 | Status/Stage distribution, Product × Org Size |
| **2 — Pipeline Health** | 2.1–2.4 | Funnel conversion, Industry WR, Country, Monthly trend |
| **3 — Agent Performance** | 3.1–3.4 | Scorecard, Duration, Close accuracy, Calibration |
| **4 — Forecast** | 4.1 | 3-method comparison with CROSS JOIN CTEs |
| **5 — Lost Analysis** | 5.1–5.2 | UNION ALL by 3 dimensions, Industry × Product pivot |
| **6 — Window Functions** | 6.1–6.3 | Running totals, RANK+LAG, At-risk scoring |
| **7 — Executive Summary** | 7.1 | Single-query portfolio KPIs |

### Techniques Used
- **CTEs:** Multi-step forecast with `hist` + `open_pipe` CTEs joined via CROSS JOIN
- **Window functions:** `RANK()`, `LAG()`, `SUM() OVER()`, `ROWS BETWEEN` rolling windows
- **Conditional aggregation:** `SUM(CASE WHEN ... END)` for manual pivot tables
- **UNION ALL:** Three-dimension loss rate analysis in one result set
- **NULLIF:** Division-safe win rate calculations throughout
- **CAST AS FLOAT:** T-SQL-specific fix for integer division precision

---

## 📊 Power BI Dashboard

**4 pages · 18 DAX measures · Cross-page slicers**

### Page 1 — Overview
High-level snapshot for management.
- **KPI Cards:** Total Leads · Total Won · Win Rate (57.64%) · Open Pipeline ($1.91M) · Forecast M1 ($1.10M)
- **Funnel Chart:** Status distribution — Opportunity bottleneck (867 deals) visible
- **Donut Chart:** Stage breakdown filtered to active pipeline only
- **Line + Column:** Monthly trend Jan–May 2024 — volume bars + win rate line

### Page 2 — Pipeline & Market
Geographic and industry analysis for Sales strategy.
- **Bar Chart:** Industry win rate — IT Services (81%) vs Agriculture (22%)
- **Line + Column:** Country analysis — Belgium highest WR (73%), Austria lowest (40%)
- **Matrix:** Industry × Product win rate heatmap (conditional color formatting)
- **Line + Column:** Org size — Avg Won Deal + Win Rate by company size

### Page 3 — Agent Performance
Team analysis for coaching and deal assignment decisions.
- **Bar Chart:** Win rate by agent — Sarah Davis leads (72.7%), David Wilson last (33.3%)
- **Bar Chart:** Revenue by agent — Laura Thompson leads ($48K), different ranking reveals style difference
- **Clustered Column:** Deal duration Won (194d) vs Lost (239d)
- **Scatter Chart:** Probability calibration — bubble size = deals closed, X = expected %, Y = actual %

### Page 4 — Forecast & Risk
Forward-looking view for finance and Sales ops teams.
- **KPI Cards:** Forecast M1 ($1.10M) · Forecast M2 ($873K) · Spread ($228K) · Win Rate (58%)
- **Column Chart:** Three-method forecast comparison
- **Bar Chart:** Revenue at stake by risk score — Score 3 has largest exposure ($763K)
- **Bar Chart:** Loss rate by industry — Agriculture 78% most urgent exit signal

---

## 🛠️ Skills Demonstrated

| Area | What I Did |
|---|---|
| Data Cleaning | Date parsing, null analysis, type validation, feature derivation |
| Feature Engineering | Boolean flags, duration calculations, period grouping, ordered categorical |
| EDA & Visualization | 15+ chart types across 4 themes — funnel, heatmap, scatter, boxplot |
| SQL | 19 queries in SSMS — window functions, CTEs, CASE WHEN pivots, UNION ALL |
| DAX & Power BI | 18 DAX measures, calculated columns, cross-page slicers, conditional formatting |
| Forecasting | 3-method revenue forecast with calibration validation |
| Business Thinking | Root-cause analysis for lost deals, at-risk scoring model, agent coaching insights |

---

## 📁 Project Structure

```
CRM_Sales_Pipeline_Analytics/
├── data/
│   ├── CRM_and_Sales_Pipelines.xlsx       # Raw data (3,000 rows · 17 columns)
│   └── crm_cleaned_data.csv                       # Cleaned & feature-engineered export
├── notebook/
│   └── CRM_Analytics.ipynb               # Full Python analysis (9 sections)
├── sql/
│   └── crm_ssms_final.sql                # 19 T-SQL queries for SSMS
├── report/
│   └── CRM_Analytics.docx            # Word report with findings & recommendations
├── dashboard/
│   └── CRM_Analyst.pbix                  # Power BI dashboard (4 pages)
├── assets/
│   ├── overview.png                      # Page 1 screenshot
│   ├── pipeline_market.png               # Page 2 screenshot
│   ├── agent_performance.png             # Page 3 screenshot
│   └── forecast_risk.png                 # Page 4 screenshot
└── README.md
```

---

## 📂 Dataset

| | |
|---|---|
| Records | 3,000 B2B sales deals |
| Features | 17 original + 7 engineered = 24 total |
| Countries | 9 (Italy, France, Germany, Switzerland, Portugal, Belgium, Austria, Spain, Netherlands) |
| Industries | 14 |
| Sales Agents | 8 |
| Products | SAAS · Services · Custom Solution |
| Date Range | January 2024 – May 2024 |

---

## ▶️ How to Run

**1. Python notebook**
```
Open notebook/CRM_Analytics.ipynb in Jupyter or VS Code
Place CRM_and_Sales_Pipelines.xlsx in the same folder
Run All Cells (Sections 0–7)
Section 8 exports crm_data.csv
Section 9 imports to SQL Server (requires SSMS + ODBC Driver)
```

**2. SQL queries**
```
Open sql/crm_ssms_final.sql in SSMS
Run: CREATE DATABASE CRM_Analytics;
Import data via Section 9 of Python notebook
Select all queries → F5
```

**3. Power BI dashboard**
```
Open dashboard/CRM_Analyst.pbix in Power BI Desktop
Load crm_data.csv from /data folder
Refresh if prompted
Use Product and Country slicers to filter cross-page
```
