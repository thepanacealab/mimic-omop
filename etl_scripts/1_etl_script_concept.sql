--MIMIC-OMOP
--concept_
BEGIN;
INSERT INTO OMOP.CONCEPT (
concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, concept_code, valid_start_date, valid_end_date
) VALUES
  (2000000000,'Stroke Volume Variation','Measurement','','Clinical Observation','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000001,'L/min/m2','Unit','','','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000002,'dynes.sec.cm-5/m2','Unit','','','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000003,'Output Event','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000004,'Intravenous Bolus','Type Concept','','Drug Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000005,'Intravenous Continous','Type Concept','','Drug Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000006,'Ward and physical location','Type Concept','','Visit Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000007,'Labs - Culture Organisms','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000008,'Labs - Culture Sensitivity','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000009,'Labs - Hemato','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000010,'Labs - Blood Gaz','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000011,'Labs - Chemistry','Type Concept','','Meas Type','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000012,'Visit Detail','Metadata','Domain','Domain','MIMIC Generated','1979-01-01','2099-01-01')
, (2000000013,'Unwkown Ward','Visit Detail','Visit Detail','Visit_detail','MIMIC Generated','1979-01-01','2099-01-01')
;

--ITEMS
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, 'label:[' || coalesce(NULLIF(label,''),'') ||']dbsource:[' || coalesce(NULLIF(dbsource,''),'') || ']linksto:[' || coalesce(NULLIF(linksto,''),'') ||']unitname:[' || coalesce(NULLIF(unitname,''),'') || ']param_type:[' || coalesce(NULLIF(param_type,''),'') || ']'  as concept_name
, CASE WHEN itemid IN
(
  225175 --See chart for initial patient assessment
, 225209 --Cash amount
, 225811 --CV - past medical history
, 225813 --Baseline pain level
, 226179 --No wallet / money
, 226180 --Sexuality / reproductive problems
, 227687 --Tobacco Use History
, 227688 --Smoking Cessation Info Offered through BIDMC Inpatient Guide
, 228236 --Insulin pump
, 225067 --Is the spokesperson the Health Care Proxy
, 225070 --Unable to assess psychological
, 225072 --Living situation
, 225074 --Any fear in relationships
, 225076 --Emotional / physical / sexual harm by partner or close relation
, 225078 --Social work consult
, 225082 --Pregnant
, 225083 --Pregnancy due date
, 225085 --Post menopausal
, 225086 --Unable to assess cognitive / perceptual
, 225087 --Visual / hearing deficit
, 225090 --Interpreter
, 225091 --Unable to assess activity / mobility
, 225092 --Self ADL
, 225094 --History of slips / falls
, 225097 --Balance
, 225099 --Judgement
, 225101 --Use of assistive devices
, 225103 --Intravenous  / IV access prior to admission
, 225105 --Unable to assess habits
, 225106 --ETOH
, 225108 --Tobacco use
, 225110 --Recreational drug use
, 225112 --Unable to assess pain
, 225113 --Currently experiencing pain
, 225117 --Unable to assess nutrition / education
, 225118 --Difficulty swallowing
, 225120 --Appetite
, 225122 --Special diet
, 225124 --Unintentional weight loss >10 lbs.
, 225126 --Dialysis patient
, 225128 --Last dialysis
, 225129 --Unable to assess teaching / learning needs
, 225131 --Teaching directed toward
, 225133 --Discharge needs
, 225135 --Consults
, 225137 --Patient valuables
, 225142 --Money given to hospital cashier
, 226719 --Last menses
, 225279 --Date of Admission to Hospital
, 225059 --Past medical history
, 916    --Allergy 1
, 927    --Allergy 2
, 935    --Allergy 3
, 925    --Marital Status
, 226381 --Marital Status
, 926    --Religion
, 226543 --Religion
) THEN CAST('Observation' as Text)
  WHEN itemid IN (SELECT DISTINCT itemid FROM MIMIC.DATETIMEEVENTS) THEN CAST('Observation' as Text)
  ELSE CAST('Measurement' as Text) END as domain_id
, 'MIMIC d_items' as vocabulary_id
, coalesce(NULLIF(category,''), '') as concept_class_id
, CAST(itemid as Text) as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM MIMIC.D_ITEMS;

INSERT INTO OMOP.CONCEPT_SYNONYM
(
  concept_id
, concept_synonym_name
, language_concept_id
)
select
  mimic_id
, abbreviation
, 0
from MIMIC.D_ITEMS
where label != abbreviation
and NULLIF(abbreviation,'') is not null;

INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id -- the d_items mimic_id
, 'label:[' || coalesce(NULLIF(label,''),'') || ']fluid:[' || coalesce(NULLIF(fluid,''),'') || ']loinc:[' || coalesce(NULLIF(loinc_code,''),'') || ']' as concept_name
, CAST('Measurement' as Text) as domain_id
, 'MIMIC d_labitems' as vocabulary_id
, coalesce(NULLIF(category,''),'') as concept_class_id -- OMOP Lab Test
, CAST(itemid as Text) as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM D_LABITEMS;

-- DRUGS
-- Generates LOCAL concepts for mimic drugs

CREATE TEMP VIEW "tmp" AS
SELECT
 DISTINCT concept_name
    , ROW_NUMBER() OVER (ORDER BY vocabulary_id)+(SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1) as concept_id
    , domain_id
    , vocabulary_id
    , concept_class_id
    , concept_code
    , drug_name_poe
    , drug_name_generic
    , drug
    FROM (
        select
        'drug:['|| coalesce(NULLIF(drug,''), NULLIF(drug_name_poe,''), NULLIF(drug_name_generic,''),'') ||']'||  'prod_strength:['||coalesce(NULLIF(prod_strength,''),'')||']'|| 'drug_type:['||coalesce(NULLIF(drug_type,''),'')||']'|| 'formulary_drug_cd:['||coalesce(NULLIF(formulary_drug_cd,''),'') || ']' || 'dose_unit_rx:[' || coalesce(NULLIF(dose_unit_rx,''),'') || ']'  as concept_name
        , CAST('Drug_exposure' as Text) as domain_id
        , 'MIMIC prescriptions' as vocabulary_id
        , '' as concept_class_id
        , 'gsn:['||coalesce(NULLIF(gsn,''),'')||']'|| 'ndc:['||coalesce(NULLIF(ndc,''),'')||']' as concept_code
        , drug_name_poe
        , drug_name_generic
        , drug
        from MIMIC.PRESCRIPTIONS);

INSERT INTO OMOP.CONCEPT_SYNONYM
(
  concept_id
, concept_synonym_name
, language_concept_id
)
select
  concept_id
, drug_name_poe
, 0
from tmp
--DISTINCT FROM was rewritten to this
WHERE ((drug_name_poe <> drug OR NULLIF(drug_name_poe,'') IS NULL OR NULLIF(drug,'') IS NULL) AND NOT (NULLIF(drug_name_poe,'') IS NULL AND NULLIF(drug,'') IS NULL))
and NULLIF(drug_name_poe,'') is not null
UNION ALL
select
  concept_id
, drug_name_generic
, 0
from tmp
--DISTINCT FROM was rewritten to this
WHERE ((drug_name_generic <> drug OR NULLIF(drug_name_generic,'') IS NULL OR NULLIF(drug,'') IS NULL) AND NOT (NULLIF(drug_name_generic,'') IS NULL AND NULLIF(drug,'') IS NULL))
and NULLIF(drug_name_generic,'') is not null;

--UPDATING THE mimic_id_concept_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT concept_id FROM OMOP.CONCEPT_SYNONYM ORDER BY concept_id DESC LIMIT 1);


INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  concept_id
, concept_name
, domain_id
, vocabulary_id
, concept_class_id
, concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM (
    SELECT
    DISTINCT concept_name
    , ROW_NUMBER() OVER (ORDER BY vocabulary_id)+(SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1) as concept_id
    , domain_id
    , vocabulary_id
    , concept_class_id
    , concept_code
    , drug_name_poe
    , drug_name_generic
    , drug
    FROM (
        select
        'drug:['|| coalesce(NULLIF(drug,''), NULLIF(drug_name_poe,''), NULLIF(drug_name_generic,''),'') ||']'||  'prod_strength:['||coalesce(NULLIF(prod_strength,''),'')||']'|| 'drug_type:['||coalesce(NULLIF(drug_type,''),'')||']'|| 'formulary_drug_cd:['||coalesce(NULLIF(formulary_drug_cd,''),'') || ']' || 'dose_unit_rx:[' || coalesce(NULLIF(dose_unit_rx,''),'') || ']'  as concept_name
        , CAST('Drug_exposure' as Text) as domain_id
        , 'MIMIC prescriptions' as vocabulary_id
        , '' as concept_class_id
        , 'gsn:['||coalesce(NULLIF(gsn,''),'')||']'|| 'ndc:['||coalesce(NULLIF(ndc,''),'')||']' as concept_code
        , drug_name_poe
        , drug_name_generic
        , drug
        from MIMIC.PRESCRIPTIONS
    )
);

--UPDATING THE mimic_id_concept_seq SEQUENCE
UPDATE MIMIC.TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT concept_id FROM OMOP.CONCEPT ORDER BY concept_id DESC LIMIT 1);

--d_icd_procedures
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, coalesce(NULLIF(long_title,''),NULLIF(short_title,'')) as concept_name
, CAST('d_icd_procedures' as Text) as domain_id
, 'MIMIC Local Codes' as vocabulary_id
, '4-dig billing code' as concept_class_id
, coalesce(NULLIF(icd9_code,''),'') as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM MIMIC.D_ICD_PROCEDURES;

INSERT INTO OMOP.CONCEPT_SYNONYM
(
  concept_id
, concept_synonym_name
, language_concept_id
)
select
  mimic_id
, short_title
, 0
from MIMIC.D_ICD_PROCEDURES
where NULLIF(short_title,'') is not null
and NULLIF(long_title,'') IS NOT NULL;

-- NOTE_NLP mapped sections
INSERT INTO OMOP.CONCEPT (
concept_name,concept_id,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
DISTINCT label_mapped as concept_name
, mimic_id as concept_id
, CAST('Note Nlp' as Text) as domain_id
, 'MIMIC Generated' as vocabulary_id
, 'Section' as concept_class_id -- OMOP Lab Test
, 'MIMIC Generated' as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM gcpt_note_section_to_concept;

-- Derived values
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, measurement_source_value as concept_name
, CAST('Meas Value' as Text) as domain_id
, 'MIMIC Generated' as vocabulary_id
, 'Derived Value' as concept_class_id -- :OMOP_SCHEMA Lab Test
,  itemid as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM gcpt_derived_to_concept;

--visit_occurrence_concept
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, admission_type as concept_name
, CAST('Visit' as Text) as domain_id
, 'MIMIC admissions' as vocabulary_id
, 'Visit' as concept_class_id
, '' as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM gcpt_admission_type_to_concept;

--visit_occurrence_admitting
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, admission_location as concept_name
, CAST('Place of Service' as Text) as domain_id
, 'MIMIC admissions' as vocabulary_id
, 'Place of Service' as concept_class_id
, '' as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM gcpt_admission_location_to_concept;


--visit_occurrence_discharge
INSERT INTO OMOP.CONCEPT (
concept_id,concept_name,domain_id,vocabulary_id,concept_class_id,concept_code,valid_start_date,valid_end_date
)
SELECT
  mimic_id as concept_id
, discharge_location as concept_name
, CAST('Place of Service' as Text) as domain_id
, 'MIMIC admissions' as vocabulary_id
, 'Place of Service' as concept_class_id
, '' as concept_code
, '1979-01-01' as valid_start_date
, '2099-01-01' as valid_end_date
FROM gcpt_discharge_location_to_concept;

COMMIT;