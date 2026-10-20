-- =============================================================
-- 01_schema.sql  |  Gym Performance Analytics
-- Portable ANSI SQL (tested logic on SQLite; runs on SQL Server 2016+, MySQL 8+, PostgreSQL)
-- =============================================================

DROP VIEW  IF EXISTS vw_member_summary;
DROP VIEW  IF EXISTS vw_member_exercise_progress;
DROP VIEW  IF EXISTS vw_workout_nutrition;
DROP VIEW  IF EXISTS vw_workout_metrics;
DROP TABLE IF EXISTS Nutrition_Members;
DROP TABLE IF EXISTS Workouts;
DROP TABLE IF EXISTS Members;

CREATE TABLE Members (
    member_id         INT          NOT NULL PRIMARY KEY,
    name              VARCHAR(50)  NOT NULL,
    gender            VARCHAR(1)   NOT NULL CHECK (gender IN ('M', 'F')),
    age               INT          NOT NULL CHECK (age BETWEEN 14 AND 80),
    weight_kg         DECIMAL(5,1) NOT NULL CHECK (weight_kg > 0),
    goal              VARCHAR(10)  NOT NULL CHECK (goal IN ('bulk', 'cut')),
    experience_level  VARCHAR(15)  NOT NULL CHECK (experience_level IN ('beginner', 'intermediate', 'advanced'))
);

CREATE TABLE Workouts (
    workout_id     INT          NOT NULL PRIMARY KEY,
    member_id      INT          NOT NULL,
    workout_date   DATE         NOT NULL,
    exercise       VARCHAR(50)  NOT NULL,
    weight_lifted  DECIMAL(5,1) NOT NULL CHECK (weight_lifted > 0),
    reps           INT          NOT NULL CHECK (reps > 0),
    CONSTRAINT fk_workouts_member FOREIGN KEY (member_id) REFERENCES Members (member_id)
);

CREATE TABLE Nutrition_Members (
    nutrition_id  INT  NOT NULL PRIMARY KEY,
    member_id     INT  NOT NULL,
    log_date      DATE NOT NULL,
    calories      INT  NOT NULL CHECK (calories > 0),
    protein_g     INT  NOT NULL CHECK (protein_g >= 0),
    CONSTRAINT fk_nutrition_member FOREIGN KEY (member_id) REFERENCES Members (member_id),
    CONSTRAINT uq_nutrition_member_day UNIQUE (member_id, log_date)
);

CREATE INDEX ix_workouts_member_date ON Workouts (member_id, workout_date);
