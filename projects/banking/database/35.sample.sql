UPDATE orgs SET org_name = 'OpenBaraza', cert_number = 'C.102554', pin = 'P051165288J', vat_number = '0142653A', 
default_country_id = 'KE', currency_id = 1,
org_full_name = 'OpenBaraza',
invoice_footer = 'Make all payments to : OpenBaraza
Thank you for your Business
We Turn your information into profitability'
WHERE org_id = 0;

UPDATE transaction_counters SET document_number = '10001';

INSERT INTO address (org_id, sys_country_id, table_name, table_id, post_office_box, postal_code, premises, street, town, phone_number, extension, mobile, fax, email, website, is_default, first_password, details) 
VALUES (0, 'KE', 'orgs', 0, '45689', '00100', '12th Floor, Barclays Plaza', 'Loita Street', 'Nairobi', '+254 (20) 2227100/2243097', NULL, '+254 725 819505 or +254 738 819505', NULL, 'accounts@dewcis.com', 'www.dewcis.com', true, NULL, NULL);

DELETE FROM currency WHERE currency_id IN (2, 3, 4);

INSERT INTO fiscal_years (fiscal_year, org_id, fiscal_year_start, fiscal_year_end) VALUES
('2017', 0, '2017-01-01', '2017-12-31'),
('2018', 0, '2018-01-01', '2018-12-31');

SELECT add_periods(fiscal_year_id::text, null, null)
FROM fiscal_years
ORDER BY fiscal_year_id;

UPDATE periods SET opened = true WHERE start_date <= current_date;
UPDATE periods SET activated = true WHERE start_date <= current_date;

INSERT INTO customers (customer_id, entity_id, org_id, business_account, person_title, customer_name, identification_number, identification_type, client_email, telephone_number, telephone_number2, address, town, zip_code, date_of_birth, gender, nationality, marital_status, picture_file, employed, self_employed, employer_name, monthly_salary, monthly_net_income, annual_turnover, annual_net_income, employer_address, introduced_by, application_date, approve_status, workflow_table_id, action_date, details) VALUES 
(1, 0, 0, 1, NULL, 'Open Baraza', 'C732423423', 'Certificate', 'info@openbaraza.org', '797897897', NULL, '23423', 'Nairobi', '00100', '2014-06-10', NULL, 'KE', NULL, NULL, true, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:15:24.095569', 'Approved', 1, '2017-06-07 15:09:33.88081', NULL),
(2, 0, 0, 1, NULL, 'Dew CIS Solutions Ltd', 'C7878978', 'Certificate', 'info@dewcis.com', '797897897', NULL, '23423', 'Nairobi', '00100', '2014-06-10', NULL, 'KE', NULL, NULL, true, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:15:24.095569', 'Approved', 1, '2017-06-07 15:09:33.88081', NULL),
(3, 0, 0, 0, 'Mr', 'Dennis Wachira Gichangi', '787897897', 'ID', 'dennis@dennis.me.ke', '797897897', NULL, '23423', 'Nairobi', NULL, '2010-06-08', 'M', 'KE', 'M', NULL, true, false, 'Dew CIS Solutions Ltd', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 14:14:49.971406', 'Approved', 2, '2017-06-07 15:09:33.906413', NULL),
(4, 0, 0, 0, 'Mrs', 'Rachel Mogire', '9898989', 'ID', 'rachel@gmail.com', '79878977', NULL, '778778', 'Nairobi', '00100', '1980-02-05', 'F', 'KE', 'M', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Approved', 3, '2017-06-07 15:09:33.922914', NULL),
(5, 0, 0, 0, 'Miss', 'Florence Ngugi', '543253453', 'ID', 'fngugi@gmail.com', '79878977', NULL, '778778', 'Nairobi', '00100', '1980-02-05', 'F', 'KE', 'M', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Approved', 3, '2017-06-07 15:09:33.922914', NULL),
(6, 0, 0, 0, 'Mr', 'Blackshamrat Sazzadur Rahman', '453443545', 'ID', 'bsazzadur@gmail.com', '79878977', NULL, '778778', 'Nairobi', '00100', '1980-02-05', 'F', 'KE', 'M', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Approved', 3, '2017-06-07 15:09:33.922914', NULL),
(7, 0, 0, 0, 'Mr', 'Ondero Stanley Makori', '4567654765', 'ID', 'smakori@gmail.com', '79878977', NULL, '778778', 'Nairobi', '00100', '1980-02-05', 'F', 'KE', 'M', NULL, true, false, 'Dew CIS', NULL, NULL, NULL, NULL, NULL, NULL, '2017-06-07 15:06:57.308398', 'Approved', 3, '2017-06-07 15:09:33.922914', NULL);

SELECT pg_catalog.setval('customers_customer_id_seq', 3, true);

UPDATE entitys SET customer_id = 1;

INSERT INTO deposit_accounts (customer_id, product_id, entity_id, org_id, opening_date, is_active) VALUES
(1, 1, 0, 0, '2017-02-02', true),
(1, 3, 0, 0, '2017-02-02', true),
(2, 1, 0, 0, '2017-03-02', true),
(2, 3, 0, 0, '2017-03-02', true),
(3, 3, 0, 0, '2017-04-02', true),
(4, 1, 0, 0, '2017-05-02', true),
(5, 3, 0, 0, '2017-06-02', true),
(6, 1, 0, 0, '2017-07-02', true),
(7, 3, 0, 0, '2017-08-02', true);

UPDATE deposit_accounts SET approve_status = 'Completed';
UPDATE deposit_accounts SET approve_status = 'Approved';

INSERT INTO loans (customer_id, product_id, entity_id, org_id, disburse_account, principal_amount, repayment_period, disbursed_date) VALUES
(1, 2, 0, 0, '400000105', 100000, 10, '2017-04-12'),
(4, 4, 0, 0, '400000410', 50000, 10, '2017-05-12');

UPDATE loans SET approve_status = 'Completed';
UPDATE loans SET approve_status = 'Approved';

---- Savings cash deposits
INSERT INTO account_activity (activity_date, value_date, deposit_account_id, account_credit, activity_type_id, activity_frequency_id, activity_status_id, currency_id, entity_id, org_id) VALUES
('2017-02-10', '2017-02-10', 6, 250000, 2, 1, 1, 1, 0, 0),
('2017-03-10', '2017-03-10', 8, 140000, 2, 1, 1, 1, 0, 0),
('2017-03-10', '2017-08-10', 8, 45000, 2, 1, 1, 1, 0, 0),
('2017-04-10', '2017-04-10', 9, 74000, 2, 1, 1, 1, 0, 0),
('2017-07-10', '2017-07-10', 11, 55000, 2, 1, 1, 1, 0, 0),
('2017-08-10', '2017-08-10', 13, 45000, 2, 1, 1, 1, 0, 0),
('2018-02-10', '2018-02-10', 13, 45000, 2, 1, 1, 1, 0, 0);

------ Cash withdraw
INSERT INTO account_activity (activity_date, value_date, deposit_account_id, account_debit, activity_type_id, activity_frequency_id, activity_status_id, currency_id, entity_id, org_id) VALUES
('2017-04-10', '2017-04-14', 5, 95000, 5, 1, 1, 1, 0, 0),
('2017-04-10', '2017-05-14', 10, 40000, 5, 1, 1, 1, 0, 0);

------ Cash transfers
INSERT INTO account_activity (activity_date, value_date, deposit_account_id, transfer_account_no, account_debit, activity_type_id, activity_frequency_id, activity_status_id, currency_id, entity_id, org_id) VALUES
('2017-03-10', '2017-03-10', 8, '400000207', 25000, 5, 1, 1, 1, 0, 0),
('2017-08-10', '2017-08-10', 11, '400000612', 12000, 5, 1, 1, 1, 0, 0);

------- Loan Payments
INSERT INTO account_activity (activity_date, value_date, deposit_account_id, account_credit, activity_type_id, activity_frequency_id, activity_status_id, currency_id, entity_id, org_id)
SELECT start_date + 4, start_date + 4, 5, 15000, 2, 1, 1, 1, 0, 0
FROM periods
WHERE (start_date > '2017-02-02') AND (start_date < current_date)
ORDER BY period_id;

INSERT INTO account_activity (activity_date, value_date, deposit_account_id, account_credit, activity_type_id, activity_frequency_id, activity_status_id, currency_id, entity_id, org_id)
SELECT start_date + 4, start_date + 4, 10, 5500, 2, 1, 1, 1, 0, 0
FROM periods
WHERE (start_date > '2017-06-02') AND (start_date < current_date)
ORDER BY period_id;


SELECT compute_loans(period_id::text, '0', '1', '') 
FROM periods
WHERE (start_date < current_date)
ORDER BY period_id;

SELECT compute_savings(period_id::text, '0', '1', '')
FROM periods
WHERE (start_date < current_date)
ORDER BY period_id;



---------- Re-compute the activity data

SELECT account_activity_id, deposit_account_id, transfer_account_id,
       activity_type_id, activity_frequency_id, activity_status_id,
       currency_id, period_id, entity_id, org_id, link_activity_id,
       transfer_link_id, deposit_account_no, transfer_account_no, activity_date,
       value_date, account_credit, account_debit, balance, exchange_rate,
       application_date, approve_status, workflow_table_id, action_date,
       details, loan_id, transfer_loan_id INTO tmp1
FROM account_activity
ORDER BY account_activity_id;


CREATE OR REPLACE FUNCTION ins_account_activity() RETURNS trigger AS $$
DECLARE
    v_deposit_account_id        integer;
    v_period_id                    integer;
    v_loan_id                    integer;
    v_activity_type_id            integer;
    v_use_key_id                integer;
    v_minimum_balance            real;
    v_account_transfer            varchar(32);
BEGIN
   
    IF(TG_OP = 'INSERT')THEN
        IF(NEW.deposit_account_id is not null)THEN
            SELECT sum(account_credit - account_debit) INTO NEW.balance
            FROM account_activity
            WHERE (account_activity_id < NEW.account_activity_id)
                AND (deposit_account_id = NEW.deposit_account_id);
        END IF;
        IF(NEW.loan_id is not null)THEN
            SELECT sum(account_credit - account_debit) INTO NEW.balance
            FROM account_activity
            WHERE (account_activity_id < NEW.account_activity_id)
                AND (loan_id = NEW.loan_id);
        END IF;
        IF(NEW.balance is null)THEN
            NEW.balance := 0;
        END IF;
        NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE account_activity DISABLE TRIGGER aft_account_activity;
ALTER TABLE account_activity DISABLE TRIGGER log_account_activity;

DELETE FROM logs.lg_account_activity;
DELETE FROM account_activity;

INSERT INTO account_activity (deposit_account_id, transfer_account_id,
       activity_type_id, activity_frequency_id, activity_status_id,
       currency_id, period_id, entity_id, org_id, link_activity_id,
       transfer_link_id, deposit_account_no, transfer_account_no, activity_date,
       value_date, account_credit, account_debit, balance, exchange_rate,
       application_date, approve_status, workflow_table_id, action_date,
       details, loan_id, transfer_loan_id)
SELECT deposit_account_id, transfer_account_id,
       activity_type_id, activity_frequency_id, activity_status_id,
       currency_id, period_id, entity_id, org_id, link_activity_id,
       transfer_link_id, deposit_account_no, transfer_account_no, activity_date,
       value_date, account_credit, account_debit, balance, exchange_rate,
       application_date, approve_status, workflow_table_id, action_date,
       details, loan_id, transfer_loan_id
FROM tmp1
ORDER BY activity_date, account_activity_id;


ALTER TABLE account_activity ENABLE TRIGGER aft_account_activity;
ALTER TABLE account_activity ENABLE TRIGGER log_account_activity;



CREATE OR REPLACE FUNCTION ins_account_activity() RETURNS trigger AS $$
DECLARE
	v_deposit_account_id		integer;
	v_period_id					integer;
	v_loan_id					integer;
	v_activity_type_id			integer;
	v_use_key_id				integer;
	v_minimum_balance			real;
	v_account_transfer			varchar(32);
BEGIN

	IF((NEW.account_credit = 0) AND (NEW.account_debit = 0))THEN
		RAISE EXCEPTION 'You must enter a debit or credit amount';
	ELSIF((NEW.account_credit < 0) OR (NEW.account_debit < 0))THEN
		RAISE EXCEPTION 'The amounts must be positive';
	ELSIF((NEW.account_credit > 0) AND (NEW.account_debit > 0))THEN
		RAISE EXCEPTION 'Both debit and credit cannot not have an amount at the same time';
	END IF;
	
	SELECT periods.period_id INTO NEW.period_id
	FROM periods
	WHERE (opened = true) AND (activated = true) AND (closed = false)
		AND (start_date <= NEW.activity_date) AND (end_date >= NEW.activity_date)
		AND (org_id = NEW.org_id);
	IF(NEW.period_id is null)THEN
		RAISE EXCEPTION 'The transaction needs to be in an open and active period';
	END IF;
	
	IF(NEW.link_activity_id is null)THEN
		NEW.link_activity_id := nextval('link_activity_id_seq');
	END IF;
	
	IF(NEW.transfer_link_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM deposit_accounts WHERE (deposit_account_id = NEW.transfer_link_id);
		NEW.activity_date := current_date;
		NEW.value_date := current_date;
		NEW.exchange_rate := 1;
		IF(NEW.transfer_account_no is null)THEN
			RAISE EXCEPTION 'Enter the correct transfer account';
		END IF;
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		IF(NEW.deposit_account_id is not null)THEN
			SELECT sum(account_credit - account_debit) INTO NEW.balance
			FROM account_activity
			WHERE (account_activity_id < NEW.account_activity_id)
				AND (deposit_account_id = NEW.deposit_account_id);
		END IF;
		IF(NEW.loan_id is not null)THEN
			SELECT sum(account_credit - account_debit) INTO NEW.balance
			FROM account_activity
			WHERE (account_activity_id < NEW.account_activity_id)
				AND (loan_id = NEW.loan_id);
		END IF;
		IF(NEW.balance is null)THEN
			NEW.balance := 0;
		END IF;
		NEW.balance := NEW.balance + (NEW.account_credit - NEW.account_debit);
		
		SELECT use_key_id INTO v_use_key_id
		FROM activity_types WHERE (activity_type_id = NEW.activity_type_id);
		
		IF(v_use_key_id IN (102, 104, 107))THEN
			SELECT COALESCE(minimum_balance, 0) INTO v_minimum_balance
			FROM deposit_accounts WHERE deposit_account_id = NEW.deposit_account_id;
			
			IF((NEW.balance < v_minimum_balance) AND (NEW.activity_status_id = 1))THEN
					RAISE EXCEPTION 'You cannot withdraw below allowed minimum balance';
			END IF;
		END IF;
	END IF;
	
	IF((NEW.transfer_account_no is null) AND (NEW.transfer_account_id is null) AND (NEW.transfer_loan_id is null))THEN
		SELECT vw_account_definations.account_number INTO NEW.transfer_account_no
		FROM vw_account_definations INNER JOIN deposit_accounts ON vw_account_definations.product_id = deposit_accounts.product_id
		WHERE (deposit_accounts.deposit_account_id = NEW.deposit_account_id) 
			AND (vw_account_definations.activity_type_id = NEW.activity_type_id) 
			AND (vw_account_definations.use_key_id IN (101, 102));
	END IF;
	
	IF(NEW.transfer_account_no is not null)THEN
		SELECT deposit_account_id INTO v_deposit_account_id
		FROM deposit_accounts WHERE (account_number = NEW.transfer_account_no);
		
		IF(v_deposit_account_id is null)THEN
			SELECT loan_id INTO v_loan_id
			FROM loans WHERE (account_number = NEW.transfer_account_no);
		END IF;
		
		IF((v_deposit_account_id is null) AND (v_loan_id is null))THEN
			RAISE EXCEPTION 'Enter a valid account to do transfer';
		ELSIF((v_deposit_account_id is not null) AND (NEW.deposit_account_id = v_deposit_account_id))THEN
			RAISE EXCEPTION 'You cannot do a transfer on same account';
		ELSIF((v_loan_id is not null) AND (NEW.loan_id = v_loan_id))THEN
			RAISE EXCEPTION 'You cannot do a transfer on same account';
		ELSIF(v_deposit_account_id is not null)THEN
			NEW.transfer_account_id := v_deposit_account_id;
		ELSIF(v_loan_id is not null)THEN
			NEW.transfer_loan_id := v_loan_id;
		END IF;
	ELSIF(NEW.transfer_account_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM deposit_accounts WHERE (deposit_account_id = NEW.transfer_account_id);
	ELSIF(NEW.transfer_loan_id is not null)THEN
		SELECT account_number INTO NEW.transfer_account_no
		FROM loans WHERE (loan_id = NEW.transfer_loan_id);
	END IF;
			
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;



--------- Reset users
UPDATE entitys SET entity_password = md5('baraza');
