# Data Dictionary

## Members
| Column | Type | Description |
|---|---|---|
| member_id | INT (PK) | Unique member id |
| name | VARCHAR(50) | First name |
| gender | CHAR(1) | `M` / `F` |
| age | INT | Age in years (14–80) |
| weight_kg | DECIMAL(5,1) | Body weight in kg |
| goal | VARCHAR(10) | `bulk` or `cut` |
| experience_level | VARCHAR(15) | `beginner`, `intermediate`, `advanced` |

## Workouts (one row = one lift in one session)
| Column | Type | Description |
|---|---|---|
| workout_id | INT (PK) | Unique id |
| member_id | INT (FK → Members) | Who trained |
| workout_date | DATE | Session date |
| exercise | VARCHAR(50) | Bench Press, Squat, Deadlift, Overhead Press, Barbell Row |
| weight_lifted | DECIMAL(5,1) | Working-set weight in kg |
| reps | INT | Repetitions in that set |

## Nutrition_Members (one row = one member-day)
| Column | Type | Description |
|---|---|---|
| nutrition_id | INT (PK) | Unique id |
| member_id | INT (FK → Members) | Member |
| log_date | DATE | Day logged (unique per member) |
| calories | INT | Total kcal that day |
| protein_g | INT | Protein in grams |

## Derived metrics
| Metric | Formula |
|---|---|
| volume | weight_lifted × reps |
| est_1rm (Epley) | weight_lifted × (1 + reps / 30) |
| improvement_pct | (latest e1RM − first e1RM) / first e1RM × 100, per member + exercise, ≥ 3 sessions |

## Changes from the original schema
`id` → `member_id` / `workout_id` / `nutrition_id` · `date` → `workout_date` / `log_date` (`date` is a reserved word) · `weight` → `weight_kg` · `protein` → `protein_g` · added `gender`, `experience_level`, primary/foreign keys, CHECK and UNIQUE constraints.
