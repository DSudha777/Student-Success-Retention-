Student Success & Retention Intelligence Platform
An end-to-end Microsoft Fabric analytics solution built on real U.S. Department of Education data (College Scorecard, 6,273 institutions). It covers ingestion, medallion-architecture transformation, a star-schema warehouse, a Direct Lake semantic model with row-level security, governance, and Dev/Test/Prod deployment.

Business question: Which institutions deliver strong retention, completion, and earnings outcomes relative to cost and debt, and how do access indicators (first-generation and Pell-eligible students) relate to those outcomes?
________________________________________
Architecture
Insert architecture diagram here: Source CSV → Bronze (Lakehouse) → Silver (Lakehouse) → Gold (Warehouse) → Direct Lake semantic model → Power BI reports

Bronze. The raw College Scorecard institution-level file is loaded as-is into a Delta table in bronze_lakehouse, using a Data Pipeline with a Copy data activity. The table holds 6,273 rows and more than 1,800 columns.

Silver. A Spark SQL notebook in the Lakehouse narrows the raw data to 22 relevant fields. It converts PS (PrivacySuppressed) values to NULL, casts the columns to proper types, decodes coded values such as the control type, and renames the columns to readable names.

Gold. In gold_warehouse, T-SQL builds the star schema: a fact table, fact_institution_outcomes, surrounded by three dimensions, dim_institution, dim_degree_type, and dim_year.

Serving. A Direct Lake semantic model sits on top of the Warehouse. It holds the table relationships, the DAX measures, and the row-level security role.

Reporting. Power BI reports connect to the semantic model. They include a retention overview and a cost and value report.



Tech Stack
Microsoft Fabric (Lakehouse, Warehouse, Data Pipelines, Notebooks), PySpark / Spark SQL, T-SQL, Power BI, DAX, Direct Lake, Fabric Deployment Pipelines
________________________________________
Data Source
College Scorecard, U.S. Department of Education (institution-level file). The raw file has 1,800+ columns covering admissions, cost, aid, enrollment demographics, completion, debt, repayment, and post-graduation earnings.
I deliberately narrowed it to the 22 fields that support the student-success story (identity and location, control type, predominant degree, admission rate, SAT average, enrollment, first-generation and demographic shares, cost, Pell and loan shares, retention, completion rates, debt, repayment, and 10-year earnings) rather than carrying every column forward.

Data Model
•	fact_institution_outcomes: one row per institution per year (currently one snapshot year), holding all numeric measures
•	dim_institution: institution attributes, including a state_name column decoded from state codes
•	dim_degree_type: decodes the predominant-degree code (Certificate / Associate's / Bachelor's / Graduate)
•	dim_year: built to support additional years of historical data

Key Design Decisions
•	Privacy-suppressed data is treated as unknown, not zero. College Scorecard suppresses values for small cohorts (coded PS). The pipeline converts these to NULL so averages are not silently distorted.

•	Surrogate keys without IDENTITY. Fabric Warehouse doesn't support IDENTITY columns, so keys are generated with ROW_NUMBER() at load time.

•	Constraints are metadata-only. Fabric Warehouse primary and foreign keys must be declared NOT ENFORCED, so referential integrity is handled in the load logic (de-duplication and joins) rather than by the engine.

•	Wide raw data stays Spark-only. The raw table exceeds T-SQL's 1,024-column limit, so Bronze is only ever accessed from Spark, and only the narrow Silver table is exposed to the Warehouse.

•	Direct Lake on SQL was chosen for the semantic model for its DirectQuery fallback behavior while the model was still evolving.

Real Problems I Solved
1.	Silent truncation to 1,000 rows. The fact and dimension tables loaded only 1,000 rows against a 6,273-row source. Tracing row counts layer by layer (Bronze → Silver → dimension → fact) isolated the cause to a Silver table that had been rebuilt incorrectly, not the Warehouse logic.
2.	Rebuild pointed at the wrong table. A Silver rebuild query referenced the Silver table itself instead of Bronze, causing a column-not-found error on a column that had already been renamed. Reading the error's table reference, not just the column name, exposed it.
3.	SQL analytics endpoint sync lag. After recreating a Lakehouse table in a notebook, Warehouse cross-database queries kept seeing the old schema ("invalid column name"). Fixed by refreshing the SQL analytics endpoint before querying.
4.	1,024-column limit. Attempting to sync the raw table through the SQL endpoint failed. Restructured the architecture so raw wide data stays Spark-only.
5.	Fabric Warehouse T-SQL differences. Adapted to unsupported inline PRIMARY KEY, IDENTITY, and nullable-key constraints by using post-create ALTER TABLE ... NOT ENFORCED constraints and NOT NULL key columns.
6.	Misleading chart values. A flat 100% retention chart and a $ prefix on a rate were traced to duplicate model relationships, a duplicated measure, and incorrect measure formatting.
Semantic Model and Reports

Direct Lake semantic model with explicit DAX measures, including:
•	Average retention rate, average 150%-time graduation rate, institution count, average annual cost
•	Debt-to-earnings ratio (median graduate debt divided by median 10-year earnings)

Report pages:
•	Retention overview: average retention by state, broken down by control type
•	Cost & value: cost versus earnings scatter, and institutions ranked by debt-to-earnings ratio

Governance
•	Lineage view showing Bronze → Silver → Gold → semantic model → report
•	Workspace roles defined (Admin / Contributor / Viewer)
•	Semantic model promoted with a description of grain, source, and refresh cadence

Deployment
Git integration was attempted but blocked (GitHub required a tenant admin setting I didn't control, and the Azure DevOps route hit account issues), so promotion uses Fabric Deployment Pipelines across Dev → Test → Prod workspaces.

