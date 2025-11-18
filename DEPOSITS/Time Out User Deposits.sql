WITH denied_today AS (
    SELECT DISTINCT
        f.id AS user_id,
        a.fip_id,
        a.masked_account_number,
        a.link_ref_number,
        DATE(a.data_updated_at) AS updated_date
    FROM finny_user f
    JOIN aa_account_data_status a 
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE','IN_PROGRESS')
      AND a.category = 'DEPOSITS'
      AND a.data_status = 'TIMEOUT'
      AND DATE(a.data_updated_at) = CURRENT_DATE
),
denied_yesterday AS (
    SELECT DISTINCT
        f.id AS user_id,
        a.fip_id,
        a.masked_account_number
    FROM finny_user f
    JOIN aa_account_data_status a
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE','IN_PROGRESS')
      AND a.category = 'DEPOSITS'
      AND a.data_status = 'TIMEOUT'
      AND DATE(a.data_updated_at) = CURRENT_DATE - INTERVAL '1 day'
),
denied_past_week AS (
    SELECT DISTINCT
        f.id AS user_id,
        a.fip_id,
        a.masked_account_number
    FROM finny_user f
    JOIN aa_account_data_status a
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE','IN_PROGRESS')
      AND a.category = 'DEPOSITS'
      AND a.data_status = 'TIMEOUT'
      AND DATE(a.data_updated_at) >= CURRENT_DATE - INTERVAL '7 days'
      AND DATE(a.data_updated_at) < CURRENT_DATE - INTERVAL '1 day'  -- exclude today and yesterday
)
SELECT
    dt.user_id,
    dt.fip_id AS fip_timeout_today,
    dt.masked_account_number AS account,
    
    CASE WHEN dy.user_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS timeout_yesterday,
    CASE WHEN dpw.user_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS timeout_in_past_week
FROM denied_today dt
LEFT JOIN denied_yesterday dy
  ON dt.user_id = dy.user_id 
  AND dt.fip_id = dy.fip_id 
  AND dt.masked_account_number = dy.masked_account_number
LEFT JOIN denied_past_week dpw
  ON dt.user_id = dpw.user_id 
  AND dt.fip_id = dpw.fip_id 
  AND dt.masked_account_number = dpw.masked_account_number
ORDER BY dt.user_id, dt.fip_id, dt.masked_account_number;
