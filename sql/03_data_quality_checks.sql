-- =============================================================
-- 03_data_quality_checks.sql  |  every check should return 0 rows / 0
-- =============================================================

-- 1) Workouts without a matching member (orphans)
SELECT COUNT(*) AS orphan_workouts
FROM Workouts w LEFT JOIN Members m ON m.member_id = w.member_id
WHERE m.member_id IS NULL;

-- 2) Nutrition logs without a matching member
SELECT COUNT(*) AS orphan_nutrition
FROM Nutrition_Members n LEFT JOIN Members m ON m.member_id = n.member_id
WHERE m.member_id IS NULL;

-- 3) Same member + exercise + day logged twice
SELECT member_id, workout_date, exercise, COUNT(*) AS times_logged
FROM Workouts
GROUP BY member_id, workout_date, exercise
HAVING COUNT(*) > 1;

-- 4) Implausible values
SELECT workout_id, weight_lifted, reps
FROM Workouts
WHERE weight_lifted > 400 OR reps > 50;

SELECT nutrition_id, calories, protein_g
FROM Nutrition_Members
WHERE calories NOT BETWEEN 1000 AND 6000 OR protein_g > 400;

-- 5) Coverage: workouts that have NO nutrition log that day (expected, but worth knowing)
SELECT COUNT(*) AS workouts_without_nutrition
FROM Workouts w
LEFT JOIN Nutrition_Members n ON n.member_id = w.member_id AND n.log_date = w.workout_date
WHERE n.nutrition_id IS NULL;
