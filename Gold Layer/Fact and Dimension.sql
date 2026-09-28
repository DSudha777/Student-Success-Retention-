
SELECT * FROM bronze_lakehouse.dbo.silver_scorecard_institutions

-- Dimension: Institution
CREATE TABLE dim_institution (
    institution_key INT NOT NULL,
    institution_id BIGINT,
    institution_name VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(10),
    region VARCHAR(50),
    locale_type VARCHAR(50),
    control_type VARCHAR(50),
    degree_key INT
);

-- Dimension: dim_year;
CREATE TABLE dim_year (
    year_key INT NOT NULL,
    academic_year VARCHAR(10)
);

ALTER TABLE dim_year
ADD CONSTRAINT PK_dim_year PRIMARY KEY NONCLUSTERED (year_key) NOT ENFORCED;



ALTER TABLE dim_year
ADD CONSTRAINT PK_dim_year PRIMARY KEY NONCLUSTERED (year_key) NOT ENFORCED;

-- dim_degree_type
CREATE TABLE dim_degree_type (
    degree_key INT,
    degree_code INT,
    degree_description VARCHAR(50)
);

ALTER TABLE dim_degree_type
ADD CONSTRAINT PK_dim_degree_type PRIMARY KEY NONCLUSTERED (degree_key) NOT ENFORCED;

-- dim_year
CREATE TABLE dim_year (
    year_key INT,
    academic_year VARCHAR(10)
);

ALTER TABLE dim_year
ADD CONSTRAINT PK_dim_year PRIMARY KEY NONCLUSTERED (year_key) NOT ENFORCED;

-- fact_institution_outcomes
DROP TABLE fact_institution_outcomes;
CREATE TABLE fact_institution_outcomes (
    fact_key BIGINT NOT NULL,
    institution_key INT,
    year_key INT,
    admission_rate DECIMAL(5,2),
    avg_sat_score INT,
    undergrad_enrollment INT,
    pct_first_gen_students DECIMAL(5,2),
    avg_age_at_entry DECIMAL(5,2),
    pct_white_students DECIMAL(5,2),
    pct_black_students DECIMAL(5,2),
    pct_hispanic_students DECIMAL(5,2),
    avg_annual_cost DECIMAL(10,2),
    pct_pell_grant_recipients DECIMAL(5,2),
    pct_federal_loan_recipients DECIMAL(5,2),
    retention_rate_fulltime DECIMAL(5,2),
    grad_rate_on_time_4yr DECIMAL(5,2),
    grad_rate_150pct_time DECIMAL(5,2),
    median_grad_debt DECIMAL(10,2),
    loan_repayment_rate_3yr DECIMAL(5,2),
    median_earnings_10yr DECIMAL(10,2)
);
ALTER TABLE fact_institution_outcomes
ADD CONSTRAINT PK_fact_institution_outcomes PRIMARY KEY NONCLUSTERED (fact_key) NOT ENFORCED;
ALTER TABLE fact_institution_outcomes
ADD CONSTRAINT FK_fact_institution FOREIGN KEY (institution_key) REFERENCES dim_institution(institution_key) NOT ENFORCED;
ALTER TABLE fact_institution_outcomes
ADD CONSTRAINT FK_fact_year FOREIGN KEY (year_key) REFERENCES dim_year(year_key) NOT ENFORCED;

-- dim_degree_type
drop table dim_degree_type;
CREATE TABLE dim_degree_type (
    degree_key INT NOT NULL,
    degree_code INT,
    degree_description VARCHAR(50)
);

ALTER TABLE dim_degree_type
ADD CONSTRAINT PK_dim_degree_type PRIMARY KEY NONCLUSTERED (degree_key) NOT ENFORCED;
