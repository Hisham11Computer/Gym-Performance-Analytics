-- =============================================================
-- 05_analysis_queries.sql  |  business questions answered with SQL
-- Requires: 01_schema, 02_seed_data, 04_views
-- =============================================================

-- Q1. Headline KPIs
SELECT  COUNT(*)                         AS total_workouts,
        COUNT(DISTINCT member_id)        AS active_members,
        ROUND(SUM(volume), 0)            AS total_volume_kg,
        ROUND(AVG(est_1rm), 1)           AS avg_est_1rm
FROM vw_workout_metrics;

-- Q2. Which exercises are done most, and how heavy are they? (replaces plain COUNT per exercise)
SELECT  exercise,
        COUNT(*)                         AS times_done,
        ROUND(AVG(weight_lifted), 1)     AS avg_weight_kg,
        ROUND(AVG(volume), 0)            AS avg_volume,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS popularity_rank
FROM vw_workout_metrics
GROUP BY exercise
ORDER BY times_done DESC;

-- Q3. Top 10 members by average strength improvement (% gain in estimated 1RM)
SELECT  member_id, name, goal, experience_level, sessions, ROUND(avg_improvement_pct, 1) AS avg_improvement_pct,
        RANK() OVER (ORDER BY avg_improvement_pct DESC) AS rnk
FROM vw_member_summary
WHERE avg_improvement_pct IS NOT NULL
ORDER BY avg_improvement_pct DESC
LIMIT 10;                       -- SQL Server: use SELECT TOP 10 ...

-- Q4. Bulk vs Cut: who progresses more, and on how many calories?
SELECT  goal,
        COUNT(*)                                AS members,
        ROUND(AVG(avg_improvement_pct), 1)      AS avg_improvement_pct,
        ROUND(AVG(avg_calories), 0)             AS avg_calories,
        ROUND(AVG(avg_protein_g), 0)            AS avg_protein_g,
        ROUND(AVG(sessions), 1)                 AS avg_sessions
FROM vw_member_summary
WHERE avg_improvement_pct IS NOT NULL
GROUP BY goal;

-- Q5. Do calories drive performance? Pearson correlation computed per goal
--     (split by goal because bulkers eat more AND train differently - mixing them would mislead).
WITH d AS (
    SELECT goal, avg_calories AS x, avg_improvement_pct AS y
    FROM vw_member_summary
    WHERE avg_calories IS NOT NULL AND avg_improvement_pct IS NOT NULL
), s AS (
    SELECT goal, COUNT(*) AS n, SUM(x) AS sx, SUM(y) AS sy,
           SUM(x * y) AS sxy, SUM(x * x) AS sxx, SUM(y * y) AS syy
    FROM d GROUP BY goal
)
SELECT  goal,
        n AS members,
        ROUND((n * sxy - sx * sy) /
              SQRT((n * sxx - sx * sx) * (n * syy - sy * sy)), 2) AS correlation_calories_vs_improvement
FROM s;

-- Q6. Improvement by calorie band
SELECT  calorie_band,
        COUNT(*)                            AS members,
        ROUND(AVG(avg_improvement_pct), 1)  AS avg_improvement_pct
FROM (
    SELECT avg_improvement_pct,
           CASE WHEN avg_calories < 2200 THEN '1) < 2200 kcal'
                WHEN avg_calories < 2600 THEN '2) 2200-2599 kcal'
                WHEN avg_calories < 3000 THEN '3) 2600-2999 kcal'
                ELSE                          '4) 3000+ kcal' END AS calorie_band
    FROM vw_member_summary
    WHERE avg_calories IS NOT NULL AND avg_improvement_pct IS NOT NULL
) t
GROUP BY calorie_band
ORDER BY calorie_band;

-- Q7. Consistency: does attending more mean progressing more?
SELECT  attendance_group,
        COUNT(*)                            AS members,
        ROUND(AVG(avg_improvement_pct), 1)  AS avg_improvement_pct
FROM (
    SELECT avg_improvement_pct,
           CASE WHEN sessions >= 30 THEN 'High (30+ sessions)'
                WHEN sessions >= 20 THEN 'Medium (20-29)'
                ELSE                      'Low (<20)' END AS attendance_group
    FROM vw_member_summary
    WHERE avg_improvement_pct IS NOT NULL
) t
GROUP BY attendance_group
ORDER BY avg_improvement_pct DESC;

-- Q8. Churn risk: members not seen in the last 6 gym days of the dataset
--     (DENSE_RANK over distinct dates keeps this portable - no date arithmetic needed)
WITH days AS (
    SELECT DISTINCT workout_date, DENSE_RANK() OVER (ORDER BY workout_date DESC) AS day_rank
    FROM Workouts
), last_seen AS (
    SELECT member_id, MAX(workout_date) AS last_workout, COUNT(*) AS total_sessions
    FROM Workouts GROUP BY member_id
)
SELECT  m.member_id, m.name, m.goal, ls.last_workout, ls.total_sessions
FROM last_seen ls
JOIN Members m ON m.member_id = ls.member_id
WHERE ls.last_workout NOT IN (SELECT workout_date FROM days WHERE day_rank <= 6)
ORDER BY ls.last_workout;

-- Q9. Session-by-session progression for one member (LAG = change vs previous session of the same lift)
SELECT  workout_date, exercise, weight_lifted, reps,
        ROUND(est_1rm, 1) AS est_1rm,
        ROUND(est_1rm - LAG(est_1rm) OVER (PARTITION BY member_id, exercise ORDER BY workout_date), 1) AS change_vs_prev
FROM vw_workout_metrics
WHERE member_id = 1
ORDER BY exercise, workout_date;

-- Q10. Personal records: best estimated 1RM per member + lift (top row of each partition)
WITH pr AS (
    SELECT member_id, name, exercise, workout_date, weight_lifted, reps, ROUND(est_1rm, 1) AS est_1rm,
           ROW_NUMBER() OVER (PARTITION BY member_id, exercise ORDER BY est_1rm DESC) AS rn
    FROM vw_workout_metrics
)
SELECT member_id, name, exercise, workout_date AS pr_date, weight_lifted, reps, est_1rm
FROM pr WHERE rn = 1
ORDER BY est_1rm DESC
LIMIT 15;                       -- SQL Server: SELECT TOP 15 ...
