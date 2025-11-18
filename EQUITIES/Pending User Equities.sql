WITH pending_today AS (
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
      AND a.category = 'EQUITIES'
      AND a.data_status = 'PENDING'
      AND DATE(a.data_updated_at) = (
          CASE 
              -- If today is Sunday → take Friday’s data (2 days before)
              WHEN EXTRACT(ISODOW FROM CURRENT_DATE) = 7 THEN CURRENT_DATE - INTERVAL '1 day'
              -- If today is Monday → take Friday’s data (3 days before)
              WHEN EXTRACT(ISODOW FROM CURRENT_DATE) = 1 THEN CURRENT_DATE - INTERVAL '2 day'
              ELSE CURRENT_DATE
          END
      )
),
pending_yesterday AS (
    SELECT DISTINCT
        f.id AS user_id,
        a.fip_id,
        a.masked_account_number
    FROM finny_user f
    JOIN aa_account_data_status a
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE','IN_PROGRESS')
      AND a.category = 'EQUITIES'
      AND a.data_status = 'PENDING'
      AND DATE(a.data_updated_at) = (
          CASE 
              -- If yesterday is Sunday → use Friday (2 days before today)
              WHEN EXTRACT(ISODOW FROM CURRENT_DATE - INTERVAL '1 day') = 7 THEN CURRENT_DATE - INTERVAL '2 day'
              -- If yesterday is Monday → use Friday (3 days before today)
              WHEN EXTRACT(ISODOW FROM CURRENT_DATE - INTERVAL '1 day') = 1 THEN CURRENT_DATE - INTERVAL '3 day'
              ELSE CURRENT_DATE - INTERVAL '1 day'
          END
      )
),
pending_past_week AS (
    SELECT DISTINCT
        f.id AS user_id,
        a.fip_id,
        a.masked_account_number
    FROM finny_user f
    JOIN aa_account_data_status a
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE', 'IN_PROGRESS')
      AND a.category = 'EQUITIES'
      AND a.data_status = 'PENDING'
      -- Fetch data pending in the past 7 days (excluding today & yesterday)
      AND DATE(a.data_updated_at) >= CURRENT_DATE - INTERVAL '7 days'
      AND DATE(a.data_updated_at) < CURRENT_DATE - INTERVAL '1 day'


)
SELECT
    pt.user_id,
    pt.fip_id AS fip_pending_today,
    pt.masked_account_number AS account,
    CASE WHEN py.user_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS pending_yesterday,
    CASE WHEN ppw.user_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS pending_in_past_week
FROM pending_today pt
LEFT JOIN pending_yesterday py
  ON pt.user_id = py.user_id 
  AND pt.fip_id = py.fip_id 
  AND pt.masked_account_number = py.masked_account_number
LEFT JOIN pending_past_week ppw
  ON pt.user_id = ppw.user_id 
  AND pt.fip_id = ppw.fip_id 
  AND pt.masked_account_number = ppw.masked_account_number
ORDER BY pt.user_id, pt.fip_id, pt.masked_account_number;
