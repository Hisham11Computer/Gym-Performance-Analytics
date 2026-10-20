# Power BI Guide

## 1. Fix the model first
**Import:** `Members`, `Workouts`, `Nutrition_Members`, plus the views `vw_member_summary` and `vw_member_exercise_progress`.
**Add a date table:** `Date = CALENDAR(MIN(Workouts[workout_date]), MAX(Workouts[workout_date]))`

**Relationships (all one-to-many, single direction):**
- `Members[member_id]` → `Workouts[member_id]`
- `Members[member_id]` → `Nutrition_Members[member_id]`
- `Date[Date]` → `Workouts[workout_date]` and `Nutrition_Members[log_date]`

**Never relate Workouts to Nutrition directly.** In the current dashboard the table shows Ahmed with 24,000 calories, but his real total is 9,000 (2,800 + 3,000 + 3,200), and several members show blank calories. That pattern points to a bad relationship/filter path. Always go through `Members` and `Date`.

## 2. DAX measures
```DAX
Total Workouts   = COUNTROWS(Workouts)
Active Members   = DISTINCTCOUNT(Workouts[member_id])
Total Volume     = SUMX(Workouts, Workouts[weight_lifted] * Workouts[reps])
Avg Est 1RM      = AVERAGEX(Workouts, Workouts[weight_lifted] * (1 + Workouts[reps] / 30))
Avg Calories     = AVERAGE(Nutrition_Members[calories])
Avg Protein      = AVERAGE(Nutrition_Members[protein_g])
Sessions / Member = DIVIDE([Total Workouts], [Active Members])
Avg Improvement % = DIVIDE(AVERAGE(vw_member_exercise_progress[improvement_pct]), 100)   -- format as %
```

## 3. Issues in the first version
| Problem | Fix |
|---|---|
| "Average weight lifted" mixes bench, squat and deadlift | Use **Avg Est 1RM** or **Total Volume**, or split by exercise |
| `Sum of weight_lifted` / `Sum of reps` in the table | Meaningless totals — replace with volume and e1RM |
| Scatter chart has only 5 points | Use the 44-member data set with one point per member, coloured by goal |
| "Best Exercises" chart counts workouts | Rename to **Most Performed Exercises** |
| Goal slicer (bulk / cut) collapsed and hard to read | Use a visible tile slicer on every page |
| No titles/units, inconsistent colours | Add titles with units, one colour palette, consistent fonts |

## 4. Suggested pages
1. **Overview** — KPI cards (Workouts, Active Members, Total Volume, Avg e1RM), weekly volume trend, exercise popularity, goal slicer.
2. **Member Performance** — top 10 by Avg Improvement %, member drill-through (session-by-session e1RM line), personal-records table.
3. **Nutrition vs Performance** — scatter: Avg Calories (x) vs Avg Improvement % (y) coloured by goal with a trend line; calorie-band column chart.
4. **Retention** — attendance groups, sessions per member, churn-risk table (members with no recent sessions).
