-- LABS FROM labevents
BEGIN;

SELECT load_extension('/data/student_work/luis_work/mimicIII/re');
CREATE TEMP VIEW "msm_labevents_temp" AS
	SELECT
	mimic_id as measurement_id
	, subject_id
	, charttime as measurement_datetime
	, hadm_id
	, itemid
	, coalesce(NULLIF(valueuom,''), regexp_substr(value, '(ml\/hr|ml\/h|cc\/h|cc\/hr|\/h|mg\/h|mg\/hr|g\/h|g\/hr|mcg\/h|mcg\/hr|U\/hr|U\/h|lpm|g|gram|grams|gm|gms|grm|mg|meq|mcg|kg|liter|l|ppm|s|sec|min|min\.|minutes|minute|mins|hour|hr|hrs|in|inch|cm|mm|m|meters|ml|mmHg|cs|wks|weeks|week|French|fr|gauge|degrees|%|cc)$')) as unit_source_value
	, flag
	, value as value_source_value
    , CASE WHEN value LIKE '%>=%' THEN '>=' ELSE CASE WHEN value LIKE '%>%' THEN '>' ELSE CASE WHEN value LIKE '%<=%' THEN '<=' ELSE CASE WHEN value LIKE '%<%' THEN '<' ELSE NULL END END END END AS operator_name
    , CAST(regexp_substr(replace(replace(value,',',''),' ',''),'[+-]?[0-9]*[.][0-9]+|[+-]?[0-9]+') AS DECIMAL) as value_as_number
	FROM labevents;

CREATE TEMP VIEW "msm_patients_temp" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "msm_admissions_temp" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "msm_d_labitems_temp" AS SELECT itemid, label as measurement_source_value, fluid, loinc_code, category, mimic_id FROM d_labitems;
CREATE TEMP VIEW "msm_gcpt_lab_label_to_concept_temp" AS SELECT label as measurement_source_value, concept_id as measurement_concept_id FROM gcpt_lab_label_to_concept;
CREATE TEMP VIEW "msm_omop_loinc" AS SELECT concept_id AS measurement_concept_id, concept_code as loinc_code FROM OMOP.concept WHERE vocabulary_id = 'LOINC' AND domain_id = 'Measurement';
CREATE TEMP VIEW "msm_omop_operator" AS SELECT concept_name as operator_name, concept_id as operator_concept_id FROM OMOP.concept WHERE  LOWER(domain_id) like 'Meas Value Operator';
CREATE TEMP VIEW "msm_gcpt_lab_unit_to_concept_temp" AS SELECT unit as unit_source_value, concept_id as unit_concept_id FROM gcpt_lab_unit_to_concept;
CREATE TEMP VIEW "msm_row_to_insert" AS 
SELECT
  msm_labevents_temp.measurement_id
, msm_patients_temp.person_id
, coalesce(NULLIF(msm_omop_loinc.measurement_concept_id,''), NULLIF(msm_gcpt_lab_label_to_concept_temp.measurement_concept_id,''), 0) as measurement_concept_id
, CAST(msm_labevents_temp.measurement_datetime as Text) as measurement_date
, msm_labevents_temp.measurement_datetime as measurement_datetime
, CASE
     WHEN LOWER(category) LIKE 'blood gas'  THEN  2000000010
     WHEN LOWER(category) LIKE 'chemistry'  THEN  2000000011
     WHEN LOWER(category) LIKE 'hematology' THEN  2000000009
     ELSE 44818702 --labs
  END AS measurement_type_concept_id -- Lab result
, operator_concept_id as operator_concept_id -- =, >, ... operator
, msm_labevents_temp.value_as_number as value_as_number
, CAST(0 as integer) as value_as_concept_id
, msm_gcpt_lab_unit_to_concept_temp.unit_concept_id
, CAST(null AS double precision) AS range_low
, CAST(null AS double precision) AS range_high
, CAST(null AS bigint) AS provider_id
, msm_admissions_temp.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, CAST(msm_d_labitems_temp.itemid AS text) AS measurement_source_value       -- this might be linked to concept.concept_code
, msm_d_labitems_temp.mimic_id AS measurement_source_concept_id
, msm_gcpt_lab_unit_to_concept_temp.unit_source_value
, msm_labevents_temp.value_source_value
, specimen_concept_id
FROM msm_labevents_temp
LEFT JOIN msm_patients_temp USING (subject_id)
LEFT JOIN msm_admissions_temp USING (hadm_id)
LEFT JOIN msm_d_labitems_temp USING (itemid)
LEFT JOIN msm_omop_loinc USING (loinc_code)
LEFT JOIN msm_omop_operator USING (operator_name)
LEFT JOIN msm_gcpt_lab_label_to_concept_temp USING (measurement_source_value)
LEFT JOIN msm_gcpt_lab_unit_to_concept_temp USING (unit_source_value)
LEFT JOIN gcpt_labs_specimen_to_concept ON (msm_d_labitems_temp.fluid =  gcpt_labs_specimen_to_concept.label);

CREATE TEMP VIEW "msm_specimen_lab" AS --generated specimen: each lab is associated with a fictive specimen
SELECT
  ROW_NUMBER() OVER (ORDER BY msm_row_to_insert.measurement_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as specimen_id -- non NULL
, person_id                                 -- non NULL
, coalesce(NULLIF(specimen_concept_id,''), 0 ) as specimen_concept_id
, 581378 as specimen_type_concept_id    -- non NULL
, measurement_date as specimen_date
, measurement_datetime as specimen_datetime
, CAST(null AS double precision) as quantity
, CAST(null AS integer) unit_concept_id
, CAST(null AS integer) anatomic_site_concept_id
, CAST(null AS integer) disease_status_concept_id
, CAST(null AS integer) specimen_source_id
, CAST(null AS text) specimen_source_value
, CAST(null AS text) unit_source_value
, CAST(null AS text) anatomic_site_source_value
, CAST(null AS text) disease_status_source_value
, msm_row_to_insert.measurement_id -- usefull for fact_relationship
FROM msm_row_to_insert;

INSERT INTO OMOP.specimen
(
	  specimen_id
	, person_id
	, specimen_concept_id
	, specimen_type_concept_id
	, specimen_date
	, specimen_datetime
	, quantity
	, unit_concept_id
	, anatomic_site_concept_id
	, disease_status_concept_id
	, specimen_source_id
	, specimen_source_value
	, unit_source_value
	, anatomic_site_source_value
	, disease_status_source_value
)
SELECT
  specimen_id    -- non NULL
, person_id                         -- non NULL
, specimen_concept_id         -- non NULL
, specimen_type_concept_id    -- non NULL
, specimen_date
, specimen_datetime
, quantity
, unit_concept_id
, anatomic_site_concept_id
, disease_status_concept_id
, specimen_source_id
, specimen_source_value
, unit_source_value
, anatomic_site_source_value
, disease_status_source_value
FROM msm_specimen_lab;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT specimen_id FROM msm_specimen_lab ORDER BY specimen_id DESC LIMIT 1);

INSERT INTO OMOP.fact_relationship
    SELECT
      36 AS domain_concept_id_1 -- Specimen
    , specimen_id as fact_id_1
    , 21 AS domain_concept_id_2 -- Measurement
    , measurement_id as fact_id_2
    , 44818854 as relationship_concept_id -- Specimen of (SNOMED)
    FROM msm_specimen_lab
    UNION ALL
    SELECT
      21 AS domain_concept_id_1 -- Measurement
    , measurement_id as fact_id_1
    , 36 AS domain_concept_id_2 -- Specimen
    , specimen_id as fact_id_2
    , 44818756 as relationship_concept_id -- Has specimen (SNOMED)
    FROM msm_specimen_lab;

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert.measurement_id
, msm_row_to_insert.person_id
, msm_row_to_insert.measurement_concept_id
, msm_row_to_insert.measurement_date
, msm_row_to_insert.measurement_datetime
, msm_row_to_insert.measurement_type_concept_id
, msm_row_to_insert.operator_concept_id
, msm_row_to_insert.value_as_number
, msm_row_to_insert.value_as_concept_id
, msm_row_to_insert.unit_concept_id
, msm_row_to_insert.range_low
, msm_row_to_insert.range_high
, msm_row_to_insert.provider_id
, msm_row_to_insert.visit_occurrence_id
, msm_row_to_insert.visit_detail_id
, msm_row_to_insert.measurement_source_value
, msm_row_to_insert.measurement_source_concept_id
, msm_row_to_insert.unit_source_value
, msm_row_to_insert.value_source_value
FROM msm_row_to_insert;

-- LABS from chartevents
CREATE TEMP VIEW "msm_chartevents_lab" AS
	SELECT
	  chartevents.itemid
	, chartevents.mimic_id as measurement_id
	, subject_id
	, hadm_id
	, storetime as measurement_datetime --according to Alistair, storetime is the result time
	, charttime as specimen_datetime                -- according to Alistair, charttime is the specimen time
	, value as value_source_value
    , CASE WHEN value LIKE '%>=%' THEN '>=' ELSE CASE WHEN value LIKE '%>%' THEN '>' ELSE CASE WHEN value LIKE '%<=%' THEN '<=' ELSE CASE WHEN value LIKE '%<%' THEN '<' ELSE NULL END END END END AS operator_name
    , CAST(regexp_substr(replace(replace(value,',',''),' ',''),'[+-]?[0-9]*[.][0-9]+|[+-]?[0-9]+') AS DECIMAL) as value_as_number
	, coalesce(NULLIF(valueuom,''), regexp_substr(value, '(ml\/hr|ml\/h|cc\/h|cc\/hr|\/h|mg\/h|mg\/hr|g\/h|g\/hr|mcg\/h|mcg\/hr|U\/hr|U\/h|lpm|g|gram|grams|gm|gms|grm|mg|meq|mcg|kg|liter|l|ppm|s|sec|min|min\.|minutes|minute|mins|hour|hr|hrs|in|inch|cm|mm|m|meters|ml|mmHg|cs|wks|weeks|week|French|fr|gauge|degrees|%|cc)$')) AS unit_source_value
	FROM chartevents
        JOIN OMOP.concept -- concept driven dispatcher
        ON (    concept_code  = CAST(itemid AS Text)
            AND domain_id     = 'Measurement'
            AND vocabulary_id = 'MIMIC d_items'
            AND concept_class_id IN ( 'Labs', 'Blood Gases', 'Hematology', 'Heme/Coag', 'Coags', 'CSF', 'Enzymes','Chemistry')

           )
	WHERE NULLIF(error,'') IS NULL OR error= 0;

CREATE TEMP VIEW "msm_d_items_temp2" AS SELECT itemid, category, label, mimic_id FROM d_items;
CREATE TEMP VIEW "msm_patients_temp2" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "msm_admissions_temp2" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "msm_omop_operator_temp2" AS SELECT concept_name as operator_name, concept_id as operator_concept_id FROM OMOP.concept WHERE  LOWER(domain_id) like 'Meas Value Operator';
CREATE TEMP VIEW "msm_omop_loinc_temp2" AS 
	SELECT distinct concept_name AS label, concept_id AS measurement_concept_id
	FROM OMOP.concept
	WHERE vocabulary_id = 'LOINC'
	AND domain_id = 'Measurement'
	AND standard_concept = 'S';
CREATE TEMP VIEW "msm_gcpt_lab_label_to_concept_temp2" AS SELECT label, concept_id as measurement_concept_id FROM gcpt_lab_label_to_concept;
CREATE TEMP VIEW "msm_gcpt_lab_unit_to_concept_temp2" AS SELECT unit as unit_source_value, concept_id as unit_concept_id FROM gcpt_lab_unit_to_concept;
CREATE TEMP VIEW "msm_gcpt_labs_from_chartevents_to_concept_temp2" AS SELECT label, category, measurement_type_concept_id from gcpt_labs_from_chartevents_to_concept;
CREATE TEMP VIEW "msm_row_to_insert_2" AS 
	SELECT
  msm_chartevents_lab.measurement_id
, msm_patients_temp2.person_id
, coalesce(NULLIF(msm_omop_loinc_temp2.measurement_concept_id,''), NULLIF(msm_gcpt_lab_label_to_concept_temp2.measurement_concept_id,''), 0) as measurement_concept_id
, CAST(msm_chartevents_lab.measurement_datetime AS Text) AS measurement_date
, msm_chartevents_lab.measurement_datetime AS measurement_datetime
, CASE
     WHEN LOWER(category) LIKE 'blood gases'  THEN  2000000010
     WHEN lower(category) IN ('chemistry','enzymes')  THEN  2000000011
     WHEN lower(category) IN ('hematology','heme/coag','csf','coags') THEN  2000000009
     WHEN lower(category) IN ('labs') THEN coalesce(NULLIF(msm_gcpt_labs_from_chartevents_to_concept_temp2.measurement_type_concept_id,''),44818702)
     ELSE 44818702 -- there no trivial way to classify
  END AS measurement_type_concept_id -- Lab result
, operator_concept_id AS operator_concept_id -- = operator
, msm_chartevents_lab.value_as_number AS value_as_number
, CAST(null AS bigint) AS value_as_concept_id
, msm_gcpt_lab_unit_to_concept_temp2.unit_concept_id
, CAST(null AS double precision) AS range_low
, CAST(null AS double precision) AS range_high
, CAST(null AS bigint) AS provider_id
, msm_admissions_temp2.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, msm_d_items_temp2.label AS measurement_source_value
, msm_d_items_temp2.mimic_id AS measurement_source_concept_id
, msm_gcpt_lab_unit_to_concept_temp2.unit_source_value
, msm_chartevents_lab.value_source_value
, specimen_datetime
  FROM msm_chartevents_lab
LEFT JOIN msm_patients_temp2 USING (subject_id)
LEFT JOIN msm_admissions_temp2 USING (hadm_id)
LEFT JOIN msm_d_items_temp2 USING (itemid)
LEFT JOIN msm_omop_loinc_temp2 USING (label)
LEFT JOIN msm_omop_operator_temp2 USING (operator_name)
LEFT JOIN msm_gcpt_lab_label_to_concept_temp2 USING (label)
LEFT JOIN msm_gcpt_labs_from_chartevents_to_concept_temp2 USING (category, label)
LEFT JOIN msm_gcpt_lab_unit_to_concept_temp2 USING (unit_source_value);

CREATE TEMP VIEW "msm_specimen_lab_2" AS  -- generated specimen: each lab measurement is associated with a fictive specimen
SELECT
  ROW_NUMBER() OVER (ORDER BY msm_row_to_insert_2.measurement_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as specimen_id
, person_id
, CAST(0 AS integer) as specimen_concept_id         -- no information right now about any specimen provenance
, 581378 as specimen_type_concept_id
, CAST(specimen_datetime AS Text) as specimen_date
, specimen_datetime as specimen_datetime
, CAST(null AS double precision) as quantity
, CAST(null AS integer) unit_concept_id
, CAST(null AS integer) anatomic_site_concept_id
, CAST(null AS integer) disease_status_concept_id
, CAST(null AS integer) specimen_source_id
, CAST(null AS text) specimen_source_value
, CAST(null AS text) unit_source_value
, CAST(null AS text) anatomic_site_source_value
, CAST(null AS text) disease_status_source_value
, msm_row_to_insert_2.measurement_id -- usefull for fact_relationship
FROM msm_row_to_insert_2;

INSERT INTO OMOP.specimen
(
	  specimen_id
	, person_id
	, specimen_concept_id
	, specimen_type_concept_id
	, specimen_date
	, specimen_datetime
	, quantity
	, unit_concept_id
	, anatomic_site_concept_id
	, disease_status_concept_id
	, specimen_source_id
	, specimen_source_value
	, unit_source_value
	, anatomic_site_source_value
	, disease_status_source_value
)
SELECT
  specimen_id    -- non NULL
, person_id                         -- non NULL
, specimen_concept_id         -- non NULL
, specimen_type_concept_id    -- non NULL
, specimen_date
, specimen_datetime
, quantity
, unit_concept_id
, anatomic_site_concept_id
, disease_status_concept_id
, specimen_source_id
, specimen_source_value
, unit_source_value
, anatomic_site_source_value
, disease_status_source_value
FROM msm_specimen_lab_2;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT specimen_id FROM msm_specimen_lab_2 ORDER BY specimen_id DESC LIMIT 1);

INSERT INTO OMOP.fact_relationship
    SELECT
      36 AS domain_concept_id_1 -- Specimen
    , specimen_id as fact_id_1
    , 21 AS domain_concept_id_2 -- Measurement
    , measurement_id as fact_id_2
    , 44818854 as relationship_concept_id -- Specimen of (SNOMED)
    FROM msm_specimen_lab_2
    UNION ALL
    SELECT
      21 AS domain_concept_id_1 -- Measurement
    , measurement_id as fact_id_1
    , 36 AS domain_concept_id_2 -- Specimen
    , specimen_id as fact_id_2
    , 44818756 as relationship_concept_id -- Has specimen (SNOMED)
    FROM msm_specimen_lab_2;

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id --no visit_detail assignation since datetime is not relevant
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert_2.measurement_id
, msm_row_to_insert_2.person_id
, msm_row_to_insert_2.measurement_concept_id
, msm_row_to_insert_2.measurement_date
, msm_row_to_insert_2.measurement_datetime
, msm_row_to_insert_2.measurement_type_concept_id
, msm_row_to_insert_2.operator_concept_id
, msm_row_to_insert_2.value_as_number
, msm_row_to_insert_2.value_as_concept_id
, msm_row_to_insert_2.unit_concept_id
, msm_row_to_insert_2.range_low
, msm_row_to_insert_2.range_high
, msm_row_to_insert_2.provider_id
, msm_row_to_insert_2.visit_occurrence_id
, msm_row_to_insert_2.visit_detail_id --no visit_detail assignation since datetime is not relevant
, msm_row_to_insert_2.measurement_source_value
, msm_row_to_insert_2.measurement_source_concept_id
, msm_row_to_insert_2.unit_source_value
, msm_row_to_insert_2.value_source_value
FROM msm_row_to_insert_2;

-- Microbiology
-- NOTICE: the number of culture is complicated to determine (the distinct on (coalesce).. is a result)
CREATE TEMP VIEW "culture" AS
	SELECT
        DISTINCT subject_id, hadm_id, coalesce(NULLIF(charttime,''),NULLIF(chartdate,'')), coalesce(NULLIF(spec_itemid,''),0) AS spec_itemid --NOTE: coalesce(org_name,'') was removed
        , microbiologyevents.mimic_id as measurement_id
        , chartdate as measurement_date
        , charttime as measurement_datetime
        , subject_id
        , hadm_id
        , org_name
        , spec_type_desc as measurement_source_value
        , spec_itemid as specimen_source_value -- TODO: add the specimen type local concepts
        --, specimen_source_id --TODO: wait for next mimic release that will ship the specimen details
        , specimen_concept_id
        FROM microbiologyevents
    LEFT JOIN gcpt_microbiology_specimen_to_concept ON (label = spec_type_desc);

CREATE TEMP VIEW "resistance" AS
	SELECT
	spec_itemid
	, ab_itemid
    , ROW_NUMBER() OVER (ORDER BY mimic_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as measurement_id
	, chartdate as measurement_date
	, charttime as measurement_datetime
	, subject_id
	, hadm_id
    , CASE WHEN dilution_text LIKE '%>=%' THEN '>=' ELSE CASE WHEN dilution_text LIKE '%>%' THEN '>' ELSE CASE WHEN dilution_text LIKE '%<=%' THEN '<=' ELSE CASE WHEN dilution_text LIKE '%<%' THEN '<' ELSE NULL END END END END AS operator_name
	, CAST(regexp_substr(replace(replace(dilution_text,',',''),' ',''),'[+-]?[0-9]*[.][0-9]+|[+-]?[0-9]+') AS DECIMAL) as value_as_number
	, ab_name as measurement_source_value
	, interpretation
	, dilution_text as value_source_value
	, org_name
	FROM microbiologyevents
	WHERE NULLIF(dilution_text,'') IS NOT NULL;

CREATE TEMP VIEW "fact_relationship" AS
 SELECT
  culture.measurement_id as fact_id_1
  , resistance.measurement_id AS fact_id_2
 FROM resistance
 LEFT JOIN culture ON (resistance.subject_id = culture.subject_id AND resistance.hadm_id = culture.hadm_id AND
 coalesce(NULLIF(culture.measurement_datetime,''),NULLIF(culture.measurement_date,'')) = coalesce(NULLIF(resistance.measurement_datetime,''),NULLIF(resistance.measurement_date,''))
 AND coalesce(NULLIF(resistance.spec_itemid,''),0) = coalesce(NULLIF(culture.spec_itemid,''),0) AND coalesce(NULLIF(resistance.org_name,''),'') = coalesce(NULLIF(culture.org_name,''),''));

INSERT INTO OMOP.fact_relationship
    SELECT
      21 AS domain_concept_id_1 -- Measurement
    , fact_id_1
    , 21 AS domain_concept_id_2 -- Measurement
    , fact_id_2
    , 44818757 as relationship_concept_id -- Has interpretation (SNOMED) TODO find a better predicate
    FROM fact_relationship
UNION ALL
    SELECT
      21 AS domain_concept_id_1 -- Measurement
    , fact_id_2 as fact_id_1
    , 21 AS domain_concept_id_2 -- Measurement
    , fact_id_1 as  fact_id_2
    , 44818855  as relationship_concept_id --  Interpretation of (SNOMED) TODO find a better predicate
    FROM fact_relationship;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT measurement_id FROM resistance ORDER BY measurement_id DESC LIMIT 1);

CREATE TEMP VIEW "msm_patients_temp3" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "msm_admissions_temp3" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "specimen_culture" AS  --generated specimen
SELECT
  ROW_NUMBER() OVER (ORDER BY culture.measurement_id)+(SELECT mimic_id_seq FROM TEMP_SEQUENCES LIMIT 1) as specimen_id
, msm_patients_temp3.person_id
, coalesce(NULLIF(specimen_concept_id,''),  0) as specimen_concept_id         -- found manually
, 581378 as specimen_type_concept_id
, culture.measurement_date as specimen_date               -- this is not really the specimen date but better than nothing
, culture.measurement_datetime as specimen_datetime
, CAST(null AS double precision) as quantity
, CAST(null AS integer) unit_concept_id
, CAST(null AS integer) anatomic_site_concept_id
, CAST(null AS integer) disease_status_concept_id
, CAST(null AS integer) specimen_source_id            --TODO: wait for next mimic release that will ship the specimen details
, specimen_source_value as specimen_source_value
, CAST(null AS text) unit_source_value
, CAST(null AS text) anatomic_site_source_value
, CAST(null AS text) disease_status_source_value
, culture.measurement_id -- usefull for fact_relationship
FROM culture
LEFT JOIN msm_patients_temp3 USING (subject_id);

INSERT INTO OMOP.specimen
(
	  specimen_id
	, person_id
	, specimen_concept_id
	, specimen_type_concept_id
	, specimen_date
	, specimen_datetime
	, quantity
	, unit_concept_id
	, anatomic_site_concept_id
	, disease_status_concept_id
	, specimen_source_id
	, specimen_source_value
	, unit_source_value
	, anatomic_site_source_value
	, disease_status_source_value
)
SELECT
  specimen_id    -- non NULL
, person_id                         -- non NULL
, specimen_concept_id         -- non NULL
, specimen_type_concept_id    -- non NULL
, specimen_date               -- this is not really the specimen date but better than nothing
, specimen_datetime
, quantity
, unit_concept_id
, anatomic_site_concept_id
, disease_status_concept_id
, specimen_source_id
, specimen_source_value
, unit_source_value
, anatomic_site_source_value
, disease_status_source_value
FROM specimen_culture;

INSERT INTO OMOP.fact_relationship
    SELECT
      36 AS domain_concept_id_1 -- Specimen
    , specimen_id as fact_id_1
    , 21 AS domain_concept_id_2 -- Measurement
    , measurement_id as fact_id_2
    , 44818854 as relationship_concept_id -- Specimen of (SNOMED)
    FROM specimen_culture
    UNION ALL
    SELECT
      21 AS domain_concept_id_1 -- Measurement
    , measurement_id as fact_id_1
    , 36 AS domain_concept_id_2 -- Specimen
    , specimen_id as fact_id_2
    , 44818756 as relationship_concept_id -- Has specimen (SNOMED)
    FROM specimen_culture;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT measurement_id FROM specimen_culture ORDER BY measurement_id DESC LIMIT 1);

CREATE TEMP VIEW "msm_omop_operator_temp4" AS SELECT concept_name as operator_name, concept_id as operator_concept_id FROM OMOP.concept WHERE  LOWER(domain_id) like 'Meas Value Operator';
CREATE TEMP VIEW "gcpt_resistance_to_concept_temp4" AS SELECT * FROM gcpt_resistance_to_concept;
CREATE TEMP VIEW "gcpt_org_name_to_concept_temp4" AS SELECT org_name, concept_id AS value_as_concept_id FROM gcpt_org_name_to_concept JOIN OMOP.concept ON (concept_code = CAST(snomed AS text) AND vocabulary_id = 'SNOMED');
CREATE TEMP VIEW "gcpt_spec_type_to_concept_temp4" AS SELECT concept_id as measurement_concept_id, spec_type_desc as measurement_source_value FROM gcpt_spec_type_to_concept LEFT JOIN OMOP.concept ON (loinc = concept_code AND standard_concept ='S' AND domain_id = 'Measurement');
CREATE TEMP VIEW "gcpt_atb_to_concept_temp4" AS SELECT concept_id as measurement_concept_id, ab_name as measurement_source_value FROM gcpt_atb_to_concept LEFT JOIN OMOP.concept ON (concept.concept_code = gcpt_atb_to_concept.concept_code AND standard_concept = 'S' AND domain_id = 'Measurement');
CREATE TEMP VIEW "msm_d_items_temp4" AS SELECT mimic_id as measurement_source_concept_id, itemid FROM d_items WHERE category IN ( 'SPECIMEN', 'ORGANISM');
CREATE TEMP VIEW "msm_row_to_insert_3" AS SELECT
  culture.measurement_id AS measurement_id
, msm_patients_temp3.person_id
, coalesce(NULLIF(gcpt_spec_type_to_concept_temp4.measurement_concept_id,''), 4098207) as measurement_concept_id      -- --30088009 -- Blood Culture but not done yet
, measurement_date AS measurement_date
, measurement_datetime AS measurement_datetime
, 2000000007 AS measurement_type_concept_id -- Lab result -- Microbiology - Culture
, null AS operator_concept_id
, null value_as_number
, CASE WHEN NULLIF(org_name,'') IS NULL THEN 9189 ELSE coalesce(NULLIF(gcpt_org_name_to_concept_temp4.value_as_concept_id,''), 0) END AS value_as_concept_id           -- staphiloccocus OR negative in case nothing
, CAST(null AS bigint) AS unit_concept_id
, CAST(null AS double precision) AS range_low
, CAST(null AS double precision) AS range_high
, CAST(null AS bigint) AS provider_id
, msm_admissions_temp3.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, culture.measurement_source_value AS measurement_source_value -- BLOOD
, msm_d_items_temp4.measurement_source_concept_id AS measurement_source_concept_id
, CAST(null AS text) AS unit_source_value
, culture.org_name AS value_source_value -- Staph...
FROM culture
LEFT JOIN msm_d_items_temp4 ON (spec_itemid = itemid)
LEFT JOIN gcpt_spec_type_to_concept_temp4 USING (measurement_source_value)
LEFT JOIN gcpt_org_name_to_concept_temp4 USING (org_name)
LEFT JOIN msm_patients_temp3 USING (subject_id)
LEFT JOIN msm_admissions_temp3 USING (hadm_id)
UNION ALL
SELECT
  measurement_id AS measurement_id
, msm_patients_temp3.person_id
, coalesce(NULLIF(gcpt_atb_to_concept_temp4.measurement_concept_id,''), 4170475) as measurement_concept_id      -- Culture Sensitivity
, measurement_date AS measurement_date
, measurement_datetime AS measurement_datetime
, 2000000008 AS measurement_type_concept_id -- Lab result
, operator_concept_id AS operator_concept_id -- = operator
, value_as_number AS value_as_number
, gcpt_resistance_to_concept_temp4.value_as_concept_id AS value_as_concept_id
, CAST(null AS bigint) AS unit_concept_id
, CAST(null AS double precision) AS range_low
, CAST(null AS double precision) AS range_high
, CAST(null AS bigint) AS provider_id
, msm_admissions_temp3.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, resistance.measurement_source_value AS measurement_source_value
, msm_d_items_temp4.measurement_source_concept_id AS measurement_source_concept_id
, CAST(null AS text) AS unit_source_value
, value_source_value AS  value_source_value
FROM resistance
LEFT JOIN msm_d_items_temp4 ON (ab_itemid = itemid)
LEFT JOIN gcpt_resistance_to_concept_temp4 USING (interpretation)
LEFT JOIN gcpt_atb_to_concept_temp4 USING (measurement_source_value)
LEFT JOIN msm_patients_temp3 USING (subject_id)
LEFT JOIN msm_admissions_temp3 USING (hadm_id)
LEFT JOIN msm_omop_operator_temp4 USING (operator_name);

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert_3.measurement_id
, msm_row_to_insert_3.person_id
, msm_row_to_insert_3.measurement_concept_id
, msm_row_to_insert_3.measurement_date
, msm_row_to_insert_3.measurement_datetime
, msm_row_to_insert_3.measurement_type_concept_id
, msm_row_to_insert_3.operator_concept_id
, msm_row_to_insert_3.value_as_number
, msm_row_to_insert_3.value_as_concept_id
, msm_row_to_insert_3.unit_concept_id
, msm_row_to_insert_3.range_low
, msm_row_to_insert_3.range_high
, msm_row_to_insert_3.provider_id
, msm_row_to_insert_3.visit_occurrence_id
, msm_row_to_insert_3.visit_detail_id --no visit_detail assignation since datetime is not relevant
, msm_row_to_insert_3.measurement_source_value
, msm_row_to_insert_3.measurement_source_concept_id
, msm_row_to_insert_3.unit_source_value
, msm_row_to_insert_3.value_source_value
FROM msm_row_to_insert_3;


--MEASUREMENT from chartevents (without labs)
CREATE TEMP VIEW "msm_chartevents_temp" as
SELECT
      c.mimic_id as measurement_id,
      c.subject_id,
      c.hadm_id,
      c.cgid,
      m.measurement_concept_id as measurement_concept_id,
      c.charttime as measurement_datetime,
      c.valuenum as value_as_number,
      v.concept_id as value_as_concept_id,
      m.unit_concept_id as unit_concept_id,
      concept.concept_id as measurement_source_concept_id,
      c.valueuom as unit_source_value,
      CASE
	WHEN d_items.category   = 'Text' THEN valuenum -- discreteous variable
        WHEN m.label_type = 'systolic_bp' AND regexp_like(value, '[0-9]+/[0-9]+') THEN CAST(regexp_replace(value,'([0-9]+)/[0-9]*','\\1') AS double precision)
        WHEN m.label_type = 'diastolic_bp' AND regexp_like(value, '[0-9]+/[0-9]+') THEN CAST(regexp_replace(value,'[0-9]*/([0-9]+)','\\1') AS double precision)
        WHEN m.label_type = 'map_bp' AND regexp_like(value, '[0-9]+/[0-9]+') THEN CAST(regexp_replace(value,'[0-9]+/([0-9]+)','\\1') AS FLOAT)+CAST((CAST(regexp_replace(value,'([0-9]+)/[0-9]+','\\1') AS FLOAT)/3) AS FLOAT)-CAST((CAST(regexp_replace(value,'[0-9]+/([0-9]+)','\\1') AS FLOAT)/3) AS FLOAT)
        WHEN m.label_type = 'fio2' AND c.valuenum between 0 AND 1 THEN c.valuenum * 100
	WHEN m.label_type = 'temperature' AND c.VALUENUM > 85 THEN (c.VALUENUM - 32)*5/9
	WHEN m.label_type = 'pain_level' THEN CASE
		WHEN LOWER(d_items.LABEL) LIKE 'level' THEN CASE
		      WHEN LOWER(c.VALUE) LIKE 'unable' THEN NULL
		      WHEN LOWER(c.VALUE) LIKE 'none' AND LOWER(c.VALUE) NOT LIKE 'mild' THEN 0
		      WHEN LOWER(c.VALUE) LIKE 'none' AND LOWER(c.VALUE) LIKE 'mild' THEN 1
		      WHEN LOWER(c.VALUE) LIKE 'mild' AND LOWER(c.VALUE) NOT LIKE 'mod' THEN 2
		      WHEN LOWER(c.VALUE) LIKE 'mild' AND LOWER(c.VALUE) LIKE 'mod' THEN 3
		      WHEN LOWER(c.VALUE) LIKE 'mod'  AND LOWER(c.VALUE) NOT LIKE 'sev' THEN 4
		      WHEN LOWER(c.VALUE) LIKE 'mod'  AND LOWER(c.VALUE) LIKE 'sev' THEN 5
		      WHEN LOWER(c.VALUE) LIKE 'sev'  AND LOWER(c.VALUE) NOT LIKE 'wor' THEN 6
		      WHEN LOWER(c.VALUE) LIKE 'sev'  AND LOWER(c.VALUE) LIKE 'wor' THEN 7
		      WHEN LOWER(c.VALUE) LIKE 'wor' THEN 8
		      ELSE NULL
		      END
		WHEN LOWER(c.VALUE) LIKE 'no' THEN 0
		WHEN LOWER(c.VALUE) LIKE 'yes' THEN  1
	        END
        WHEN m.label_type = 'sas_rass'  THEN CASE
                WHEN d_items.LABEL LIKE 'Riker%' THEN CASE
                      WHEN c.VALUE = 'Unarousable' THEN 1
                      WHEN c.VALUE = 'Very Sedated' THEN 2
                      WHEN c.VALUE = 'Sedated' THEN 3
                      WHEN c.VALUE = 'Calm/Cooperative' THEN 4
                      WHEN c.VALUE = 'Agitated' THEN 5
                      WHEN c.VALUE = 'Very Agitated' THEN 6
                      WHEN c.VALUE = 'Dangerous Agitation' THEN 7
                      ELSE NULL
                END
        END
	WHEN m.label_type = 'height_weight'  THEN CASE
		WHEN d_items.LABEL LIKE 'W' THEN CASE
	           WHEN LOWER(d_items.LABEL) LIKE 'lb' THEN 0.453592 * c.VALUENUM
		   ELSE NULL
		   END
		WHEN d_items.LABEL LIKE 'cm' THEN c.VALUENUM / CAST(100 AS numeric)
		ELSE 0.0254 * c.VALUENUM
		END
	ELSE NULL
	END AS valuenum_fromvalue,
      c.value as value_source_value,
      m.value_lb as value_lb,
      m.value_ub as value_ub,
      concept.concept_code AS measurement_source_value
    FROM chartevents as c
    JOIN OMOP.concept -- concept driven dispatcher
    ON (    concept_code  = CAST(c.itemid AS Text)
	AND domain_id     = 'Measurement'
	AND vocabulary_id = 'MIMIC d_items'
	AND concept_class_id IS NOT 'Labs'  -- NOTE: A IS NOT B => A IS DISTINCT FROM
	AND concept_class_id IS NOT 'Blood Gases'
	AND concept_class_id IS NOT 'Hematology'
	AND concept_class_id IS NOT 'Chemistry'
	AND concept_class_id IS NOT 'Heme/Coag'
	AND concept_class_id IS NOT 'Coags'
	AND concept_class_id IS NOT 'CSF'
	AND concept_class_id IS NOT 'Enzymes'
       )  -- remove the labs, because done before
    LEFT JOIN d_items USING (itemid)
    LEFT JOIN gcpt_chart_label_to_concept as m ON (label = d_label)
    LEFT JOIN
       (
	SELECT mimic_name, concept_id, CAST('heart_rhythm' AS text) AS label_type
	FROM gcpt_heart_rhythm_to_concept
       ) as v  ON m.label_type = v.label_type AND c.value = v.mimic_name
    WHERE NULLIF(error,'') IS NULL OR error= 0;

CREATE TEMP VIEW "msm_patients_temp5" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "msm_caregivers_temp5" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "msm_admissions_temp5" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "msm_row_to_insert_4" AS SELECT
  measurement_id AS measurement_id
, msm_patients_temp5.person_id
, coalesce(NULLIF(measurement_concept_id,''), 0) as measurement_concept_id
, CAST(measurement_datetime AS Text) AS measurement_date
, measurement_datetime AS measurement_datetime
, 44818701 as measurement_type_concept_id  -- from physical examination
, 4172703 AS operator_concept_id
, coalesce(NULLIF(valuenum_fromvalue,''), NULLIF(value_as_number,'')) AS value_as_number
, value_as_concept_id AS value_as_concept_id
, unit_concept_id AS unit_concept_id
, value_lb AS range_low
, value_ub AS range_high
, msm_caregivers_temp5.provider_id AS provider_id
, msm_admissions_temp5.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, measurement_source_value
, measurement_source_concept_id AS measurement_source_concept_id
, unit_source_value AS unit_source_value
, value_source_value AS  value_source_value
FROM msm_chartevents_temp
LEFT JOIN msm_patients_temp5 USING (subject_id)
LEFT JOIN msm_caregivers_temp5 USING (cgid)
LEFT JOIN msm_admissions_temp5 USING (hadm_id);

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert_4.measurement_id
, msm_row_to_insert_4.person_id
, msm_row_to_insert_4.measurement_concept_id
, msm_row_to_insert_4.measurement_date
, msm_row_to_insert_4.measurement_datetime
, msm_row_to_insert_4.measurement_type_concept_id
, msm_row_to_insert_4.operator_concept_id
, msm_row_to_insert_4.value_as_number
, msm_row_to_insert_4.value_as_concept_id
, msm_row_to_insert_4.unit_concept_id
, msm_row_to_insert_4.range_low
, msm_row_to_insert_4.range_high
, msm_row_to_insert_4.provider_id
, msm_row_to_insert_4.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, msm_row_to_insert_4.measurement_source_value
, msm_row_to_insert_4.measurement_source_concept_id
, msm_row_to_insert_4.unit_source_value
, msm_row_to_insert_4.value_source_value
FROM msm_row_to_insert_4
LEFT JOIN OMOP.visit_detail_assign
ON msm_row_to_insert_4.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND msm_row_to_insert_4.measurement_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND msm_row_to_insert_4.measurement_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND msm_row_to_insert_4.measurement_datetime > visit_detail_assign.visit_start_datetime AND msm_row_to_insert_4.measurement_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY measurement_id;

-- OUTPUT events
CREATE TEMP VIEW "msm_outputevents_temp" AS SELECT
  subject_id
, hadm_id
, itemid
, cgid
, valueuom AS unit_source_value
, CASE
    WHEN itemid IN (227488,227489) THEN -1 * value
    ELSE value
  END AS value
, mimic_id as measurement_id
, charttime as measurement_datetime
FROM outputevents
where NULLIF(iserror,'') is null;

CREATE TEMP VIEW "gcpt_output_label_to_concept_temp6" AS SELECT item_id as itemid, concept_id as measurement_concept_id FROM gcpt_output_label_to_concept;
CREATE TEMP VIEW "msm_gcpt_lab_unit_to_concept_temp6" AS SELECT unit as unit_source_value, concept_id as unit_concept_id FROM gcpt_lab_unit_to_concept;
CREATE TEMP VIEW "msm_patients_temp6" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW "msm_caregivers_temp6" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "msm_admissions_temp6" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "msm_row_to_insert_5" AS SELECT
  measurement_id AS measurement_id
, msm_patients_temp6.person_id
, coalesce(NULLIF(measurement_concept_id,''),0) as measurement_concept_id
, CAST(measurement_datetime AS Text) AS measurement_date
, measurement_datetime AS measurement_datetime
, 2000000003 as measurement_type_concept_id
, 4172703 AS operator_concept_id
, value AS value_as_number
, CAST(null AS bigint) AS value_as_concept_id
, unit_concept_id AS unit_concept_id
, CAST(null AS double precision) AS range_low
, CAST(null AS double precision) AS range_high
, msm_caregivers_temp6.provider_id AS provider_id
, msm_admissions_temp6.visit_occurrence_id AS visit_occurrence_id
, CAST(null AS bigint) As visit_detail_id
, d_items.label AS measurement_source_value
, d_items.mimic_id AS measurement_source_concept_id
, msm_outputevents_temp.unit_source_value AS unit_source_value
, CAST(null AS text) AS value_source_value
FROM msm_outputevents_temp
LEFT JOIN gcpt_output_label_to_concept_temp6 USING (itemid)
LEFT JOIN msm_gcpt_lab_unit_to_concept_temp6 ON LOWER(msm_gcpt_lab_unit_to_concept_temp6.unit_source_value) like msm_outputevents_temp.unit_source_value
LEFT JOIN d_items USING (itemid)
LEFT JOIN msm_patients_temp6 USING (subject_id)
LEFT JOIN msm_caregivers_temp6 USING (cgid)
LEFT JOIN msm_admissions_temp6 USING (hadm_id);

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert_5.measurement_id
, msm_row_to_insert_5.person_id
, msm_row_to_insert_5.measurement_concept_id
, msm_row_to_insert_5.measurement_date
, msm_row_to_insert_5.measurement_datetime
, msm_row_to_insert_5.measurement_type_concept_id
, msm_row_to_insert_5.operator_concept_id
, msm_row_to_insert_5.value_as_number
, msm_row_to_insert_5.value_as_concept_id
, msm_row_to_insert_5.unit_concept_id
, msm_row_to_insert_5.range_low
, msm_row_to_insert_5.range_high
, msm_row_to_insert_5.provider_id
, msm_row_to_insert_5.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, msm_row_to_insert_5.measurement_source_value
, msm_row_to_insert_5.measurement_source_concept_id
, msm_row_to_insert_5.unit_source_value
, msm_row_to_insert_5.value_source_value
FROM msm_row_to_insert_5
LEFT JOIN OMOP.visit_detail_assign
ON msm_row_to_insert_5.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND msm_row_to_insert_5.measurement_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND msm_row_to_insert_5.measurement_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND msm_row_to_insert_5.measurement_datetime > visit_detail_assign.visit_start_datetime AND msm_row_to_insert_5.measurement_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY measurement_id;

-- weight from inputevent_mv
CREATE TEMP VIEW "msm_patients_temp7" AS SELECT mimic_id AS person_id, subject_id FROM patients;
CREATE TEMP VIEW"msm_admissions_temp7" AS SELECT mimic_id AS visit_occurrence_id, hadm_id FROM admissions;
CREATE TEMP VIEW "msm_caregivers_temp7" AS SELECT mimic_id AS provider_id, cgid FROM caregivers;
CREATE TEMP VIEW "msm_row_to_insert_6" as
select
          ROW_NUMBER() OVER (ORDER BY inputevents_mv.mimic_id)+(SELECT observation_id FROM observation ORDER BY observation_id DESC) as measurement_id
        , person_id
        , 3025315 as measurement_concept_id  --loinc weight
        , CAST(starttime AS Text) as measurement_date
        , starttime as measurement_datetime
        , 44818701 as measurement_type_concept_id -- from physical examination
	, 4172703 as operator_concept_id
        , patientweight as value_as_number
        , CAST(null AS integer) as value_as_concept_id
        , 9529 as unit_concept_id --kilogram
	, CAST(null AS numeric) as range_low
	, CAST(null AS numeric) as range_high
        , msm_caregivers_temp7.provider_id
        , visit_occurrence_id
        , CAST(null AS text) as measurement_source_value
        , CAST(null AS integer) as measurement_source_concept_id
        , CAST(null AS text) as unit_source_value
        , CAST(null AS text) as value_source_value
	FROM inputevents_mv
        LEFT JOIN msm_patients_temp7 USING (subject_id)
        LEFT JOIN msm_caregivers_temp7 USING (cgid)
        LEFT JOIN msm_admissions_temp7 USING (hadm_id)
	WHERE NULLIF(patientweight,'') is not null;

INSERT INTO OMOP.measurement
(
	  measurement_id
	, person_id
	, measurement_concept_id
	, measurement_date
	, measurement_datetime
	, measurement_type_concept_id
	, operator_concept_id
	, value_as_number
	, value_as_concept_id
	, unit_concept_id
	, range_low
	, range_high
	, provider_id
	, visit_occurrence_id
	, visit_detail_id
	, measurement_source_value
	, measurement_source_concept_id
	, unit_source_value
	, value_source_value
)
SELECT
  msm_row_to_insert_6.measurement_id
, msm_row_to_insert_6.person_id
, msm_row_to_insert_6.measurement_concept_id
, msm_row_to_insert_6.measurement_date
, msm_row_to_insert_6.measurement_datetime
, msm_row_to_insert_6.measurement_type_concept_id
, msm_row_to_insert_6.operator_concept_id
, msm_row_to_insert_6.value_as_number
, msm_row_to_insert_6.value_as_concept_id
, msm_row_to_insert_6.unit_concept_id
, msm_row_to_insert_6.range_low
, msm_row_to_insert_6.range_high
, msm_row_to_insert_6.provider_id
, msm_row_to_insert_6.visit_occurrence_id
, visit_detail_assign.visit_detail_id
, msm_row_to_insert_6.measurement_source_value
, msm_row_to_insert_6.measurement_source_concept_id
, msm_row_to_insert_6.unit_source_value
, msm_row_to_insert_6.value_source_value
FROM msm_row_to_insert_6
LEFT JOIN OMOP.visit_detail_assign
ON msm_row_to_insert_6.visit_occurrence_id = visit_detail_assign.visit_occurrence_id
AND
(--only one visit_detail
(is_first IS TRUE AND is_last IS TRUE)
OR -- first
(is_first IS TRUE AND is_last IS FALSE AND msm_row_to_insert_6.measurement_datetime <= visit_detail_assign.visit_end_datetime)
OR -- last
(is_last IS TRUE AND is_first IS FALSE AND msm_row_to_insert_6.measurement_datetime > visit_detail_assign.visit_start_datetime)
OR -- middle
(is_last IS FALSE AND is_first IS FALSE AND msm_row_to_insert_6.measurement_datetime > visit_detail_assign.visit_start_datetime AND msm_row_to_insert_6.measurement_datetime <= visit_detail_assign.visit_end_datetime)
) GROUP BY measurement_id;

--UPDATING THE mimic_id_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_seq = (SELECT measurement_id FROM measurement ORDER BY measurement_id DESC LIMIT 1);

----- Updating non-standard concepts to standard concepts from manual mapping table------------------------
CREATE TEMP VIEW "upgraded_measurement_concepts" AS
 
SELECT measurement_concept_id, concept_id_1, concept.concept_name, standard_concept FROM measurement
LEFT JOIN concept ON measurement_concept_id = concept_id LEFT JOIN concept_relationship ON concept_id_2 = measurement_concept_id
WHERE standard_concept != 'S' AND relationship_id = 'Mapped from' GROUP BY measurement_concept_id;

--UPDATE measurement SET measurement_concept_id = (SELECT concept_id_1 FROM upgraded_measurement_concepts umc
--WHERE umc.measurement_concept_id = measurement.measurement_concept_id)
--WHERE measurement_concept_id IN (SELECT measurement_concept_id FROM upgraded_measurement_concepts);

--- NOTE: Automatic updating can be done by uncomenting the previous lines and comenting the next 13 lines below
UPDATE measurement SET measurement_concept_id = 3022217 WHERE measurement_concept_id = 3034795;
UPDATE measurement SET measurement_concept_id = 4265595 WHERE measurement_concept_id = 3036345;
UPDATE measurement SET measurement_concept_id = 46236952 WHERE measurement_concept_id = 3030354;
UPDATE measurement SET measurement_concept_id = 3028437 WHERE measurement_concept_id = 3004169;
UPDATE measurement SET measurement_concept_id = 3000593 WHERE measurement_concept_id = 3006751;
UPDATE measurement SET measurement_concept_id = 3028167 WHERE measurement_concept_id = 3000298;
UPDATE measurement SET measurement_concept_id = 3014037 WHERE measurement_concept_id = 3003381;
UPDATE measurement SET measurement_concept_id = 3001405 WHERE measurement_concept_id = 3023654;
UPDATE measurement SET measurement_concept_id = 40757349 WHERE measurement_concept_id = 3002269;
UPDATE measurement SET measurement_concept_id = 3007449 WHERE measurement_concept_id = 3036974;
UPDATE measurement SET measurement_concept_id = 40769146 WHERE measurement_concept_id = 3016141;
UPDATE measurement SET measurement_concept_id = 42869450 WHERE measurement_concept_id = 3039095;
UPDATE measurement SET measurement_concept_id = 3023029 WHERE measurement_concept_id = 3029375;
------------------------------------------------------------------------------------------------------------

COMMIT;