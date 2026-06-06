
SELECT
    COUNT(*) AS total_rows,
    SUM(is_won) AS won,
    SUM(is_lost) AS lost,
    SUM(is_open) AS open_deals,
    SUM(is_closed) AS closed
FROM dbo.crm_deals;

-- 1. EDA — Phân bổ cơ bản
-- 1.1 Status distribution
SELECT
    Status,
    COUNT(*) AS cnt,
    ROUND(CAST(COUNT(*) AS FLOAT) * 100
          / (SELECT COUNT(*) FROM dbo.crm_deals), 1) AS pct
FROM dbo.crm_deals
GROUP BY Status
ORDER BY cnt DESC;
-- 1.2 Stage distribution
SELECT
    Stage,
    COUNT(*) AS cnt,
    ROUND(CAST(COUNT(*) AS FLOAT) * 100
          / (SELECT COUNT(*) FROM dbo.crm_deals WHERE Stage IS NOT NULL), 1) AS pct
FROM dbo.crm_deals
WHERE Stage IS NOT NULL
GROUP BY Stage
ORDER BY cnt DESC;
-- 1.3 Categorical breakdown
SELECT
    Product,
    [Organization_size],
    COUNT(*) AS cnt,
    ROUND(AVG(CAST([Deal_Value_USD] AS FLOAT)), 0) AS avg_deal_value
FROM dbo.crm_deals
GROUP BY Product, [Organization_size]
ORDER BY Product, cnt DESC;

-- 2. PIPELINE HEALTH
-- 2.1 Funnel conversion — tim bottleneck
WITH funnel AS (
    SELECT
        COUNT(*) AS total_leads,
        SUM(CASE WHEN Status IN ('Qualified','Sales Accepted',
                                 'Opportunity','Customer')
                 THEN 1 ELSE 0 END) AS qualified,
        SUM(CASE WHEN Status = 'Opportunity'
                 THEN 1 ELSE 0 END) AS opportunity,
        SUM(is_closed) AS closed,
        SUM(is_won) AS won
    FROM dbo.crm_deals
)
SELECT
    total_leads,
    qualified,
    opportunity,
    closed,
    won,
    ROUND(CAST(qualified   AS FLOAT) * 100.0 / total_leads,  1) AS lead_to_qual_pct,
    ROUND(CAST(opportunity AS FLOAT) * 100.0 / qualified,    1) AS qual_to_opp_pct,
    ROUND(CAST(closed AS FLOAT) * 100.0 / opportunity,  1) AS opp_to_closed_pct,
    ROUND(CAST(won  AS FLOAT) * 100.0 / closed,       1) AS closed_to_won_pct,
    ROUND(CAST(won AS FLOAT) * 100.0 / total_leads,  2) AS overall_conv_pct
FROM funnel;


-- 2.2 Industry win rate
SELECT
    Industry,
    COUNT(*)  AS closed_deals,
    SUM(is_won) AS won,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0/ NULLIF(SUM(is_closed), 0), 1)  AS win_rate_pct,

    ROUND(AVG(CAST([Deal_Value_USD] AS FLOAT)), 0) AS avg_deal_value,
    ROUND(SUM(CASE WHEN is_won=1 THEN [Deal_Value_USD] ELSE 0 END), 0) AS total_won_revenue
FROM dbo.crm_deals
WHERE is_closed = 1
GROUP BY Industry
ORDER BY win_rate_pct DESC;

-- 2.3 Country analysis

SELECT
    Country,
    COUNT(*) AS total_leads,
    SUM(is_won) AS won,
    SUM(is_closed)AS closed,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0/ NULLIF(SUM(is_closed), 0), 1)  AS win_rate_pct,
    ROUND(AVG(CAST([Deal_Value_USD] AS FLOAT)), 0)  AS avg_deal_value
FROM dbo.crm_deals
GROUP BY Country
ORDER BY total_leads DESC;


-- 2.4 Monthly trend
SELECT
    lead_month,
    COUNT(*)  AS total_leads,
    SUM(is_won) AS won,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0/ NULLIF(SUM(is_closed), 0), 1)  AS win_rate_pct,
    ROUND(AVG(CAST([Deal_Value_USD] AS FLOAT)), 0)  AS avg_deal_value
FROM dbo.crm_deals
WHERE lead_month IS NOT NULL
GROUP BY lead_month
ORDER BY lead_month;

-- 3. AGENT PERFORMANCE
-- 3.1 Agent scorecard
SELECT
    Owner  AS agent,
    COUNT(*)  AS closed_deals,
    SUM(is_won) AS won,
    SUM(is_lost) AS lost,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0/ NULLIF(SUM(is_closed), 0), 1)  AS win_rate_pct,
    ROUND(SUM(CASE WHEN is_won=1 THEN [Deal_Value_USD] ELSE 0 END), 0) AS total_revenue,
    ROUND(AVG(CASE WHEN is_won=1 THEN CAST([Deal_Value_USD] AS FLOAT) END), 0) AS avg_won_deal,
    ROUND(AVG(CAST(deal_duration_days AS FLOAT)), 0) AS avg_duration_days
FROM dbo.crm_deals
WHERE is_closed = 1
GROUP BY Owner
ORDER BY win_rate_pct DESC;


-- 3.2 Deal duration: Won vs Lost
WITH MedianData AS (
    SELECT 
        CASE WHEN is_won = 1 THEN 'Won' ELSE 'Lost' END AS outcome,
        deal_duration_days,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY deal_duration_days) 
                             OVER (PARTITION BY CASE WHEN is_won = 1 THEN 'Won' ELSE 'Lost' END) AS median_days
    FROM dbo.crm_deals
    WHERE is_closed = 1 AND deal_duration_days IS NOT NULL
)
SELECT 
    outcome,
    COUNT(*) AS deals,
    ROUND(AVG(CAST(deal_duration_days AS FLOAT)), 0) AS avg_days,
    MIN(deal_duration_days) AS min_days,
    MAX(deal_duration_days) AS max_days,
    ROUND(MAX(median_days), 0) AS median_days -- Dùng MAX để lấy median ra khỏi Group By
FROM MedianData
GROUP BY outcome;

-- 3.3 Close date accuracy by agent
WITH MedianData AS (
    SELECT 
        Owner,
        close_delay_days,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY close_delay_days) 
                             OVER (PARTITION BY Owner) AS median_delay
    FROM dbo.crm_deals
    WHERE close_delay_days IS NOT NULL
)
SELECT 
    Owner,
    COUNT(*) AS deals,
    ROUND(AVG(CAST(close_delay_days AS FLOAT)), 0) AS avg_delay_days,
    ROUND(MAX(median_delay), 0) AS median_delay, 
    SUM(CASE WHEN close_delay_days < 0 THEN 1 ELSE 0 END) AS closed_early,
    ROUND(CAST(SUM(CASE WHEN close_delay_days < 0 THEN 1 ELSE 0 END) AS FLOAT) * 100.0 / COUNT(*), 1)

FROM MedianData
GROUP BY Owner
ORDER BY avg_delay_days ASC;


-- 3.4 Probability calibration
SELECT
    FLOOR([Probability_pct] / 10) * 10  AS prob_bucket,
    COUNT(*) AS deals,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0 / COUNT(*), 1) AS actual_win_rate,
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0 / COUNT(*) 
    - FLOOR([Probability_pct] / 10) * 10, 1) AS calibration_gap
FROM dbo.crm_deals
WHERE is_closed = 1 AND [Probability_pct] IS NOT NULL
GROUP BY FLOOR([Probability_pct] / 10) * 10
ORDER BY prob_bucket;


-- 4. FORECAST — Du bao doanh thu
-- 4.1 3-method forecast
WITH hist AS (
    SELECT
        CAST(SUM(is_won) AS FLOAT)
        / NULLIF(SUM(is_closed), 0) AS win_rate
    FROM dbo.crm_deals
),
open_pipe AS (
    SELECT
        COUNT(*) AS open_deals,
        SUM(CAST([Deal_Value_USD] AS FLOAT)) AS pipeline_value,
        SUM(CAST([Deal_Value_USD] AS FLOAT)
            * [Probability_pct] / 100.0)  AS prob_weighted
    FROM dbo.crm_deals
    WHERE is_open = 1
)
SELECT
    o.open_deals,
    ROUND(o.pipeline_value, 0) AS open_pipeline,
    ROUND(h.win_rate * 100, 1) AS hist_win_rate_pct,
    ROUND(o.pipeline_value * h.win_rate, 0) AS forecast_m1_flat,
    ROUND(o.prob_weighted, 0)  AS forecast_m2_prob,
    ABS(ROUND(o.pipeline_value * h.win_rate, 0)
        - ROUND(o.prob_weighted, 0))  AS m1_m2_spread
FROM open_pipe o
CROSS JOIN hist h;


-- 5. LOST ANALYSIS
-- 5.1 Loss rate theo Industry, Product, Country (UNION ALL)
SELECT 'Industry' AS dimension, Industry AS value,
    SUM(is_lost)  AS lost,
    SUM(is_closed) AS closed,
    -- Đã sửa: Bỏ CAST thừa ở khối 1
    ROUND(SUM(is_lost) * 100.0 / NULLIF(SUM(is_closed), 0), 1) AS loss_rate_pct
FROM dbo.crm_deals WHERE is_closed = 1
GROUP BY Industry

UNION ALL

SELECT 'Product', Product,
    SUM(is_lost), SUM(is_closed),
    ROUND(CAST(SUM(is_lost) AS FLOAT) * 100.0
      / NULLIF(SUM(is_closed), 0), 1) AS loss_rate_pct
FROM dbo.crm_deals WHERE is_closed = 1
GROUP BY Product

UNION ALL

SELECT 'Country', Country,
    SUM(is_lost), SUM(is_closed),
    -- Đã sửa: Bỏ CAST thừa ở khối 3
    ROUND(SUM(is_lost) * 100.0 / NULLIF(SUM(is_closed), 0), 1)
FROM dbo.crm_deals WHERE is_closed = 1
GROUP BY Country

ORDER BY dimension, loss_rate_pct DESC;

-- 5.2 Win rate heatmap: Industry x Product (manual pivot)
SELECT
    Industry,
    
    -- Win rate cho SAAS (làm tròn 1 chữ số thập phân)
    ROUND(CAST(SUM(CASE WHEN Product='SAAS' AND is_closed=1 
                        THEN is_won END) AS FLOAT) * 100.0 
          / NULLIF(SUM(CASE WHEN Product='SAAS' 
                            AND is_closed=1 THEN 1 END), 0), 1) AS SAAS_wr,
                            
    -- Win rate cho Services (làm tròn 1 chữ số thập phân)
    ROUND(CAST(SUM(CASE WHEN Product='Services' AND is_closed=1 
                        THEN is_won END) AS FLOAT) * 100.0 
          / NULLIF(SUM(CASE WHEN Product='Services' 
                            AND is_closed=1 THEN 1 END), 0), 1) AS Services_wr,
                            
    -- Win rate cho Custom solution (làm tròn 1 chữ số thập phân)
    ROUND(CAST(SUM(CASE WHEN Product='Custom solution' AND is_closed=1 
                        THEN is_won END) AS FLOAT) * 100.0 
          / NULLIF(SUM(CASE WHEN Product='Custom solution' 
                            AND is_closed=1 THEN 1 END), 0), 1) AS Custom_wr,
                            
    -- Overall win rate
    ROUND(CAST(SUM(is_won) AS FLOAT) * 100.0 
          / NULLIF(SUM(is_closed), 0), 1) AS overall_wr,
          
    SUM(is_closed) AS total_closed
FROM dbo.crm_deals
GROUP BY Industry
HAVING SUM(is_closed) >= 3
ORDER BY overall_wr DESC;

-- 6. WINDOW FUNCTIONS — T-SQL Advanced

-- 6.1 Running revenue + 3-month rolling average
WITH monthly AS (
    SELECT
        lead_month,
        COUNT(*)    AS leads,
        SUM(is_won) AS won,
        ROUND(SUM(CASE WHEN is_won=1
                       THEN CAST([Deal_Value_USD] AS FLOAT)
                       ELSE 0 END), 0)                               AS revenue
    FROM dbo.crm_deals
    WHERE lead_month IS NOT NULL
    GROUP BY lead_month
)
SELECT
    lead_month,
    leads,
    won,
    revenue,
    -- Running total tu dau den hien tai
    SUM(revenue) OVER (
        ORDER BY lead_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_rev,
    -- 3-month rolling average
    ROUND(AVG(CAST(revenue AS FLOAT)) OVER (
        ORDER BY lead_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 0)   AS rev_3mo_avg,
    
  ROUND(
    CAST(SUM(won) OVER (ORDER BY lead_month 
                        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS FLOAT) * 100.0
    / NULLIF(SUM(leads) OVER (ORDER BY lead_month 
                              ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0)
, 1) AS win_rate_3mo
FROM monthly
ORDER BY lead_month;

-- 6.2 Agent ranking voi RANK() va LAG()
WITH agent_monthly AS (
    SELECT
        Owner,
        lead_month,
        SUM(is_won) AS won,
        ROUND(SUM(CASE WHEN is_won=1
                       THEN CAST([Deal_Value_USD] AS FLOAT)
                       ELSE 0 END), 0)                               AS revenue
    FROM dbo.crm_deals
    WHERE lead_month IS NOT NULL
    GROUP BY Owner, lead_month
)
SELECT
    Owner,
    lead_month,
    won,
    revenue,
    -- Xep hang trong thang (ai ban nhieu nhat thang do?)
    RANK() OVER (PARTITION BY lead_month ORDER BY revenue DESC) AS rank_in_month,
    -- Doanh thu thang truoc cua cung agent
    LAG(revenue) OVER (PARTITION BY Owner ORDER BY lead_month) AS prev_month_rev,
    -- % thay doi so voi thang truoc (MoM growth)
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY Owner ORDER BY lead_month))
        * 100.0
        / NULLIF(LAG(revenue) OVER (PARTITION BY Owner ORDER BY lead_month), 0)
    , 1)  AS mom_growth_pct
FROM agent_monthly
ORDER BY lead_month, rank_in_month;

-- 6.3 At-risk deals — deals dang mo co nguy co thua
WITH risk AS (
    SELECT
        Organization AS company,
        Owner AS agent,
        Industry,
        Stage,
        CAST([Deal_Value_USD] AS FLOAT)  AS deal_value,
        deal_duration_days,
        CAST([Probability_pct] AS FLOAT) AS probability,
        
        -- Rule-based risk score
          CASE WHEN deal_duration_days > 180 THEN 2 ELSE 0 END
        + CASE WHEN [Probability_pct] < 40   THEN 2 ELSE 0 END
        + CASE WHEN Stage = 'Initial contact' THEN 1 ELSE 0 END
        + CASE WHEN Stage = 'Nurturing'       THEN 1 ELSE 0 END AS risk_score
        
    FROM dbo.crm_deals
    WHERE is_open = 1
)
SELECT
    risk_score, -- Đã sửa: Thêm dấu phẩy bị thiếu ở đây
    COUNT(*)  AS deals_at_risk,
    ROUND(AVG(deal_value), 0)   AS avg_deal_value,
    ROUND(SUM(deal_value), 0)    AS revenue_at_stake,
    ROUND(AVG(probability), 1)   AS avg_probability,
    ROUND(AVG(CAST(deal_duration_days AS FLOAT)), 0) AS avg_days_open
FROM risk
GROUP BY risk_score
ORDER BY risk_score DESC;