/*
Created: 22/8/2025
Modified: 25/10/2025
Model: Oracle 19c
Database: Oracle 19c
*/


-- Create sequences section -------------------------------------------------

CREATE SEQUENCE SEQ_HC_BAC_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_HCN_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_MSC_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PRL_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PRM_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PRT_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PMS_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PST_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PCD_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PRF_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_RDC_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_SCN_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_TRN_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_USR_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_BNE_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_DOT_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_BSC_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

CREATE SEQUENCE SEQ_HC_PCT_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 CACHE 20
/

CREATE SEQUENCE SEQ_HC_MVT_id
 INCREMENT BY 1
 START WITH 1
 NOMAXVALUE
 MINVALUE 1
 NOCACHE
/

-- Create tables section -------------------------------------------------

-- Table HC_Profile

CREATE TABLE HC_Profile(
  PRF_id Number NOT NULL,
  PRF_name Varchar2(30 ) NOT NULL,
  PRF_description Char(20 ),
  version Number NOT NULL
)
/

-- Add keys for table HC_Profile

ALTER TABLE HC_Profile ADD CONSTRAINT PK_HC_Profile PRIMARY KEY (PRF_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Profile.PRF_id IS 'Primary key of the profile'
/
COMMENT ON COLUMN HC_Profile.PRF_name IS 'Name of the profile'
/
COMMENT ON COLUMN HC_Profile.PRF_description IS 'Description of the profile'
/

-- Table HC_Screen

CREATE TABLE HC_Screen(
  SCN_id Number NOT NULL,
  SCN_name Varchar2(30 ) NOT NULL,
  FK_SCN_id Number,
  version Number NOT NULL
)
/

-- Create indexes for table HC_Screen

CREATE INDEX IX_Screen_Screen ON HC_Screen (FK_SCN_id)
/

-- Add keys for table HC_Screen

ALTER TABLE HC_Screen ADD CONSTRAINT PK_HC_Screen PRIMARY KEY (SCN_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Screen.SCN_id IS 'Primary key of the screen'
/
COMMENT ON COLUMN HC_Screen.SCN_name IS 'Name of the screen'
/

-- Table HC_Permission

CREATE TABLE HC_Permission(
  PMS_id Number NOT NULL,
  PMS_name Varchar2(30 ) NOT NULL,
  PMS_description Varchar2(200 ),
  version Number NOT NULL
)
/

-- Add keys for table HC_Permission

ALTER TABLE HC_Permission ADD CONSTRAINT PK_HC_Permission PRIMARY KEY (PMS_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Permission.PMS_id IS 'Primary key of the permission'
/
COMMENT ON COLUMN HC_Permission.PMS_name IS 'Name of the permission'
/
COMMENT ON COLUMN HC_Permission.PMS_description IS 'Description of the permission'
/

-- Table HC_PermissionXScreen

CREATE TABLE HC_PermissionXScreen(
  SCN_id Number NOT NULL,
  PMS_id Number NOT NULL
)
/

-- Add keys for table HC_PermissionXScreen

ALTER TABLE HC_PermissionXScreen ADD CONSTRAINT PK_HC_PermissionXScreen PRIMARY KEY (SCN_id,PMS_id)
/

-- Table HC_User

CREATE TABLE HC_User(
  USR_id Number NOT NULL,
  PF_id Number,
  USR_identification Varchar2(30 ) NOT NULL,
  USR_f_name Varchar2(30 ) NOT NULL,
  USR_identification_type Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_identification_type CHECK (USR_identification_type in ('N','F')),
  USR_civil_status Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_civil_status CHECK (USR_civil_status in ('S','M','D','W')),
  USR_home_address Varchar2(1000 ),
  USR_work_address Varchar2(1000 ),
  USR_phone Varchar2(30 ),
  USR_gender Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_gender CHECK (USR_gender in ('F','M','O')),
  USR_dateofbirth Date NOT NULL,
  USR_state Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_state CHECK (USR_state in ('A','I')),
  USR_type Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_type CHECK (USR_type in ('M','A')),
  USR_approved Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_USR_approved CHECK (USR_approved in ('Y','N')),
  USR_email Varchar2(200 ) NOT NULL,
  BAC_id Number,
  PR_id Number,
  USR_f_lastname Varchar2(30 ),
  USR_s_lastname Varchar2(30 ),
  version Number NOT NULL,
  USR_s_name Varchar2(30 )
)
/

-- Create indexes for table HC_User

CREATE INDEX IX_PayrollType_User ON HC_User (PR_id)
/

-- Add keys for table HC_User

ALTER TABLE HC_User ADD CONSTRAINT PK_HC_User PRIMARY KEY (USR_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_User.USR_id IS 'Primary key for user'
/
COMMENT ON COLUMN HC_User.PF_id IS 'Profile of the user once is approved'
/
COMMENT ON COLUMN HC_User.USR_identification IS 'Identification number of the user'
/
COMMENT ON COLUMN HC_User.USR_f_name IS 'First name of the User'
/
COMMENT ON COLUMN HC_User.USR_identification_type IS 'Type of the identification (N for National, F for Foreigner)'
/
COMMENT ON COLUMN HC_User.USR_civil_status IS 'S for Single, M  for Married, D for Divorced and W for Widowed'
/
COMMENT ON COLUMN HC_User.USR_home_address IS 'Address to user''s home'
/
COMMENT ON COLUMN HC_User.USR_work_address IS 'Address to user''s work place'
/
COMMENT ON COLUMN HC_User.USR_phone IS 'User''s phone number'
/
COMMENT ON COLUMN HC_User.USR_gender IS 'M for Male, F Female and O for other.'
/
COMMENT ON COLUMN HC_User.USR_dateofbirth IS 'Date of birth of the User'
/
COMMENT ON COLUMN HC_User.USR_state IS 'A for active and I for Inactive'
/
COMMENT ON COLUMN HC_User.USR_type IS 'Type of user (F for Medic and A for administrative)'
/
COMMENT ON COLUMN HC_User.USR_approved IS 'State of aprovation by an administrator, is needed for be used as a user and have a profile
(Y for yes and N for no)'
/
COMMENT ON COLUMN HC_User.USR_email IS 'Email of the user'
/
COMMENT ON COLUMN HC_User.BAC_id IS 'Main bank account of the user'
/
COMMENT ON COLUMN HC_User.USR_f_lastname IS 'First lastname of the user'
/
COMMENT ON COLUMN HC_User.USR_s_lastname IS 'Second lastname of the user'
/
COMMENT ON COLUMN HC_User.USR_s_name IS 'Second name of the User'
/

-- Table HC_ProfileXPermissionXScreen

CREATE TABLE HC_ProfileXPermissionXScreen(
  PRF_id Number NOT NULL,
  SCN_id Number NOT NULL,
  PMS_id Number NOT NULL
)
/

-- Add keys for table HC_ProfileXPermissionXScreen

ALTER TABLE HC_ProfileXPermissionXScreen ADD CONSTRAINT PK_HC_ProfileXPermissionXScreen PRIMARY KEY (PRF_id,SCN_id,PMS_id)
/

-- Table HC_RequestedDocument

CREATE TABLE HC_RequestedDocument(
  RDC_id Number NOT NULL,
  RDC_name Varchar2(30 ) NOT NULL,
  RDC_description Varchar2(30 ) NOT NULL,
  RDC_for_type Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_RDC_for_type CHECK (RDC_for_type in ('M','A')),
  DOT_id Number,
  version Number NOT NULL
)
/

-- Create indexes for table HC_RequestedDocument

CREATE INDEX IX_DocumentType_RequestedDocument ON HC_RequestedDocument (DOT_id)
/

-- Add keys for table HC_RequestedDocument

ALTER TABLE HC_RequestedDocument ADD CONSTRAINT PK_HC_RequestedDocument PRIMARY KEY (RDC_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_RequestedDocument.RDC_id IS 'PK of the requested document'
/
COMMENT ON COLUMN HC_RequestedDocument.RDC_name IS 'Name of the requested document'
/
COMMENT ON COLUMN HC_RequestedDocument.RDC_description IS 'Description of the requested document'
/
COMMENT ON COLUMN HC_RequestedDocument.RDC_for_type IS 'Type of user that needs to give this document (F for Medic, A for administrative and B for both)'
/

-- Table HC_UserXRequestedDocument

CREATE TABLE HC_UserXRequestedDocument(
  USR_id Number NOT NULL,
  RDC_id Number NOT NULL,
  URD_document_url Varchar2(1000 ) NOT NULL
)
/

-- Add keys for table HC_UserXRequestedDocument

ALTER TABLE HC_UserXRequestedDocument ADD CONSTRAINT PK_HC_UserXRequestedDocument PRIMARY KEY (USR_id,RDC_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_UserXRequestedDocument.USR_id IS 'User who bringed the document'
/
COMMENT ON COLUMN HC_UserXRequestedDocument.RDC_id IS 'Requested document '
/
COMMENT ON COLUMN HC_UserXRequestedDocument.URD_document_url IS 'Direction of the document bringed by the user'
/

-- Table HC_BankAccount

CREATE TABLE HC_BankAccount(
  BAC_account_number Varchar2(1000 ) NOT NULL,
  BAC_id Number NOT NULL,
  USR_id Number NOT NULL,
  BNE_id Number,
  version Number NOT NULL
)
/

-- Create indexes for table HC_BankAccount

CREATE INDEX IX_BankEntity ON HC_BankAccount (BNE_id)
/

-- Add keys for table HC_BankAccount

ALTER TABLE HC_BankAccount ADD CONSTRAINT PK_HC_BankAccount PRIMARY KEY (BAC_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_BankAccount.BAC_account_number IS 'Account number used for transactions
'
/
COMMENT ON COLUMN HC_BankAccount.BAC_id IS 'Primary key of the bank account'
/
COMMENT ON COLUMN HC_BankAccount.USR_id IS 'User owner of the bank account'
/

-- Table HC_HealthCenter

CREATE TABLE HC_HealthCenter(
  HCN_id Number NOT NULL,
  HCN_name Varchar2(30 ) NOT NULL,
  HCN_location Varchar2(2000 ) NOT NULL,
  HCN_phone_number Varchar2(30 ) NOT NULL,
  version Number NOT NULL
)
/

-- Add keys for table HC_HealthCenter

ALTER TABLE HC_HealthCenter ADD CONSTRAINT PK_HC_HealthCenter PRIMARY KEY (HCN_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_HealthCenter.HCN_id IS 'Primary key of the health center'
/
COMMENT ON COLUMN HC_HealthCenter.HCN_name IS 'Name of the health center'
/
COMMENT ON COLUMN HC_HealthCenter.HCN_location IS 'Location of the health center'
/
COMMENT ON COLUMN HC_HealthCenter.HCN_phone_number IS 'Phone number of the health center'
/

-- Table HC_Position

CREATE TABLE HC_Position(
  PST_id Number NOT NULL,
  PST_name Varchar2(30 ) NOT NULL,
  PST_description Varchar2(1000 ),
  PST_base_hourly_payment Number(10,2),
  PST_base_hourly_price Number(10,2),
  HCN_id Number NOT NULL,
  USR_id Number,
  PST_day_of_week Varchar2(3 ) NOT NULL
        CONSTRAINT CHK_PST_day_of_week CHECK (PST_day_of_week in ('MON','TUE','WED','THU','FRI','SAT','SUN')),
  TRN_id Number,
  version Number NOT NULL
)
/

-- Create indexes for table HC_Position

CREATE INDEX IX_HealthCenter_Position ON HC_Position (HCN_id)
/

CREATE INDEX IX_User_Position ON HC_Position (USR_id)
/

CREATE INDEX IX_Turn_Position ON HC_Position (TRN_id)
/

-- Add keys for table HC_Position

ALTER TABLE HC_Position ADD CONSTRAINT PK_HC_Position PRIMARY KEY (PST_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Position.PST_id IS 'Primary key of the position'
/
COMMENT ON COLUMN HC_Position.PST_name IS 'Name of the position'
/
COMMENT ON COLUMN HC_Position.PST_description IS 'Description of the position'
/
COMMENT ON COLUMN HC_Position.PST_base_hourly_payment IS 'Base rate of the hour for the worker'
/
COMMENT ON COLUMN HC_Position.PST_base_hourly_price IS 'Base rate of the hour for the health center'
/
COMMENT ON COLUMN HC_Position.PST_day_of_week IS 'Specic day of the week to the position to cover'
/

-- Table HC_Turn

CREATE TABLE HC_Turn(
  TRN_id Number NOT NULL,
  TRN_start_hour Number NOT NULL,
  TRN_end_hour Number NOT NULL
)
/

-- Add keys for table HC_Turn

ALTER TABLE HC_Turn ADD CONSTRAINT PK_HC_Turn PRIMARY KEY (TRN_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Turn.TRN_id IS 'Primary identifier of the turn'
/
COMMENT ON COLUMN HC_Turn.TRN_start_hour IS 'Start hour of the turn'
/
COMMENT ON COLUMN HC_Turn.TRN_end_hour IS 'End hour of the turn'
/

-- Table HC_Procedure

CREATE TABLE HC_Procedure(
  PCD_id Number NOT NULL,
  PCD_name Varchar2(200 ) NOT NULL,
  PCD_description Varchar2(2000 ),
  PCD_health_center_price Number(10,2) NOT NULL,
  PCD_medic_revenue Number(10,2) NOT NULL,
  USR_id Number NOT NULL,
  PCD_date Date NOT NULL,
  PCT_id Number NOT NULL,
  HCN_id Number NOT NULL,
  PCD_processed Varchar2(1 ) DEFAULT 'N' NOT NULL
        CONSTRAINT CHK_PCD_processed CHECK (PCD_processed in ('Y','N')),
  version Number NOT NULL
)
/

-- Create indexes for table HC_Procedure

CREATE INDEX IX_User_Procedure ON HC_Procedure (USR_id)
/

CREATE INDEX IX_Date_Procedure ON HC_Procedure (PCD_date)
/

CREATE INDEX IX_ProcedureType_Procedure ON HC_Procedure (PCT_id)
/

CREATE INDEX IX_HealthCenter_Procedure ON HC_Procedure (HCN_id)
/

-- Add keys for table HC_Procedure

ALTER TABLE HC_Procedure ADD CONSTRAINT PK_HC_Procedure PRIMARY KEY (PCD_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Procedure.PCD_id IS 'Primary identifier of the procedure'
/
COMMENT ON COLUMN HC_Procedure.PCD_name IS 'Name of the procedure'
/
COMMENT ON COLUMN HC_Procedure.PCD_description IS 'Description of the procedure'
/
COMMENT ON COLUMN HC_Procedure.PCD_health_center_price IS 'Price of the procedure for the health center'
/
COMMENT ON COLUMN HC_Procedure.PCD_medic_revenue IS 'Revenue of the medic for the procedure'
/
COMMENT ON COLUMN HC_Procedure.PCD_date IS 'Date of the procedure'
/
COMMENT ON COLUMN HC_Procedure.PCD_processed IS 'Indicates if the procedure has been processed for the payroll (Y for yes and N for no)'
/

-- Table HC_MonthScale

CREATE TABLE HC_MonthScale(
  MSC_id Number NOT NULL,
  MSC_state Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_MSC_state CHECK (MSC_state in ('B','A','R','P','C')),
  MSC_month Varchar2(3 ) NOT NULL
        CONSTRAINT CHK_MSC_month CHECK (MSC_month in ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC')),
  MSC_year Varchar2(4 ) NOT NULL,
  HCN_id Number NOT NULL,
  MSC_processed Varchar2(1 ) DEFAULT 'N' NOT NULL
        CONSTRAINT CHK_MSC_processed CHECK (MSC_processed in ('Y','N')),
  version Number NOT NULL
)
/

-- Create indexes for table HC_MonthScale

CREATE INDEX IX_HealthCenter_MonthScale ON HC_MonthScale (HCN_id)
/

-- Add keys for table HC_MonthScale

ALTER TABLE HC_MonthScale ADD CONSTRAINT PK_HC_MonthScale PRIMARY KEY (MSC_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_MonthScale.MSC_id IS 'Primary identifies of the scale'
/
COMMENT ON COLUMN HC_MonthScale.MSC_state IS 'Indicates the state of the scale B for Building, A for Active, R for Review, P for Payment, and C for Completed.'
/
COMMENT ON COLUMN HC_MonthScale.MSC_month IS 'Indicates the specific month of the scale'
/
COMMENT ON COLUMN HC_MonthScale.MSC_year IS 'Indicates the specific year of the scale'
/
COMMENT ON COLUMN HC_MonthScale.MSC_processed IS 'Indicates if the month scale has been processed for the payroll (Y for yes and N for no)'
/

-- Table HC_PayrollType

CREATE TABLE HC_PayrollType(
  PRT_id Number NOT NULL,
  PRT_name Varchar2(30 ) NOT NULL,
  PRT_html Varchar2(4000 ) NOT NULL,
  version Number NOT NULL
)
/

-- Add keys for table HC_PayrollType

ALTER TABLE HC_PayrollType ADD CONSTRAINT PK_HC_PayrollType PRIMARY KEY (PRT_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_PayrollType.PRT_id IS 'Primary identifier of the type of payroll'
/
COMMENT ON COLUMN HC_PayrollType.PRT_name IS 'Name of the payroll type'
/
COMMENT ON COLUMN HC_PayrollType.PRT_html IS 'HTML for this type of payroll'
/

-- Table HC_PayrollMovement

CREATE TABLE HC_PayrollMovement(
  PRM_id Number NOT NULL,
  PRM_amount Number(10,2) NOT NULL,
  PRM_amount_type Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_PRM_amount_type CHECK (PRM_amount_type in ('A','P')),
  PRM_name Varchar2(30 ) NOT NULL,
  PRM_description Varchar2(300 ),
  PRM_date Date NOT NULL,
  PRM_type Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_PRM_type CHECK (PRM_type in ('I','D')),
  MVT_id Number NOT NULL,
  USR_id Number NOT NULL,
  PRL_id Number NOT NULL,
  version Number NOT NULL
)
/

-- Create indexes for table HC_PayrollMovement

CREATE INDEX IX_MovementType_PayrollMovement ON HC_PayrollMovement (MVT_id)
/

CREATE INDEX IX_PayrollXUser_PayrollMovement ON HC_PayrollMovement (USR_id,PRL_id)
/

-- Add keys for table HC_PayrollMovement

ALTER TABLE HC_PayrollMovement ADD CONSTRAINT PK_HC_PayrollMovement PRIMARY KEY (PRM_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_PayrollMovement.PRM_id IS 'Primary identifier of the movement'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_amount IS 'Amount of money of the movement'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_amount_type IS 'Type of amount of the movement (A for absolute and P for percentage )'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_name IS 'Name of the movement'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_description IS 'Description of the movement'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_date IS 'Date of register of the movement'
/
COMMENT ON COLUMN HC_PayrollMovement.PRM_type IS 'Type of the movement (I for income and D for deduction)'
/

-- Table HC_Payroll

CREATE TABLE HC_Payroll(
  PRL_id Number NOT NULL,
  PRL_authorized Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_PRL_authorized CHECK (PRL_authorized in ('Y','N')),
  PRL_month Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_PRL_month CHECK (PRL_month in ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC')),
  PRL_year Varchar2(4 ) NOT NULL,
  PRL_deposited Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_PRL_deposited CHECK (PRL_deposited in ('Y','N')),
  PRT_id Number NOT NULL,
  version Number NOT NULL
)
/

-- Create indexes for table HC_Payroll

CREATE INDEX IX_PayrollType_Payroll ON HC_Payroll (PRT_id)
/

-- Add keys for table HC_Payroll

ALTER TABLE HC_Payroll ADD CONSTRAINT PK_HC_Payroll PRIMARY KEY (PRL_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_Payroll.PRL_id IS 'Primary identifier of the payroll'
/
COMMENT ON COLUMN HC_Payroll.PRL_authorized IS 'State of approval of the payroll (Y for authorized and N for Unathorized)'
/
COMMENT ON COLUMN HC_Payroll.PRL_month IS 'Month of the payroll'
/
COMMENT ON COLUMN HC_Payroll.PRL_year IS 'Year of the payroll'
/
COMMENT ON COLUMN HC_Payroll.PRL_deposited IS 'State of deposit of the payroll (Y for deposited and N for not deposited)'
/

-- Table HC_BankEntity

CREATE TABLE HC_BankEntity(
  BNE_id Number NOT NULL,
  BNE_name Varchar2(50 ) NOT NULL,
  version Number NOT NULL
)
/

-- Add keys for table HC_BankEntity

ALTER TABLE HC_BankEntity ADD CONSTRAINT PK_HC_BankEntity PRIMARY KEY (BNE_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_BankEntity.BNE_id IS 'Primary identifier of the bank entity'
/
COMMENT ON COLUMN HC_BankEntity.BNE_name IS 'Name of the bank entity'
/

-- Table HC_DocumentType

CREATE TABLE HC_DocumentType(
  DOT_id Number NOT NULL,
  DOT_name Varchar2(30 ) NOT NULL,
  version Number NOT NULL
)
/

-- Add keys for table HC_DocumentType

ALTER TABLE HC_DocumentType ADD CONSTRAINT PK_HC_DocumentType PRIMARY KEY (DOT_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_DocumentType.DOT_id IS 'Primary identifier of the document type'
/
COMMENT ON COLUMN HC_DocumentType.DOT_name IS 'Name of the document type'
/

-- Table HC_ProcedureType

CREATE TABLE HC_ProcedureType(
  PCT_id Number NOT NULL,
  PCT_name Varchar2(200 ) NOT NULL,
  PCT_description Varchar2(2000 ),
  version Number NOT NULL
)
/

-- Add keys for table HC_ProcedureType

ALTER TABLE HC_ProcedureType ADD CONSTRAINT PK_HC_ProcedureType PRIMARY KEY (PCT_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_ProcedureType.PCT_id IS 'Primary identifier of the procedure type'
/
COMMENT ON COLUMN HC_ProcedureType.PCT_name IS 'Name of the procedure type'
/
COMMENT ON COLUMN HC_ProcedureType.PCT_description IS 'Description of the procedure type'
/

-- Table HC_MovementType

CREATE TABLE HC_MovementType(
  MVT_id Number NOT NULL,
  MVT_name Varchar2(50 ) NOT NULL,
  MVT_description Varchar2(2000 ),
  MVT_automatic Varchar2(1 ) NOT NULL
        CONSTRAINT CHK_MVT_automatic CHECK (MVT_automatic in ('Y','N')),
  MVT_amount Number(12,2),
  MTV_amount_type Varchar2(1 )
        CONSTRAINT CHK_MTV_amount_type CHECK (MTV_amount_type in ('A','P')),
  MVT_lower_limit Number(12,2),
  MTV_upper_limit Number(12,2),
  version Number NOT NULL,
  MTV_type Varchar2(1 ) DEFAULT 'I' NOT NULL
        CONSTRAINT CHK_MTV_type CHECK (MTV_type in ('I','D'))
)
/

-- Add keys for table HC_MovementType

ALTER TABLE HC_MovementType ADD CONSTRAINT PK_HC_MovementType PRIMARY KEY (MVT_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_MovementType.MVT_id IS 'Primary identifier of the movement type'
/
COMMENT ON COLUMN HC_MovementType.MVT_name IS 'Name of the movement type'
/
COMMENT ON COLUMN HC_MovementType.MVT_description IS 'Description of the movement type'
/
COMMENT ON COLUMN HC_MovementType.MVT_automatic IS 'Indicates if the movements of this type shut be created automatically (Y for yes and N for no)'
/
COMMENT ON COLUMN HC_MovementType.MVT_amount IS 'Amount to be applied in case of an automatic movement'
/
COMMENT ON COLUMN HC_MovementType.MTV_amount_type IS 'Type of amount to be applied in case of an automatic movement(A for absolute and P for percentage )'
/
COMMENT ON COLUMN HC_MovementType.MVT_lower_limit IS 'If necessary, lower limit to apply the amount in case of automatic movement'
/
COMMENT ON COLUMN HC_MovementType.MTV_upper_limit IS 'If necessary, upper limit to apply the amount in case of automatic movement'
/
COMMENT ON COLUMN HC_MovementType.MTV_type IS 'Type of the movement type (I for income and D for deduction)'
/

-- Table HC_PayrollXUser

CREATE TABLE HC_PayrollXUser(
  USR_id Number NOT NULL,
  PRL_id Number NOT NULL,
  PRU_amount Number(12,2) DEFAULT 0.00 NOT NULL,
  PRU_account_number Varchar2(1000 ) NOT NULL,
  PRU_notified Varchar2(1 ) DEFAULT 'N' NOT NULL
        CONSTRAINT CHK_PRU_notified CHECK (PRU_notified in ('Y','N')),
  version Number NOT NULL
)
/

-- Add keys for table HC_PayrollXUser

ALTER TABLE HC_PayrollXUser ADD CONSTRAINT PK_HC_PayrollXUser PRIMARY KEY (USR_id,PRL_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_PayrollXUser.PRU_amount IS 'Total amount of the payroll to be paid to the user'
/
COMMENT ON COLUMN HC_PayrollXUser.PRU_account_number IS 'Account number to pay the payroll'
/
COMMENT ON COLUMN HC_PayrollXUser.PRU_notified IS 'Indicates if the notification email has been send (Y for yes and N for no)'
/

-- Table HC_TurnXMonthScale

CREATE TABLE HC_TurnXMonthScale(
  MSC_id Number NOT NULL,
  TRN_id Number NOT NULL,
  TMS_compliance Varchar2(3 ) DEFAULT 'PDG' NOT NULL
        CONSTRAINT CHK_TMS_compliance CHECK (TMS_compliance in ('F','PTL','PDG')),
  TMS_partial_worked_hours Number(10,2),
  TMS_date Date NOT NULL,
  USR_id Number,
  TMS_hourly_price Number(10,2),
  TMS_hourly_payment Number(10,2),
  TSM_name Varchar2(30 ) NOT NULL,
  TSM_description Varchar2(1000 ),
  TMS_processed Varchar2(1 ) DEFAULT 'N' NOT NULL
        CONSTRAINT CHK_TMS_processed CHECK (TMS_processed in ('Y','N')),
  version Number NOT NULL
)
/

-- Create indexes for table HC_TurnXMonthScale

CREATE INDEX IX_User_TurnXMonthScale ON HC_TurnXMonthScale (USR_id)
/

CREATE INDEX IX_MonthScale_TurnXMonthScale ON HC_TurnXMonthScale (MSC_id)
/

CREATE INDEX IX_Turn_TurnXMonthScale ON HC_TurnXMonthScale (TRN_id)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_TurnXMonthScale.TMS_compliance IS 'Compliance state of the turn (F for full, PTL for partial, PDG for pending)'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TMS_partial_worked_hours IS 'In case of compliance partial it indicates the amount of worked hours'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TMS_date IS 'Day to be worked by the  user'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TMS_hourly_price IS 'Price of the hour of this turn for the health center'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TMS_hourly_payment IS 'Payment of the hour for this turn'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TSM_name IS 'Name of the posiiton that is being covered'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TSM_description IS 'Description of the position that is being covered'
/
COMMENT ON COLUMN HC_TurnXMonthScale.TMS_processed IS 'Indicates if the turn on the month scale has been processed for the payroll (Y for yes and N for no)'
/

-- Table HC_MovementTypeXPayrollType

CREATE TABLE HC_MovementTypeXPayrollType(
  PRT_id Number NOT NULL,
  MVT_id Number NOT NULL
)
/

-- Add keys for table HC_MovementTypeXPayrollType

ALTER TABLE HC_MovementTypeXPayrollType ADD CONSTRAINT PK_HC_MovementTypeXPayrollType PRIMARY KEY (PRT_id,MVT_id)
/

-- Table HC_NationalRegister

CREATE TABLE HC_NationalRegister(
  NRG_national_identification Varchar2(30 ) NOT NULL,
  NRG_f_name Varchar2(30 ) NOT NULL,
  NRG_f_lastname Varchar2(30 ) NOT NULL,
  NRG_s_lastname Varchar2(30 ) NOT NULL,
  NRG_s_name Varchar2(30 ),
  version Number NOT NULL
)
/

-- Create indexes for table HC_NationalRegister

CREATE UNIQUE INDEX IX_national_identification ON HC_NationalRegister (NRG_national_identification)
/

-- Table and Columns comments section

COMMENT ON COLUMN HC_NationalRegister.NRG_national_identification IS 'National identification number of the person'
/
COMMENT ON COLUMN HC_NationalRegister.NRG_f_name IS 'First Name of the person'
/
COMMENT ON COLUMN HC_NationalRegister.NRG_f_lastname IS 'First last name of the person'
/
COMMENT ON COLUMN HC_NationalRegister.NRG_s_lastname IS 'Second last name of the person'
/
COMMENT ON COLUMN HC_NationalRegister.NRG_s_name IS 'Second Name of the person'
/

-- Table GeneralParameters

CREATE TABLE GeneralParameters(
  GP_name Varchar2(50 ) NOT NULL,
  GP_value Varchar2(500 ) NOT NULL,
  version Number NOT NULL
)
/

-- Create indexes for table GeneralParameters

CREATE UNIQUE INDEX IDX_GP_name ON GeneralParameters (GP_name)
/

-- Trigger for sequence SEQ_HC_PRF_id for column PRF_id in table HC_Profile ---------
CREATE OR REPLACE TRIGGER ts_HC_Profile_SEQ_HC_PRF_id BEFORE INSERT
ON HC_Profile FOR EACH ROW
BEGIN
  :new.PRF_id := SEQ_HC_PRF_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Profile_SEQ_HC_PRF_id AFTER UPDATE OF PRF_id
ON HC_Profile FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PRF_id in table HC_Profile as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_SCN_id for column SCN_id in table HC_Screen ---------
CREATE OR REPLACE TRIGGER ts_HC_Screen_SEQ_HC_SCN_id BEFORE INSERT
ON HC_Screen FOR EACH ROW
BEGIN
  :new.SCN_id := SEQ_HC_SCN_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Screen_SEQ_HC_SCN_id AFTER UPDATE OF SCN_id
ON HC_Screen FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column SCN_id in table HC_Screen as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PMS_id for column PMS_id in table HC_Permission ---------
CREATE OR REPLACE TRIGGER ts_HC_Permission_SEQ_HC_PMS_id BEFORE INSERT
ON HC_Permission FOR EACH ROW
BEGIN
  :new.PMS_id := SEQ_HC_PMS_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Permission_SEQ_HC_PMS_id AFTER UPDATE OF PMS_id
ON HC_Permission FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PMS_id in table HC_Permission as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_USR_id for column USR_id in table HC_User ---------
CREATE OR REPLACE TRIGGER ts_HC_User_SEQ_HC_USR_id BEFORE INSERT
ON HC_User FOR EACH ROW
BEGIN
  :new.USR_id := SEQ_HC_USR_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_User_SEQ_HC_USR_id AFTER UPDATE OF USR_id
ON HC_User FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column USR_id in table HC_User as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_RDC_id for column RDC_id in table HC_RequestedDocument ---------
CREATE OR REPLACE TRIGGER ts_HC_RequestedDocument_SEQ_HC_RDC_id BEFORE INSERT
ON HC_RequestedDocument FOR EACH ROW
BEGIN
  :new.RDC_id := SEQ_HC_RDC_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_RequestedDocument_SEQ_HC_RDC_id AFTER UPDATE OF RDC_id
ON HC_RequestedDocument FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column RDC_id in table HC_RequestedDocument as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_BAC_id for column BAC_id in table HC_BankAccount ---------
CREATE OR REPLACE TRIGGER ts_HC_BankAccount_SEQ_HC_BAC_id BEFORE INSERT
ON HC_BankAccount FOR EACH ROW
BEGIN
  :new.BAC_id := SEQ_HC_BAC_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_BankAccount_SEQ_HC_BAC_id AFTER UPDATE OF BAC_id
ON HC_BankAccount FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column BAC_id in table HC_BankAccount as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_HCN_id for column HCN_id in table HC_HealthCenter ---------
CREATE OR REPLACE TRIGGER ts_HC_HealthCenter_SEQ_HC_HCN_id BEFORE INSERT
ON HC_HealthCenter FOR EACH ROW
BEGIN
  :new.HCN_id := SEQ_HC_HCN_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_HealthCenter_SEQ_HC_HCN_id AFTER UPDATE OF HCN_id
ON HC_HealthCenter FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column HCN_id in table HC_HealthCenter as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PST_id for column PST_id in table HC_Position ---------
CREATE OR REPLACE TRIGGER ts_HC_Position_SEQ_HC_PST_id BEFORE INSERT
ON HC_Position FOR EACH ROW
BEGIN
  :new.PST_id := SEQ_HC_PST_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Position_SEQ_HC_PST_id AFTER UPDATE OF PST_id
ON HC_Position FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PST_id in table HC_Position as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_TRN_id for column TRN_id in table HC_Turn ---------
CREATE OR REPLACE TRIGGER ts_HC_Turn_SEQ_HC_TRN_id BEFORE INSERT
ON HC_Turn FOR EACH ROW
BEGIN
  :new.TRN_id := SEQ_HC_TRN_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Turn_SEQ_HC_TRN_id AFTER UPDATE OF TRN_id
ON HC_Turn FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column TRN_id in table HC_Turn as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PCD_id for column PCD_id in table HC_Procedure ---------
CREATE OR REPLACE TRIGGER ts_HC_Procedure_SEQ_HC_PCD_id BEFORE INSERT
ON HC_Procedure FOR EACH ROW
BEGIN
  :new.PCD_id := SEQ_HC_PCD_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Procedure_SEQ_HC_PCD_id AFTER UPDATE OF PCD_id
ON HC_Procedure FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PCD_id in table HC_Procedure as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_MSC_id for column MSC_id in table HC_MonthScale ---------
CREATE OR REPLACE TRIGGER ts_HC_MonthScale_SEQ_HC_MSC_id BEFORE INSERT
ON HC_MonthScale FOR EACH ROW
BEGIN
  :new.MSC_id := SEQ_HC_MSC_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_MonthScale_SEQ_HC_MSC_id AFTER UPDATE OF MSC_id
ON HC_MonthScale FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column MSC_id in table HC_MonthScale as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PRT_id for column PRT_id in table HC_PayrollType ---------
CREATE OR REPLACE TRIGGER ts_HC_PayrollType_SEQ_HC_PRT_id BEFORE INSERT
ON HC_PayrollType FOR EACH ROW
BEGIN
  :new.PRT_id := SEQ_HC_PRT_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_PayrollType_SEQ_HC_PRT_id AFTER UPDATE OF PRT_id
ON HC_PayrollType FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PRT_id in table HC_PayrollType as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PRM_id for column PRM_id in table HC_PayrollMovement ---------
CREATE OR REPLACE TRIGGER ts_HC_PayrollMovement_SEQ_HC_PRM_id BEFORE INSERT
ON HC_PayrollMovement FOR EACH ROW
BEGIN
  :new.PRM_id := SEQ_HC_PRM_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_PayrollMovement_SEQ_HC_PRM_id AFTER UPDATE OF PRM_id
ON HC_PayrollMovement FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PRM_id in table HC_PayrollMovement as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PRL_id for column PRL_id in table HC_Payroll ---------
CREATE OR REPLACE TRIGGER ts_HC_Payroll_SEQ_HC_PRL_id BEFORE INSERT
ON HC_Payroll FOR EACH ROW
BEGIN
  :new.PRL_id := SEQ_HC_PRL_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_Payroll_SEQ_HC_PRL_id AFTER UPDATE OF PRL_id
ON HC_Payroll FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PRL_id in table HC_Payroll as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_BNE_id for column BNE_id in table HC_BankEntity ---------
CREATE OR REPLACE TRIGGER ts_HC_BankEntity_SEQ_HC_BNE_id BEFORE INSERT
ON HC_BankEntity FOR EACH ROW
BEGIN
  :new.BNE_id := SEQ_HC_BNE_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_BankEntity_SEQ_HC_BNE_id AFTER UPDATE OF BNE_id
ON HC_BankEntity FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column BNE_id in table HC_BankEntity as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_DOT_id for column DOT_id in table HC_DocumentType ---------
CREATE OR REPLACE TRIGGER ts_HC_DocumentType_SEQ_HC_DOT_id BEFORE INSERT
ON HC_DocumentType FOR EACH ROW
BEGIN
  :new.DOT_id := SEQ_HC_DOT_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_DocumentType_SEQ_HC_DOT_id AFTER UPDATE OF DOT_id
ON HC_DocumentType FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column DOT_id in table HC_DocumentType as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_PCT_id for column PCT_id in table HC_ProcedureType ---------
CREATE OR REPLACE TRIGGER ts_HC_ProcedureType_SEQ_HC_PCT_id BEFORE INSERT
ON HC_ProcedureType FOR EACH ROW
BEGIN
  :new.PCT_id := SEQ_HC_PCT_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_ProcedureType_SEQ_HC_PCT_id AFTER UPDATE OF PCT_id
ON HC_ProcedureType FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column PCT_id in table HC_ProcedureType as it uses sequence.');
END;
/

-- Trigger for sequence SEQ_HC_MVT_id for column MVT_id in table HC_MovementType ---------
CREATE OR REPLACE TRIGGER ts_HC_MovementType_SEQ_HC_MVT_id BEFORE INSERT
ON HC_MovementType FOR EACH ROW
BEGIN
  :new.MVT_id := SEQ_HC_MVT_id.nextval;
END;
/
CREATE OR REPLACE TRIGGER tsu_HC_MovementType_SEQ_HC_MVT_id AFTER UPDATE OF MVT_id
ON HC_MovementType FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(-20010,'Cannot update column MVT_id in table HC_MovementType as it uses sequence.');
END;
/


-- Create foreign keys (relationships) section ------------------------------------------------- 

ALTER TABLE HC_PermissionXScreen ADD CONSTRAINT HC_FK_PermissionXScreen_Screen FOREIGN KEY (SCN_id) REFERENCES HC_Screen (SCN_id)
/



ALTER TABLE HC_PermissionXScreen ADD CONSTRAINT HC_FK_PermissionXScreen_Permission FOREIGN KEY (PMS_id) REFERENCES HC_Permission (PMS_id)
/



ALTER TABLE HC_User ADD CONSTRAINT HC_FK_User_Profile FOREIGN KEY (PF_id) REFERENCES HC_Profile (PRF_id)
/



ALTER TABLE HC_ProfileXPermissionXScreen ADD CONSTRAINT HC_FK_ProfileXPermisionXScreen_Profile FOREIGN KEY (PRF_id) REFERENCES HC_Profile (PRF_id)
/



ALTER TABLE HC_ProfileXPermissionXScreen ADD CONSTRAINT HC_FK_ProfileXPermissionXScreen_PermissionXScreen FOREIGN KEY (SCN_id, PMS_id) REFERENCES HC_PermissionXScreen (SCN_id, PMS_id)
/



ALTER TABLE HC_UserXRequestedDocument ADD CONSTRAINT HC_FK_UserXRequestDocument_User FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_UserXRequestedDocument ADD CONSTRAINT HC_FK_UserXRequesteDocument_RequestedDocument FOREIGN KEY (RDC_id) REFERENCES HC_RequestedDocument (RDC_id)
/



ALTER TABLE HC_BankAccount ADD CONSTRAINT HC_FK_BankAccount_User FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_User ADD CONSTRAINT HC_FK_BankAccount_User_02 FOREIGN KEY (BAC_id) REFERENCES HC_BankAccount (BAC_id)
/



ALTER TABLE HC_User ADD CONSTRAINT HC_FK_PayrollType_User FOREIGN KEY (PR_id) REFERENCES HC_PayrollType (PRT_id)
/



ALTER TABLE HC_Procedure ADD CONSTRAINT HC_FK_ProcedureXUser FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_BankAccount ADD CONSTRAINT HC_BankEntity_BankAccount FOREIGN KEY (BNE_id) REFERENCES HC_BankEntity (BNE_id)
/



ALTER TABLE HC_RequestedDocument ADD CONSTRAINT HC_FK_DocumentType_RequestedDocument FOREIGN KEY (DOT_id) REFERENCES HC_DocumentType (DOT_id)
/



ALTER TABLE HC_Screen ADD CONSTRAINT HC_FK_Screen_Screen FOREIGN KEY (FK_SCN_id) REFERENCES HC_Screen (SCN_id)
/



ALTER TABLE HC_MonthScale ADD CONSTRAINT HC_FK_MonthScale_HealthCenter FOREIGN KEY (HCN_id) REFERENCES HC_HealthCenter (HCN_id)
/



ALTER TABLE HC_Procedure ADD CONSTRAINT HC_FK_Procedure_ProcedureType FOREIGN KEY (PCT_id) REFERENCES HC_ProcedureType (PCT_id)
/



ALTER TABLE HC_PayrollMovement ADD CONSTRAINT HC_FK_MovementType_PayrollMovement FOREIGN KEY (MVT_id) REFERENCES HC_MovementType (MVT_id)
/



ALTER TABLE HC_Payroll ADD CONSTRAINT HC_FK_Payroll_PayrollType FOREIGN KEY (PRT_id) REFERENCES HC_PayrollType (PRT_id)
/



ALTER TABLE HC_PayrollXUser ADD CONSTRAINT HC_FK_PayrollXUser_User FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_PayrollXUser ADD CONSTRAINT HC_FK_PayrollXUser_Payroll FOREIGN KEY (PRL_id) REFERENCES HC_Payroll (PRL_id)
/



ALTER TABLE HC_Position ADD CONSTRAINT HC_FK_Position_HealthCenter FOREIGN KEY (HCN_id) REFERENCES HC_HealthCenter (HCN_id)
/



ALTER TABLE HC_Position ADD CONSTRAINT HC_FK_Position_User FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_TurnXMonthScale ADD CONSTRAINT HC_FK_TurnXMonthScale_MonthScale FOREIGN KEY (MSC_id) REFERENCES HC_MonthScale (MSC_id)
/



ALTER TABLE HC_TurnXMonthScale ADD CONSTRAINT HC_FK_TurnXMonthScale_Turn FOREIGN KEY (TRN_id) REFERENCES HC_Turn (TRN_id)
/



ALTER TABLE HC_TurnXMonthScale ADD CONSTRAINT HC_FK_TurnXMonthScale_User FOREIGN KEY (USR_id) REFERENCES HC_User (USR_id)
/



ALTER TABLE HC_Position ADD CONSTRAINT HC_FK_Position_Turn FOREIGN KEY (TRN_id) REFERENCES HC_Turn (TRN_id)
/



ALTER TABLE HC_Procedure ADD CONSTRAINT HC_FK_Procedure_HealthCenter FOREIGN KEY (HCN_id) REFERENCES HC_HealthCenter (HCN_id)
/



ALTER TABLE HC_MovementTypeXPayrollType ADD CONSTRAINT HC_FK_MovementTypeXPayrollType_PayrollType FOREIGN KEY (PRT_id) REFERENCES HC_PayrollType (PRT_id)
/



ALTER TABLE HC_MovementTypeXPayrollType ADD CONSTRAINT HC_FK_MovementTypeXPayrollType_MovementType FOREIGN KEY (MVT_id) REFERENCES HC_MovementType (MVT_id)
/



ALTER TABLE HC_PayrollMovement ADD CONSTRAINT HC_FK_PayrollMovement_PayrollXUser FOREIGN KEY (USR_id, PRL_id) REFERENCES HC_PayrollXUser (USR_id, PRL_id)
/





