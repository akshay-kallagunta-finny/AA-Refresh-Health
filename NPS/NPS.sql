WITH user_fip_status AS (
    SELECT 
        f.id AS user_id,
        a.fip_id,
        a.data_status,          -- plain text column
        a.data_updated_at AS updated_at
    FROM finny_user f
    JOIN aa_account_data_status a
      ON f.id = a.user_id
    WHERE f.status IN ('ACTIVE', 'IN_PROGRESS')
      AND a.category = 'NPS'
      AND DATE(a.data_updated_at) = CURRENT_DATE  -- only today's data
),
user_fip_final_status AS (
    SELECT
        user_id,
        fip_id,
        MAX(updated_at) AS last_updated,
        -- Assign each user one final status based on priority
        CASE 
            WHEN BOOL_OR(data_status = 'DENIED') THEN 'DENIED'
            WHEN BOOL_OR(data_status = 'TIMEOUT') THEN 'TIMEOUT'
            WHEN BOOL_OR(data_status = 'DATA_NOT_RETURNED_IN_TIME') THEN 'DATA_NOT_RETURNED_IN_TIME'
            WHEN BOOL_OR(data_status = 'PENDING') THEN 'PENDING'
            WHEN BOOL_OR(data_status = 'COMPLETED') THEN 'COMPLETED'
            ELSE 'UNKNOWN'
        END AS final_status
    FROM user_fip_status
    GROUP BY user_id, fip_id
),
fip_totals AS (
    SELECT 
        fip_id,
        COUNT(*) AS total_users
    FROM user_fip_final_status
    GROUP BY fip_id
),
fip_last_updated AS (
    SELECT 
        fip_id,
        MAX(last_updated) AS last_updated
    FROM user_fip_final_status
    GROUP BY fip_id
)
SELECT
    f.fip_id,

    --  COMPLETED
    CASE 
        WHEN COUNT(CASE WHEN final_status = 'COMPLETED' THEN 1 END) = 0 
        THEN '-'
        ELSE CONCAT(
            COUNT(CASE WHEN final_status = 'COMPLETED' THEN 1 END),
            ' (',
            ROUND(100.0 * COUNT(CASE WHEN final_status = 'COMPLETED' THEN 1 END) / t.total_users),
            '%)'
        )
    END AS data_is_fetched,

    --  DENIED
    CASE 
        WHEN COUNT(CASE WHEN final_status = 'DENIED' THEN 1 END) = 0 
        THEN '-'
        ELSE CONCAT(
            COUNT(CASE WHEN final_status = 'DENIED' THEN 1 END),
            ' (',
            ROUND(100.0 * COUNT(CASE WHEN final_status = 'DENIED' THEN 1 END) / t.total_users),
            '%)'
        )
    END AS data_is_rejected,

    --  PENDING
    CASE 
        WHEN COUNT(CASE WHEN final_status = 'PENDING' THEN 1 END) = 0 
        THEN '-'
        ELSE CONCAT(
            COUNT(CASE WHEN final_status = 'PENDING' THEN 1 END),
            ' (',
            ROUND(100.0 * COUNT(CASE WHEN final_status = 'PENDING' THEN 1 END) / t.total_users),
            '%)'
        )
    END AS pending,

    --  TIMEOUT
    CASE 
        WHEN COUNT(CASE WHEN final_status = 'TIMEOUT' THEN 1 END) = 0 
        THEN '-'
        ELSE CONCAT(
            COUNT(CASE WHEN final_status = 'TIMEOUT' THEN 1 END),
            ' (',
            ROUND(100.0 * COUNT(CASE WHEN final_status = 'TIMEOUT' THEN 1 END) / t.total_users),
            '%)'
        )
    END AS timeout,

    --  DATA_NOT_RETURNED_IN_TIME
    CASE 
        WHEN COUNT(CASE WHEN final_status = 'DATA_NOT_RETURNED_IN_TIME' THEN 1 END) = 0 
        THEN '-'
        ELSE CONCAT(
            COUNT(CASE WHEN final_status = 'DATA_NOT_RETURNED_IN_TIME' THEN 1 END),
            ' (',
            ROUND(100.0 * COUNT(CASE WHEN final_status = 'DATA_NOT_RETURNED_IN_TIME' THEN 1 END) / t.total_users),
            '%)'
        )
    END AS data_not_returned,

    t.total_users,
    DATE(l.last_updated) AS last_updated

FROM user_fip_final_status f
JOIN fip_totals t ON f.fip_id = t.fip_id
JOIN fip_last_updated l ON f.fip_id = l.fip_id
GROUP BY f.fip_id, t.total_users, DATE(l.last_updated)
ORDER BY t.total_users DESC;
