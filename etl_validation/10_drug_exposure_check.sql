BEGIN;
SELECT "Drug exposure - Check number of patients with prescription matches (OMOP):";
SELECT COUNT(distinct person_id), COUNT(distinct visit_occurrence_id)
FROM omop.drug_exposure
WHERE drug_type_concept_id = 38000177;
SELECT "Drug exposure - Check number of patients with prescription matches (MIMIC):";
SELECT COUNT(distinct subject_id), COUNT(distinct hadm_id)
FROM prescriptions;
SELECT "==============================================================================";
/*This test case is still experimental since it requires manual mapping
Check Line 18 from the 12_etl_script_drug_exposure.sql Script
Moreover, on line 59 from the same script, the code is mapping 
an ndc code with a concept value (a number with a string, which does NOT match)

SELECT "Drug exposure - Check drug_source_value matches source (OMOP):";
SELECT CAST(drug_source_value AS text), COUNT(1) FROM omop.drug_exposure
  WHERE drug_type_concept_id = 38000177
  GROUP BY 1 ORDER BY 2,1 DESC;
SELECT "Drug exposure - Check drug_source_value matches source (MIMIC):";
SELECT CAST(drug AS text), COUNT(1) FROM prescriptions GROUP BY 1 ORDER by 2,1 DESC;
SELECT "==============================================================================";
*/
SELECT "OMOP Drug exposure - Is concept source id full filled (Actual Result):";
SELECT CAST(COUNT(1) AS integer) FROM omop.drug_exposure WHERE drug_source_concept_id = 0;
SELECT "OMOP Drug exposure - Is concept source id full filled (Expected):";
SELECT 0;
SELECT "==============================================================================";

SELECT "OMOP Drug exposure - Standard concept checker (Actual Result):";
SELECT CAST(COUNT(1) AS integer) FROM omop.drug_exposure
LEFT JOIN omop.concept ON drug_concept_id = concept_id
WHERE drug_concept_id != 0 AND standard_concept != 'S';
SELECT "OMOP Drug exposure - Standard concept checker (Expected):";
SELECT 0;

ROLLBACK;