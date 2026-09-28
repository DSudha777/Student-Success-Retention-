# Student Success & Retention Intelligence Platform

An end-to-end **Microsoft Fabric** analytics solution built on real U.S. Department of Education data (**College Scorecard**, 6,273 institutions). It covers ingestion, medallion-architecture transformation, a star-schema warehouse, a Direct Lake semantic model with row-level security, governance, and Dev/Test/Prod deployment.

**Business question:** Which institutions deliver strong retention, completion, and earnings outcomes relative to cost and debt, and how do access indicators (first-generation and Pell-eligible students) relate to those outcomes?

## Tech Stack

Microsoft Fabric (Lakehouse, Warehouse, Data Pipelines, Notebooks), PySpark / Spark SQL, T-SQL, Power BI, DAX, Direct Lake, Fabric Deployment Pipelines

## Architecture

**Bronze.** The raw College Scorecard institution-level file is loaded as-is into a Delta table in `bronze_lakehouse`, using a Data Pipeline with a Copy data activity. The table holds 6,273 rows and more than 1,800 columns.

**Silver.** A Spark SQL notebook in the Lakehouse narrows the raw data to 22 relevant fields. It converts `PS` (PrivacySuppressed) values to `NULL`, casts the columns to proper types, decodes coded values such as the control type, and renames the columns to readable names. The notebook is in this repo: [`nb_silver_transform_scorecard (2).ipynb`](<nb_silver_transform_scorecard (2).ipynb>).

**Gold.** In `gold_warehouse`, T-SQL builds the star schema: a fact table, `fact_institution_outcomes`, surrounded by three dimensions, `dim_institution`, `dim_degree_type`, and `dim_year`. The scripts are in the [`Gold Layer`](<Gold Layer>) folder.

**Serving.** A Direct Lake semantic model sits on top of the Warehouse. It holds the table relationships, the DAX measures, and the row-level security role.

**Reporting.** Power BI reports connect to the semantic model. They include a retention overview and a cost and value report. The report file is [`Student success Report.pbix`](<Student success Report.pbix>).

![Semantic model](Semantic%20Model.png)

## Data Source

**College Scorecard, U.S. Department of Education** (institution-level file), available at https://collegescorecard.ed.gov/data. The raw file has 1,800+ columns covering admissions, cost, aid, enrollment demographics, completion, debt, repayment, and post-graduation earnings. The raw data is not committed to this repo because of its size.

I deliberately narrowed it to the 22 fields that support the student-success story (identity and location, control type, predominant degree, admission rate, SAT average, enrollment, first-generation and demographic shares, cost, Pell and loan shares, retention, completion rates, debt, repayment, and 10-year earnings) rather than carrying every column forward.

## Data Model

- **`fact_institution_outcomes`**: one row per institution per year (currently one snapshot year), holding all numeric measures
- **`dim_institution`**: institution attributes, including a `state_name` column decoded from state codes
- **`dim_degree_type`**: decodes the predominant-degree code (Certificate / Associate's / Bachelor's / Graduate)
- **`dim_year`**: built to support additional years of historical data

## Key Design Decisions

- **Privacy-suppressed data is treated as unknown, not zero.** College Scorecard suppresses values for small cohorts (coded `PS`). The pipeline converts these to `NULL` so averages are not silently distorted.
- **Surrogate keys without `IDENTITY`.** Fabric Warehouse doesn't support `IDENTITY` columns, so keys are generated with `ROW_NUMBER()` at load time.
- **Constraints are metadata-only.** Fabric Warehouse primary and foreign keys must be declared `NOT ENFORCED`, so referential integrity is handled in the load logic (de-duplication and joins) rather than by the engine.
- **Wide raw data stays Spark-only.** The raw table exceeds T-SQL's 1,024-column limit, so Bronze is only accessed from Spark, and only the narrow Silver table is exposed to the Warehouse.
- **Direct Lake on SQL** was chosen for the semantic model for its DirectQuery fallback behavior while the model was still evolving.

## Problems I Solved

1. **Silent truncation to 1,000 rows.** The dimension and fact tables loaded only 1,000 rows against a 6,273-row source. I counted rows layer by layer (Bronze, Silver, dimension, fact) and found that the Silver table itself held only 1,000 rows, so the Warehouse logic was not the cause. Rebuilding Silver from Bronze restored all 6,273 rows and 22 columns, and I then reloaded the dimension and fact tables.
2. **The 1,024-column limit.** The raw table has 1,800+ columns, more than T-SQL allows. I restructured the architecture so the raw wide table stays Spark-only and only the curated Silver table is queried from the Warehouse.
3. **Fabric Warehouse T-SQL differences.** Inline `PRIMARY KEY`, `IDENTITY`, and nullable key columns are not supported. I used `ROW_NUMBER()` for surrogate keys, `NOT NULL` key columns, and post-create `ALTER TABLE ... NOT ENFORCED` constraints, with the load logic handling integrity.
4. **Misleading chart values.** A retention chart showed a flat 100% for every state, and a rate was displayed with a `$` prefix. I traced these to duplicate model relationships, a duplicated measure, and incorrect measure formatting, and fixed each.
5. **Column-name differences from the data dictionary.** Several fields in the actual file differed from the documentation (for example `FIRST_GEN`, and suppressed values coded as `PS` rather than `PrivacySuppressed`). I checked column names against the real schema instead of assuming.

## Semantic Model and Reports

Direct Lake semantic model with explicit DAX measures, including:

- Average retention rate, average 150%-time graduation rate, institution count, average annual cost
- Debt-to-earnings ratio (median graduate debt divided by median 10-year earnings)

Report pages:

- **Retention overview**: average retention by state, broken down by control type
- **Cost & value**: cost versus earnings scatter, and institutions ranked by debt-to-earnings ratio

## Governance

- **Lineage:** the lineage view shows Bronze, Silver, Gold, the semantic model, and the report connected end to end.
- **Access:** workspace roles are defined (Admin / Contributor / Viewer).
- **Endorsement:** the semantic model is promoted with a description of its grain, source, and refresh cadence.

![Lineage view](Student%20Success%20Lineage%20View.png)

## Deployment

Git integration was attempted but blocked (GitHub required a tenant admin setting I didn't control, and the Azure DevOps route hit account issues), so promotion uses **Fabric Deployment Pipelines** across Dev, Test, and Prod workspaces.

![Deployment pipeline](Student%20Success%20Deployment%20Pipeline.png)


