"""
One-command pipeline: build a SQLite database from the SQL files, validate data quality,
run every analysis query, export results to CSV and render the README charts.

    python scripts/run_pipeline.py

No database server needed. Exits with a non-zero code if any data-quality check fails
(this is what the CI workflow runs).
"""
import csv
import math
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = ROOT / "sql"
RESULTS = ROOT / "results"
IMAGES = ROOT / "docs" / "images"
DB_PATH = ROOT / "gym.db"

INFO_ONLY = {"workouts_without_nutrition"}   # informational check, not a failure


def connect():
    if DB_PATH.exists():
        DB_PATH.unlink()
    con = sqlite3.connect(DB_PATH)
    # SQLite builds without math functions need SQRT registered (used by the correlation query)
    con.create_function("SQRT", 1, lambda x: math.sqrt(x) if x is not None and x >= 0 else None)
    for name in ("01_schema.sql", "02_seed_data.sql", "04_views.sql"):
        con.executescript((SQL / name).read_text(encoding="utf-8"))
    return con


def strip_comments(stmt):
    return "\n".join(l for l in stmt.splitlines() if not l.strip().startswith("--")).strip()


def run_quality_checks(con):
    text = (SQL / "03_data_quality_checks.sql").read_text(encoding="utf-8")
    failures = 0
    for stmt in filter(None, (strip_comments(s) for s in text.split(";"))):
        cur = con.execute(stmt)
        rows, cols = cur.fetchall(), [d[0] for d in cur.description]
        if len(rows) == 1 and len(cols) == 1:           # a COUNT(*) style check
            label, value = cols[0], rows[0][0]
            ok = value == 0 or label in INFO_ONLY
            status = "INFO" if label in INFO_ONLY else ("PASS" if ok else "FAIL")
            print(f"[{status}] {label} = {value}")
        else:                                            # a "must return no rows" check
            ok = len(rows) == 0
            print(f"[{'PASS' if ok else 'FAIL'}] {cols} -> {len(rows)} offending rows")
        failures += 0 if ok else 1
    return failures


def run_analysis(con):
    text = (SQL / "05_analysis_queries.sql").read_text(encoding="utf-8")
    parts = re.split(r"(?m)^-- (Q\d+)\. ", text)[1:]
    RESULTS.mkdir(exist_ok=True)
    out = {}
    for qid, body in zip(parts[::2], parts[1::2]):
        title, _, sql = body.partition("\n")
        sql = sql[: sql.rindex(";") + 1]                 # drop trailing inline comments
        cur = con.execute(sql)
        cols, rows = [d[0] for d in cur.description], cur.fetchall()
        slug = re.sub(r"[^a-z0-9]+", "_", title.lower()).strip("_")[:40]
        with open(RESULTS / f"{qid}_{slug}.csv", "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f); w.writerow(cols); w.writerows(rows)
        out[qid] = (cols, rows)
        print(f"[OK] {qid}: {title.strip()} ({len(rows)} rows)")
    return out


def render_charts(con, results):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("[SKIP] matplotlib not installed - charts not rendered")
        return
    IMAGES.mkdir(parents=True, exist_ok=True)
    BULK, CUT, GREY = "#14B8A6", "#F59E0B", "#64748B"
    plt.rcParams.update({"font.size": 11, "axes.spines.top": False, "axes.spines.right": False,
                         "axes.titleweight": "bold", "figure.dpi": 130})

    def save(fig, name):
        fig.tight_layout(); fig.savefig(IMAGES / name, bbox_inches="tight"); plt.close(fig)

    # 1) improvement by goal (Q4)
    cols, rows = results["Q4"]
    fig, ax = plt.subplots(figsize=(5.5, 4))
    goals = [r[0] for r in rows]; vals = [r[cols.index("avg_improvement_pct")] for r in rows]
    bars = ax.bar(goals, vals, color=[BULK if g == "bulk" else CUT for g in goals], width=0.55)
    ax.bar_label(bars, fmt="%.1f%%", padding=3)
    ax.set_title("Average strength gain by goal"); ax.set_ylabel("Estimated 1RM improvement (%)")
    save(fig, "01_improvement_by_goal.png")

    # 2) calories vs improvement, per goal with trend lines
    data = con.execute("SELECT goal, avg_calories, avg_improvement_pct FROM vw_member_summary "
                       "WHERE avg_calories IS NOT NULL AND avg_improvement_pct IS NOT NULL").fetchall()
    fig, ax = plt.subplots(figsize=(7, 4.6))
    for goal, color in (("bulk", BULK), ("cut", CUT)):
        pts = np.array([(c, i) for g, c, i in data if g == goal])
        ax.scatter(pts[:, 0], pts[:, 1], color=color, label=f"{goal} (n={len(pts)})", alpha=0.85)
        m, b = np.polyfit(pts[:, 0], pts[:, 1], 1)
        xs = np.linspace(pts[:, 0].min(), pts[:, 0].max(), 50)
        ax.plot(xs, m * xs + b, color=color, lw=1.8, ls="--")
    ax.set_title("Calories vs. strength improvement (one dot per member)")
    ax.set_xlabel("Average daily calories (kcal)"); ax.set_ylabel("Estimated 1RM improvement (%)")
    ax.legend(frameon=False)
    save(fig, "02_calories_vs_improvement.png")

    # 3) attendance groups (Q7)
    cols, rows = results["Q7"]
    order = ["High (30+ sessions)", "Medium (20-29)", "Low (<20)"]
    rows = sorted(rows, key=lambda r: order.index(r[0]))
    fig, ax = plt.subplots(figsize=(6.5, 4))
    bars = ax.bar([r[0] for r in rows], [r[2] for r in rows], color=[BULK, BULK, "#EF4444"], width=0.55)
    ax.bar_label(bars, fmt="%.1f%%", padding=3)
    ax.set_title("Strength gain by attendance"); ax.set_ylabel("Estimated 1RM improvement (%)")
    save(fig, "03_improvement_by_attendance.png")

    # 4) top 10 members (Q3)
    cols, rows = results["Q3"]
    rows = rows[::-1]
    fig, ax = plt.subplots(figsize=(7, 4.6))
    colors = [BULK if r[2] == "bulk" else CUT for r in rows]
    bars = ax.barh([r[1] for r in rows], [r[5] for r in rows], color=colors)
    ax.bar_label(bars, fmt="%.1f%%", padding=3)
    ax.set_title("Top 10 members by strength gain"); ax.set_xlabel("Estimated 1RM improvement (%)")
    save(fig, "04_top10_members.png")
    print(f"[OK] charts written to {IMAGES.relative_to(ROOT)}")


if __name__ == "__main__":
    con = connect()
    print("== Data quality ==")
    failed = run_quality_checks(con)
    print("\n== Analysis ==")
    res = run_analysis(con)
    print("\n== Charts ==")
    render_charts(con, res)
    con.close()
    DB_PATH.unlink(missing_ok=True)
    if failed:
        sys.exit(f"\n{failed} data-quality check(s) failed")
    print("\nAll data-quality checks passed.")
