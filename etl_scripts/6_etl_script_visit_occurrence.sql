BEGIN;

WITH
"admissions_emerged" AS (SELECT subject_id, admission_location, discharge_location, mimic_id, coalesce(NULLIF(edregtime,''), NULLIF(admittime,'')) AS admittime, dischtime, admission_type, edregtime, diagnosis FROM admissions ),
"admissions_temp" AS (
                           SELECT subject_id
                                , admission_location
                                , discharge_location
                                , mimic_id as visit_occurrence_id
                                , (CASE WHEN dischtime > admittime THEN CAST(admittime AS text) ELSE CAST(dischtime AS text) END) as visit_start_date
                                , (CASE WHEN dischtime > admittime THEN admittime ELSE dischtime END) as visit_start_datetime
                                , (CASE WHEN dischtime > admittime THEN CAST(dischtime AS text) ELSE CAST(admittime AS text) END) as visit_end_date
                                , (CASE WHEN dischtime > admittime THEN dischtime ELSE admittime END) as visit_end_datetime
                                , 44818518 as visit_type_concept_id
                                , admission_type as visit_source_value
                                , admission_location as admitting_source_value
                                , discharge_location as discharge_to_source_value
				, diagnosis
                                , LAG(mimic_id) OVER ( PARTITION BY subject_id ORDER BY admittime ASC) as preceding_visit_occurrence_id
             FROM admissions_emerged
                  ),
"patients_temp" AS (SELECT subject_id, mimic_id as person_id FROM patients),
"gcpt_admission_type_to_concept_temp" AS (SELECT mimic_id as visit_source_concept_id, admission_type as visit_source_value, visit_concept_id FROM gcpt_admission_type_to_concept),
"gcpt_admission_location_to_concept_temp" AS (SELECT concept_id as admitting_concept_id, mimic_id as admitting_source_concept_id, admission_location FROM gcpt_admission_location_to_concept),
"gcpt_discharge_location_to_concept_temp" AS (SELECT concept_id as discharge_to_concept_id, mimic_id as discharge_to_source_concept_id, discharge_location FROM gcpt_discharge_location_to_concept),
"care_site" as (select care_site_id from OMOP.care_site where care_site_name = 'BIDMC') -- Beth Israel hospital for all
 INSERT INTO OMOP.VISIT_OCCURRENCE
 (
      visit_occurrence_id
    , person_id
    , visit_concept_id
    , visit_start_date
    , visit_start_datetime
    , visit_end_date
    , visit_end_datetime
    , visit_type_concept_id
    , provider_id
    , care_site_id
    , visit_source_value
    , visit_source_concept_id
    , admitting_concept_id --
    , admitting_source_value
    , admitting_source_concept_id
    , discharge_to_concept_id --
    , discharge_to_source_value
    , discharge_to_source_concept_id
    , preceding_visit_occurrence_id
 )
 SELECT
   admissions_temp.visit_occurrence_id
 , patients_temp.person_id
 , gcpt_admission_type_to_concept_temp.visit_concept_id
 , admissions_temp.visit_start_date
 , admissions_temp.visit_start_datetime
 , admissions_temp.visit_end_date
 , admissions_temp.visit_end_datetime
 , admissions_temp.visit_type_concept_id
 , CAST(null AS integer) as provider_id
 , care_site.care_site_id
 , gcpt_admission_type_to_concept_temp.visit_source_value
 , gcpt_admission_type_to_concept_temp.visit_source_concept_id
 , CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN  4216643 -- DEAD/EXPIRED
        ELSE gcpt_admission_location_to_concept_temp.admitting_concept_id END AS admitting_concept_id --
 , CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN 'DEAD/EXPIRED'
        ELSE gcpt_admission_location_to_concept_temp.admission_location END AS admitting_source_value
 , gcpt_admission_location_to_concept_temp.admitting_source_concept_id
 , CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN 4022058 --ORGAN DONOR
        ELSE gcpt_discharge_location_to_concept_temp.discharge_to_concept_id END AS discharge_to_concept_id --
 ,CASE WHEN LOWER(diagnosis) LIKE '%organ donor%' THEN diagnosis
       ELSE gcpt_discharge_location_to_concept_temp.discharge_location END AS  discharge_to_source_value
 , gcpt_discharge_location_to_concept_temp.discharge_to_source_concept_id
 , admissions_temp.preceding_visit_occurrence_id
   FROM admissions_temp
 LEFT JOIN gcpt_admission_location_to_concept_temp USING (admission_location)
 LEFT JOIN gcpt_discharge_location_to_concept_temp USING (discharge_location)
 LEFT JOIN gcpt_admission_type_to_concept_temp USING (visit_source_value)
 LEFT JOIN patients_temp USING (subject_id)
 left join care_site ON (1=1);

 COMMIT;