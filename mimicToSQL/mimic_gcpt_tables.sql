BEGIN;
.mode csv
.import 'mimicToSQL/concept/admission_location_to_concept.csv' gcpt_admission_location_to_concept
.import 'mimicToSQL/concept/admission_type_to_concept.csv' gcpt_admission_type_to_concept
.import 'mimicToSQL/concept/admissions_diagnosis_to_concept.csv' gcpt_admissions_diagnosis_to_concept
.import 'mimicToSQL/concept/atb_to_concept.csv' gcpt_atb_to_concept
.import 'mimicToSQL/concept/care_site.csv' gcpt_care_site
.import 'mimicToSQL/concept/chart_label_to_concept.csv' gcpt_chart_label_to_concept
.import 'mimicToSQL/concept/chart_observation_to_concept.csv' gcpt_chart_observation_to_concept
.import 'mimicToSQL/concept/continuous_unit_carevue.csv' gcpt_continuous_unit_carevue
.import 'mimicToSQL/concept/cpt4_to_concept.csv' gcpt_cpt4_to_concept
.import 'mimicToSQL/concept/cv_input_label_to_concept.csv' gcpt_cv_input_label_to_concept
--.import 'mimicToSQL/concept/datetimeevents_to_concept.csv' gcpt_datetimeevents_to_concept
.import 'mimicToSQL/concept/derived_to_concept.csv' gcpt_derived_to_concept
.import 'mimicToSQL/concept/discharge_location_to_concept.csv' gcpt_discharge_location_to_concept
.import 'mimicToSQL/concept/drgcode_to_concept.csv' gcpt_drgcode_to_concept
.import 'mimicToSQL/concept/ethnicity_to_concept.csv' gcpt_ethnicity_to_concept
.import 'mimicToSQL/concept/heart_rhythm_to_concept.csv' gcpt_heart_rhythm_to_concept
.import 'mimicToSQL/concept/inputevents_drug_to_concept.csv' gcpt_inputevents_drug_to_concept
.import 'mimicToSQL/concept/insurance_to_concept.csv' gcpt_insurance_to_concept
.import 'mimicToSQL/concept/lab_label_to_concept.csv' gcpt_lab_label_to_concept
.import 'mimicToSQL/concept/lab_unit_to_concept.csv' gcpt_lab_unit_to_concept
.import 'mimicToSQL/concept/lab_value_to_concept.csv' gcpt_lab_value_to_concept
.import 'mimicToSQL/concept/labs_from_chartevents_to_concept.csv' gcpt_labs_from_chartevents_to_concept
.import 'mimicToSQL/concept/labs_specimen_to_concept.csv' gcpt_labs_specimen_to_concept
.import 'mimicToSQL/concept/map_route_to_concept.csv' gcpt_map_route_to_concept
.import 'mimicToSQL/concept/marital_status_to_concept.csv' gcpt_marital_status_to_concept
.import 'mimicToSQL/concept/microbiology_specimen_to_concept.csv' gcpt_microbiology_specimen_to_concept
.import 'mimicToSQL/concept/mv_input_label_to_concept.csv' gcpt_mv_input_label_to_concept
.import 'mimicToSQL/concept/note_category_to_concept.csv' gcpt_note_category_to_concept
.import 'mimicToSQL/concept/note_section_to_concept.csv' gcpt_note_section_to_concept
.import 'mimicToSQL/concept/org_name_to_concept.csv' gcpt_org_name_to_concept
.import 'mimicToSQL/concept/output_label_to_concept.csv' gcpt_output_label_to_concept
.import 'mimicToSQL/concept/prescriptions_ndcisnullzero_to_concept.csv' gcpt_prescriptions_ndcisnullzero_to_concept
.import 'mimicToSQL/concept/procedure_to_concept.csv' gcpt_procedure_to_concept
.import 'mimicToSQL/concept/religion_to_concept.csv' gcpt_religion_to_concept
.import 'mimicToSQL/concept/resistance_to_concept.csv' gcpt_resistance_to_concept
.import 'mimicToSQL/concept/route_to_concept.csv' gcpt_route_to_concept
.import 'mimicToSQL/concept/seq_num_to_concept.csv' gcpt_seq_num_to_concept
.import 'mimicToSQL/concept/spec_type_to_concept.csv' gcpt_spec_type_to_concept
.import 'mimicToSQL/concept/unit_doseera_concept_id.csv' gcpt_unit_doseera_concept_id


ALTER TABLE gcpt_admission_location_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_admission_type_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_admissions_diagnosis_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_atb_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_care_site add column mimic_id INTEGER;
ALTER TABLE gcpt_chart_label_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_chart_observation_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_continuous_unit_carevue add column mimic_id INTEGER;
ALTER TABLE gcpt_cpt4_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_cv_input_label_to_concept add column mimic_id INTEGER;
--ALTER TABLE gcpt_datetimeevents_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_derived_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_discharge_location_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_drgcode_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_ethnicity_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_heart_rhythm_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_inputevents_drug_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_insurance_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_lab_label_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_lab_unit_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_lab_value_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_labs_from_chartevents_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_labs_specimen_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_map_route_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_marital_status_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_microbiology_specimen_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_mv_input_label_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_note_category_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_note_section_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_org_name_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_output_label_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_prescriptions_ndcisnullzero_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_procedure_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_religion_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_resistance_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_route_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_seq_num_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_spec_type_to_concept add column mimic_id INTEGER;
ALTER TABLE gcpt_unit_doseera_concept_id add column mimic_id INTEGER;

UPDATE gcpt_admission_location_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_admission_location_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_admission_type_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_admission_type_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_admissions_diagnosis_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_admissions_diagnosis_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_atb_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_atb_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_care_site SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_care_site ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_chart_label_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_chart_label_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_chart_observation_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_chart_observation_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_continuous_unit_carevue SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_continuous_unit_carevue ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_cpt4_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_cpt4_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_cv_input_label_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_cv_input_label_to_concept ORDER BY mimic_id DESC LIMIT 1);

--UPDATE gcpt_datetimeevents_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
--UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_datetimeevents_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_derived_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_derived_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_discharge_location_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_discharge_location_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_drgcode_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_drgcode_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_ethnicity_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_ethnicity_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_heart_rhythm_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_heart_rhythm_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_inputevents_drug_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_inputevents_drug_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_insurance_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_insurance_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_lab_label_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_lab_label_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_lab_unit_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_lab_unit_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_lab_value_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_lab_value_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_labs_from_chartevents_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_labs_from_chartevents_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_labs_specimen_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_labs_specimen_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_map_route_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_map_route_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_marital_status_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_marital_status_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_microbiology_specimen_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_microbiology_specimen_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_mv_input_label_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_mv_input_label_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_note_category_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_note_category_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_note_section_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_note_section_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_org_name_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_org_name_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_output_label_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_output_label_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_prescriptions_ndcisnullzero_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_prescriptions_ndcisnullzero_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_procedure_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_procedure_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_religion_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_religion_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_resistance_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_resistance_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_route_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_route_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_seq_num_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_seq_num_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_spec_type_to_concept SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_spec_type_to_concept ORDER BY mimic_id DESC LIMIT 1);

UPDATE gcpt_unit_doseera_concept_id SET mimic_id = (SELECT mimic_id_concept_seq FROM TEMP_SEQUENCES LIMIT 1)+ROWID;
UPDATE TEMP_SEQUENCES SET mimic_id_concept_seq = (SELECT mimic_id FROM gcpt_unit_doseera_concept_id ORDER BY mimic_id DESC LIMIT 1);

COMMIT;