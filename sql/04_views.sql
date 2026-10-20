-- =============================================================
-- 04_views.sql  |  reusable building blocks (also great as Power BI sources)
-- =============================================================

-- One row per workout with the metrics that actually compare across exercises.
--   volume  = weight x reps
--   est_1rm = Epley estimated one-rep max = weight x (1 + reps / 30)
CREATE VIEW vw_workout_metrics AS
SELECT  w.workout_id,
        w.member_id,
        m.name,
        m.gender,
        m.goal,
        m.experience_level,
        w.workout_date,
        w.exercise,
        w.weight_lifted,
        w.reps,
        w.weight_lifted * w.reps                 AS volume,
        w.weight_lifted * (1 + w.reps / 30.0)    AS est_1rm
FROM Workouts w
JOIN Members  m ON m.member_id = w.member_id;

-- Workout + same-day nutrition (LEFT JOIN: keeps workouts with no nutrition log).
CREATE VIEW vw_workout_nutrition AS
SELECT  v.*,
        n.calories,
        n.protein_g
FROM vw_workout_metrics v
LEFT JOIN Nutrition_Members n
       ON n.member_id = v.member_id AND n.log_date = v.workout_date;

-- First vs latest estimated 1RM per member + exercise (needs >= 3 sessions to be meaningful).
CREATE VIEW vw_member_exercise_progress AS
WITH ranked AS (
    SELECT  member_id, exercise, workout_date, est_1rm,
            ROW_NUMBER() OVER (PARTITION BY member_id, exercise ORDER BY workout_date ASC,  workout_id ASC)  AS rn_first,
            ROW_NUMBER() OVER (PARTITION BY member_id, exercise ORDER BY workout_date DESC, workout_id DESC) AS rn_last,
            COUNT(*)     OVER (PARTITION BY member_id, exercise)                                              AS sessions
    FROM vw_workout_metrics
)
SELECT  f.member_id,
        f.exercise,
        f.sessions,
        f.est_1rm                                                  AS first_1rm,
        l.est_1rm                                                  AS latest_1rm,
        l.est_1rm - f.est_1rm                                      AS gain_1rm,
        ROUND(100.0 * (l.est_1rm - f.est_1rm) / f.est_1rm, 1)      AS improvement_pct
FROM ranked f
JOIN ranked l ON l.member_id = f.member_id AND l.exercise = f.exercise
WHERE f.rn_first = 1 AND l.rn_last = 1 AND f.sessions >= 3;

-- One row per member: attendance, nutrition averages, average strength improvement.
CREATE VIEW vw_member_summary AS
SELECT  m.member_id,
        m.name,
        m.gender,
        m.goal,
        m.experience_level,
        COALESCE(w.sessions, 0)             AS sessions,
        w.total_volume,
        n.avg_calories,
        n.avg_protein_g,
        p.avg_improvement_pct
FROM Members m
LEFT JOIN (SELECT member_id, COUNT(*) AS sessions, SUM(volume) AS total_volume
           FROM vw_workout_metrics GROUP BY member_id) w ON w.member_id = m.member_id
LEFT JOIN (SELECT member_id, AVG(calories * 1.0) AS avg_calories, AVG(protein_g * 1.0) AS avg_protein_g
           FROM Nutrition_Members GROUP BY member_id) n ON n.member_id = m.member_id
LEFT JOIN (SELECT member_id, AVG(improvement_pct) AS avg_improvement_pct
           FROM vw_member_exercise_progress GROUP BY member_id) p ON p.member_id = m.member_id;
