--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: logs; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA logs;


ALTER SCHEMA logs OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: add_client(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_client(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec						RECORD;
	v_lead_id				integer;
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_industry_id			integer;
	v_sales_id				integer;
	v_account_id			integer;
	msg 					varchar(120);
BEGIN

	msg := null;

	IF($3 = '1')THEN
		SELECT org_id, business_id, business_name, business_address, city,
			state, country_id, number_of_employees, telephone, website,
			primary_contact, job_title, primary_email
		INTO rec
		FROM leads WHERE lead_id = $1::integer;
		
		SELECT entity_id INTO v_entity_id
		FROM entitys WHERE user_name = lower(trim(rec.primary_email));
		
		SELECT max(entity_type_id) INTO v_entity_type_id
		FROM entity_types
		WHERE (org_id = rec.org_id) AND (use_key_id = 2);
		
		SELECT account_id INTO v_account_id
		FROM default_accounts 
		WHERE (org_id = rec.org_id) AND (use_key_id = 51);

		IF(rec.business_id is not null)THEN
			msg := 'The business is already added.';
		ELSIF(rec.primary_email is null)THEN
			RAISE EXCEPTION 'You must enter an email address';
		ELSIF(v_entity_id is not null)THEN
			RAISE EXCEPTION 'You must have a unique email address';
		ELSIF(v_entity_type_id is null)THEN
			RAISE EXCEPTION 'You must and entity type with use key being 2';
		ELSE
			v_entity_id := nextval('entitys_entity_id_seq');
			INSERT INTO entitys (entity_id, org_id, entity_type_id, account_id, entity_name, attention, user_name, primary_email,  function_role, use_key_id)
			VALUES (v_entity_id, rec.org_id, v_entity_type_id, v_account_id, rec.business_name, rec.primary_contact, lower(trim(rec.primary_email)), lower(trim(rec.primary_email)), 'client', 2);
			
			INSERT INTO address (address_name, sys_country_id, table_name, org_id, table_id, premises, town, phone_number, website, is_default) 
			VALUES (rec.business_name, rec.country_id, 'entitys', rec.org_id, v_entity_id, rec.business_address, rec.city, rec.telephone, rec.website, true);
			
			UPDATE leads SET business_id = v_entity_id WHERE (lead_id = $1::integer);
			
			msg := 'You have added the client';
		END IF;
	ELSIF($3 = '2')THEN
		SELECT a.org_id, a.entity_id, a.entity_type_id, a.org_id, a.entity_name, a.user_name, a.primary_email, 
			a.primary_telephone, a.attention, b.sys_country_id, b.address_name, 
			b.post_office_box, b.postal_code, b.premises, b.town, b.website INTO rec
		FROM entitys a LEFT JOIN
			(SELECT address_id, address_type_id, sys_country_id, org_id, address_name, 
			table_id, post_office_box, postal_code, premises, 
			street, town, phone_number, mobile, email, website
			FROM address
			WHERE (is_default = true) AND (table_name = 'entitys')) b
		ON a.entity_id = b.table_id
		WHERE (a.entity_id = $1::integer);
		
		SELECT lead_id INTO v_lead_id
		FROM leads 
		WHERE (business_id = rec.entity_id) OR (lower(trim(business_name)) = lower(trim(rec.entity_name)));
		
		IF(v_lead_id is not null)THEN
			msg := 'The business is already added.';
		ELSE		
			SELECT min(industry_id) INTO v_industry_id
			FROM industry WHERE (org_id = rec.org_id);
			
			SELECT min(entity_id) INTO v_sales_id
			FROM entitys
			WHERE (org_id = rec.org_id) AND (use_function = 0);
	
			INSERT INTO leads(industry_id, entity_id, org_id, business_id, business_name, 
				business_address, city, country_id, 
				telephone, primary_contact, primary_email, website)
			VALUES (v_industry_id, v_sales_id, rec.org_id, rec.entity_id, rec.entity_name,
				rec.premises, rec.town, rec.sys_country_id,
				rec.primary_telephone, rec.attention, rec.primary_email, rec.website);
			
            msg := 'You have added the lead';
		END IF;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.add_client(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: add_periods(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_periods(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	msg					varchar(120);
BEGIN

	SELECT org_id INTO v_org_id
	FROM fiscal_years
	WHERE (fiscal_year_id = $1::int);
	
	UPDATE periods SET fiscal_year_id = fiscal_years.fiscal_year_id
	FROM fiscal_years WHERE (fiscal_years.fiscal_year_id = $1::int)
		AND (fiscal_years.fiscal_year_start <= start_date) AND (fiscal_years.fiscal_year_end >= end_date);
	
	SELECT period_id INTO v_period_id
	FROM periods
	WHERE (fiscal_year_id = $1::int) AND (org_id = v_org_id);
	
	IF(v_period_id is null)THEN
		INSERT INTO periods (fiscal_year_id, org_id, start_date, end_date)
		SELECT $1::int, v_org_id, period_start, CAST(period_start + CAST('1 month' as interval) as date) - 1
		FROM (SELECT CAST(generate_series(fiscal_year_start, fiscal_year_end, '1 month') as date) as period_start
			FROM fiscal_years WHERE fiscal_year_id = $1::int) as a;
		msg := 'Months for the year generated';
	ELSE
		msg := 'Months year already created';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.add_periods(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: add_sys_login(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_sys_login(character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_sys_login_id			integer;
	v_entity_id				integer;
BEGIN
	SELECT entity_id INTO v_entity_id
	FROM entitys WHERE user_name = $1;

	v_sys_login_id := nextval('sys_logins_sys_login_id_seq');	

	INSERT INTO sys_logins (sys_login_id, entity_id)
	VALUES (v_sys_login_id, v_entity_id);

	return v_sys_login_id;
END;
$_$;


ALTER FUNCTION public.add_sys_login(character varying) OWNER TO postgres;

--
-- Name: add_tx_link(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION add_tx_link(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
BEGIN
	
	INSERT INTO transaction_details (transaction_id, org_id, item_id, quantity, amount, tax_amount, narrative, details)
	SELECT CAST($3 as integer), org_id, item_id, quantity, amount, tax_amount, narrative, details
	FROM transaction_details
	WHERE (transaction_detail_id = CAST($1 as integer));

	INSERT INTO transaction_links (org_id, transaction_detail_id, transaction_detail_to, quantity, amount)
	SELECT org_id, transaction_detail_id, currval('transaction_details_transaction_detail_id_seq'), quantity, amount
	FROM transaction_details
	WHERE (transaction_detail_id = CAST($1 as integer));

	return 'DONE';
END;
$_$;


ALTER FUNCTION public.add_tx_link(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: af_upd_transaction_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION af_upd_transaction_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_amount					real;
	v_tax_amount				real;
BEGIN

	IF(TG_OP = 'DELETE')THEN
		SELECT SUM(quantity * (amount + tax_amount) * ((100 - discount) / 100)), 
			SUM(quantity *  tax_amount * ((100 - discount) / 100)) 
			INTO v_amount, v_tax_amount
		FROM transaction_details WHERE (transaction_id = OLD.transaction_id);
		
		UPDATE transactions SET transaction_amount = v_amount, transaction_tax_amount = v_tax_amount
		WHERE (transaction_id = OLD.transaction_id);	
	ELSE
		SELECT SUM(quantity * (amount + tax_amount) * ((100 - discount) / 100)), 
			SUM(quantity *  tax_amount * ((100 - discount) / 100)) 
			INTO v_amount, v_tax_amount
		FROM transaction_details WHERE (transaction_id = NEW.transaction_id);
		
		UPDATE transactions SET transaction_amount = v_amount, transaction_tax_amount = v_tax_amount
		WHERE (transaction_id = NEW.transaction_id);	
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.af_upd_transaction_details() OWNER TO postgres;

--
-- Name: aft_account_activity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION aft_account_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca 						RECORD;
	v_account_activity_id		integer;
	v_product_id				integer;
	v_use_key_id				integer;
	v_actual_balance			real;
	v_total_debits				real;
BEGIN

	IF(NEW.deposit_account_id is not null) THEN
		SELECT product_id INTO v_product_id
		FROM deposit_accounts WHERE deposit_account_id = NEW.deposit_account_id;
	END IF;
	IF(NEW.loan_id is not null) THEN 
		SELECT product_id INTO v_product_id
		FROM loans WHERE loan_id = NEW.loan_id;
	END IF;
	
	--- Generate the countra entry for a transfer
	IF(NEW.transfer_account_id is not null)THEN
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (deposit_account_id = NEW.transfer_account_id)
			AND (link_activity_id = NEW.link_activity_id);
			
		IF(v_account_activity_id is null)THEN
			INSERT INTO account_activity (deposit_account_id, transfer_account_id, transfer_loan_id, activity_type_id,
				currency_id, org_id, entity_id, link_activity_id, activity_date, value_date,
				activity_status_id, account_credit, account_debit, activity_frequency_id)
			VALUES (NEW.transfer_account_id, NEW.deposit_account_id, NEW.loan_id, NEW.activity_type_id,
				NEW.currency_id, NEW.org_id, NEW.entity_id, NEW.link_activity_id, NEW.activity_date, NEW.value_date,
				NEW.activity_status_id, NEW.account_debit, NEW.account_credit, 1);
		END IF;
	END IF;
	
	--- Generate the countra entry for a loan
	IF(NEW.transfer_loan_id is not null)THEN
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (loan_id = NEW.transfer_loan_id)
			AND (link_activity_id = NEW.link_activity_id);
			
		IF(v_account_activity_id is null)THEN
			INSERT INTO account_activity (loan_id, transfer_account_id, transfer_loan_id, activity_type_id,
				currency_id, org_id, entity_id, link_activity_id, activity_date, value_date,
				activity_status_id, account_credit, account_debit, activity_frequency_id)
			VALUES (NEW.transfer_loan_id, NEW.deposit_account_id, NEW.loan_id, NEW.activity_type_id,
				NEW.currency_id, NEW.org_id, NEW.entity_id, NEW.link_activity_id, NEW.activity_date, NEW.value_date,
				NEW.activity_status_id, NEW.account_debit, NEW.account_credit, 1);
		END IF;
	END IF;

	--- Posting the charge on the transfer transaction
	SELECT use_key_id INTO v_use_key_id
	FROM activity_types
	WHERE (activity_type_id = NEW.activity_type_id);
	IF((v_use_key_id < 200) AND (NEW.account_debit > 0))THEN
		INSERT INTO account_activity (deposit_account_id, activity_type_id, activity_frequency_id,
			activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
			link_activity_id, activity_date, value_date, account_debit)
		SELECT NEW.deposit_account_id, account_definations.charge_activity_id, account_definations.activity_frequency_id,
			1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
			NEW.link_activity_id, current_date, current_date, 
			(account_definations.fee_amount + account_definations.fee_ps * NEW.account_debit / 100)
			
		FROM account_definations INNER JOIN products ON account_definations.product_id = products.product_id
		WHERE (account_definations.product_id = v_product_id)
			AND (account_definations.activity_frequency_id = 1) 
			AND (account_definations.activity_type_id = NEW.activity_type_id) 
			AND (account_definations.is_active = true) AND (account_definations.has_charge = true)
			AND (account_definations.start_date < current_date);
	END IF;
	
	--- compute for Commited amounts taking the date into consideration
	IF((NEW.account_credit > 0) AND (NEW.activity_status_id = 1))THEN
		SELECT sum((account_credit - account_debit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id < 3) AND (value_date <= NEW.value_date);
		IF(v_actual_balance is null)THEN v_actual_balance := 0; END IF;
		SELECT sum(account_debit * exchange_rate) INTO v_total_debits
		FROM account_activity 
		WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id = 3) AND (value_date <= NEW.value_date);
		IF(v_total_debits is null)THEN v_total_debits := 0; END IF;
		v_actual_balance := v_actual_balance - v_total_debits;
			
		FOR reca IN SELECT account_activity_id, activity_status_id, link_activity_id, 
				(account_debit * exchange_rate) as debit_amount
			FROM account_activity 
			WHERE (deposit_account_id = NEW.deposit_account_id) AND (activity_status_id = 4) AND (activity_date <= NEW.value_date)
				AND (account_credit = 0) AND (account_debit > 0)
			ORDER BY activity_date, account_activity_id
		LOOP
			IF(v_actual_balance > reca.debit_amount)THEN
				UPDATE account_activity SET activity_status_id = 1 WHERE link_activity_id = reca.link_activity_id;
				v_actual_balance := v_actual_balance - reca.debit_amount;
			END IF;
		END LOOP;
	END IF;
	
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_account_activity() OWNER TO postgres;

--
-- Name: aft_customers(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION aft_customers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_type_id		integer;
	v_entity_id				integer;
	v_user_name				varchar(32);
BEGIN

	IF((TG_OP = 'INSERT') AND (NEW.business_account = 0))THEN
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 100);
		v_entity_id := nextval('entitys_entity_id_seq');
		v_user_name := 'OR' || NEW.org_id || 'EN' || v_entity_id;
		
		INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, customer_id, entity_name, user_name, primary_email, primary_telephone, function_role)
		VALUES (v_entity_id, NEW.org_id, 100, v_entity_type_id, NEW.customer_id, NEW.customer_name, v_user_name, lower(trim(NEW.client_email)), NEW.telephone_number, 'client');
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.aft_customers() OWNER TO postgres;

--
-- Name: apply_approval(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION apply_approval(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg							varchar(120);
	v_deposit_account_id		integer;
	v_principal_amount			real;
	v_repayment_amount			real;
	v_maximum_repayments		integer;
	v_repayment_period			integer;
BEGIN

	IF($3 = '1')THEN
		UPDATE customers SET approve_status = 'Completed' 
		WHERE (customer_id = $1::integer) AND (approve_status = 'Draft');

		msg := 'Applied for client approval';
	ELSIF($3 = '2')THEN
		UPDATE deposit_accounts SET approve_status = 'Completed' 
		WHERE (deposit_account_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for account approval';
	ELSIF($3 = '3')THEN
		SELECT deposit_accounts.deposit_account_id, loans.principal_amount, loans.repayment_amount,
				loans.repayment_period, products.maximum_repayments
			INTO v_deposit_account_id, v_principal_amount, v_repayment_amount, v_repayment_period, v_maximum_repayments
		FROM deposit_accounts INNER JOIN loans ON (deposit_accounts.account_number = loans.disburse_account)
			INNER JOIN products ON loans.product_id = products.product_id
			AND (deposit_accounts.customer_id = loans.customer_id) AND (loans.loan_id = $1::integer)
			AND (deposit_accounts.approve_status = 'Approved');
		
		IF(v_deposit_account_id is null)THEN
			msg := 'The disburse account needs to be active and owned by the clients';
			RAISE EXCEPTION '%', msg;
		ELSIF(v_repayment_period > v_maximum_repayments)THEN
			msg := 'The repayment periods are more than what is prescribed by the product';
			RAISE EXCEPTION '%', msg;
		ELSE
			UPDATE loans SET approve_status = 'Completed' 
			WHERE (loan_id = $1::integer) AND (approve_status = 'Draft');
			
			msg := 'Applied for loan approval';
		END IF;
	ELSIF($3 = '4')THEN
		UPDATE guarantees SET approve_status = 'Completed' 
		WHERE (guarantee_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for guarantees approval';
	ELSIF($3 = '5')THEN
		UPDATE collaterals SET approve_status = 'Completed' 
		WHERE (collateral_id = $1::integer) AND (approve_status = 'Draft');
		
		msg := 'Applied for collateral approval';
	ELSIF($3 = '7')THEN
		UPDATE transfer_beneficiary SET approve_status = 'Approved' 
		WHERE (transfer_beneficiary_id = $1::integer) AND (approve_status = 'Completed');
		
		msg := 'Applied for beneficiary application submited';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.apply_approval(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: budget_process(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION budget_process(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec 	RECORD;
	recb 	RECORD;

	nb_id 	INTEGER;
	ntrx	INTEGER;
	msg 	varchar(120);
BEGIN
	SELECT budget_id, org_id, fiscal_year_id, department_id, link_budget_id, budget_type, budget_name, approve_status INTO rec
	FROM budgets
	WHERE (budget_id = CAST($1 as integer));
	
	IF($3 = '1') THEN
		IF(rec.approve_status = 'Draft') THEN
			UPDATE budgets SET approve_status = 'Completed', entity_id = CAST($2 as integer)
			WHERE budget_id = rec.budget_id;
		END IF;
		msg := 'Transaction completed.';
	ELSIF (($3 = '2') OR ($3 = '3')) THEN
		IF(rec.approve_status = 'Approved') THEN
			IF(rec.link_budget_id is null) THEN
				nb_id := create_budget(rec.budget_id, rec.fiscal_year_id, CAST($3 as int));
				UPDATE budgets SET link_budget_id = nb_id WHERE budget_id = rec.budget_id;
				msg := 'The budget created.';
			ELSE
				msg := 'Another budget has already been created';
			END IF;
		ELSE
			msg := 'The budget needs to be aprroved first';
		END IF;
	ELSIF (($3 = '4')) THEN
		SELECT transaction_id, approve_status INTO recb 
		FROM vw_budget_lines WHERE (budget_line_id = CAST($1 as integer));

		IF(recb.approve_status != 'Approved') THEN
			msg := 'The budget neets approval first.';
		ELSIF(recb.transaction_id is null) THEN
			INSERT INTO transactions (org_id, currency_id, entity_id, department_id, transaction_type_id, transaction_date)
			SELECT orgs.org_id, orgs.currency_id, CAST($2 as integer), vw_budget_lines.department_id, 16, current_date
			FROM vw_budget_lines INNER JOIN orgs ON vw_budget_lines.org_id = orgs.org_id
			WHERE (budget_line_id = CAST($1 as integer));

			ntrx := currval('transactions_transaction_id_seq');

			INSERT INTO transaction_details (org_id, transaction_id, account_id, item_id, quantity, amount, tax_amount, narrative, details)
			SELECT org_id, ntrx, account_id, item_id, quantity, amount, tax_amount, narrative, details
			FROM vw_budget_lines
			WHERE (budget_line_id = CAST($1 as integer));

			UPDATE budget_lines SET transaction_id = ntrx WHERE (budget_line_id = CAST($1 as integer));

			msg := 'Requisition Created.';
		ELSE
			msg := 'Requisition had been created from this budget.';
		END IF;
	ELSE
		msg := 'Transaction alerady completed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.budget_process(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: change_password(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION change_password(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	old_password 	varchar(64);
	passchange 		varchar(120);
	entityID		integer;
BEGIN
	passchange := 'Password Error';
	entityID := CAST($1 AS INT);
	SELECT Entity_password INTO old_password
	FROM entitys WHERE (entity_id = entityID);

	IF ($2 = '0') THEN
		passchange := first_password();
		UPDATE entitys SET first_password = passchange, Entity_password = md5(passchange) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSIF (old_password = md5($2)) THEN
		UPDATE entitys SET Entity_password = md5($3) WHERE (entity_id = entityID);
		passchange := 'Password Changed';
	ELSE
		passchange := null;
	END IF;

	return passchange;
END;
$_$;


ALTER FUNCTION public.change_password(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_issue(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_issue(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 					varchar(120);
BEGIN

	msg := null;
	
	IF($3 = '1')THEN
		UPDATE helpdesk SET closed_by = $2::integer, solved_time = current_timestamp, is_solved = true
		WHERE helpdesk_id = $1::integer;
		
		msg := 'Closed the call';
	END IF;
	
	return msg;
END;
$_$;


ALTER FUNCTION public.close_issue(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_periods(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_periods(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg 					varchar(120);
BEGIN
	
	IF(v_period_id is null)THEN
		INSERT INTO periods (fiscal_year_id, org_id, start_date, end_date)
		SELECT $1::int, v_org_id, period_start, CAST(period_start + CAST('1 month' as interval) as date) - 1
		FROM (SELECT CAST(generate_series(fiscal_year_start, fiscal_year_end, '1 month') as date) as period_start
			FROM fiscal_years WHERE fiscal_year_id = $1::int) as a;
		msg := 'Months for the year generated';
	ELSE
		msg := 'Months year already created';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.close_periods(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: close_year(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION close_year(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	trx_date		DATE;
	periodid		INTEGER;
	journalid		INTEGER;
	profit_acct		INTEGER;
	retain_acct		INTEGER;
	rec				RECORD;
	msg				varchar(120);
BEGIN
	SELECT fiscal_year_id, fiscal_year_start, fiscal_year_end, year_opened, year_closed INTO rec
	FROM fiscal_years
	WHERE (fiscal_year_id = CAST($1 as integer));

	SELECT account_id INTO profit_acct FROM default_accounts WHERE default_account_id = 1;
	SELECT account_id INTO retain_acct FROM default_accounts WHERE default_account_id = 2;
	
	trx_date := CAST($1 || '-12-31' as date);
	periodid := get_open_period(trx_date);
	IF(periodid is null) THEN
		msg := 'Cannot post. No active period to post.';
	ELSIF(rec.year_opened = false)THEN
		msg := 'Cannot post. The year is not opened.';
	ELSIF(rec.year_closed = true)THEN
		msg := 'Cannot post. The year is closed.';
	ELSE
		INSERT INTO journals (period_id, journal_date, narrative, year_closing)
		VALUES (periodid, trx_date, 'End of year closing', false);
		journalid := currval('journals_journal_id_seq');

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, account_id, dr_amount, cr_amount, 'Account Balance'
		FROM ((SELECT account_id, sum(bal_credit) as dr_amount, sum(bal_debit) as cr_amount
		FROM vw_ledger
		WHERE (chat_type_id > 3) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0)
		GROUP BY account_id)
		UNION
		(SELECT profit_acct, (CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END),
		(CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END)
		FROM vw_ledger
		WHERE (chat_type_id > 3) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0))) as a;

		msg := process_journal(CAST(journalid as varchar),'0','0');

		INSERT INTO journals (period_id, journal_date, narrative, year_closing)
		VALUES (periodid, trx_date, 'Retained Earnings', false);
		journalid := currval('journals_journal_id_seq');

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, profit_acct, (CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END),
			(CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END), 'Retained Earnings'
		FROM vw_ledger
		WHERE (account_id = profit_acct) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0);

		INSERT INTO gls (journal_id, account_id, debit, credit, gl_narrative)
		SELECT journalid, retain_acct, (CASE WHEN sum(bal_debit) > sum(bal_credit) THEN sum(bal_debit - bal_credit) ELSE 0 END),
			(CASE WHEN sum(bal_debit) < sum(bal_credit) THEN sum(bal_credit - bal_debit) ELSE 0 END), 'Retained Earnings'
		FROM vw_ledger
		WHERE (account_id = profit_acct) AND (fiscal_year_id = rec.fiscal_year_id) AND (acc_balance <> 0);

		msg := process_journal(CAST(journalid as varchar),'0','0');

		UPDATE fiscal_years SET year_closed = true WHERE fiscal_year_id = rec.fiscal_year_id;
		UPDATE periods SET period_closed = true WHERE fiscal_year_id = rec.fiscal_year_id;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.close_year(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: complete_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION complete_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	bankacc INTEGER;
	msg varchar(120);
BEGIN
	SELECT transaction_id, transaction_type_id, transaction_status_id, bank_account_id INTO rec
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	IF($3 = '2') THEN
		UPDATE transactions SET transaction_status_id = 4 
		WHERE transaction_id = rec.transaction_id;
		msg := 'Transaction Archived';
	ELSIF($3 = '1') AND (rec.transaction_status_id = 1)THEN
		IF((rec.transaction_type_id = 7) or (rec.transaction_type_id = 8)) THEN
			IF(rec.bank_account_id is null)THEN
				msg := 'Transaction completed.';
				RAISE EXCEPTION 'You need to add the bank account to receive the funds';
			ELSE
				UPDATE transactions SET transaction_status_id = 2, approve_status = 'Completed'
				WHERE transaction_id = rec.transaction_id;
				msg := 'Transaction completed.';
			END IF;
		ELSE
			UPDATE transactions SET transaction_status_id = 2, approve_status = 'Completed'
			WHERE transaction_id = rec.transaction_id;
			msg := 'Transaction completed.';
		END IF;
	ELSE
		msg := 'Transaction alerady completed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.complete_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: compute_loans(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION compute_loans(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reca 						RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_start_date				date;
	v_end_date					date;
	v_account_activity_id		integer;
	v_penalty_formural			varchar(320);
	v_penalty_account			varchar(32);
	v_penalty_amount			real;
	v_activity_type_id			integer;
	v_reducing_payments			boolean;
	v_interest_formural			varchar(320);
	v_interest_account			varchar(32);
	v_interest_amount			real;
	v_repayment_amount			real;
	v_repayment_balance			real;
	v_available_balance			real;
	v_activity_status_id		integer;
	msg							varchar(120);
BEGIN

	SELECT period_id, org_id, start_date, end_date
		INTO v_period_id, v_org_id, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = true) AND (closed = false);

	FOR reca IN SELECT currency_id, loan_id, customer_id, product_id, activity_frequency_id,
			account_number, disburse_account, principal_amount, interest_rate,
			repayment_period, repayment_amount, disbursed_date, actual_balance
		FROM vw_loans
		WHERE (org_id = v_org_id) AND (approve_status = 'Approved') AND (actual_balance > 0) AND (disbursed_date < v_start_date)
	LOOP
	
		---- Compute for penalty
		v_repayment_amount := 0;
		v_account_activity_id := null;
		v_penalty_amount := 0;
		SELECT penalty_methods.activity_type_id, penalty_methods.formural, penalty_methods.account_number 
			INTO v_activity_type_id, v_penalty_formural, v_penalty_account
		FROM penalty_methods INNER JOIN products ON penalty_methods.penalty_method_id = products.penalty_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_penalty_formural is not null)THEN
			v_penalty_formural := replace(v_penalty_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_penalty_formural || ' FROM loans WHERE loan_id = ' || reca.loan_id 
			INTO v_penalty_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		END IF;
		IF((v_penalty_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, v_penalty_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_penalty_amount);
			v_repayment_amount := v_penalty_amount;
		END IF;
	
		---- Compute for intrest
		v_account_activity_id := null;
		v_interest_amount := 0;
		SELECT interest_methods.activity_type_id, interest_methods.formural, interest_methods.account_number, interest_methods.reducing_payments
			INTO v_activity_type_id, v_interest_formural, v_interest_account, v_reducing_payments
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_interest_formural is not null)THEN
			v_interest_formural := replace(v_interest_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_interest_formural || ' FROM loans WHERE loan_id = ' || reca.loan_id 
			INTO v_interest_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		END IF;
		IF((v_interest_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_interest_amount);
			IF(v_reducing_payments = true)THEN
				v_repayment_amount := v_repayment_amount + v_interest_amount;
			END IF;
		END IF;
		
		--- Computer for repayment
		v_account_activity_id := null;
		SELECT activity_type_id INTO v_activity_type_id
		FROM vw_account_definations 
		WHERE (product_id = reca.product_id) AND (use_key_id = 107);
		SELECT account_activity_id INTO v_account_activity_id
		FROM account_activity
		WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (loan_id = reca.loan_id);
		IF((v_account_activity_id is null) AND (v_activity_type_id is not null))THEN
			v_repayment_balance := v_repayment_amount + reca.actual_balance;
			v_repayment_amount := v_repayment_amount + reca.repayment_amount;
			v_activity_status_id := 1;
			
			SELECT available_balance INTO v_available_balance
			FROM vw_deposit_accounts
			WHERE (account_number = reca.disburse_account);
			IF(v_repayment_amount > v_repayment_balance)THEN v_repayment_amount := v_repayment_balance; END IF;
			IF(v_available_balance < v_repayment_amount)THEN v_activity_status_id := 4; END IF;
			
			INSERT INTO account_activity (period_id, loan_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.loan_id, reca.disburse_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, v_activity_status_id, v_repayment_amount, 0);
		END IF;
	END LOOP;

	msg := 'loans computed';

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.compute_loans(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: compute_savings(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION compute_savings(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reca 						RECORD;
	v_period_id					integer;
	v_org_id					integer;
	v_start_date				date;
	v_end_date					date;
	v_account_activity_id		integer;
	v_penalty_formural			varchar(320);
	v_penalty_account			varchar(32);
	v_penalty_amount			real;
	v_activity_type_id			integer;
	v_reducing_balance			boolean;
	v_interest_formural			varchar(320);
	v_interest_account			varchar(32);
	v_interest_amount			real;
	msg							varchar(120);
BEGIN

	SELECT period_id, org_id, start_date, end_date
		INTO v_period_id, v_org_id, v_start_date, v_end_date
	FROM periods
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = true) AND (closed = false);

	FOR reca IN SELECT currency_id, deposit_account_id, product_id, activity_frequency_id, credit_limit,
		minimum_balance, maximum_balance, interest_rate, lockin_period_frequency, lockedin_until_date
	FROM vw_deposit_accounts
	WHERE (org_id = v_org_id) AND (approve_status = 'Approved') AND (is_active = true) AND (opening_date < v_start_date)
	LOOP

		---- Compute for penalty
		v_account_activity_id := null;
		v_penalty_amount := 0;
		SELECT penalty_methods.activity_type_id, penalty_methods.formural, penalty_methods.account_number 
			INTO v_activity_type_id, v_penalty_formural, v_penalty_account
		FROM penalty_methods INNER JOIN products ON penalty_methods.penalty_method_id = products.penalty_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_penalty_formural is not null)THEN
			v_penalty_formural := replace(v_penalty_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_penalty_formural || ' FROM deposit_accounts WHERE deposit_account_id = ' || reca.deposit_account_id 
			INTO v_penalty_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (deposit_account_id = reca.deposit_account_id);
		END IF;
		IF((v_penalty_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, deposit_account_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.deposit_account_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, 0, v_penalty_amount);
		END IF;
	
		---- Compute for intrest
		v_account_activity_id := null;
		v_interest_amount := 0;
		SELECT interest_methods.activity_type_id, interest_methods.formural, interest_methods.account_number, interest_methods.reducing_balance
			INTO v_activity_type_id, v_interest_formural, v_interest_account, v_reducing_balance
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = reca.product_id);
		IF(v_interest_formural is not null)THEN
			v_interest_formural := replace(v_interest_formural, 'period_id', v_period_id::text);
			EXECUTE 'SELECT ' || v_interest_formural || ' FROM deposit_accounts WHERE deposit_account_id = ' || reca.deposit_account_id 
			INTO v_interest_amount;
			
			SELECT account_activity_id INTO v_account_activity_id
			FROM account_activity
			WHERE (period_id = v_period_id) AND (activity_type_id = v_activity_type_id) AND (deposit_account_id = reca.deposit_account_id);
		END IF;
		IF((v_interest_amount > 0) AND (v_account_activity_id is null))THEN
			INSERT INTO account_activity (period_id, deposit_account_id, transfer_account_no, activity_type_id,
				currency_id, org_id, activity_date, value_date,
				activity_frequency_id, activity_status_id, account_credit, account_debit)
			VALUES (v_period_id, reca.deposit_account_id, v_interest_account, v_activity_type_id,
				reca.currency_id, v_org_id, v_end_date, v_end_date,
				1, 1, v_interest_amount, 0);
		END IF;
	END LOOP;

	msg := 'Savings computed';

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.compute_savings(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: copy_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION copy_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg varchar(120);
BEGIN

	INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, order_number, payment_terms, job, narrative, details, notes)
	SELECT org_id, department_id, entity_id, currency_id, transaction_type_id, CURRENT_DATE, order_number, payment_terms, job, narrative, details, notes
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	INSERT INTO transaction_details (org_id, transaction_id, account_id, item_id, quantity, amount, tax_amount, narrative, details, discount)
	SELECT org_id, currval('transactions_transaction_id_seq'), account_id, item_id, quantity, amount, tax_amount, narrative, details, discount
	FROM transaction_details
	WHERE (transaction_id = CAST($1 as integer));

	msg := 'Transaction Copied';

	return msg;
END;
$_$;


ALTER FUNCTION public.copy_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: cpy_trx_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION cpy_trx_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_ledger_date				timestamp;
	last_date					timestamp;
	v_start						integer;
	v_end						integer;
	v_inteval					interval;
	msg							varchar(120);
BEGIN

	SELECT max(payment_date)::timestamp INTO last_date
	FROM transactions
	WHERE (to_char(payment_date, 'YYYY.MM') = $1);
	v_start := EXTRACT(YEAR FROM last_date) * 12 + EXTRACT(MONTH FROM last_date);
	
	SELECT max(payment_date)::timestamp INTO v_ledger_date
	FROM transactions;
	v_end := EXTRACT(YEAR FROM v_ledger_date) * 12 + EXTRACT(MONTH FROM v_ledger_date) + 1;
	v_inteval :=  ((v_end - v_start) || ' months')::interval;

	IF ($3 = '1') THEN
		INSERT INTO transactions(ledger_type_id, entity_id, bank_account_id, 
				currency_id, journal_id, org_id, exchange_rate, tx_type, payment_date, 
				transaction_amount, transaction_tax_amount, reference_number, 
				narrative, transaction_type_id, transaction_date)
		SELECT ledger_type_id, entity_id, bank_account_id, 
			currency_id, journal_id, org_id, exchange_rate, tx_type, (payment_date + v_inteval), 
			transaction_amount, transaction_tax_amount, reference_number,
			narrative, transaction_type_id, (transaction_date  + v_inteval)
		FROM transactions
		WHERE (tx_type is not null) AND (to_char(payment_date, 'YYYY.MM') = $1);

		msg := 'Appended a new month';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.cpy_trx_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: create_budget(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION create_budget(integer, integer, integer) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec 	RECORD;
	
	nb_id 	INTEGER;
	p_id	INTEGER;
	p_date	DATE;
BEGIN
	INSERT INTO budgets (budget_type, org_id, fiscal_year_id, department_id, entity_id, budget_name)
	SELECT $3, org_id, fiscal_year_id, department_id, entity_id, budget_name
	FROM budgets
	WHERE (budget_id = $1);

	nb_id := currval('budgets_budget_id_seq');

	FOR rec IN SELECT org_id, period_id, account_id, item_id, spend_type, quantity, amount, tax_amount, income_budget, narrative
	FROM budget_lines WHERE (budget_id =  $1) ORDER BY period_id LOOP
		IF(rec.spend_type = 1)THEN
			INSERT INTO budget_lines (budget_id, period_id, org_id, account_id, item_id, quantity, amount, tax_amount, income_budget, narrative)
			SELECT nb_id, period_id, rec.org_id, rec.account_id, rec.item_id, rec.quantity, rec.amount, rec.tax_amount, rec.income_budget, rec.narrative
			FROM periods
			WHERE (fiscal_year_id = $2);
		ELSIF(rec.spend_type = 2)THEN
			FOR i IN 0..3 LOOP
				SELECT start_date + (i*3 || ' month')::INTERVAL INTO p_date 
				FROM periods WHERE (period_id = rec.period_id);
				SELECT period_id INTO p_id
				FROM periods WHERE (start_date <= p_date) AND (end_date >= p_date);

				IF(p_id is not null)THEN
					INSERT INTO budget_lines (budget_id, period_id, org_id, account_id, item_id, quantity, amount, tax_amount, income_budget, narrative)
					VALUES(nb_id, p_id, rec.org_id, rec.account_id, rec.item_id, rec.quantity, rec.amount, rec.tax_amount, rec.income_budget, rec.narrative);
				END IF;
			END LOOP;
		ELSE
			INSERT INTO budget_lines (budget_id, period_id, org_id, account_id, item_id, quantity, amount, tax_amount, income_budget, narrative)
			VALUES(nb_id, rec.period_id, rec.org_id, rec.account_id, rec.item_id, rec.quantity, rec.amount, rec.tax_amount, rec.income_budget, rec.narrative);
		END IF;
	END LOOP;

	RETURN nb_id;
END;
$_$;


ALTER FUNCTION public.create_budget(integer, integer, integer) OWNER TO postgres;

--
-- Name: curr_base_returns(date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION curr_base_returns(date, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(base_credit - base_debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (year_closing = false)
		AND (journal_date >= $1) AND (journal_date <= $2);
$_$;


ALTER FUNCTION public.curr_base_returns(date, date) OWNER TO postgres;

--
-- Name: curr_returns(date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION curr_returns(date, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(credit - debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (year_closing = false)
		AND (journal_date >= $1) AND (journal_date <= $2);
$_$;


ALTER FUNCTION public.curr_returns(date, date) OWNER TO postgres;

--
-- Name: default_currency(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION default_currency(character varying) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT orgs.currency_id
	FROM orgs INNER JOIN entitys ON orgs.org_id = entitys.org_id
	WHERE (entitys.entity_id = CAST($1 as integer));
$_$;


ALTER FUNCTION public.default_currency(character varying) OWNER TO postgres;

--
-- Name: emailed(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION emailed(integer, character varying) RETURNS void
    LANGUAGE sql
    AS $_$
	UPDATE sys_emailed SET emailed = true WHERE (sys_emailed_id = CAST($2 as int));
$_$;


ALTER FUNCTION public.emailed(integer, character varying) OWNER TO postgres;

--
-- Name: first_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION first_password() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
	rnd integer;
	passchange varchar(12);
BEGIN
	passchange := trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	passchange := passchange || trunc(random()*1000);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);
	rnd := trunc(65+random()*25);
	passchange := passchange || chr(rnd);

	return passchange;
END;
$$;


ALTER FUNCTION public.first_password() OWNER TO postgres;

--
-- Name: get_acct(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_acct(integer, date, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT sum(gls.debit - gls.credit)
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) AND (journals.year_closing = false)
		AND (journals.journal_date >= $2) AND (journals.journal_date <= $3);
$_$;


ALTER FUNCTION public.get_acct(integer, date, date) OWNER TO postgres;

--
-- Name: get_balance(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_balance(integer, character varying) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(exchange_rate * (debit_amount - credit_amount)), 0)
	FROM vw_trx
	WHERE (vw_trx.approve_status = 'Approved')
		AND (vw_trx.for_posting = true)
		AND (vw_trx.entity_id = $1)
		AND (vw_trx.transaction_date < $2::date);
$_$;


ALTER FUNCTION public.get_balance(integer, character varying) OWNER TO postgres;

--
-- Name: get_balance(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_balance(integer, integer, character varying) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(debit_amount - credit_amount), 0)
	FROM vw_trx
	WHERE (vw_trx.approve_status = 'Approved')
		AND (vw_trx.for_posting = true)
		AND (vw_trx.entity_id = $1)
		AND (vw_trx.currency_id = $2)
		AND (vw_trx.transaction_date < $3::date);
$_$;


ALTER FUNCTION public.get_balance(integer, integer, character varying) OWNER TO postgres;

--
-- Name: get_base_acct(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_base_acct(integer, date, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT sum(gls.debit * journals.exchange_rate - gls.credit * journals.exchange_rate) 
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) AND (journals.year_closing = false)
		AND (journals.journal_date >= $2) AND (journals.journal_date <= $3);
$_$;


ALTER FUNCTION public.get_base_acct(integer, date, date) OWNER TO postgres;

--
-- Name: get_budgeted(integer, date, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_budgeted(integer, date, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reca		RECORD;
	app_id		Integer;
	v_bill		real;
	v_variance	real;
BEGIN

	FOR reca IN SELECT transaction_detail_id, account_id, amount 
		FROM transaction_details WHERE (transaction_id = $1) LOOP

		SELECT sum(amount) INTO v_bill
		FROM transactions INNER JOIN transaction_details ON transactions.transaction_id = transaction_details.transaction_id
		WHERE (transactions.department_id = $3) AND (transaction_details.account_id = reca.account_id)
			AND (transactions.journal_id is null) AND (transaction_details.transaction_detail_id <> reca.transaction_detail_id);
		IF(v_bill is null)THEN
			v_bill := 0;
		END IF;

		SELECT sum(budget_lines.amount) INTO v_variance
		FROM fiscal_years INNER JOIN budgets ON fiscal_years.fiscal_year_id = budgets.fiscal_year_id
			INNER JOIN budget_lines ON budgets.budget_id = budget_lines.budget_id
		WHERE (budgets.department_id = $3) AND (budget_lines.account_id = reca.account_id)
			AND (budgets.approve_status = 'Approved')
			AND (fiscal_years.fiscal_year_start <= $2) AND (fiscal_years.fiscal_year_end >= $2);
		IF(v_variance is null)THEN
			v_variance := 0;
		END IF;

		v_variance := v_variance - (reca.amount + v_bill);

		IF(v_variance < 0)THEN
			RETURN v_variance;
		END IF;
	END LOOP;

	RETURN v_variance;
END;
$_$;


ALTER FUNCTION public.get_budgeted(integer, date, integer) OWNER TO postgres;

--
-- Name: get_currency_rate(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_currency_rate(integer, integer) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT max(exchange_rate)
	FROM currency_rates
	WHERE (org_id = $1) AND (currency_id = $2)
		AND (exchange_date = (SELECT max(exchange_date) FROM currency_rates WHERE (org_id = $1) AND (currency_id = $2)));
$_$;


ALTER FUNCTION public.get_currency_rate(integer, integer) OWNER TO postgres;

--
-- Name: get_current_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_current_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_current_year(character varying) OWNER TO postgres;

--
-- Name: get_customer_id(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_customer_id(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT customer_id FROM entitys WHERE (entity_id = $1);
$_$;


ALTER FUNCTION public.get_customer_id(integer) OWNER TO postgres;

--
-- Name: get_default_account(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_account(integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT accounts.account_no
	FROM default_accounts INNER JOIN accounts ON default_accounts.account_id = accounts.account_id
	WHERE (default_accounts.use_key_id = $1) AND (default_accounts.org_id = $2);
$_$;


ALTER FUNCTION public.get_default_account(integer, integer) OWNER TO postgres;

--
-- Name: get_default_account_id(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_account_id(integer, integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT accounts.account_id
	FROM default_accounts INNER JOIN accounts ON default_accounts.account_id = accounts.account_id
	WHERE (default_accounts.use_key_id = $1) AND (default_accounts.org_id = $2);
$_$;


ALTER FUNCTION public.get_default_account_id(integer, integer) OWNER TO postgres;

--
-- Name: get_default_country(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_country(integer) RETURNS character
    LANGUAGE sql
    AS $_$
	SELECT default_country_id::varchar(2)
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_country(integer) OWNER TO postgres;

--
-- Name: get_default_currency(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_default_currency(integer) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT currency_id
	FROM orgs
	WHERE (org_id = $1);
$_$;


ALTER FUNCTION public.get_default_currency(integer) OWNER TO postgres;

--
-- Name: get_end_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_end_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '31/12/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_end_year(character varying) OWNER TO postgres;

--
-- Name: get_et_field_name(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_et_field_name(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT et_field_name
	FROM et_fields WHERE (et_field_id = $1);
$_$;


ALTER FUNCTION public.get_et_field_name(integer) OWNER TO postgres;

--
-- Name: get_intrest(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_intrest(integer, integer, integer) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_principal_amount 			real;
	v_interest_rate				real;
	v_actual_balance			real;
	v_total_debits				real;
	v_start_date				date;
	v_end_date					date;
	ans							real;
BEGIN

	SELECT start_date, end_date INTO v_start_date, v_end_date
	FROM periods WHERE (period_id = $3::integer);

	IF($1 = 1)THEN
		SELECT interest_rate INTO v_interest_rate
		FROM loans  WHERE (loan_id = $2);

		SELECT sum((account_debit - account_credit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (loan_id = $2) AND (activity_status_id < 2) AND (value_date <= v_end_date);

		ans := v_actual_balance * v_interest_rate / 1200;
	ELSIF($1 = 2)THEN
		SELECT principal_amount, interest_rate INTO v_principal_amount, v_interest_rate
		FROM vw_loans 
		WHERE (loan_id = $2);
		
		ans := v_principal_amount * v_interest_rate / 1200;
	ELSIF($1 = 3)THEN
		SELECT interest_rate INTO v_interest_rate
		FROM deposit_accounts  WHERE (deposit_account_id = $2);
		
		SELECT sum((account_credit - account_debit) * exchange_rate) INTO v_actual_balance
		FROM account_activity 
		WHERE (deposit_account_id = $2) AND (activity_status_id < 2) AND (value_date < v_start_date);
		IF(v_actual_balance is null)THEN v_actual_balance := 0; END IF;
		SELECT sum(account_debit * exchange_rate) INTO v_total_debits
		FROM account_activity 
		WHERE (deposit_account_id = $2) AND (activity_status_id < 2) AND (value_date BETWEEN v_start_date AND v_end_date);
		IF(v_total_debits is null)THEN v_total_debits := 0; END IF;
	
		ans := (v_actual_balance - v_total_debits) * v_interest_rate / 1200;
	END IF;

	RETURN ans;
END;
$_$;


ALTER FUNCTION public.get_intrest(integer, integer, integer) OWNER TO postgres;

--
-- Name: get_ledger_link(integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_ledger_link(integer, integer, integer, character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_ledger_type_id		integer;
	v_account_no			integer;
	v_account_id			integer;
BEGIN

	SELECT ledger_types.ledger_type_id, accounts.account_no INTO v_ledger_type_id, v_account_no
	FROM ledger_types INNER JOIN ledger_links ON ledger_types.ledger_type_id = ledger_links.ledger_type_id
		INNER JOIN accounts ON ledger_types.account_id = accounts.account_id
	WHERE (ledger_links.org_id = $1) AND (ledger_links.link_type = $2) AND (ledger_links.link_id = $3);
	
	IF(v_ledger_type_id is null)THEN
		v_ledger_type_id := nextval('ledger_types_ledger_type_id_seq');
		SELECT accounts.account_id INTO v_account_id
		FROM accounts
		WHERE (accounts.org_id = $1) AND (accounts.account_no::text = $4);
		
		INSERT INTO ledger_types (ledger_type_id, account_id, tax_account_id, org_id,
			ledger_type_name, ledger_posting, expense_ledger, income_ledger)
		VALUES (v_ledger_type_id, v_account_id, v_account_id, $1,
			$5, true, true, false);

		INSERT INTO ledger_links (ledger_type_id, org_id, link_type, link_id)
		VALUES (v_ledger_type_id, $1, $2, $3);
	END IF;
	
	RETURN v_ledger_type_id;
END;
$_$;


ALTER FUNCTION public.get_ledger_link(integer, integer, integer, character varying, character varying) OWNER TO postgres;

--
-- Name: get_open_period(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_open_period(date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT period_id FROM periods WHERE (start_date <= $1) AND (end_date >= $1)
		AND (opened = true) AND (closed = false); 
$_$;


ALTER FUNCTION public.get_open_period(date) OWNER TO postgres;

--
-- Name: get_opening_stock(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_opening_stock(integer, date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(q_purchased - q_sold - q_used)::integer, 0)
	FROM vw_stock_movement
	WHERE (item_id = $1) AND (transaction_date < $2);
$_$;


ALTER FUNCTION public.get_opening_stock(integer, date) OWNER TO postgres;

--
-- Name: get_org_logo(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_org_logo(integer) RETURNS character varying
    LANGUAGE sql
    AS $_$
	SELECT orgs.logo
	FROM orgs WHERE (orgs.org_id = $1);
$_$;


ALTER FUNCTION public.get_org_logo(integer) OWNER TO postgres;

--
-- Name: get_penalty(integer, integer, integer, real); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_penalty(integer, integer, integer, real) RETURNS real
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_actual_default			real;
	v_start_date				date;
	v_end_date					date;
	ans							real;
BEGIN

	SELECT start_date, end_date INTO v_start_date, v_end_date
	FROM periods WHERE (period_id = $3::integer);

	IF($1 = 1)THEN
		SELECT sum(account_credit * exchange_rate) INTO v_actual_default
		FROM account_activity 
		WHERE (loan_id = $2) AND (activity_status_id = 4) AND (value_date < v_start_date);
		
		ans := v_actual_default * $3 / 1200;
	END IF;

	RETURN ans;
END;
$_$;


ALTER FUNCTION public.get_penalty(integer, integer, integer, real) OWNER TO postgres;

--
-- Name: get_period(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_period(date) RETURNS integer
    LANGUAGE sql
    AS $_$
	SELECT period_id FROM periods WHERE (start_date <= $1) AND (end_date >= $1); 
$_$;


ALTER FUNCTION public.get_period(date) OWNER TO postgres;

--
-- Name: get_phase_email(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_email(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	myemail	varchar(320);
BEGIN
	myemail := null;
	FOR myrec IN SELECT entitys.primary_email
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myemail is null) THEN
			IF (myrec.primary_email is not null) THEN
				myemail := myrec.primary_email;
			END IF;
		ELSE
			IF (myrec.primary_email is not null) THEN
				myemail := myemail || ', ' || myrec.primary_email;
			END IF;
		END IF;

	END LOOP;

	RETURN myemail;
END;
$_$;


ALTER FUNCTION public.get_phase_email(integer) OWNER TO postgres;

--
-- Name: get_phase_entitys(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_entitys(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec			RECORD;
	myentitys		varchar(320);
BEGIN
	myentitys := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM entitys INNER JOIN entity_subscriptions ON entitys.entity_id = entity_subscriptions.entity_id
		WHERE (entity_subscriptions.entity_type_id = $1) LOOP

		IF (myentitys is null) THEN
			IF (myrec.entity_name is not null) THEN
				myentitys := myrec.entity_name;
			END IF;
		ELSE
			IF (myrec.entity_name is not null) THEN
				myentitys := myentitys || ', ' || myrec.entity_name;
			END IF;
		END IF;

	END LOOP;

	RETURN myentitys;
END;
$_$;


ALTER FUNCTION public.get_phase_entitys(integer) OWNER TO postgres;

--
-- Name: get_phase_status(boolean, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_phase_status(boolean, boolean) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	ps		varchar(16);
BEGIN
	ps := 'Draft';
	IF ($1 = true) THEN
		ps := 'Approved';
	END IF;
	IF ($2 = true) THEN
		ps := 'Rejected';
	END IF;

	RETURN ps;
END;
$_$;


ALTER FUNCTION public.get_phase_status(boolean, boolean) OWNER TO postgres;

--
-- Name: get_reporting_list(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_reporting_list(integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
    myrec	RECORD;
	mylist	varchar(320);
BEGIN
	mylist := null;
	FOR myrec IN SELECT entitys.entity_name
		FROM reporting INNER JOIN entitys ON reporting.report_to_id = entitys.entity_id
		WHERE (reporting.primary_report = true) AND (reporting.entity_id = $1) 
	LOOP

		IF (mylist is null) THEN
			mylist := myrec.entity_name;
		ELSE
			mylist := mylist || ', ' || myrec.entity_name;
		END IF;
	END LOOP;

	RETURN mylist;
END;
$_$;


ALTER FUNCTION public.get_reporting_list(integer) OWNER TO postgres;

--
-- Name: get_start_year(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_start_year(character varying) RETURNS character varying
    LANGUAGE sql
    AS $$
	SELECT '01/01/' || to_char(current_date, 'YYYY'); 
$$;


ALTER FUNCTION public.get_start_year(character varying) OWNER TO postgres;

--
-- Name: get_tax_min(double precision, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION get_tax_min(double precision, integer, integer) RETURNS double precision
    LANGUAGE sql
    AS $_$
	SELECT CASE WHEN max(tax_range) is null THEN 0 ELSE max(tax_range) END 
	FROM period_tax_rates WHERE (tax_range < $1) AND (period_tax_type_id = $2) AND (employer_rate = $3);
$_$;


ALTER FUNCTION public.get_tax_min(double precision, integer, integer) OWNER TO postgres;

--
-- Name: ins_account_activity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_account_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.ins_account_activity() OWNER TO postgres;

--
-- Name: ins_accounts_limit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_accounts_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_deposit_accounts		integer;
	v_accounts_limit		integer;
BEGIN

	SELECT count(deposit_account_id) INTO v_deposit_accounts
	FROM deposit_accounts
	WHERE (org_id = NEW.org_id);
	
	SELECT accounts_limit INTO v_accounts_limit
	FROM orgs
	WHERE (org_id = NEW.org_id);
	
	IF(v_deposit_accounts > v_accounts_limit)THEN
		RAISE EXCEPTION 'You have reached the maximum staff limit, request for a quite for more';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_accounts_limit() OWNER TO postgres;

--
-- Name: ins_activity_limit(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_activity_limit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_account_activitys			integer;
	v_activity_limit			integer;
BEGIN

	SELECT count(account_activity_id) INTO v_account_activitys
	FROM account_activity
	WHERE (org_id = NEW.org_id);
	
	SELECT activity_limit INTO v_activity_limit
	FROM orgs
	WHERE (org_id = NEW.org_id);
	
	IF(v_account_activitys > v_activity_limit)THEN
		RAISE EXCEPTION 'You have reached the maximum transaction limit, request for a quite for more';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_activity_limit() OWNER TO postgres;

--
-- Name: ins_address(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_address() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_address_id		integer;
BEGIN
	SELECT address_id INTO v_address_id
	FROM address WHERE (is_default = true)
		AND (table_name = NEW.table_name) AND (table_id = NEW.table_id) AND (address_id <> NEW.address_id);

	IF(NEW.is_default is null)THEN
		NEW.is_default := false;
	END IF;

	IF(NEW.is_default = true) AND (v_address_id is not null) THEN
		RAISE EXCEPTION 'Only one default Address allowed.';
	ELSIF (NEW.is_default = false) AND (v_address_id is null) THEN
		NEW.is_default := true;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_address() OWNER TO postgres;

--
-- Name: ins_applicants(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_applicants() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_customer_id			integer;
BEGIN

	IF (TG_OP = 'INSERT') THEN
		NEW.approve_status := 'Completed';
	ELSIF(NEW.approve_status = 'Approved')THEN
		SELECT customer_id INTO v_customer_id
		FROM customers WHERE (identification_number = NEW.identification_number);
		
		IF(v_customer_id is null)THEN
			v_customer_id := nextval('customers_customer_id_seq');
			INSERT INTO customers(customer_id, org_id, business_account, person_title, 
				customer_name, identification_number, identification_type, client_email, 
				telephone_number, telephone_number2, address, town, zip_code, 
				date_of_birth, gender, nationality, marital_status, picture_file, 
				employed, self_employed, employer_name, employer_address, introduced_by,
				details)
			VALUES (v_customer_id, NEW.org_id, NEW.business_account, NEW.person_title, 
				NEW.customer_name, NEW.identification_number, NEW.identification_type, NEW.client_email, 
				NEW.telephone_number, NEW.telephone_number2, NEW.address, NEW.town, NEW.zip_code, 
				NEW.date_of_birth, NEW.gender, NEW.nationality, NEW.marital_status, NEW.picture_file, 
				NEW.employed, NEW.self_employed, NEW.employer_name, NEW.employer_address, NEW.introduced_by,
				NEW.details);
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_applicants() OWNER TO postgres;

--
-- Name: ins_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
BEGIN

	IF (NEW.forward_id is not null) THEN
		SELECT workflow_phase_id, org_entity_id, app_entity_id, approval_level, table_name, table_id INTO reca
		FROM approvals
		WHERE (approval_id = NEW.forward_id);

		NEW.workflow_phase_id := reca.workflow_phase_id;
		NEW.approval_level := reca.approval_level;
		NEW.table_name := reca.table_name;
		NEW.table_id := reca.table_id;
		NEW.approve_status := 'Completed';
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_approvals() OWNER TO postgres;

--
-- Name: ins_budget(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_budget() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

	INSERT INTO pc_allocations (period_id, department_id, org_id)
	SELECT NEW.period_id, department_id, org_id
	FROM departments
	WHERE (departments.active = true) AND (departments.petty_cash = true) AND (departments.org_id = NEW.org_id);

	INSERT INTO pc_budget (	pc_allocation_id, org_id, pc_item_id, budget_units, budget_price)
	SELECT pc_allocations.pc_allocation_id, pc_allocations.org_id,
		pc_items.pc_item_id, pc_items.default_units, pc_items.default_price
	FROM pc_allocation CROSS JOIN pc_items
	WHERE (pc_allocation.period_id = NEW.period_id) AND (pc_allocation.org_id = NEW.org_id)
		AND (pc_items.default_units > 0);
	
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_budget() OWNER TO postgres;

--
-- Name: ins_deposit_accounts(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_deposit_accounts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_fee_amount		real;
	v_fee_ps			real;
	myrec				RECORD;
BEGIN

	IF(TG_OP = 'INSERT')THEN
		SELECT interest_rate, activity_frequency_id, min_opening_balance, lockin_period_frequency,
			minimum_balance, maximum_balance INTO myrec
		FROM products WHERE product_id = NEW.product_id;
		
		IF(NEW.customer_id is null)THEN
			SELECT customer_id INTO NEW.customer_id
			FROM entitys WHERE (entity_id = NEW.entity_id);
		END IF;
	
		NEW.account_number := '4' || lpad(NEW.org_id::varchar, 2, '0')  || lpad(NEW.customer_id::varchar, 4, '0') || lpad(NEW.deposit_account_id::varchar, 2, '0');
		
		IF(NEW.minimum_balance is null) THEN NEW.minimum_balance := myrec.minimum_balance; END IF;
		IF(NEW.maximum_balance is null) THEN NEW.maximum_balance := myrec.maximum_balance; END IF;
		IF(NEW.interest_rate is null) THEN NEW.interest_rate := myrec.interest_rate; END IF;
		
		NEW.activity_frequency_id := myrec.activity_frequency_id;
		NEW.lockin_period_frequency := myrec.lockin_period_frequency;
	ELSE
		IF(NEW.approve_status = 'Approved')THEN
			INSERT INTO account_activity (deposit_account_id, activity_type_id, activity_frequency_id,
				activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
				activity_date, value_date, account_debit)
			SELECT NEW.deposit_account_id, account_definations.activity_type_id, account_definations.activity_frequency_id,
				1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
				NEW.opening_date, NEW.opening_date, account_definations.fee_amount
			FROM account_definations INNER JOIN activity_types ON account_definations.activity_type_id = activity_types.activity_type_id
				INNER JOIN products ON account_definations.product_id = products.product_id
			WHERE (account_definations.product_id = NEW.product_id) AND (account_definations.org_id = NEW.org_id)
				AND (account_definations.activity_frequency_id = 1) AND (activity_types.use_key_id = 201) 
				AND (account_definations.is_active = true)
				AND (account_definations.start_date < NEW.opening_date);
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_deposit_accounts() OWNER TO postgres;

--
-- Name: ins_entitys(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entitys() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	IF(NEW.entity_type_id is not null) THEN
		INSERT INTO Entity_subscriptions (org_id, entity_type_id, entity_id, subscription_level_id)
		VALUES (NEW.org_id, NEW.entity_type_id, NEW.entity_id, 0);
	END IF;

	INSERT INTO entity_values (org_id, entity_id, entity_field_id)
	SELECT NEW.org_id, NEW.entity_id, entity_field_id
	FROM entity_fields
	WHERE (org_id = NEW.org_id) AND (is_active = true);

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_entitys() OWNER TO postgres;

--
-- Name: ins_entry_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec 		RECORD;
	vorgid		integer;
	formName 	varchar(120);
	msg 		varchar(120);
BEGIN
	SELECT entry_form_id, org_id INTO rec
	FROM entry_forms 
	WHERE (form_id = CAST($1 as int)) AND (entity_ID = CAST($2 as int))
		AND (approve_status = 'Draft');

	SELECT form_name, org_id INTO formName, vorgid
	FROM forms WHERE (form_id = CAST($1 as int));

	IF rec.entry_form_id is null THEN
		INSERT INTO entry_forms (form_id, entity_id, org_id) 
		VALUES (CAST($1 as int), CAST($2 as int), vorgid);
		msg := 'Added Form : ' || formName;
	ELSE
		msg := 'There is an incomplete form : ' || formName;
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.ins_entry_form(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: ins_entry_forms(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_entry_forms() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca		RECORD;
BEGIN
	
	SELECT default_values, default_sub_values INTO reca
	FROM forms
	WHERE (form_id = NEW.form_id);
	
	NEW.answer := reca.default_values;
	NEW.sub_answer := reca.default_sub_values;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_entry_forms() OWNER TO postgres;

--
-- Name: ins_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.field_order is null) THEN
		SELECT max(field_order) INTO v_ord
		FROM fields
		WHERE (form_id = NEW.form_id);

		IF (v_ord is null) THEN
			NEW.field_order := 10;
		ELSE
			NEW.field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_fields() OWNER TO postgres;

--
-- Name: ins_loans(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_loans() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	myrec					RECORD;
	v_activity_type_id		integer;
	v_repayments			integer;
	v_currency_id			integer;
	v_less_initial_fee		boolean;
	v_reducing_balance		boolean;
	v_reducing_payments		boolean;
	v_loan_amount			real;
	v_nir					real;
	v_disbursed_date		date;
BEGIN

	IF(NEW.repayment_period < 1)THEN
		RAISE EXCEPTION 'The repayment period has to be greater than 1 or 1';
	ELSIF(NEW.principal_amount < 1)THEN
		RAISE EXCEPTION 'The principal amount has to be greater than 1';
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		SELECT interest_rate, activity_frequency_id, min_opening_balance, lockin_period_frequency,
			minimum_balance, maximum_balance INTO myrec
		FROM products WHERE product_id = NEW.product_id;
		
		IF(NEW.customer_id is null)THEN
			SELECT customer_id INTO NEW.customer_id
			FROM entitys WHERE (entity_id = NEW.entity_id);
		END IF;
	
		NEW.account_number := '5' || lpad(NEW.org_id::varchar, 2, '0')  || lpad(NEW.customer_id::varchar, 4, '0') || lpad(NEW.loan_id::varchar, 2, '0');
			
		NEW.interest_rate := myrec.interest_rate;
		NEW.activity_frequency_id := myrec.activity_frequency_id;
	ELSIF((NEW.approve_status = 'Approved') AND (OLD.approve_status <> 'Approved'))THEN
		SELECT activity_type_id INTO v_activity_type_id
		FROM vw_account_definations 
		WHERE (use_key_id = 108) AND (is_active = true) AND (product_id = NEW.product_id);
		
		SELECT currency_id, less_initial_fee INTO v_currency_id, v_less_initial_fee
		FROM products
		WHERE (product_id = NEW.product_id);
		
		v_disbursed_date := current_date;
		IF(NEW.disbursed_date is not null)THEN v_disbursed_date := NEW.disbursed_date; END IF;
		
		INSERT INTO account_activity (loan_id, activity_type_id, activity_frequency_id,
			activity_status_id, currency_id, entity_id, org_id, transfer_account_no,
			activity_date, value_date, account_debit)
		SELECT NEW.loan_id, account_definations.activity_type_id, account_definations.activity_frequency_id,
			1, products.currency_id, NEW.entity_id, NEW.org_id, account_definations.account_number,
			v_disbursed_date, v_disbursed_date, account_definations.fee_amount
		FROM account_definations INNER JOIN activity_types ON account_definations.activity_type_id = activity_types.activity_type_id
			INNER JOIN products ON account_definations.product_id = products.product_id
		WHERE (account_definations.product_id = NEW.product_id) AND (account_definations.org_id = NEW.org_id)
			AND (account_definations.activity_frequency_id = 1) AND (activity_types.use_key_id = 201) 
			AND (account_definations.is_active = true)
			AND (account_definations.start_date < v_disbursed_date);
		
		v_loan_amount := NEW.principal_amount;
		IF(v_less_initial_fee = true)THEN
			SELECT sum(account_debit - account_credit) INTO v_loan_amount
			FROM account_activity WHERE loan_id = NEW.loan_id;
			IF(v_loan_amount is null)THEN v_loan_amount := 0; END IF;
			v_loan_amount := NEW.principal_amount - v_loan_amount;
		END IF;
		
		IF(v_activity_type_id is not null)THEN
			INSERT INTO account_activity (loan_id, transfer_account_no, org_id, activity_type_id, currency_id, 
				activity_frequency_id, activity_date, value_date, activity_status_id, account_credit, account_debit)
			VALUES (NEW.loan_id, NEW.disburse_account, NEW.org_id, v_activity_type_id, v_currency_id, 
				1, v_disbursed_date, v_disbursed_date, 1, 0, v_loan_amount);
		
			NEW.disbursed_date := v_disbursed_date;
			NEW.expected_matured_date := v_disbursed_date + (NEW.repayment_period || ' months')::interval;
		END IF;
	END IF;
	
	---- Calculate for repayment
	IF(NEW.approve_status <> 'Approved')THEN
		SELECT interest_methods.reducing_balance, interest_methods.reducing_payments INTO v_reducing_balance, v_reducing_payments
		FROM interest_methods INNER JOIN products ON interest_methods.interest_method_id = products.interest_method_id
		WHERE (products.product_id = NEW.product_id);
		IF(v_reducing_balance = true)THEN
			v_nir := NEW.interest_rate / 1200;
			IF(v_reducing_payments = true)THEN
				NEW.repayment_amount := NEW.principal_amount / NEW.repayment_period;
				NEW.expected_repayment := NEW.principal_amount * NEW.repayment_period * v_nir;
				NEW.expected_repayment := NEW.expected_repayment - (NEW.repayment_period * (NEW.repayment_period - 1) * NEW.repayment_amount * v_nir / 2);
				NEW.expected_repayment := NEW.expected_repayment + NEW.principal_amount;
			ELSE
				NEW.repayment_amount := (v_nir * NEW.principal_amount) / (1 - ((1 + v_nir) ^ (-NEW.repayment_period)));
				NEW.expected_repayment := NEW.repayment_amount * NEW.repayment_period;
			END IF;
			
			RAISE NOTICE 'Month Intrest % ', v_nir;
			RAISE NOTICE 'Expected % ', NEW.expected_repayment;
		ELSE
			NEW.expected_repayment := NEW.principal_amount * ((1.0 + (NEW.interest_rate / 100)) ^ (NEW.repayment_period::real / 12));
			NEW.repayment_amount := NEW.expected_repayment / NEW.repayment_period;
			
			RAISE NOTICE 'repayment period % ', NEW.repayment_period;
			RAISE NOTICE 'repayment annual % ', (NEW.repayment_period::real / 12);
			RAISE NOTICE 'Intrest Rate % ', (1.0 + (NEW.interest_rate / 100));
			RAISE NOTICE 'repayment rate % ', ((1.0 + (NEW.interest_rate / 100)) ^ (NEW.repayment_period::real / 12));
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_loans() OWNER TO postgres;

--
-- Name: ins_mpesa_api(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_mpesa_api() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_customer_id			integer;
BEGIN

	NEW.TransactionTime := to_timestamp(NEW.TransTime, 'YYYYMMDDHH24MISS');
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_mpesa_api() OWNER TO postgres;

--
-- Name: ins_password(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id		integer;
BEGIN

	SELECT entity_id INTO v_entity_id
	FROM entitys
	WHERE (trim(lower(user_name)) = trim(lower(NEW.user_name)))
		AND entity_id <> NEW.entity_id;
		
	IF(v_entity_id is not null)THEN
		RAISE EXCEPTION 'The username exists use a different one or reset password for the current one';
	END IF;

	IF(TG_OP = 'INSERT') THEN
		IF(NEW.first_password is null)THEN
			NEW.first_password := first_password();
		END IF;

		IF (NEW.entity_password is null) THEN
			NEW.entity_password := md5(NEW.first_password);
		END IF;
	ELSIF(OLD.first_password <> NEW.first_password) THEN
		NEW.Entity_password := md5(NEW.first_password);
	END IF;
	
	IF(NEW.user_name is null)THEN
		SELECT org_sufix || '.' || lower(trim(replace(NEW.entity_name, ' ', ''))) INTO NEW.user_name
		FROM orgs
		WHERE org_id = NEW.org_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_password() OWNER TO postgres;

--
-- Name: ins_periods(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_periods() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	year_close 		BOOLEAN;
BEGIN
	SELECT year_closed INTO year_close
	FROM fiscal_years
	WHERE (fiscal_year_id = NEW.fiscal_year_id);

	IF(year_close = true)THEN
		RAISE EXCEPTION 'The year is closed not transactions are allowed.';
	END IF;
	IF(NEW.start_date > NEW.end_date)THEN
		RAISE EXCEPTION 'The starting date has to be before the ending date.';
	END IF;
	
	IF(TG_OP = 'UPDATE')THEN    
		IF (OLD.closed = true) AND (NEW.closed = false) THEN
			NEW.approve_status := 'Draft';
		END IF;
	ELSE
		IF(NEW.gl_payroll_account is null)THEN NEW.gl_payroll_account := get_default_account(27, NEW.org_id); END IF;
		IF(NEW.gl_advance_account is null)THEN NEW.gl_advance_account := get_default_account(28, NEW.org_id); END IF;
	END IF;

	IF (NEW.approve_status = 'Approved') THEN
		NEW.opened = false;
		NEW.activated = false;
		NEW.closed = true;
	END IF;


	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_periods() OWNER TO postgres;

--
-- Name: ins_sub_fields(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sub_fields() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_ord	integer;
BEGIN
	IF(NEW.sub_field_order is null) THEN
		SELECT max(sub_field_order) INTO v_ord
		FROM sub_fields
		WHERE (field_id = NEW.field_id);

		IF (v_ord is null) THEN
			NEW.sub_field_order := 10;
		ELSE
			NEW.sub_field_order := v_ord + 10;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_sub_fields() OWNER TO postgres;

--
-- Name: ins_subscriptions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_subscriptions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id				integer;
	v_entity_type_id		integer;
	v_org_id				integer;
	v_currency_id			integer;
	v_customer_id			integer;
	v_account_number		varchar(32);
	v_product_id			integer;
	v_department_id			integer;
	v_bank_id				integer;
	v_deposit_account		integer;
	v_tax_type_id			integer;
	v_workflow_id			integer;
	v_org_suffix			char(2);
	myrec 					RECORD;
BEGIN

	IF (TG_OP = 'INSERT') THEN
		SELECT entity_id INTO v_entity_id
		FROM entitys WHERE lower(trim(user_name)) = lower(trim(NEW.primary_email));

		IF(v_entity_id is null)THEN
			NEW.entity_id := nextval('entitys_entity_id_seq');
			INSERT INTO entitys (entity_id, org_id, use_key_id, entity_type_id, entity_name, User_name, primary_email,  function_role, first_password)
			VALUES (NEW.entity_id, 0, 5, 5, NEW.primary_contact, lower(trim(NEW.primary_email)), lower(trim(NEW.primary_email)), 'subscription', null);
		
			INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
			VALUES (4, 0, NEW.entity_id, 'subscription');
		
			NEW.approve_status := 'Completed';
		ELSE
			RAISE EXCEPTION 'You already have an account, login and request for services';
		END IF;
	ELSIF(NEW.approve_status = 'Approved')THEN

		NEW.org_id := nextval('orgs_org_id_seq');
		v_customer_id := nextval('customers_customer_id_seq');
		v_deposit_account := nextval('deposit_accounts_deposit_account_id_seq');
		INSERT INTO orgs(org_id, currency_id, org_name, org_full_name, org_sufix, default_country_id, logo)
		VALUES(NEW.org_id, 1, NEW.business_name, NEW.business_name, NEW.org_id, NEW.country_id, 'logo.png');
		
		INSERT INTO address (address_name, sys_country_id, table_name, table_id, premises, town, phone_number, website, is_default) 
		VALUES (NEW.business_name, NEW.country_id, 'orgs', NEW.org_id, NEW.business_address, NEW.city, NEW.telephone, NEW.website, true);
		
		v_currency_id := nextval('currency_currency_id_seq');
		INSERT INTO currency (org_id, currency_id, currency_name, currency_symbol) VALUES (NEW.org_id, v_currency_id, 'Default Currency', 'DC');
		UPDATE orgs SET currency_id = v_currency_id WHERE org_id = NEW.org_id;
		
		INSERT INTO currency_rates (org_id, currency_id, exchange_rate) VALUES (NEW.org_id, v_currency_id, 1);
		
		INSERT INTO entity_types (org_id, entity_type_name, entity_role, use_key_id)
		SELECT NEW.org_id, entity_type_name, entity_role, use_key_id
		FROM entity_types WHERE org_id = 1;
		
		INSERT INTO subscription_levels (org_id, subscription_level_name)
		SELECT NEW.org_id, subscription_level_name
		FROM subscription_levels WHERE org_id = 1;
		
		INSERT INTO locations (org_id, location_name) VALUES (NEW.org_id, 'Head Office');
		INSERT INTO departments (org_id, department_name) VALUES (NEW.org_id, 'Board of Directors');
		
		FOR myrec IN SELECT tax_type_id, use_key_id, tax_type_name, formural, tax_relief, 
			tax_type_order, in_tax, linear, percentage, employer, employer_ps, active,
			account_number, employer_account
			FROM tax_types WHERE org_id = 1 AND ((sys_country_id is null) OR (sys_country_id = NEW.country_id))
			ORDER BY tax_type_id 
		LOOP
			v_tax_type_id := nextval('tax_types_tax_type_id_seq');
			INSERT INTO tax_types (org_id, tax_type_id, use_key_id, tax_type_name, formural, tax_relief, tax_type_order, in_tax, linear, percentage, employer, employer_ps, active, currency_id, account_number, employer_account)
			VALUES (NEW.org_id, v_tax_type_id, myrec.use_key_id, myrec.tax_type_name, myrec.formural, myrec.tax_relief, myrec.tax_type_order, myrec.in_tax, myrec.linear, myrec.percentage, myrec.employer, myrec.employer_ps, myrec.active, v_currency_id, myrec.account_number, myrec.employer_account);
			
			INSERT INTO tax_rates (org_id, tax_type_id, tax_range, tax_rate)
			SELECT NEW.org_id,  v_tax_type_id, tax_range, tax_rate
			FROM tax_rates
			WHERE org_id = 1 and tax_type_id = myrec.tax_type_id;
		END LOOP;
		
		v_bank_id := nextval('banks_bank_id_seq');
		INSERT INTO banks (org_id, bank_id, bank_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		INSERT INTO bank_branch (org_id, bank_id, bank_branch_name) VALUES (NEW.org_id, v_bank_id, 'Cash');
		
		INSERT INTO transaction_counters(transaction_type_id, org_id, document_number)
		SELECT transaction_type_id, NEW.org_id, 1
		FROM transaction_types;
		
		INSERT INTO sys_emails (org_id, use_type,  sys_email_name, title, details) 
		SELECT NEW.org_id, use_type, sys_email_name, title, details
		FROM sys_emails
		WHERE org_id = 1;
		
		INSERT INTO account_class (org_id, account_class_no, chat_type_id, chat_type_name, account_class_name)
		SELECT NEW.org_id, account_class_no, chat_type_id, chat_type_name, account_class_name
		FROM account_class
		WHERE org_id = 1;
		
		INSERT INTO account_types (org_id, account_class_id, account_type_no, account_type_name)
		SELECT a.org_id, a.account_class_id, b.account_type_no, b.account_type_name
		FROM account_class a INNER JOIN vw_account_types b ON a.account_class_no = b.account_class_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO accounts (org_id, account_type_id, account_no, account_name)
		SELECT a.org_id, a.account_type_id, b.account_no, b.account_name
		FROM account_types a INNER JOIN vw_accounts b ON a.account_type_no = b.account_type_no
		WHERE (a.org_id = NEW.org_id) AND (b.org_id = 1);
		
		INSERT INTO default_accounts (org_id, use_key_id, account_id)
		SELECT c.org_id, a.use_key_id, c.account_id
		FROM default_accounts a INNER JOIN accounts b ON a.account_id = b.account_id
			INNER JOIN accounts c ON b.account_no = c.account_no
		WHERE (a.org_id = 1) AND (c.org_id = NEW.org_id);
		
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Services');
		INSERT INTO item_category (org_id, item_category_name) VALUES (NEW.org_id, 'Goods');

		INSERT INTO item_units (org_id, item_unit_name) VALUES (NEW.org_id, 'Each');
		
		SELECT entity_type_id INTO v_entity_type_id
		FROM entity_types 
		WHERE (org_id = NEW.org_id) AND (use_key_id = 0);
				
		UPDATE entitys SET org_id = NEW.org_id, entity_type_id = v_entity_type_id, function_role='subscription,admin,manager'
		WHERE entity_id = NEW.entity_id;
		
		UPDATE entity_subscriptions SET org_id = NEW.org_id, entity_type_id = v_entity_type_id
		WHERE entity_id = NEW.entity_id;
		
		INSERT INTO collateral_types (org_id, collateral_type_name) VALUES (NEW.org_id, 'Property Title Deed');
		
		INSERT INTO activity_types (cr_account_id, dr_account_id, use_key_id, org_id, activity_type_name, is_active, activity_type_no)
		SELECT dra.account_id, cra.account_id, vw_activity_types.use_key_id, NEW.org_id, 
			vw_activity_types.activity_type_name, vw_activity_types.is_active, vw_activity_types.activity_type_no
		FROM vw_activity_types
			INNER JOIN accounts dra ON vw_activity_types.dr_account_no = dra.account_no
			INNER JOIN accounts cra ON vw_activity_types.cr_account_no = cra.account_no
		WHERE (dra.org_id = NEW.org_id) AND (cra.org_id = NEW.org_id) AND (vw_activity_types.org_id = 1)
		ORDER BY vw_activity_types.activity_type_id;
		
		v_account_number := '4' || lpad(NEW.org_id::varchar, 2, '0')  || lpad(v_customer_id::varchar, 4, '0');

		INSERT INTO interest_methods (activity_type_id, org_id, interest_method_name, reducing_balance, reducing_payments, formural, interest_method_no, account_number)
		SELECT oa.activity_type_id, oa.org_id, interest_methods.interest_method_name, 
			interest_methods.reducing_balance, interest_methods.reducing_payments, 
			interest_methods.formural, interest_methods.interest_method_no,
			v_account_number || lpad((v_deposit_account + 3)::varchar, 2, '0') 
		FROM interest_methods INNER JOIN activity_types ON interest_methods.activity_type_id = activity_types.activity_type_id
			INNER JOIN activity_types oa ON activity_types.activity_type_no = oa.activity_type_no
		WHERE (activity_types.org_id = 1) AND (oa.org_id = NEW.org_id)
		ORDER BY interest_methods.interest_method_id;
		
		INSERT INTO penalty_methods(activity_type_id, org_id, penalty_method_name, formural, penalty_method_no, account_number)
		SELECT oa.activity_type_id, oa.org_id, penalty_methods.penalty_method_name, 
			penalty_methods.formural, penalty_methods.penalty_method_no,
			v_account_number || lpad((v_deposit_account + 4)::varchar, 2, '0') 
		FROM penalty_methods INNER JOIN activity_types ON penalty_methods.activity_type_id = activity_types.activity_type_id
			INNER JOIN activity_types oa ON activity_types.activity_type_no = oa.activity_type_no
		WHERE (activity_types.org_id = 1) AND (oa.org_id = NEW.org_id)
		ORDER BY penalty_methods.penalty_method_id;
		
		INSERT INTO products(interest_method_id, penalty_method_id, activity_frequency_id, 
			currency_id, org_id, product_name, description, loan_account, 
			is_active, interest_rate, min_opening_balance, lockin_period_frequency, 
			minimum_balance, maximum_balance, minimum_day, maximum_day, minimum_trx, 
			maximum_trx, maximum_repayments, product_no,  approve_status)
		SELECT interest_methods.interest_method_id, penalty_methods.penalty_method_id, vw_products.activity_frequency_id, 
			v_currency_id, NEW.org_id, vw_products.product_name, vw_products.description, vw_products.loan_account, 
			vw_products.is_active, vw_products.interest_rate, vw_products.min_opening_balance, vw_products.lockin_period_frequency, 
			vw_products.minimum_balance, vw_products.maximum_balance, vw_products.minimum_day, vw_products.maximum_day, vw_products.minimum_trx, 
			vw_products.maximum_trx, vw_products.maximum_repayments, vw_products.product_no, vw_products.approve_status
		FROM vw_products INNER JOIN interest_methods ON vw_products.interest_method_no = interest_methods.interest_method_no
			INNER JOIN penalty_methods ON vw_products.penalty_method_no = penalty_methods.penalty_method_no
		WHERE (vw_products.org_id = 1) 
			AND (interest_methods.org_id = NEW.org_id) AND (penalty_methods.org_id = NEW.org_id)
		ORDER BY vw_products.product_id;

		INSERT INTO account_definations(product_id, activity_type_id, charge_activity_id, 
			activity_frequency_id, org_id, account_defination_name, start_date, 
			end_date, fee_amount, fee_ps, has_charge, is_active, account_number)
		SELECT products.product_id, activity_types.activity_type_id, charge_activity.activity_type_id, 
			ad.activity_frequency_id, NEW.org_id, ad.account_defination_name, 
			ad.start_date, ad.end_date, ad.fee_amount, 
			ad.fee_ps, ad.has_charge, ad.is_active, 
			v_account_number || lpad((v_deposit_account + ad.account_number::integer)::varchar, 2, '0')
		FROM vw_account_definations as ad INNER JOIN products ON ad.product_no = products.product_no
			INNER JOIN activity_types ON ad.activity_type_no = activity_types.activity_type_no
			INNER JOIN activity_types as charge_activity ON ad.charge_activity_no = charge_activity.activity_type_no
		WHERE (ad.org_id = 1) 
			AND (products.org_id = NEW.org_id) AND (activity_types.org_id = NEW.org_id) AND (charge_activity.org_id = NEW.org_id);

		SELECT product_id INTO v_product_id
		FROM products WHERE (product_no = 0) AND (org_id = NEW.org_id);
		
		INSERT INTO customers (customer_id, org_id, business_account, customer_name, identification_number, identification_type, client_email, telephone_number, date_of_birth, nationality, approve_status)
		VALUES (v_customer_id, NEW.org_id, 2, 'OpenBaraza Bank', '0', 'Org', 'info@openbaraza.org', '+254', current_date, 'KE', 'Approved');

		INSERT INTO deposit_accounts (customer_id, product_id, org_id, is_active, approve_status, narrative, minimum_balance) VALUES 
		(v_customer_id, v_product_id, NEW.org_id, true, 'Approved', 'Deposits', -100000000000),
		(v_customer_id, v_product_id, NEW.org_id, true, 'Approved', 'Charges', -100000000000),
		(v_customer_id, v_product_id, NEW.org_id, true, 'Approved', 'Interest', -100000000000),
		(v_customer_id, v_product_id, NEW.org_id, true, 'Approved', 'Penalty', -100000000000),
		(v_customer_id, v_product_id, NEW.org_id, true, 'Approved', 'Loan', -100000000000);
		
		INSERT INTO workflows (link_copy, org_id, source_entity_id, workflow_name, table_name, approve_email, reject_email) 
		SELECT aa.workflow_id, cc.org_id, cc.entity_type_id, aa.workflow_name, aa.table_name, aa.approve_email, aa.reject_email
		FROM workflows aa INNER JOIN entity_types bb ON aa.source_entity_id = bb.entity_type_id
			INNER JOIN entity_types cc ON bb.use_key_id = cc.use_key_id
		WHERE aa.org_id = 1 AND cc.org_id = NEW.org_id
		ORDER BY aa.workflow_id;

		INSERT INTO workflow_phases (org_id, workflow_id, approval_entity_id, approval_level, return_level, 
			escalation_days, escalation_hours, required_approvals, advice, notice, 
			phase_narrative, advice_email, notice_email) 
		SELECT bb.org_id, bb.workflow_id, dd.entity_type_id, aa.approval_level, aa.return_level, 
			aa.escalation_days, aa.escalation_hours, aa.required_approvals, aa.advice, aa.notice, 
			aa.phase_narrative, aa.advice_email, aa.notice_email
		FROM workflow_phases aa INNER JOIN workflows bb ON aa.workflow_id = bb.link_copy
			INNER JOIN entity_types cc ON aa.approval_entity_id = cc.entity_type_id
			INNER JOIN entity_types dd ON cc.use_key_id = dd.use_key_id
		WHERE aa.org_id = 1 AND bb.org_id = NEW.org_id AND dd.org_id = NEW.org_id;
		
		INSERT INTO sys_emails (org_id, use_type, sys_email_name, title, details)
		SELECT NEW.org_id, use_type, sys_email_name, title, details
		FROM sys_emails
		WHERE org_id = 1;

		INSERT INTO sys_emailed (sys_email_id, org_id, table_id, table_name)
		VALUES (5, NEW.org_id, NEW.entity_id, 'subscription');
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_subscriptions() OWNER TO postgres;

--
-- Name: ins_sys_reset(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_sys_reset() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_entity_id			integer;
	v_org_id			integer;
	v_password			varchar(32);
BEGIN
	SELECT entity_id, org_id INTO v_entity_id, v_org_id
	FROM entitys
	WHERE (lower(trim(primary_email)) = lower(trim(NEW.request_email)));

	IF(v_entity_id is not null) THEN
		v_password := upper(substring(md5(random()::text) from 3 for 9));

		UPDATE entitys SET first_password = v_password, entity_password = md5(v_password)
		WHERE entity_id = v_entity_id;

		INSERT INTO sys_emailed (org_id, sys_email_id, table_id, table_name)
		VALUES(v_org_id, 3, v_entity_id, 'entitys');
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.ins_sys_reset() OWNER TO postgres;

--
-- Name: ins_transactions(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_transactions() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_counter_id	integer;
	transid 		integer;
	currid			integer;
BEGIN

	IF(TG_OP = 'INSERT') THEN
		SELECT transaction_counter_id, document_number INTO v_counter_id, transid
		FROM transaction_counters 
		WHERE (transaction_type_id = NEW.transaction_type_id) AND (org_id = NEW.org_id);
		UPDATE transaction_counters SET document_number = transid + 1 
		WHERE (transaction_counter_id = v_counter_id);

		NEW.document_number := transid;
		IF(NEW.currency_id is null)THEN
			SELECT currency_id INTO NEW.currency_id
			FROM orgs
			WHERE (org_id = NEW.org_id);
		END IF;
				
		IF(NEW.payment_date is null) AND (NEW.transaction_date is not null)THEN
			NEW.payment_date := NEW.transaction_date;
		END IF;
	ELSE
	
		--- Ensure the direct expediture items are not added
		IF (OLD.ledger_type_id is null) AND (NEW.ledger_type_id is not null) THEN
			NEW.ledger_type_id := null;
		END IF;
			
		IF (OLD.journal_id is null) AND (NEW.journal_id is not null) THEN
		ELSIF ((OLD.approve_status != 'Completed') AND (NEW.approve_status = 'Completed')) THEN
			NEW.completed = true;
		ELSIF ((OLD.approve_status = 'Completed') AND (NEW.approve_status != 'Completed')) THEN
		ELSIF ((OLD.is_cleared = false) AND (NEW.is_cleared = true)) THEN
		ELSIF ((OLD.journal_id is not null) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already posted no changes are allowed.', NEW.transaction_id;
		ELSIF ((OLD.transaction_status_id > 1) AND (OLD.transaction_status_id = NEW.transaction_status_id)) THEN
			RAISE EXCEPTION 'Transaction % is already completed no changes are allowed.', NEW.transaction_id;
		END IF;
	END IF;
	
	IF ((NEW.approve_status = 'Draft') AND (NEW.completed = true)) THEN
		NEW.approve_status := 'Completed';
		NEW.transaction_status_id := 2;
	END IF;
	
	IF(NEW.transaction_type_id = 7)THEN
		NEW.tx_type := 1;
	END IF;
	IF(NEW.transaction_type_id = 8)THEN
		NEW.tx_type := -1;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_transactions() OWNER TO postgres;

--
-- Name: ins_transfer_beneficiary(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION ins_transfer_beneficiary() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	v_customer_id			integer;
BEGIN

	SELECT customer_id INTO NEW.customer_id
	FROM entitys WHERE (entity_id = NEW.entity_id);
	
	SELECT deposit_account_id, customer_id INTO NEW.deposit_account_id, v_customer_id
	FROM deposit_accounts
	WHERE (is_active = true) AND (approve_status = 'Approved')
		AND (account_number = NEW.account_number);
		
	IF(NEW.deposit_account_id is null)THEN
		RAISE EXCEPTION 'The account needs to exist and be active';
	ELSIF(NEW.customer_id = v_customer_id)THEN
		RAISE EXCEPTION 'You cannot add your own account as a beneficiary account';
	END IF;
	
	IF(TG_OP = 'INSERT')THEN
		NEW.approve_status = 'Completed';
	END IF;
	
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.ins_transfer_beneficiary() OWNER TO postgres;

--
-- Name: log_account_activity(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_account_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log.lg_account_activity_log(account_activity_id, deposit_account_id, 
		transfer_account_id, activity_type_id, activity_frequency_id, 
		activity_status_id, currency_id, period_id, entity_id,
		loan_id, transfer_loan_id, org_id, link_activity_id, deposit_account_no, 
		transfer_link_id, transfer_account_no, activity_date, value_date, account_credit, 
		account_debit, balance, exchange_rate, application_date, approve_status, 
		workflow_table_id, action_date, details)
    VALUES (OLD.account_activity_id, OLD.deposit_account_id, 
		OLD.transfer_account_id, OLD.activity_type_id, OLD.activity_frequency_id, 
		OLD.activity_status_id, OLD.currency_id, OLD.period_id, OLD.entity_id,
		OLD.loan_id, OLD.transfer_loan_id, OLD.org_id, OLD.link_activity_id, OLD.deposit_account_no, 
		OLD.transfer_link_id, OLD.transfer_account_no, OLD.activity_date, OLD.value_date, OLD.account_credit, 
		OLD.account_debit, OLD.balance, OLD.exchange_rate, OLD.application_date, OLD.approve_status, 
		OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_account_activity() OWNER TO postgres;

--
-- Name: log_collaterals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_collaterals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log.lg_collaterals(collateral_id, loan_id, collateral_type_id, entity_id, org_id, 
		collateral_amount, collateral_received, collateral_released, 
		application_date, approve_status, workflow_table_id, action_date, details)
	VALUES (collateral_id, OLD.loan_id, OLD.collateral_type_id, OLD.entity_id, OLD.org_id,
		OLD.collateral_amount, OLD.collateral_received, OLD.collateral_released,
		OLD.application_date, OLD.approve_status, OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_collaterals() OWNER TO postgres;

--
-- Name: log_customers(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_customers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO logs.lg_customers(customer_id, entity_id, org_id, business_account, person_title, 
		customer_name, identification_number, identification_type, client_email, 
		telephone_number, telephone_number2, address, town, zip_code, 
		date_of_birth, gender, nationality, marital_status, picture_file, 
		employed, self_employed, employer_name, monthly_salary, monthly_net_income, 
		annual_turnover, annual_net_income, employer_address, introduced_by, 
		application_date, approve_status, workflow_table_id, action_date, details)
	VALUES (OLD.customer_id, OLD.entity_id, OLD.org_id, OLD.business_account, OLD.person_title,
		OLD.customer_name, OLD.identification_number, OLD.identification_type, OLD.client_email,
		OLD.telephone_number, OLD.telephone_number2, OLD.address, OLD.town, OLD.zip_code,
		OLD.date_of_birth, OLD.gender, OLD.nationality, OLD.marital_status, OLD.picture_file,
		OLD.employed, OLD.self_employed, OLD.employer_name, OLD.monthly_salary, OLD.monthly_net_income,
		OLD.annual_turnover, OLD.annual_net_income, OLD.employer_address, OLD.introduced_by,
		OLD.application_date, OLD.approve_status, OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_customers() OWNER TO postgres;

--
-- Name: log_deposit_accounts(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_deposit_accounts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO logs.lg_deposit_accounts(deposit_account_id, customer_id, product_id, activity_frequency_id, 
		entity_id, org_id, is_active, account_number, narrative, opening_date, 
		last_closing_date, credit_limit, minimum_balance, maximum_balance, 
		interest_rate, lockin_period_frequency, lockedin_until_date, 
		application_date, approve_status, workflow_table_id, action_date, details)
	VALUES (OLD.deposit_account_id, OLD.customer_id, OLD.product_id, OLD.activity_frequency_id,
		OLD.entity_id, OLD.org_id, OLD.is_active, OLD.account_number, OLD.narrative, OLD.opening_date,
		OLD.last_closing_date, OLD.credit_limit, OLD.minimum_balance, OLD.maximum_balance,
		OLD.interest_rate, OLD.lockin_period_frequency, OLD.lockedin_until_date,
		OLD.application_date, OLD.approve_status, OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_deposit_accounts() OWNER TO postgres;

--
-- Name: log_guarantees(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_guarantees() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO log.lg_guarantees(guarantee_id, loan_id, customer_id, entity_id, org_id, guarantee_amount, 
		guarantee_accepted, accepted_date, application_date, approve_status, 
		workflow_table_id, action_date, details)
	VALUES(OLD.guarantee_id, OLD.loan_id, OLD.customer_id, OLD.entity_id, OLD.org_id, OLD.guarantee_amount,
		OLD.guarantee_accepted, OLD.accepted_date, OLD.application_date, OLD.approve_status,
		OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_guarantees() OWNER TO postgres;

--
-- Name: log_loans(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION log_loans() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO logs.lg_loans(loan_id, customer_id, product_id, activity_frequency_id, entity_id, 
		org_id, account_number, disburse_account, principal_amount, interest_rate, 
		repayment_amount, repayment_period, disbursed_date, matured_date, 
		expected_matured_date, expected_repayment, application_date, 
		approve_status, workflow_table_id, action_date, details)
	VALUES(OLD.loan_id, OLD.customer_id, OLD.product_id, OLD.activity_frequency_id, OLD.entity_id,
		OLD.org_id, OLD.account_number, OLD.disburse_account, OLD.principal_amount, OLD.interest_rate,
		OLD.repayment_amount, OLD.repayment_period, OLD.disbursed_date, OLD.matured_date,
		OLD.expected_matured_date, OLD.expected_repayment, OLD.application_date,
		OLD.approve_status, OLD.workflow_table_id, OLD.action_date, OLD.details);
	RETURN NULL;
END;
$$;


ALTER FUNCTION public.log_loans() OWNER TO postgres;

--
-- Name: open_periods(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION open_periods(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id			integer;
	v_period_id			integer;
	msg					varchar(120);
BEGIN

	IF ($3 = '1') THEN
		UPDATE periods SET opened = true WHERE period_id = $1::int;
		msg := 'Period Opened';
	ELSIF ($3 = '2') THEN
		UPDATE periods SET closed = true WHERE period_id = $1::int;
		msg := 'Period Closed';
	ELSIF ($3 = '3') THEN
		UPDATE periods SET activated = true WHERE period_id = $1::int;
		msg := 'Period Activated';
	ELSIF ($3 = '4') THEN
		UPDATE periods SET activated = false WHERE period_id = $1::int;
		msg := 'Period De-activated';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.open_periods(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: password_validate(character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION password_validate(character varying, character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_entity_id			integer;
	v_entity_password	varchar(64);
BEGIN

	SELECT entity_id, entity_password INTO v_entity_id, v_entity_password
	FROM entitys WHERE (user_name = $1);

	IF(v_entity_id is null)THEN
		v_entity_id = -1;
	ELSIF(md5($2) != v_entity_password) THEN
		v_entity_id = -1;
	END IF;

	return v_entity_id;
END;
$_$;


ALTER FUNCTION public.password_validate(character varying, character varying) OWNER TO postgres;

--
-- Name: payroll_payable(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION payroll_payable(integer, integer) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	v_org_id				integer;
	v_org_name				varchar(50);
	v_org_client_id			integer;
	v_account_id			integer;
	v_entity_type_id		integer;
	v_bank_account_id		integer;
	reca					RECORD;
	msg						varchar(120);
BEGIN

	SELECT orgs.org_id, orgs.org_client_id, orgs.org_name INTO v_org_id, v_org_client_id, v_org_name
	FROM orgs INNER JOIN periods ON orgs.org_id = periods.org_id
	WHERE (periods.period_id = $1);
	
	IF(v_org_client_id is null)THEN
		SELECT account_id INTO v_account_id
		FROM default_accounts 
		WHERE (org_id = v_org_id) AND (use_key_id = 52);
		
		SELECT max(entity_type_id) INTO v_entity_type_id
		FROM entity_types
		WHERE (org_id = v_org_id) AND (use_key_id = 3);
		
		IF((v_account_id is not null) AND (v_entity_type_id is not null))THEN
			v_org_client_id := nextval('entitys_entity_id_seq');
			
			INSERT INTO entitys (entity_id, org_id, entity_type_id, account_id, entity_name, user_name, function_role, use_key_id)
			VALUES (v_org_client_id, v_org_id, v_entity_type_id, v_account_id, v_org_name, lower(trim(v_org_name)), 'supplier', 3);
		END IF;
	END IF;
	
	SELECT bank_account_id INTO v_bank_account_id
	FROM bank_accounts
	WHERE (org_id = v_org_id) AND (is_default = true);
	
	IF((v_org_client_id is not null) AND (v_bank_account_id is not null))THEN
		--- add transactions for banking payments	
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 1, a.pay_group_id, a.gl_payment_account, 'PAYROLL Payments ' || a.pay_group_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.b_banked),
			'PAYROLL Payments ' || a.pay_group_name
		FROM vw_ems a
		WHERE (a.period_id = $1)
		GROUP BY a.org_id, a.period_id, a.end_date, a.gl_payment_account, a.pay_group_id, a.currency_id, 
			a.exchange_rate, a.pay_group_name;

		--- add transactions for deduction remitance
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 2, a.adjustment_id, a.account_number, 'PAYROLL Deduction ' || a.adjustment_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.amount),
			'PAYROLL Deduction ' || a.adjustment_name
		FROM vw_employee_adjustments a
		WHERE (a.period_id = $1)
		GROUP BY a.currency_id, a.org_id, a.adjustment_id, a.account_number, a.adjustment_name, 
			a.exchange_rate, a.end_date;
			
		--- add transactions for tax remitance
		INSERT INTO transactions (transaction_type_id, transaction_status_id, entered_by, tx_type, 
			entity_id, bank_account_id, currency_id, org_id, ledger_type_id,
			exchange_rate, transaction_date, payment_date, transaction_amount, narrative)
		SELECT 21, 1, $2, -1, 
			v_org_client_id, v_bank_account_id, a.currency_id, a.org_id, 
			get_ledger_link(a.org_id, 3, a.tax_type_id, a.account_number, 'PAYROLL Tax ' || a.tax_type_name),
			a.exchange_rate, a.end_date, a.end_date, sum(a.amount + a.employer),
			'PAYROLL Tax ' || a.tax_type_name
		FROM vw_employee_tax_types a
		WHERE (a.period_id = $1)
		GROUP BY a.currency_id, a.org_id, a.tax_type_id, a.account_number, a.tax_type_name, 
			a.exchange_rate, a.end_date;
	END IF;
		
	RETURN msg;
END;
$_$;


ALTER FUNCTION public.payroll_payable(integer, integer) OWNER TO postgres;

--
-- Name: post_banking(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION post_banking(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	reca 						RECORD;
	v_journal_id				integer;
	v_org_id					integer;
	v_currency_id				integer;
	v_period_id					integer;
	v_start_date				date;
	v_end_date					date;

	msg							varchar(120);
BEGIN

	SELECT orgs.org_id, orgs.currency_id, periods.period_id, periods.start_date, periods.end_date
		INTO v_org_id, v_currency_id, v_period_id, v_start_date, v_end_date
	FROM periods INNER JOIN orgs ON periods.org_id = orgs.org_id
	WHERE (period_id = $1::integer) AND (opened = true) AND (activated = false) AND (closed = false);
	
	IF(v_period_id is null)THEN
		msg := 'Banking not posted period need to be open but not active';
	ELSE
		UPDATE account_activity SET period_id = v_period_id 
		WHERE (period_id is null) AND (activity_date BETWEEN v_start_date AND v_end_date);
		
		v_journal_id := nextval('journals_journal_id_seq');
		INSERT INTO journals (journal_id, org_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (v_journal_id, v_org_id, v_currency_id, v_period_id, 1, v_end_date, 'Banking - ' || to_char(v_start_date, 'MMYYY'));
		
		INSERT INTO gls(org_id, journal_id, account_activity_id, account_id, 
			debit, credit, gl_narrative)
		SELECT v_org_id, v_journal_id, account_activity.account_activity_id, activity_types.account_id,
			(account_activity.account_debit * account_activity.exchange_rate),
			(account_activity.account_credit * account_activity.exchange_rate),
			COALESCE(deposit_accounts.account_number, loans.account_number)
		FROM account_activity INNER JOIN activity_types ON account_activity.activity_type_id = activity_types.activity_type_id
			LEFT JOIN deposit_accounts ON account_activity.deposit_account_id = deposit_accounts.deposit_account_id
			LEFT JOIN loans ON account_activity.loan_id = loans.loan_id
		WHERE (account_activity.period_id = v_period_id);
	
		msg := 'Banking posted';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.post_banking(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: post_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION post_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec					RECORD;
	v_period_id			int;
	v_journal_id		int;
	msg					varchar(120);
BEGIN
	SELECT org_id, department_id, transaction_id, transaction_type_id, transaction_type_name as tx_name, 
		transaction_status_id, journal_id, gl_bank_account_id, currency_id, exchange_rate,
		transaction_date, transaction_amount, transaction_tax_amount, document_number, 
		credit_amount, debit_amount, entity_account_id, entity_name, approve_status, 
		ledger_account_id, tax_account_id, ledger_posting INTO rec
	FROM vw_transactions
	WHERE (transaction_id = CAST($1 as integer));

	v_period_id := get_open_period(rec.transaction_date);
	IF(v_period_id is null) THEN
		msg := 'No active period to post.';
		RAISE EXCEPTION 'No active period to post.';
	ELSIF(rec.journal_id is not null) THEN
		msg := 'Transaction previously Posted.';
		RAISE EXCEPTION 'Transaction previously Posted.';
	ELSIF(rec.transaction_status_id = 1) THEN
		msg := 'Transaction needs to be completed first.';
		RAISE EXCEPTION 'Transaction needs to be completed first.';
	ELSIF(rec.approve_status != 'Approved') THEN
		msg := 'Transaction is not yet approved.';
		RAISE EXCEPTION 'Transaction is not yet approved.';
	ELSIF((rec.ledger_account_id is not null) AND (rec.ledger_posting = false)) THEN
		msg := 'Transaction not for posting.';
		RAISE EXCEPTION 'Transaction not for posting.';
	ELSE
		v_journal_id := nextval('journals_journal_id_seq');
		INSERT INTO journals (journal_id, org_id, department_id, currency_id, period_id, exchange_rate, journal_date, narrative)
		VALUES (v_journal_id, rec.org_id, rec.department_id, rec.currency_id, v_period_id, rec.exchange_rate, rec.transaction_date, rec.tx_name || ' - posting for ' || rec.document_number);
		
		IF((rec.transaction_type_id = 7) or (rec.transaction_type_id = 8)) THEN
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.entity_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.gl_bank_account_id, rec.credit_amount, rec.debit_amount, rec.tx_name || ' - ' || rec.entity_name);
		ELSIF((rec.transaction_type_id = 21) or (rec.transaction_type_id = 22)) THEN		
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.gl_bank_account_id, rec.credit_amount, rec.debit_amount, rec.tx_name || ' - ' || rec.entity_name);
			
			IF(rec.transaction_tax_amount = 0)THEN
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);
			ELSIF(rec.transaction_type_id = 21)THEN
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount - rec.transaction_tax_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);
				
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.tax_account_id, rec.transaction_tax_amount, 0, rec.tx_name || ' - ' || rec.entity_name);
			ELSE
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.ledger_account_id, rec.debit_amount, rec.credit_amount - rec.transaction_tax_amount, rec.tx_name || ' - ' || rec.entity_name);
				
				INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
				VALUES (rec.org_id, v_journal_id, rec.tax_account_id, 0, rec.transaction_tax_amount, rec.tx_name || ' - ' || rec.entity_name);			
			END IF;
		ELSE
			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			VALUES (rec.org_id, v_journal_id, rec.entity_account_id, rec.debit_amount, rec.credit_amount, rec.tx_name || ' - ' || rec.entity_name);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, v_journal_id, trans_account_id, full_debit_amount, full_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_amount > 0);

			INSERT INTO gls (org_id, journal_id, account_id, debit, credit, gl_narrative)
			SELECT org_id, v_journal_id, tax_account_id, tax_debit_amount, tax_credit_amount, rec.tx_name || ' - ' || item_name
			FROM vw_transaction_details
			WHERE (transaction_id = rec.transaction_id) AND (full_tax_amount > 0);
		END IF;

		UPDATE transactions SET journal_id = v_journal_id WHERE (transaction_id = rec.transaction_id);
		msg := process_journal(CAST(v_journal_id as varchar),'0','0');
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.post_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: prev_acct(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_acct(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT sum(gls.debit - gls.credit)
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) 
		AND (journals.journal_date < $2);
$_$;


ALTER FUNCTION public.prev_acct(integer, date) OWNER TO postgres;

--
-- Name: prev_balance(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_balance(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(transactions.exchange_rate * transactions.tx_type * transactions.transaction_amount), 0)::real
	FROM transactions
	WHERE (transactions.payment_date < $1) 
		AND (transactions.tx_type is not null);
$_$;


ALTER FUNCTION public.prev_balance(date) OWNER TO postgres;

--
-- Name: prev_base_acct(integer, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_base_acct(integer, date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT sum(gls.debit * journals.exchange_rate - gls.credit * journals.exchange_rate) 
	FROM gls INNER JOIN journals ON gls.journal_id = journals.journal_id
	WHERE (gls.account_id = $1) AND (journals.posted = true) 
		AND (journals.journal_date < $2);
$_$;


ALTER FUNCTION public.prev_base_acct(integer, date) OWNER TO postgres;

--
-- Name: prev_base_returns(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_base_returns(date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(base_credit - base_debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (journal_date < $1);
$_$;


ALTER FUNCTION public.prev_base_returns(date) OWNER TO postgres;

--
-- Name: prev_clear_balance(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_clear_balance(date) RETURNS real
    LANGUAGE sql
    AS $_$
    SELECT COALESCE(sum(transactions.exchange_rate * transactions.tx_type * transactions.transaction_amount), 0)::real
	FROM transactions
	WHERE (transactions.payment_date < $1) AND (transactions.completed = true) 
		AND (transactions.is_cleared = true) AND (transactions.tx_type is not null);
$_$;


ALTER FUNCTION public.prev_clear_balance(date) OWNER TO postgres;

--
-- Name: prev_returns(date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION prev_returns(date) RETURNS real
    LANGUAGE sql
    AS $_$
	SELECT COALESCE(sum(credit - debit), 0)
	FROM vw_gls
	WHERE (chat_type_id > 3) AND (posted = true) AND (journal_date < $1);
$_$;


ALTER FUNCTION public.prev_returns(date) OWNER TO postgres;

--
-- Name: process_journal(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION process_journal(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	msg varchar(120);
BEGIN
	SELECT periods.start_date, periods.end_date, periods.opened, periods.closed, journals.journal_date, journals.posted, 
		sum(debit) as sum_debit, sum(credit) as sum_credit INTO rec
	FROM (periods INNER JOIN journals ON periods.period_id = journals.period_id)
		INNER JOIN gls ON journals.journal_id = gls.journal_id
	WHERE (journals.journal_id = CAST($1 as integer))
	GROUP BY periods.start_date, periods.end_date, periods.opened, periods.closed, journals.journal_date, journals.posted;

	IF(rec.posted = true) THEN
		msg := 'Journal previously Processed.';
	ELSIF((rec.start_date > rec.journal_date) OR (rec.end_date < rec.journal_date)) THEN
		msg := 'Journal date has to be within periods date.';
	ELSIF((rec.opened = false) OR (rec.closed = true)) THEN
		msg := 'Transaction period has to be opened and not closed.';
	ELSIF(rec.sum_debit <> rec.sum_credit) THEN
		msg := 'Cannot process Journal because credits do not equal debits.';
	ELSE
		UPDATE journals SET posted = true WHERE (journals.journal_id = CAST($1 as integer));
		msg := 'Journal Processed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.process_journal(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: process_transaction(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION process_transaction(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	rec RECORD;
	bankacc INTEGER;
	msg varchar(120);
BEGIN
	SELECT org_id, transaction_id, transaction_type_id, transaction_status_id, transaction_amount INTO rec
	FROM transactions
	WHERE (transaction_id = CAST($1 as integer));

	IF(rec.transaction_status_id = 1) THEN
		msg := 'Transaction needs to be completed first.';
	ELSIF(rec.transaction_status_id = 2) THEN
		IF (($3 = '7') AND ($3 = '8')) THEN
			SELECT max(bank_account_id) INTO bankacc
			FROM bank_accounts WHERE (is_default = true);

			INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, bank_account_id, transaction_amount)
			SELECT transactions.org_id, transactions.department_id, transactions.entity_id, transactions.currency_id, 1, CURRENT_DATE, bankacc, 
				SUM(transaction_details.quantity * (transaction_details.amount + transaction_details.tax_amount))
			FROM transactions INNER JOIN transaction_details ON transactions.transaction_id = transaction_details.transaction_id
			WHERE (transactions.transaction_id = rec.transaction_id)
			GROUP BY transactions.transaction_id, transactions.entity_id;

			INSERT INTO transaction_links (org_id, transaction_id, transaction_to, amount)
			VALUES (rec.org_id, currval('transactions_transaction_id_seq'), rec.transaction_id, rec.transaction_amount);
		
			UPDATE transactions SET transaction_status_id = 3 WHERE transaction_id = rec.transaction_id;
		ELSE
			INSERT INTO transactions (org_id, department_id, entity_id, currency_id, transaction_type_id, transaction_date, order_number, payment_terms, job, narrative, details)
			SELECT org_id, department_id, entity_id, currency_id, CAST($3 as integer), CURRENT_DATE, order_number, payment_terms, job, narrative, details
			FROM transactions
			WHERE (transaction_id = rec.transaction_id);

			INSERT INTO transaction_details (org_id, transaction_id, account_id, item_id, quantity, amount, tax_amount, narrative, details)
			SELECT org_id, currval('transactions_transaction_id_seq'), account_id, item_id, quantity, amount, tax_amount, narrative, details
			FROM transaction_details
			WHERE (transaction_id = rec.transaction_id);

			INSERT INTO transaction_links (org_id, transaction_id, transaction_to, amount)
			VALUES (REC.org_id, currval('transactions_transaction_id_seq'), rec.transaction_id, rec.transaction_amount);

			UPDATE transactions SET transaction_status_id = 3 WHERE transaction_id = rec.transaction_id;
		END IF;
		msg := 'Transaction proccesed';
	ELSE
		msg := 'Transaction previously Processed.';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.process_transaction(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: transfer_approval(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION transfer_approval(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg							varchar(120);
	v_account_activity_id		integer;
BEGIN

	IF($3 = '1')THEN
		v_account_activity_id := nextval('account_activity_account_activity_id_seq');
		INSERT INTO account_activity (account_activity_id, org_id, entity_id, activity_frequency_id, activity_type_id, 
			activity_status_id, currency_id, transfer_account_no, deposit_account_id,
			activity_date, value_date, account_debit, exchange_rate)
		SELECT v_account_activity_id, org_id, entity_id, activity_frequency_id, activity_type_id, 
			1, currency_id, beneficiary_account_number, deposit_account_id,
			current_date, current_date, transfer_amount, 1
		FROM vw_transfer_activity
		WHERE (transfer_activity_id = $1::integer);
		
		UPDATE transfer_activity SET approve_status = 'Approved', account_activity_id = v_account_activity_id
		WHERE (transfer_activity_id = $1::integer);
		
		msg := 'Approved transfer';
	ELSIF($3 = '2')THEN
		UPDATE transfer_activity SET approve_status = 'Declined' 
		WHERE (transfer_activity_id = $1::integer);
		
		msg := 'Reject transfer';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.transfer_approval(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_action(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_action() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	wfid		INTEGER;
	reca		RECORD;
	tbid		INTEGER;
	iswf		BOOLEAN;
	add_flow	BOOLEAN;
BEGIN
	add_flow := false;
	IF(TG_OP = 'INSERT')THEN
		IF (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	ELSE
		IF(OLD.approve_status = 'Draft') AND (NEW.approve_status = 'Completed')THEN
			add_flow := true;
		END IF;
	END IF;

	IF(add_flow = true)THEN
		wfid := nextval('workflow_table_id_seq');
		NEW.workflow_table_id := wfid;

		IF(TG_OP = 'UPDATE')THEN
			IF(OLD.workflow_table_id is not null)THEN
				INSERT INTO workflow_logs (org_id, table_name, table_id, table_old_id)
				VALUES (NEW.org_id, TG_TABLE_NAME, wfid, OLD.workflow_table_id);
			END IF;
		END IF;

		FOR reca IN SELECT workflows.workflow_id, workflows.table_name, workflows.table_link_field, workflows.table_link_id
		FROM workflows INNER JOIN entity_subscriptions ON workflows.source_entity_id = entity_subscriptions.entity_type_id
		WHERE (workflows.table_name = TG_TABLE_NAME) AND (entity_subscriptions.entity_id= NEW.entity_id) LOOP
			iswf := true;
			IF(reca.table_link_field is null)THEN
				iswf := true;
			ELSE
				IF(TG_TABLE_NAME = 'entry_forms')THEN
					tbid := NEW.form_id;
				END IF;
				IF(tbid = reca.table_link_id)THEN
					iswf := true;
				END IF;
			END IF;

			IF(iswf = true)THEN
				INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done)
				SELECT org_id, workflow_phase_id, TG_TABLE_NAME, wfid, NEW.entity_id, escalation_days, escalation_hours, approval_level, phase_narrative, 'Approve - ' || phase_narrative
				FROM vw_workflow_entitys
				WHERE (table_name = TG_TABLE_NAME) AND (entity_id = NEW.entity_id) AND (workflow_id = reca.workflow_id)
				ORDER BY approval_level, workflow_phase_id;

				UPDATE approvals SET approve_status = 'Completed'
				WHERE (table_id = wfid) AND (approval_level = 1);
			END IF;
		END LOOP;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_action() OWNER TO postgres;

--
-- Name: upd_approvals(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	reca	RECORD;
	wfid	integer;
	vorgid	integer;
	vnotice	boolean;
	vadvice	boolean;
BEGIN

	SELECT notice, advice, org_id INTO vnotice, vadvice, vorgid
	FROM workflow_phases
	WHERE (workflow_phase_id = NEW.workflow_phase_id);

	IF (NEW.approve_status = 'Completed') THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vadvice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 1, vorgid);
	END IF;
	IF (NEW.approve_status = 'Approved') AND (vnotice = true) AND (NEW.forward_id is null) THEN
		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (NEW.approval_id, TG_TABLE_NAME, 2, vorgid);
	END IF;

	IF(TG_OP = 'INSERT') AND (NEW.forward_id is null) THEN
		INSERT INTO approval_checklists (approval_id, checklist_id, requirement, manditory, org_id)
		SELECT NEW.approval_id, checklist_id, requirement, manditory, org_id
		FROM checklists
		WHERE (workflow_phase_id = NEW.workflow_phase_id)
		ORDER BY checklist_number;
	END IF;

	RETURN NULL;
END;
$$;


ALTER FUNCTION public.upd_approvals() OWNER TO postgres;

--
-- Name: upd_approvals(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_approvals(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	app_id		Integer;
	reca 		RECORD;
	recb		RECORD;
	recc		RECORD;
	recd		RECORD;

	min_level	Integer;
	mysql		varchar(240);
	msg 		varchar(120);
BEGIN
	app_id := CAST($1 as int);
	SELECT approvals.approval_id, approvals.org_id, approvals.table_name, approvals.table_id, 
		approvals.approval_level, approvals.review_advice, approvals.org_entity_id,
		workflow_phases.workflow_phase_id, workflow_phases.workflow_id, workflow_phases.return_level 
	INTO reca
	FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
	WHERE (approvals.approval_id = app_id);

	SELECT count(approval_checklist_id) as cl_count INTO recc
	FROM approval_checklists
	WHERE (approval_id = app_id) AND (manditory = true) AND (done = false);

	SELECT orgs.org_id, transactions.transaction_type_id, orgs.enforce_budget,
		get_budgeted(transactions.transaction_id, transactions.transaction_date, transactions.department_id) as budget_var 
		INTO recd
	FROM orgs INNER JOIN transactions ON orgs.org_id = transactions.org_id
	WHERE (transactions.workflow_table_id = reca.table_id);

	IF ($3 = '1') THEN
		UPDATE approvals SET approve_status = 'Completed', completion_date = now()
		WHERE approval_id = app_id;
		msg := 'Completed';
	ELSIF ($3 = '2') AND (recc.cl_count <> 0) THEN
		msg := 'There are manditory checklist that must be checked first.';
	ELSIF (recd.transaction_type_id = 5) AND (recd.enforce_budget = true) AND (recd.budget_var < 0) THEN
		msg := 'You need a budget to approve the expenditure.';
	ELSIF ($3 = '2') AND (recc.cl_count = 0) THEN
		UPDATE approvals SET approve_status = 'Approved', action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		SELECT min(approvals.approval_level) INTO min_level
		FROM approvals INNER JOIN workflow_phases ON approvals.workflow_phase_id = workflow_phases.workflow_phase_id
		WHERE (approvals.table_id = reca.table_id) AND (approvals.approve_status = 'Draft')
			AND (workflow_phases.advice = false);
		
		IF(min_level is null)THEN
			mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Approved') 
			|| ', action_date = now()'
			|| ' WHERE workflow_table_id = ' || reca.table_id;
			EXECUTE mysql;

			INSERT INTO sys_emailed (table_id, table_name, email_type)
			VALUES (reca.table_id, 'vw_workflow_approvals', 1);
			
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level >= reca.approval_level) LOOP
				IF (recb.advice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		ELSE
			FOR recb IN SELECT workflow_phase_id, advice, notice
			FROM workflow_phases
			WHERE (workflow_id = reca.workflow_id) AND (approval_level <= min_level) LOOP
				IF (recb.advice = true) THEN
					UPDATE approvals SET approve_status = 'Approved', action_date = now(), completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				ELSE
					UPDATE approvals SET approve_status = 'Completed', completion_date = now()
					WHERE (workflow_phase_id = recb.workflow_phase_id) 
						AND (approve_status = 'Draft') AND (table_id = reca.table_id);
				END IF;
			END LOOP;
		END IF;
		msg := 'Approved';
	ELSIF ($3 = '3') THEN
		UPDATE approvals SET approve_status = 'Rejected',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Rejected') 
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		INSERT INTO sys_emailed (table_id, table_name, email_type, org_id)
		VALUES (reca.table_id, 'vw_workflow_approvals', 2, reca.org_id);
		msg := 'Rejected';
	ELSIF ($3 = '4') AND (reca.return_level = 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		mysql := 'UPDATE ' || reca.table_name || ' SET approve_status = ' || quote_literal('Draft')
		|| ', action_date = now()'
		|| ' WHERE workflow_table_id = ' || reca.table_id;
		EXECUTE mysql;

		msg := 'Forwarded for review';
	ELSIF ($3 = '4') AND (reca.return_level <> 0) THEN
		UPDATE approvals SET approve_status = 'Review',  action_date = now(), app_entity_id = CAST($2 as int)
		WHERE approval_id = app_id;

		INSERT INTO approvals (org_id, workflow_phase_id, table_name, table_id, org_entity_id, escalation_days, escalation_hours, approval_level, approval_narrative, to_be_done, approve_status)
		SELECT org_id, workflow_phase_id, reca.table_name, reca.table_id, CAST($2 as int), escalation_days, escalation_hours, approval_level, phase_narrative, reca.review_advice, 'Completed'
		FROM vw_workflow_entitys
		WHERE (workflow_id = reca.workflow_id) AND (approval_level = reca.return_level)
			AND (entity_id = reca.org_entity_id)
		ORDER BY workflow_phase_id;

		UPDATE approvals SET approve_status = 'Draft' WHERE approval_id = app_id;

		msg := 'Forwarded to owner for review';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_approvals(character varying, character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_budget_lines(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_budget_lines() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	accountid 	INTEGER;
BEGIN

	IF(NEW.income_budget = true)THEN
		SELECT sales_account_id INTO accountid
		FROM items
		WHERE (item_id = NEW.item_id);
	ELSE
		SELECT purchase_account_id INTO accountid
		FROM items
		WHERE (item_id = NEW.item_id);
	END IF;

	IF(NEW.account_id is null) THEN
		NEW.account_id = accountid;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_budget_lines() OWNER TO postgres;

--
-- Name: upd_checklist(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_checklist(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	cl_id		Integer;
	reca 		RECORD;
	recc 		RECORD;
	msg 		varchar(120);
BEGIN
	cl_id := CAST($1 as int);

	SELECT approval_checklist_id, approval_id, checklist_id, requirement, manditory, done INTO reca
	FROM approval_checklists
	WHERE (approval_checklist_id = cl_id);

	IF ($3 = '1') THEN
		UPDATE approval_checklists SET done = true WHERE (approval_checklist_id = cl_id);

		SELECT count(approval_checklist_id) as cl_count INTO recc
		FROM approval_checklists
		WHERE (approval_id = reca.approval_id) AND (manditory = true) AND (done = false);
		msg := 'Checklist done.';
	ELSIF ($3 = '2') THEN
		UPDATE approval_checklists SET done = false WHERE (approval_checklist_id = cl_id);
		msg := 'Checklist not done.';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_checklist(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_complete_form(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_complete_form(character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg varchar(120);
BEGIN
	IF ($3 = '1') THEN
		UPDATE entry_forms SET approve_status = 'Completed', completion_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Completed the form';
	ELSIF ($3 = '2') THEN
		UPDATE entry_forms SET approve_status = 'Approved', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Approved the form';
	ELSIF ($3 = '3') THEN
		UPDATE entry_forms SET approve_status = 'Rejected', action_date = now()
		WHERE (entry_form_id = CAST($1 as int));
		msg := 'Rejected the form';
	END IF;

	return msg;
END;
$_$;


ALTER FUNCTION public.upd_complete_form(character varying, character varying, character varying) OWNER TO postgres;

--
-- Name: upd_gls(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_gls() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	isposted BOOLEAN;
BEGIN
	SELECT posted INTO isposted
	FROM journals 
	WHERE (journal_id = NEW.journal_id);

	IF (isposted = true) THEN
		RAISE EXCEPTION '% Journal is already posted no changes are allowed.', NEW.journal_id;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_gls() OWNER TO postgres;

--
-- Name: upd_transaction_details(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_transaction_details() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	statusID 	INTEGER;
	journalID 	INTEGER;
	v_for_sale	BOOLEAN;
	accountid 	INTEGER;
	taxrate 	REAL;
BEGIN
	SELECT transactions.transaction_status_id, transactions.journal_id, transaction_types.for_sales
		INTO statusID, journalID, v_for_sale
	FROM transaction_types INNER JOIN transactions ON transaction_types.transaction_type_id = transactions.transaction_type_id
	WHERE (transaction_id = NEW.transaction_id);

	IF ((statusID > 1) OR (journalID is not null)) THEN
		RAISE EXCEPTION 'Transaction is already posted no changes are allowed.';
	END IF;

	IF(v_for_sale = true)THEN
		SELECT items.sales_account_id, tax_types.tax_rate INTO accountid, taxrate
		FROM tax_types INNER JOIN items ON tax_types.tax_type_id = items.tax_type_id
		WHERE (items.item_id = NEW.item_id);
	ELSE
		SELECT items.purchase_account_id, tax_types.tax_rate INTO accountid, taxrate
		FROM tax_types INNER JOIN items ON tax_types.tax_type_id = items.tax_type_id
		WHERE (items.item_id = NEW.item_id);
	END IF;

	NEW.tax_amount := NEW.amount * taxrate / 100;
	IF(accountid is not null)THEN
		NEW.account_id := accountid;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION public.upd_transaction_details() OWNER TO postgres;

--
-- Name: upd_trx_ledger(character varying, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION upd_trx_ledger(character varying, character varying, character varying, character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $_$
DECLARE
	msg							varchar(120);
BEGIN
	
	IF ($3 = '1') THEN
		UPDATE transactions SET for_processing = true WHERE transaction_id = $1::integer;
		msg := 'Opened for processing';
	ELSIF ($3 = '2') THEN
		UPDATE transactions SET for_processing = false WHERE transaction_id = $1::integer;
		msg := 'Closed for processing';
	ELSIF ($3 = '3') THEN
		UPDATE transactions  SET payment_date = current_date, completed = true
		WHERE transaction_id = $1::integer AND completed = false;
		msg := 'Completed';
	ELSIF ($3 = '4') THEN
		UPDATE transactions  SET is_cleared = true WHERE transaction_id = $1::integer;
		msg := 'Cleared for posting ';
	END IF;

	RETURN msg;
END;
$_$;


ALTER FUNCTION public.upd_trx_ledger(character varying, character varying, character varying, character varying) OWNER TO postgres;

SET search_path = logs, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: lg_account_activity; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_account_activity (
    lg_account_activity_id integer NOT NULL,
    account_activity_id integer,
    deposit_account_id integer,
    transfer_account_id integer,
    activity_type_id integer,
    activity_frequency_id integer,
    activity_status_id integer,
    currency_id integer,
    period_id integer,
    entity_id integer,
    loan_id integer,
    transfer_loan_id integer,
    org_id integer,
    link_activity_id integer NOT NULL,
    transfer_link_id integer,
    deposit_account_no character varying(32),
    transfer_account_no character varying(32),
    activity_date date DEFAULT ('now'::text)::date NOT NULL,
    value_date date NOT NULL,
    account_credit real,
    account_debit real,
    balance real,
    exchange_rate real,
    application_date timestamp without time zone,
    approve_status character varying(16),
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_account_activity OWNER TO postgres;

--
-- Name: lg_account_activity_lg_account_activity_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_account_activity_lg_account_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_account_activity_lg_account_activity_id_seq OWNER TO postgres;

--
-- Name: lg_account_activity_lg_account_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_account_activity_lg_account_activity_id_seq OWNED BY lg_account_activity.lg_account_activity_id;


--
-- Name: lg_collaterals; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_collaterals (
    lg_collateral_id integer NOT NULL,
    collateral_id integer,
    loan_id integer,
    collateral_type_id integer,
    entity_id integer,
    org_id integer,
    collateral_amount real NOT NULL,
    collateral_received boolean DEFAULT false NOT NULL,
    collateral_released boolean DEFAULT false NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_collaterals OWNER TO postgres;

--
-- Name: lg_collaterals_lg_collateral_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_collaterals_lg_collateral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_collaterals_lg_collateral_id_seq OWNER TO postgres;

--
-- Name: lg_collaterals_lg_collateral_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_collaterals_lg_collateral_id_seq OWNED BY lg_collaterals.lg_collateral_id;


--
-- Name: lg_customers; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_customers (
    lg_customer_id integer NOT NULL,
    customer_id integer,
    entity_id integer,
    org_id integer,
    business_account integer DEFAULT 0 NOT NULL,
    person_title character varying(7),
    customer_name character varying(150) NOT NULL,
    identification_number character varying(50) NOT NULL,
    identification_type character varying(50) NOT NULL,
    client_email character varying(50) NOT NULL,
    telephone_number character varying(20) NOT NULL,
    telephone_number2 character varying(20),
    address character varying(50),
    town character varying(50),
    zip_code character varying(50),
    date_of_birth date NOT NULL,
    gender character varying(1),
    nationality character(2),
    marital_status character varying(2),
    picture_file character varying(32),
    employed boolean DEFAULT true NOT NULL,
    self_employed boolean DEFAULT false NOT NULL,
    employer_name character varying(120),
    monthly_salary real,
    monthly_net_income real,
    annual_turnover real,
    annual_net_income real,
    employer_address text,
    introduced_by character varying(100),
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_customers OWNER TO postgres;

--
-- Name: lg_customers_lg_customer_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_customers_lg_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_customers_lg_customer_id_seq OWNER TO postgres;

--
-- Name: lg_customers_lg_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_customers_lg_customer_id_seq OWNED BY lg_customers.lg_customer_id;


--
-- Name: lg_deposit_accounts; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_deposit_accounts (
    lg_deposit_account_id integer NOT NULL,
    deposit_account_id integer,
    customer_id integer,
    product_id integer,
    activity_frequency_id integer,
    entity_id integer,
    org_id integer,
    is_active boolean DEFAULT false NOT NULL,
    account_number character varying(32) NOT NULL,
    narrative character varying(120),
    opening_date date DEFAULT ('now'::text)::date NOT NULL,
    last_closing_date date,
    credit_limit real,
    minimum_balance real,
    maximum_balance real,
    interest_rate real NOT NULL,
    lockin_period_frequency real,
    lockedin_until_date date,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_deposit_accounts OWNER TO postgres;

--
-- Name: lg_deposit_accounts_lg_deposit_account_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_deposit_accounts_lg_deposit_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_deposit_accounts_lg_deposit_account_id_seq OWNER TO postgres;

--
-- Name: lg_deposit_accounts_lg_deposit_account_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_deposit_accounts_lg_deposit_account_id_seq OWNED BY lg_deposit_accounts.lg_deposit_account_id;


--
-- Name: lg_guarantees; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_guarantees (
    lg_guarantee_id integer NOT NULL,
    guarantee_id integer,
    loan_id integer,
    customer_id integer,
    entity_id integer,
    org_id integer,
    guarantee_amount real NOT NULL,
    guarantee_accepted boolean DEFAULT false NOT NULL,
    accepted_date timestamp without time zone,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_guarantees OWNER TO postgres;

--
-- Name: lg_guarantees_lg_guarantee_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_guarantees_lg_guarantee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_guarantees_lg_guarantee_id_seq OWNER TO postgres;

--
-- Name: lg_guarantees_lg_guarantee_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_guarantees_lg_guarantee_id_seq OWNED BY lg_guarantees.lg_guarantee_id;


--
-- Name: lg_loans; Type: TABLE; Schema: logs; Owner: postgres; Tablespace: 
--

CREATE TABLE lg_loans (
    lg_loan_id integer NOT NULL,
    loan_id integer,
    customer_id integer,
    product_id integer,
    activity_frequency_id integer,
    entity_id integer,
    org_id integer,
    account_number character varying(32) NOT NULL,
    disburse_account character varying(32) NOT NULL,
    principal_amount real NOT NULL,
    interest_rate real NOT NULL,
    repayment_amount real NOT NULL,
    repayment_period integer NOT NULL,
    disbursed_date date,
    matured_date date,
    expected_matured_date date,
    expected_repayment real,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE logs.lg_loans OWNER TO postgres;

--
-- Name: lg_loans_lg_loan_id_seq; Type: SEQUENCE; Schema: logs; Owner: postgres
--

CREATE SEQUENCE lg_loans_lg_loan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE logs.lg_loans_lg_loan_id_seq OWNER TO postgres;

--
-- Name: lg_loans_lg_loan_id_seq; Type: SEQUENCE OWNED BY; Schema: logs; Owner: postgres
--

ALTER SEQUENCE lg_loans_lg_loan_id_seq OWNED BY lg_loans.lg_loan_id;


SET search_path = public, pg_catalog;

--
-- Name: account_activity; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_activity (
    account_activity_id integer NOT NULL,
    deposit_account_id integer,
    transfer_account_id integer,
    activity_type_id integer,
    activity_frequency_id integer,
    activity_status_id integer,
    currency_id integer,
    period_id integer,
    entity_id integer,
    org_id integer,
    link_activity_id integer NOT NULL,
    transfer_link_id integer,
    deposit_account_no character varying(32),
    transfer_account_no character varying(32),
    activity_date date DEFAULT ('now'::text)::date NOT NULL,
    value_date date NOT NULL,
    account_credit real DEFAULT 0 NOT NULL,
    account_debit real DEFAULT 0 NOT NULL,
    balance real NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text,
    loan_id integer,
    transfer_loan_id integer
);


ALTER TABLE public.account_activity OWNER TO postgres;

--
-- Name: account_activity_account_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_activity_account_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_activity_account_activity_id_seq OWNER TO postgres;

--
-- Name: account_activity_account_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_activity_account_activity_id_seq OWNED BY account_activity.account_activity_id;


--
-- Name: account_class; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_class (
    account_class_id integer NOT NULL,
    account_class_no integer NOT NULL,
    org_id integer,
    chat_type_id integer NOT NULL,
    chat_type_name character varying(50) NOT NULL,
    account_class_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.account_class OWNER TO postgres;

--
-- Name: account_class_account_class_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_class_account_class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_class_account_class_id_seq OWNER TO postgres;

--
-- Name: account_class_account_class_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_class_account_class_id_seq OWNED BY account_class.account_class_id;


--
-- Name: account_definations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_definations (
    account_defination_id integer NOT NULL,
    product_id integer NOT NULL,
    activity_type_id integer NOT NULL,
    charge_activity_id integer NOT NULL,
    activity_frequency_id integer NOT NULL,
    org_id integer,
    account_defination_name character varying(50) NOT NULL,
    start_date date NOT NULL,
    end_date date,
    fee_amount real DEFAULT 0 NOT NULL,
    fee_ps real DEFAULT 0 NOT NULL,
    has_charge boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    account_number character varying(32) NOT NULL,
    details text
);


ALTER TABLE public.account_definations OWNER TO postgres;

--
-- Name: account_definations_account_defination_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_definations_account_defination_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_definations_account_defination_id_seq OWNER TO postgres;

--
-- Name: account_definations_account_defination_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_definations_account_defination_id_seq OWNED BY account_definations.account_defination_id;


--
-- Name: account_notes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_notes (
    account_note_id integer NOT NULL,
    deposit_account_id integer,
    org_id integer,
    comment_date timestamp without time zone DEFAULT now() NOT NULL,
    narrative character varying(320) NOT NULL,
    note text NOT NULL
);


ALTER TABLE public.account_notes OWNER TO postgres;

--
-- Name: account_notes_account_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_notes_account_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_notes_account_note_id_seq OWNER TO postgres;

--
-- Name: account_notes_account_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_notes_account_note_id_seq OWNED BY account_notes.account_note_id;


--
-- Name: account_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE account_types (
    account_type_id integer NOT NULL,
    account_type_no integer NOT NULL,
    account_class_id integer,
    org_id integer,
    account_type_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.account_types OWNER TO postgres;

--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE account_types_account_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.account_types_account_type_id_seq OWNER TO postgres;

--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE account_types_account_type_id_seq OWNED BY account_types.account_type_id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE accounts (
    account_id integer NOT NULL,
    account_no integer NOT NULL,
    account_type_id integer,
    org_id integer,
    account_name character varying(120) NOT NULL,
    is_header boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE accounts_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.accounts_account_id_seq OWNER TO postgres;

--
-- Name: accounts_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE accounts_account_id_seq OWNED BY accounts.account_id;


--
-- Name: activity_frequency; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE activity_frequency (
    activity_frequency_id integer NOT NULL,
    activity_frequency_name character varying(50)
);


ALTER TABLE public.activity_frequency OWNER TO postgres;

--
-- Name: activity_status; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE activity_status (
    activity_status_id integer NOT NULL,
    activity_status_name character varying(50)
);


ALTER TABLE public.activity_status OWNER TO postgres;

--
-- Name: activity_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE activity_types (
    activity_type_id integer NOT NULL,
    dr_account_id integer NOT NULL,
    cr_account_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer,
    activity_type_name character varying(120) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    activity_type_no integer,
    details text
);


ALTER TABLE public.activity_types OWNER TO postgres;

--
-- Name: activity_types_activity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE activity_types_activity_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.activity_types_activity_type_id_seq OWNER TO postgres;

--
-- Name: activity_types_activity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE activity_types_activity_type_id_seq OWNED BY activity_types.activity_type_id;


--
-- Name: address; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address (
    address_id integer NOT NULL,
    address_type_id integer,
    sys_country_id character(2),
    org_id integer,
    address_name character varying(120),
    table_name character varying(32),
    table_id integer,
    post_office_box character varying(50),
    postal_code character varying(12),
    premises character varying(120),
    street character varying(120),
    town character varying(50),
    phone_number character varying(150),
    extension character varying(15),
    mobile character varying(150),
    fax character varying(150),
    email character varying(120),
    website character varying(120),
    is_default boolean DEFAULT false NOT NULL,
    first_password character varying(32),
    details text
);


ALTER TABLE public.address OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_address_id_seq OWNER TO postgres;

--
-- Name: address_address_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_address_id_seq OWNED BY address.address_id;


--
-- Name: address_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE address_types (
    address_type_id integer NOT NULL,
    org_id integer,
    address_type_name character varying(50)
);


ALTER TABLE public.address_types OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE address_types_address_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.address_types_address_type_id_seq OWNER TO postgres;

--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE address_types_address_type_id_seq OWNED BY address_types.address_type_id;


--
-- Name: applicants; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE applicants (
    applicant_id integer NOT NULL,
    customer_id integer,
    org_id integer,
    business_account integer DEFAULT 0 NOT NULL,
    person_title character varying(7),
    applicant_name character varying(150) NOT NULL,
    identification_number character varying(50) NOT NULL,
    identification_type character varying(50) NOT NULL,
    client_email character varying(50) NOT NULL,
    telephone_number character varying(20) NOT NULL,
    telephone_number2 character varying(20),
    address character varying(50),
    town character varying(50),
    zip_code character varying(50),
    date_of_birth date NOT NULL,
    gender character varying(1),
    nationality character(2),
    marital_status character varying(2),
    picture_file character varying(32),
    employed boolean DEFAULT true NOT NULL,
    self_employed boolean DEFAULT false NOT NULL,
    employer_name character varying(120),
    monthly_salary real,
    monthly_net_income real,
    annual_turnover real,
    annual_net_income real,
    employer_address text,
    introduced_by character varying(100),
    entity_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.applicants OWNER TO postgres;

--
-- Name: applicants_applicant_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE applicants_applicant_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.applicants_applicant_id_seq OWNER TO postgres;

--
-- Name: applicants_applicant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE applicants_applicant_id_seq OWNED BY applicants.applicant_id;


--
-- Name: approval_checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approval_checklists (
    approval_checklist_id integer NOT NULL,
    approval_id integer NOT NULL,
    checklist_id integer NOT NULL,
    org_id integer,
    requirement text,
    manditory boolean DEFAULT false NOT NULL,
    done boolean DEFAULT false NOT NULL,
    narrative character varying(320)
);


ALTER TABLE public.approval_checklists OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approval_checklists_approval_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approval_checklists_approval_checklist_id_seq OWNER TO postgres;

--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approval_checklists_approval_checklist_id_seq OWNED BY approval_checklists.approval_checklist_id;


--
-- Name: approvals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE approvals (
    approval_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_entity_id integer NOT NULL,
    app_entity_id integer,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    escalation_time timestamp without time zone DEFAULT now() NOT NULL,
    forward_id integer,
    table_name character varying(64),
    table_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    action_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    approval_narrative character varying(240),
    to_be_done text,
    what_is_done text,
    review_advice text,
    details text
);


ALTER TABLE public.approvals OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE approvals_approval_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.approvals_approval_id_seq OWNER TO postgres;

--
-- Name: approvals_approval_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE approvals_approval_id_seq OWNED BY approvals.approval_id;


--
-- Name: bank_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bank_accounts (
    bank_account_id integer NOT NULL,
    org_id integer,
    bank_branch_id integer,
    account_id integer,
    currency_id integer,
    bank_account_name character varying(120),
    bank_account_number character varying(50),
    narrative character varying(240),
    is_default boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.bank_accounts OWNER TO postgres;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bank_accounts_bank_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bank_accounts_bank_account_id_seq OWNER TO postgres;

--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bank_accounts_bank_account_id_seq OWNED BY bank_accounts.bank_account_id;


--
-- Name: bank_branch; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bank_branch (
    bank_branch_id integer NOT NULL,
    bank_id integer,
    org_id integer,
    bank_branch_name character varying(50) NOT NULL,
    bank_branch_code character varying(50),
    narrative character varying(240)
);


ALTER TABLE public.bank_branch OWNER TO postgres;

--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bank_branch_bank_branch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bank_branch_bank_branch_id_seq OWNER TO postgres;

--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bank_branch_bank_branch_id_seq OWNED BY bank_branch.bank_branch_id;


--
-- Name: banks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE banks (
    bank_id integer NOT NULL,
    sys_country_id character(2),
    org_id integer,
    bank_name character varying(50) NOT NULL,
    bank_code character varying(25),
    swift_code character varying(25),
    sort_code character varying(25),
    narrative character varying(240)
);


ALTER TABLE public.banks OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE banks_bank_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.banks_bank_id_seq OWNER TO postgres;

--
-- Name: banks_bank_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE banks_bank_id_seq OWNED BY banks.bank_id;


--
-- Name: bidders; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE bidders (
    bidder_id integer NOT NULL,
    tender_id integer,
    entity_id integer,
    org_id integer,
    tender_amount real,
    bind_bond character varying(120),
    bind_bond_amount real,
    return_date date,
    points real,
    is_awarded boolean NOT NULL,
    award_reference character varying(32),
    details text
);


ALTER TABLE public.bidders OWNER TO postgres;

--
-- Name: bidders_bidder_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE bidders_bidder_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.bidders_bidder_id_seq OWNER TO postgres;

--
-- Name: bidders_bidder_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE bidders_bidder_id_seq OWNED BY bidders.bidder_id;


--
-- Name: budget_lines; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budget_lines (
    budget_line_id integer NOT NULL,
    budget_id integer,
    period_id integer,
    account_id integer,
    item_id integer,
    transaction_id integer,
    org_id integer,
    spend_type integer DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    amount real DEFAULT 0 NOT NULL,
    tax_amount real DEFAULT 0 NOT NULL,
    income_budget boolean DEFAULT false NOT NULL,
    narrative character varying(240),
    details text
);


ALTER TABLE public.budget_lines OWNER TO postgres;

--
-- Name: budget_lines_budget_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE budget_lines_budget_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.budget_lines_budget_line_id_seq OWNER TO postgres;

--
-- Name: budget_lines_budget_line_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE budget_lines_budget_line_id_seq OWNED BY budget_lines.budget_line_id;


--
-- Name: budgets; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE budgets (
    budget_id integer NOT NULL,
    fiscal_year_id integer,
    department_id integer,
    link_budget_id integer,
    entity_id integer,
    org_id integer,
    budget_type integer DEFAULT 1 NOT NULL,
    budget_name character varying(50),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.budgets OWNER TO postgres;

--
-- Name: budgets_budget_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE budgets_budget_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.budgets_budget_id_seq OWNER TO postgres;

--
-- Name: budgets_budget_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE budgets_budget_id_seq OWNED BY budgets.budget_id;


--
-- Name: checklists; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE checklists (
    checklist_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    checklist_number integer,
    manditory boolean DEFAULT false NOT NULL,
    requirement text,
    details text
);


ALTER TABLE public.checklists OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE checklists_checklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.checklists_checklist_id_seq OWNER TO postgres;

--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE checklists_checklist_id_seq OWNED BY checklists.checklist_id;


--
-- Name: collateral_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE collateral_types (
    collateral_type_id integer NOT NULL,
    org_id integer,
    collateral_type_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.collateral_types OWNER TO postgres;

--
-- Name: collateral_types_collateral_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE collateral_types_collateral_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.collateral_types_collateral_type_id_seq OWNER TO postgres;

--
-- Name: collateral_types_collateral_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE collateral_types_collateral_type_id_seq OWNED BY collateral_types.collateral_type_id;


--
-- Name: collaterals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE collaterals (
    collateral_id integer NOT NULL,
    loan_id integer,
    collateral_type_id integer,
    entity_id integer,
    org_id integer,
    collateral_amount real NOT NULL,
    collateral_received boolean DEFAULT false NOT NULL,
    collateral_released boolean DEFAULT false NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.collaterals OWNER TO postgres;

--
-- Name: collaterals_collateral_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE collaterals_collateral_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.collaterals_collateral_id_seq OWNER TO postgres;

--
-- Name: collaterals_collateral_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE collaterals_collateral_id_seq OWNED BY collaterals.collateral_id;


--
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE contracts (
    contract_id integer NOT NULL,
    bidder_id integer,
    org_id integer,
    contract_name character varying(320) NOT NULL,
    contract_date date,
    contract_end date,
    contract_amount real,
    contract_tax real,
    details text
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE contracts_contract_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contracts_contract_id_seq OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE contracts_contract_id_seq OWNED BY contracts.contract_id;


--
-- Name: currency; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency (
    currency_id integer NOT NULL,
    currency_name character varying(50),
    currency_symbol character varying(3),
    org_id integer
);


ALTER TABLE public.currency OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_currency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_currency_id_seq OWNER TO postgres;

--
-- Name: currency_currency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_currency_id_seq OWNED BY currency.currency_id;


--
-- Name: currency_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE currency_rates (
    currency_rate_id integer NOT NULL,
    currency_id integer,
    org_id integer,
    exchange_date date DEFAULT ('now'::text)::date NOT NULL,
    exchange_rate real DEFAULT 1 NOT NULL
);


ALTER TABLE public.currency_rates OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE currency_rates_currency_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.currency_rates_currency_rate_id_seq OWNER TO postgres;

--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE currency_rates_currency_rate_id_seq OWNED BY currency_rates.currency_rate_id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE customers (
    customer_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    business_account integer DEFAULT 0 NOT NULL,
    person_title character varying(7),
    customer_name character varying(150) NOT NULL,
    identification_number character varying(50) NOT NULL,
    identification_type character varying(50) NOT NULL,
    client_email character varying(50) NOT NULL,
    telephone_number character varying(20) NOT NULL,
    telephone_number2 character varying(20),
    address character varying(50),
    town character varying(50),
    zip_code character varying(50),
    date_of_birth date NOT NULL,
    gender character varying(1),
    nationality character(2),
    marital_status character varying(2),
    picture_file character varying(32),
    employed boolean DEFAULT true NOT NULL,
    self_employed boolean DEFAULT false NOT NULL,
    employer_name character varying(120),
    monthly_salary real,
    monthly_net_income real,
    annual_turnover real,
    annual_net_income real,
    employer_address text,
    introduced_by character varying(100),
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.customers OWNER TO postgres;

--
-- Name: customers_customer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE customers_customer_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.customers_customer_id_seq OWNER TO postgres;

--
-- Name: customers_customer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE customers_customer_id_seq OWNED BY customers.customer_id;


--
-- Name: default_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE default_accounts (
    default_account_id integer NOT NULL,
    account_id integer,
    use_key_id integer NOT NULL,
    org_id integer,
    narrative character varying(240)
);


ALTER TABLE public.default_accounts OWNER TO postgres;

--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE default_accounts_default_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.default_accounts_default_account_id_seq OWNER TO postgres;

--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE default_accounts_default_account_id_seq OWNED BY default_accounts.default_account_id;


--
-- Name: default_tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE default_tax_types (
    default_tax_type_id integer NOT NULL,
    entity_id integer,
    tax_type_id integer,
    org_id integer,
    tax_identification character varying(50),
    narrative character varying(240),
    additional double precision DEFAULT 0 NOT NULL,
    active boolean DEFAULT true
);


ALTER TABLE public.default_tax_types OWNER TO postgres;

--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE default_tax_types_default_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.default_tax_types_default_tax_type_id_seq OWNER TO postgres;

--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE default_tax_types_default_tax_type_id_seq OWNED BY default_tax_types.default_tax_type_id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE departments (
    department_id integer NOT NULL,
    ln_department_id integer,
    org_id integer,
    department_name character varying(120),
    department_account character varying(50),
    function_code character varying(50),
    active boolean DEFAULT true NOT NULL,
    petty_cash boolean DEFAULT false NOT NULL,
    cost_center boolean DEFAULT true NOT NULL,
    revenue_center boolean DEFAULT true NOT NULL,
    description text,
    duties text,
    reports text,
    details text
);


ALTER TABLE public.departments OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE departments_department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.departments_department_id_seq OWNER TO postgres;

--
-- Name: departments_department_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE departments_department_id_seq OWNED BY departments.department_id;


--
-- Name: deposit_accounts; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE deposit_accounts (
    deposit_account_id integer NOT NULL,
    customer_id integer,
    product_id integer,
    activity_frequency_id integer,
    entity_id integer,
    org_id integer,
    is_active boolean DEFAULT false NOT NULL,
    account_number character varying(32) NOT NULL,
    narrative character varying(120),
    opening_date date DEFAULT ('now'::text)::date NOT NULL,
    last_closing_date date,
    credit_limit real,
    minimum_balance real,
    maximum_balance real,
    interest_rate real NOT NULL,
    lockin_period_frequency real,
    lockedin_until_date date,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.deposit_accounts OWNER TO postgres;

--
-- Name: deposit_accounts_deposit_account_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE deposit_accounts_deposit_account_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.deposit_accounts_deposit_account_id_seq OWNER TO postgres;

--
-- Name: deposit_accounts_deposit_account_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE deposit_accounts_deposit_account_id_seq OWNED BY deposit_accounts.deposit_account_id;


--
-- Name: e_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE e_fields (
    e_field_id integer NOT NULL,
    et_field_id integer,
    org_id integer,
    table_code integer NOT NULL,
    table_id integer,
    e_field_value character varying(320)
);


ALTER TABLE public.e_fields OWNER TO postgres;

--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE e_fields_e_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.e_fields_e_field_id_seq OWNER TO postgres;

--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE e_fields_e_field_id_seq OWNED BY e_fields.e_field_id;


--
-- Name: entity_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_fields (
    entity_field_id integer NOT NULL,
    org_id integer NOT NULL,
    use_type integer DEFAULT 1 NOT NULL,
    is_active boolean DEFAULT true,
    entity_field_name character varying(240),
    entity_field_source character varying(320)
);


ALTER TABLE public.entity_fields OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_fields_entity_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_fields_entity_field_id_seq OWNER TO postgres;

--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_fields_entity_field_id_seq OWNED BY entity_fields.entity_field_id;


--
-- Name: entity_subscriptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_subscriptions (
    entity_subscription_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    entity_id integer NOT NULL,
    subscription_level_id integer NOT NULL,
    org_id integer,
    details text
);


ALTER TABLE public.entity_subscriptions OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_subscriptions_entity_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_subscriptions_entity_subscription_id_seq OWNER TO postgres;

--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_subscriptions_entity_subscription_id_seq OWNED BY entity_subscriptions.entity_subscription_id;


--
-- Name: entity_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_types (
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer,
    entity_type_name character varying(50) NOT NULL,
    entity_role character varying(240),
    start_view character varying(120),
    group_email character varying(120),
    description text,
    details text
);


ALTER TABLE public.entity_types OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_types_entity_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_types_entity_type_id_seq OWNER TO postgres;

--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_types_entity_type_id_seq OWNED BY entity_types.entity_type_id;


--
-- Name: entity_values; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entity_values (
    entity_value_id integer NOT NULL,
    entity_id integer,
    entity_field_id integer,
    org_id integer,
    entity_value character varying(240)
);


ALTER TABLE public.entity_values OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entity_values_entity_value_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entity_values_entity_value_id_seq OWNER TO postgres;

--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entity_values_entity_value_id_seq OWNED BY entity_values.entity_value_id;


--
-- Name: entitys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entitys (
    entity_id integer NOT NULL,
    entity_type_id integer NOT NULL,
    use_key_id integer NOT NULL,
    org_id integer NOT NULL,
    entity_name character varying(120) NOT NULL,
    user_name character varying(120) NOT NULL,
    primary_email character varying(120),
    primary_telephone character varying(50),
    super_user boolean DEFAULT false NOT NULL,
    entity_leader boolean DEFAULT false NOT NULL,
    no_org boolean DEFAULT false NOT NULL,
    function_role character varying(240),
    date_enroled timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    entity_password character varying(64) NOT NULL,
    first_password character varying(64) NOT NULL,
    new_password character varying(64),
    start_url character varying(64),
    is_picked boolean DEFAULT false NOT NULL,
    details text,
    attention character varying(50),
    credit_limit real DEFAULT 0,
    account_id integer,
    customer_id integer
);


ALTER TABLE public.entitys OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entitys_entity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entitys_entity_id_seq OWNER TO postgres;

--
-- Name: entitys_entity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entitys_entity_id_seq OWNED BY entitys.entity_id;


--
-- Name: entry_forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE entry_forms (
    entry_form_id integer NOT NULL,
    org_id integer,
    entity_id integer,
    form_id integer,
    entered_by_id integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    completion_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(240),
    answer text,
    sub_answer text,
    details text
);


ALTER TABLE public.entry_forms OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE entry_forms_entry_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.entry_forms_entry_form_id_seq OWNER TO postgres;

--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE entry_forms_entry_form_id_seq OWNED BY entry_forms.entry_form_id;


--
-- Name: et_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE et_fields (
    et_field_id integer NOT NULL,
    org_id integer,
    et_field_name character varying(320) NOT NULL,
    table_name character varying(64) NOT NULL,
    table_code integer NOT NULL,
    table_link integer,
    is_active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.et_fields OWNER TO postgres;

--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE et_fields_et_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.et_fields_et_field_id_seq OWNER TO postgres;

--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE et_fields_et_field_id_seq OWNED BY et_fields.et_field_id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fields (
    field_id integer NOT NULL,
    org_id integer,
    form_id integer,
    field_name character varying(50),
    question text,
    field_lookup text,
    field_type character varying(25) NOT NULL,
    field_class character varying(25),
    field_bold character(1) DEFAULT '0'::bpchar NOT NULL,
    field_italics character(1) DEFAULT '0'::bpchar NOT NULL,
    field_order integer NOT NULL,
    share_line integer,
    field_size integer DEFAULT 25 NOT NULL,
    label_position character(1) DEFAULT 'L'::bpchar,
    field_fnct character varying(120),
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    tab character varying(25),
    details text
);


ALTER TABLE public.fields OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE fields_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fields_field_id_seq OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE fields_field_id_seq OWNED BY fields.field_id;


--
-- Name: fiscal_years; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE fiscal_years (
    fiscal_year_id integer NOT NULL,
    fiscal_year character varying(9) NOT NULL,
    org_id integer,
    fiscal_year_start date NOT NULL,
    fiscal_year_end date NOT NULL,
    submission_date date,
    year_opened boolean DEFAULT true NOT NULL,
    year_closed boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.fiscal_years OWNER TO postgres;

--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE fiscal_years_fiscal_year_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.fiscal_years_fiscal_year_id_seq OWNER TO postgres;

--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE fiscal_years_fiscal_year_id_seq OWNED BY fiscal_years.fiscal_year_id;


--
-- Name: follow_up; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE follow_up (
    follow_up_id integer NOT NULL,
    lead_item_id integer,
    entity_id integer,
    org_id integer,
    create_time timestamp without time zone DEFAULT now() NOT NULL,
    follow_date date DEFAULT ('now'::text)::date NOT NULL,
    follow_time time without time zone DEFAULT ('now'::text)::time with time zone NOT NULL,
    done boolean DEFAULT false NOT NULL,
    narrative character varying(240),
    details text
);


ALTER TABLE public.follow_up OWNER TO postgres;

--
-- Name: follow_up_follow_up_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE follow_up_follow_up_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.follow_up_follow_up_id_seq OWNER TO postgres;

--
-- Name: follow_up_follow_up_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE follow_up_follow_up_id_seq OWNED BY follow_up.follow_up_id;


--
-- Name: forms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE forms (
    form_id integer NOT NULL,
    org_id integer,
    form_name character varying(240) NOT NULL,
    form_number character varying(50),
    table_name character varying(50),
    version character varying(25),
    completed character(1) DEFAULT '0'::bpchar NOT NULL,
    is_active character(1) DEFAULT '0'::bpchar NOT NULL,
    use_key integer DEFAULT 0,
    form_header text,
    form_footer text,
    default_values text,
    details text
);


ALTER TABLE public.forms OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE forms_form_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.forms_form_id_seq OWNER TO postgres;

--
-- Name: forms_form_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE forms_form_id_seq OWNED BY forms.form_id;


--
-- Name: gls; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE gls (
    gl_id integer NOT NULL,
    journal_id integer NOT NULL,
    account_id integer NOT NULL,
    org_id integer,
    debit real DEFAULT 0 NOT NULL,
    credit real DEFAULT 0 NOT NULL,
    gl_narrative character varying(240),
    account_activity_id integer
);


ALTER TABLE public.gls OWNER TO postgres;

--
-- Name: gls_gl_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE gls_gl_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.gls_gl_id_seq OWNER TO postgres;

--
-- Name: gls_gl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE gls_gl_id_seq OWNED BY gls.gl_id;


--
-- Name: guarantees; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE guarantees (
    guarantee_id integer NOT NULL,
    loan_id integer,
    customer_id integer,
    entity_id integer,
    org_id integer,
    guarantee_amount real NOT NULL,
    guarantee_accepted boolean DEFAULT false NOT NULL,
    accepted_date timestamp without time zone,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.guarantees OWNER TO postgres;

--
-- Name: guarantees_guarantee_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE guarantees_guarantee_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.guarantees_guarantee_id_seq OWNER TO postgres;

--
-- Name: guarantees_guarantee_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE guarantees_guarantee_id_seq OWNED BY guarantees.guarantee_id;


--
-- Name: helpdesk; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE helpdesk (
    helpdesk_id integer NOT NULL,
    pdefinition_id integer,
    plevel_id integer,
    client_id integer,
    recorded_by integer,
    closed_by integer,
    org_id integer,
    description character varying(120) NOT NULL,
    reported_by character varying(50) NOT NULL,
    recoded_time timestamp without time zone DEFAULT now() NOT NULL,
    solved_time timestamp without time zone,
    is_solved boolean DEFAULT false NOT NULL,
    curr_action character varying(50),
    curr_status character varying(50),
    problem text,
    solution text
);


ALTER TABLE public.helpdesk OWNER TO postgres;

--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE helpdesk_helpdesk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.helpdesk_helpdesk_id_seq OWNER TO postgres;

--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE helpdesk_helpdesk_id_seq OWNED BY helpdesk.helpdesk_id;


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE holidays (
    holiday_id integer NOT NULL,
    org_id integer,
    holiday_name character varying(50) NOT NULL,
    holiday_date date,
    details text
);


ALTER TABLE public.holidays OWNER TO postgres;

--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE holidays_holiday_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.holidays_holiday_id_seq OWNER TO postgres;

--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE holidays_holiday_id_seq OWNED BY holidays.holiday_id;


--
-- Name: industry; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE industry (
    industry_id integer NOT NULL,
    org_id integer,
    industry_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.industry OWNER TO postgres;

--
-- Name: industry_industry_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE industry_industry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.industry_industry_id_seq OWNER TO postgres;

--
-- Name: industry_industry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE industry_industry_id_seq OWNED BY industry.industry_id;


--
-- Name: interest_methods; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE interest_methods (
    interest_method_id integer NOT NULL,
    activity_type_id integer NOT NULL,
    org_id integer,
    interest_method_name character varying(120) NOT NULL,
    reducing_balance boolean DEFAULT false NOT NULL,
    reducing_payments boolean DEFAULT false NOT NULL,
    formural character varying(320),
    account_number character varying(32),
    interest_method_no integer,
    details text
);


ALTER TABLE public.interest_methods OWNER TO postgres;

--
-- Name: interest_methods_interest_method_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE interest_methods_interest_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.interest_methods_interest_method_id_seq OWNER TO postgres;

--
-- Name: interest_methods_interest_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE interest_methods_interest_method_id_seq OWNED BY interest_methods.interest_method_id;


--
-- Name: item_category; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE item_category (
    item_category_id integer NOT NULL,
    org_id integer,
    item_category_name character varying(120) NOT NULL,
    details text
);


ALTER TABLE public.item_category OWNER TO postgres;

--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE item_category_item_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.item_category_item_category_id_seq OWNER TO postgres;

--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE item_category_item_category_id_seq OWNED BY item_category.item_category_id;


--
-- Name: item_units; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE item_units (
    item_unit_id integer NOT NULL,
    org_id integer,
    item_unit_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.item_units OWNER TO postgres;

--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE item_units_item_unit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.item_units_item_unit_id_seq OWNER TO postgres;

--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE item_units_item_unit_id_seq OWNED BY item_units.item_unit_id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE items (
    item_id integer NOT NULL,
    org_id integer,
    item_category_id integer,
    tax_type_id integer,
    item_unit_id integer,
    sales_account_id integer,
    purchase_account_id integer,
    item_name character varying(120) NOT NULL,
    bar_code character varying(32),
    inventory boolean DEFAULT false NOT NULL,
    for_sale boolean DEFAULT true NOT NULL,
    for_purchase boolean DEFAULT true NOT NULL,
    for_stock boolean DEFAULT true NOT NULL,
    sales_price real,
    purchase_price real,
    reorder_level integer,
    lead_time integer,
    is_active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.items OWNER TO postgres;

--
-- Name: items_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE items_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.items_item_id_seq OWNER TO postgres;

--
-- Name: items_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE items_item_id_seq OWNED BY items.item_id;


--
-- Name: journals; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE journals (
    journal_id integer NOT NULL,
    period_id integer NOT NULL,
    currency_id integer,
    department_id integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    journal_date date NOT NULL,
    posted boolean DEFAULT false NOT NULL,
    year_closing boolean DEFAULT false NOT NULL,
    narrative character varying(240),
    details text
);


ALTER TABLE public.journals OWNER TO postgres;

--
-- Name: journals_journal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE journals_journal_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.journals_journal_id_seq OWNER TO postgres;

--
-- Name: journals_journal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE journals_journal_id_seq OWNED BY journals.journal_id;


--
-- Name: lead_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE lead_items (
    lead_item_id integer NOT NULL,
    lead_id integer,
    entity_id integer,
    item_id integer,
    org_id integer,
    pitch_date date DEFAULT ('now'::text)::date NOT NULL,
    units integer DEFAULT 1 NOT NULL,
    price real DEFAULT 0 NOT NULL,
    lead_level integer DEFAULT 1 NOT NULL,
    narrative character varying(320),
    details text
);


ALTER TABLE public.lead_items OWNER TO postgres;

--
-- Name: lead_items_lead_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE lead_items_lead_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lead_items_lead_item_id_seq OWNER TO postgres;

--
-- Name: lead_items_lead_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE lead_items_lead_item_id_seq OWNED BY lead_items.lead_item_id;


--
-- Name: leads; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE leads (
    lead_id integer NOT NULL,
    industry_id integer NOT NULL,
    entity_id integer NOT NULL,
    org_id integer,
    business_id integer,
    business_name character varying(50) NOT NULL,
    business_address character varying(100),
    city character varying(30),
    state character varying(50),
    country_id character(2),
    number_of_employees integer,
    telephone character varying(50),
    website character varying(120),
    primary_contact character varying(120),
    job_title character varying(120),
    primary_email character varying(120),
    prospect_level integer DEFAULT 1 NOT NULL,
    contact_date date DEFAULT ('now'::text)::date NOT NULL,
    details text
);


ALTER TABLE public.leads OWNER TO postgres;

--
-- Name: leads_lead_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE leads_lead_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.leads_lead_id_seq OWNER TO postgres;

--
-- Name: leads_lead_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE leads_lead_id_seq OWNED BY leads.lead_id;


--
-- Name: ledger_links; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ledger_links (
    ledger_link_id integer NOT NULL,
    ledger_type_id integer,
    org_id integer,
    link_type integer,
    link_id integer
);


ALTER TABLE public.ledger_links OWNER TO postgres;

--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ledger_links_ledger_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ledger_links_ledger_link_id_seq OWNER TO postgres;

--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ledger_links_ledger_link_id_seq OWNED BY ledger_links.ledger_link_id;


--
-- Name: ledger_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ledger_types (
    ledger_type_id integer NOT NULL,
    account_id integer,
    tax_account_id integer,
    org_id integer,
    ledger_type_name character varying(120) NOT NULL,
    ledger_posting boolean DEFAULT true NOT NULL,
    income_ledger boolean DEFAULT true NOT NULL,
    expense_ledger boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.ledger_types OWNER TO postgres;

--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ledger_types_ledger_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ledger_types_ledger_type_id_seq OWNER TO postgres;

--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ledger_types_ledger_type_id_seq OWNED BY ledger_types.ledger_type_id;


--
-- Name: link_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE link_activity_id_seq
    START WITH 101
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.link_activity_id_seq OWNER TO postgres;

--
-- Name: loan_notes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE loan_notes (
    loan_note_id integer NOT NULL,
    loan_id integer,
    org_id integer,
    comment_date timestamp without time zone DEFAULT now() NOT NULL,
    narrative character varying(320) NOT NULL,
    note text NOT NULL
);


ALTER TABLE public.loan_notes OWNER TO postgres;

--
-- Name: loan_notes_loan_note_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE loan_notes_loan_note_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loan_notes_loan_note_id_seq OWNER TO postgres;

--
-- Name: loan_notes_loan_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE loan_notes_loan_note_id_seq OWNED BY loan_notes.loan_note_id;


--
-- Name: loans; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE loans (
    loan_id integer NOT NULL,
    customer_id integer,
    product_id integer,
    activity_frequency_id integer,
    entity_id integer,
    org_id integer,
    account_number character varying(32) NOT NULL,
    disburse_account character varying(32) NOT NULL,
    principal_amount real NOT NULL,
    interest_rate real NOT NULL,
    repayment_amount real NOT NULL,
    repayment_period integer NOT NULL,
    disbursed_date date,
    matured_date date,
    expected_matured_date date,
    expected_repayment real,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.loans OWNER TO postgres;

--
-- Name: loans_loan_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE loans_loan_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.loans_loan_id_seq OWNER TO postgres;

--
-- Name: loans_loan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE loans_loan_id_seq OWNED BY loans.loan_id;


--
-- Name: locations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE locations (
    location_id integer NOT NULL,
    org_id integer,
    location_name character varying(50),
    details text
);


ALTER TABLE public.locations OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE locations_location_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.locations_location_id_seq OWNER TO postgres;

--
-- Name: locations_location_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE locations_location_id_seq OWNED BY locations.location_id;


--
-- Name: mpesa_api; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE mpesa_api (
    mpesa_api_id integer NOT NULL,
    org_id integer,
    transactiontype character varying(32),
    transid character varying(32),
    transtime character varying(16),
    transamount real,
    businessshortcode character varying(16),
    billrefnumber character varying(64),
    invoicenumber character varying(64),
    orgaccountbalance real,
    thirdpartytransid character varying(64),
    msisdn character varying(16),
    firstname character varying(64),
    middlename character varying(64),
    lastname character varying(64),
    transactiontime timestamp without time zone,
    created timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.mpesa_api OWNER TO postgres;

--
-- Name: mpesa_api_mpesa_api_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE mpesa_api_mpesa_api_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mpesa_api_mpesa_api_id_seq OWNER TO postgres;

--
-- Name: mpesa_api_mpesa_api_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE mpesa_api_mpesa_api_id_seq OWNED BY mpesa_api.mpesa_api_id;


--
-- Name: mpesa_trxs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE mpesa_trxs (
    mpesa_trx_id integer NOT NULL,
    org_id integer,
    mpesa_id integer,
    mpesa_orig character varying(50),
    mpesa_dest character varying(50),
    mpesa_tstamp timestamp without time zone,
    mpesa_text character varying(320),
    mpesa_code character varying(50),
    mpesa_acc character varying(50),
    mpesa_msisdn character varying(50),
    mpesa_trx_date date,
    mpesa_trx_time time without time zone,
    mpesa_amt real,
    mpesa_sender character varying(50),
    mpesa_pick_time timestamp without time zone DEFAULT now()
);


ALTER TABLE public.mpesa_trxs OWNER TO postgres;

--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE mpesa_trxs_mpesa_trx_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mpesa_trxs_mpesa_trx_id_seq OWNER TO postgres;

--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE mpesa_trxs_mpesa_trx_id_seq OWNED BY mpesa_trxs.mpesa_trx_id;


--
-- Name: orgs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE orgs (
    org_id integer NOT NULL,
    currency_id integer,
    default_country_id character(2),
    parent_org_id integer,
    org_name character varying(50) NOT NULL,
    org_full_name character varying(120),
    org_sufix character varying(4) NOT NULL,
    is_default boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    logo character varying(50),
    pin character varying(50),
    pcc character varying(12),
    system_key character varying(64),
    system_identifier character varying(64),
    mac_address character varying(64),
    public_key bytea,
    license bytea,
    details text,
    org_client_id integer,
    payroll_payable boolean DEFAULT true NOT NULL,
    cert_number character varying(50),
    vat_number character varying(50),
    enforce_budget boolean DEFAULT true NOT NULL,
    invoice_footer text,
    accounts_limit integer DEFAULT 100 NOT NULL,
    activity_limit integer DEFAULT 1000 NOT NULL
);


ALTER TABLE public.orgs OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE orgs_org_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.orgs_org_id_seq OWNER TO postgres;

--
-- Name: orgs_org_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE orgs_org_id_seq OWNED BY orgs.org_id;


--
-- Name: pc_allocations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_allocations (
    pc_allocation_id integer NOT NULL,
    period_id integer,
    department_id integer,
    entity_id integer,
    org_id integer,
    narrative character varying(320),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.pc_allocations OWNER TO postgres;

--
-- Name: pc_allocations_pc_allocation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_allocations_pc_allocation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_allocations_pc_allocation_id_seq OWNER TO postgres;

--
-- Name: pc_allocations_pc_allocation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_allocations_pc_allocation_id_seq OWNED BY pc_allocations.pc_allocation_id;


--
-- Name: pc_banking; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_banking (
    pc_banking_id integer NOT NULL,
    pc_allocation_id integer,
    org_id integer,
    banking_date date NOT NULL,
    amount double precision NOT NULL,
    narrative character varying(320) NOT NULL,
    details text
);


ALTER TABLE public.pc_banking OWNER TO postgres;

--
-- Name: pc_banking_pc_banking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_banking_pc_banking_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_banking_pc_banking_id_seq OWNER TO postgres;

--
-- Name: pc_banking_pc_banking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_banking_pc_banking_id_seq OWNED BY pc_banking.pc_banking_id;


--
-- Name: pc_budget; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_budget (
    pc_budget_id integer NOT NULL,
    pc_allocation_id integer,
    pc_item_id integer,
    org_id integer,
    budget_units integer NOT NULL,
    budget_price double precision NOT NULL,
    details text
);


ALTER TABLE public.pc_budget OWNER TO postgres;

--
-- Name: pc_budget_pc_budget_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_budget_pc_budget_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_budget_pc_budget_id_seq OWNER TO postgres;

--
-- Name: pc_budget_pc_budget_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_budget_pc_budget_id_seq OWNED BY pc_budget.pc_budget_id;


--
-- Name: pc_category; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_category (
    pc_category_id integer NOT NULL,
    org_id integer,
    pc_category_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.pc_category OWNER TO postgres;

--
-- Name: pc_category_pc_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_category_pc_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_category_pc_category_id_seq OWNER TO postgres;

--
-- Name: pc_category_pc_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_category_pc_category_id_seq OWNED BY pc_category.pc_category_id;


--
-- Name: pc_expenditure; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_expenditure (
    pc_expenditure_id integer NOT NULL,
    pc_allocation_id integer,
    pc_item_id integer,
    pc_type_id integer,
    entity_id integer,
    org_id integer,
    is_request boolean DEFAULT true NOT NULL,
    request_date timestamp without time zone DEFAULT now(),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    units integer NOT NULL,
    unit_price double precision NOT NULL,
    receipt_number character varying(50),
    exp_date date,
    details text
);


ALTER TABLE public.pc_expenditure OWNER TO postgres;

--
-- Name: pc_expenditure_pc_expenditure_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_expenditure_pc_expenditure_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_expenditure_pc_expenditure_id_seq OWNER TO postgres;

--
-- Name: pc_expenditure_pc_expenditure_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_expenditure_pc_expenditure_id_seq OWNED BY pc_expenditure.pc_expenditure_id;


--
-- Name: pc_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_items (
    pc_item_id integer NOT NULL,
    pc_category_id integer,
    org_id integer,
    pc_item_name character varying(50) NOT NULL,
    default_price double precision NOT NULL,
    default_units integer NOT NULL,
    details text
);


ALTER TABLE public.pc_items OWNER TO postgres;

--
-- Name: pc_items_pc_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_items_pc_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_items_pc_item_id_seq OWNER TO postgres;

--
-- Name: pc_items_pc_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_items_pc_item_id_seq OWNED BY pc_items.pc_item_id;


--
-- Name: pc_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pc_types (
    pc_type_id integer NOT NULL,
    org_id integer,
    pc_type_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.pc_types OWNER TO postgres;

--
-- Name: pc_types_pc_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pc_types_pc_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pc_types_pc_type_id_seq OWNER TO postgres;

--
-- Name: pc_types_pc_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pc_types_pc_type_id_seq OWNED BY pc_types.pc_type_id;


--
-- Name: pdefinitions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE pdefinitions (
    pdefinition_id integer NOT NULL,
    ptype_id integer,
    org_id integer,
    pdefinition_name character varying(50) NOT NULL,
    description text,
    solution text
);


ALTER TABLE public.pdefinitions OWNER TO postgres;

--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE pdefinitions_pdefinition_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pdefinitions_pdefinition_id_seq OWNER TO postgres;

--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE pdefinitions_pdefinition_id_seq OWNED BY pdefinitions.pdefinition_id;


--
-- Name: penalty_methods; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE penalty_methods (
    penalty_method_id integer NOT NULL,
    activity_type_id integer NOT NULL,
    org_id integer,
    penalty_method_name character varying(120) NOT NULL,
    formural character varying(320),
    account_number character varying(32),
    penalty_method_no integer,
    details text
);


ALTER TABLE public.penalty_methods OWNER TO postgres;

--
-- Name: penalty_methods_penalty_method_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE penalty_methods_penalty_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.penalty_methods_penalty_method_id_seq OWNER TO postgres;

--
-- Name: penalty_methods_penalty_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE penalty_methods_penalty_method_id_seq OWNED BY penalty_methods.penalty_method_id;


--
-- Name: period_tax_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE period_tax_rates (
    period_tax_rate_id integer NOT NULL,
    period_tax_type_id integer,
    tax_rate_id integer,
    org_id integer,
    tax_range double precision NOT NULL,
    tax_rate double precision NOT NULL,
    employer_rate integer DEFAULT 0 NOT NULL,
    rate_relief real DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.period_tax_rates OWNER TO postgres;

--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE period_tax_rates_period_tax_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.period_tax_rates_period_tax_rate_id_seq OWNER TO postgres;

--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE period_tax_rates_period_tax_rate_id_seq OWNED BY period_tax_rates.period_tax_rate_id;


--
-- Name: period_tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE period_tax_types (
    period_tax_type_id integer NOT NULL,
    period_id integer,
    tax_type_id integer,
    account_id integer,
    org_id integer,
    period_tax_type_name character varying(50) NOT NULL,
    pay_date date DEFAULT ('now'::text)::date NOT NULL,
    formural character varying(320),
    tax_relief real DEFAULT 0 NOT NULL,
    employer_relief real DEFAULT 0 NOT NULL,
    tax_type_order integer DEFAULT 0 NOT NULL,
    in_tax boolean DEFAULT false NOT NULL,
    tax_rate real DEFAULT 0 NOT NULL,
    tax_inclusive boolean DEFAULT false NOT NULL,
    linear boolean DEFAULT true,
    percentage boolean DEFAULT true,
    account_number character varying(32),
    limit_employee real,
    employer double precision DEFAULT 0 NOT NULL,
    employer_ps double precision DEFAULT 0 NOT NULL,
    employer_formural character varying(320),
    employer_account character varying(32),
    limit_employer real,
    details text
);


ALTER TABLE public.period_tax_types OWNER TO postgres;

--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE period_tax_types_period_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.period_tax_types_period_tax_type_id_seq OWNER TO postgres;

--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE period_tax_types_period_tax_type_id_seq OWNED BY period_tax_types.period_tax_type_id;


--
-- Name: periods; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE periods (
    period_id integer NOT NULL,
    fiscal_year_id integer,
    org_id integer,
    start_date date NOT NULL,
    end_date date NOT NULL,
    opened boolean DEFAULT false NOT NULL,
    activated boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    overtime_rate double precision DEFAULT 1 NOT NULL,
    per_diem_tax_limit double precision DEFAULT 2000 NOT NULL,
    is_posted boolean DEFAULT false NOT NULL,
    loan_approval boolean DEFAULT false NOT NULL,
    gl_payroll_account character varying(32),
    gl_advance_account character varying(32),
    entity_id integer,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.periods OWNER TO postgres;

--
-- Name: periods_period_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE periods_period_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.periods_period_id_seq OWNER TO postgres;

--
-- Name: periods_period_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE periods_period_id_seq OWNED BY periods.period_id;


--
-- Name: picture_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE picture_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.picture_id_seq OWNER TO postgres;

--
-- Name: plevels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE plevels (
    plevel_id integer NOT NULL,
    org_id integer,
    plevel_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.plevels OWNER TO postgres;

--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE plevels_plevel_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.plevels_plevel_id_seq OWNER TO postgres;

--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE plevels_plevel_id_seq OWNED BY plevels.plevel_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE products (
    product_id integer NOT NULL,
    interest_method_id integer,
    penalty_method_id integer,
    activity_frequency_id integer,
    currency_id integer,
    entity_id integer,
    org_id integer,
    product_name character varying(120) NOT NULL,
    description character varying(320),
    loan_account boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    interest_rate real NOT NULL,
    min_opening_balance real DEFAULT 0 NOT NULL,
    lockin_period_frequency real,
    minimum_balance real,
    maximum_balance real,
    minimum_day real,
    maximum_day real,
    minimum_trx real,
    maximum_trx real,
    maximum_repayments integer DEFAULT 100 NOT NULL,
    less_initial_fee boolean DEFAULT false NOT NULL,
    product_no integer,
    application_date timestamp without time zone DEFAULT now() NOT NULL,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE products_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.products_product_id_seq OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE products_product_id_seq OWNED BY products.product_id;


--
-- Name: ptypes; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ptypes (
    ptype_id integer NOT NULL,
    org_id integer,
    ptype_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.ptypes OWNER TO postgres;

--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ptypes_ptype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ptypes_ptype_id_seq OWNER TO postgres;

--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ptypes_ptype_id_seq OWNED BY ptypes.ptype_id;


--
-- Name: quotations; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE quotations (
    quotation_id integer NOT NULL,
    org_id integer,
    item_id integer,
    entity_id integer,
    active boolean DEFAULT false NOT NULL,
    amount real,
    valid_from date,
    valid_to date,
    lead_time integer,
    details text
);


ALTER TABLE public.quotations OWNER TO postgres;

--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE quotations_quotation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.quotations_quotation_id_seq OWNER TO postgres;

--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE quotations_quotation_id_seq OWNED BY quotations.quotation_id;


--
-- Name: reporting; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE reporting (
    reporting_id integer NOT NULL,
    entity_id integer,
    report_to_id integer,
    org_id integer,
    date_from date,
    date_to date,
    reporting_level integer DEFAULT 1 NOT NULL,
    primary_report boolean DEFAULT true NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    ps_reporting real,
    details text
);


ALTER TABLE public.reporting OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE reporting_reporting_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.reporting_reporting_id_seq OWNER TO postgres;

--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE reporting_reporting_id_seq OWNED BY reporting.reporting_id;


--
-- Name: sms; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sms (
    sms_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    sms_number character varying(25),
    sms_numbers text,
    sms_time timestamp without time zone DEFAULT now(),
    sent boolean DEFAULT false NOT NULL,
    message text,
    details text
);


ALTER TABLE public.sms OWNER TO postgres;

--
-- Name: sms_sms_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sms_sms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sms_sms_id_seq OWNER TO postgres;

--
-- Name: sms_sms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sms_sms_id_seq OWNED BY sms.sms_id;


--
-- Name: ss_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ss_items (
    ss_item_id integer NOT NULL,
    ss_type_id integer,
    org_id integer,
    ss_item_name character varying(120),
    picture character varying(120),
    description text,
    purchase_date date NOT NULL,
    purchase_price real DEFAULT 0 NOT NULL,
    sale_date date,
    sale_price real DEFAULT 0 NOT NULL,
    sold boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.ss_items OWNER TO postgres;

--
-- Name: ss_items_ss_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ss_items_ss_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ss_items_ss_item_id_seq OWNER TO postgres;

--
-- Name: ss_items_ss_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ss_items_ss_item_id_seq OWNED BY ss_items.ss_item_id;


--
-- Name: ss_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE ss_types (
    ss_type_id integer NOT NULL,
    org_id integer,
    ss_type_name character varying(120),
    details text
);


ALTER TABLE public.ss_types OWNER TO postgres;

--
-- Name: ss_types_ss_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE ss_types_ss_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ss_types_ss_type_id_seq OWNER TO postgres;

--
-- Name: ss_types_ss_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE ss_types_ss_type_id_seq OWNED BY ss_types.ss_type_id;


--
-- Name: stock_lines; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE stock_lines (
    stock_line_id integer NOT NULL,
    org_id integer,
    stock_id integer,
    item_id integer,
    quantity integer,
    narrative character varying(240)
);


ALTER TABLE public.stock_lines OWNER TO postgres;

--
-- Name: stock_lines_stock_line_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE stock_lines_stock_line_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stock_lines_stock_line_id_seq OWNER TO postgres;

--
-- Name: stock_lines_stock_line_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE stock_lines_stock_line_id_seq OWNED BY stock_lines.stock_line_id;


--
-- Name: stocks; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE stocks (
    stock_id integer NOT NULL,
    org_id integer,
    store_id integer,
    stock_name character varying(50),
    stock_take_date date,
    details text
);


ALTER TABLE public.stocks OWNER TO postgres;

--
-- Name: stocks_stock_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE stocks_stock_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stocks_stock_id_seq OWNER TO postgres;

--
-- Name: stocks_stock_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE stocks_stock_id_seq OWNED BY stocks.stock_id;


--
-- Name: store_movement; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE store_movement (
    store_movement_id integer NOT NULL,
    store_id integer,
    store_to_id integer,
    item_id integer,
    org_id integer,
    movement_date date NOT NULL,
    quantity integer NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.store_movement OWNER TO postgres;

--
-- Name: store_movement_store_movement_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE store_movement_store_movement_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.store_movement_store_movement_id_seq OWNER TO postgres;

--
-- Name: store_movement_store_movement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE store_movement_store_movement_id_seq OWNED BY store_movement.store_movement_id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE stores (
    store_id integer NOT NULL,
    org_id integer,
    store_name character varying(120),
    details text
);


ALTER TABLE public.stores OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE stores_store_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.stores_store_id_seq OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE stores_store_id_seq OWNED BY stores.store_id;


--
-- Name: sub_fields; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sub_fields (
    sub_field_id integer NOT NULL,
    org_id integer,
    field_id integer,
    sub_field_order integer NOT NULL,
    sub_title_share character varying(120),
    sub_field_type character varying(25),
    sub_field_lookup text,
    sub_field_size integer NOT NULL,
    sub_col_spans integer DEFAULT 1 NOT NULL,
    manditory character(1) DEFAULT '0'::bpchar NOT NULL,
    show character(1) DEFAULT '1'::bpchar,
    question text
);


ALTER TABLE public.sub_fields OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sub_fields_sub_field_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sub_fields_sub_field_id_seq OWNER TO postgres;

--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sub_fields_sub_field_id_seq OWNED BY sub_fields.sub_field_id;


--
-- Name: subscription_levels; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subscription_levels (
    subscription_level_id integer NOT NULL,
    org_id integer,
    subscription_level_name character varying(50),
    details text
);


ALTER TABLE public.subscription_levels OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE subscription_levels_subscription_level_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscription_levels_subscription_level_id_seq OWNER TO postgres;

--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE subscription_levels_subscription_level_id_seq OWNED BY subscription_levels.subscription_level_id;


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE subscriptions (
    subscription_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    business_name character varying(50),
    business_address character varying(100),
    city character varying(30),
    state character varying(50),
    country_id character(2),
    telephone character varying(50),
    website character varying(120),
    primary_contact character varying(120),
    job_title character varying(120),
    primary_email character varying(120),
    confirm_email character varying(120),
    system_key character varying(64),
    subscribed boolean,
    subscribed_date timestamp without time zone,
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    application_date timestamp without time zone DEFAULT now(),
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.subscriptions OWNER TO postgres;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE subscriptions_subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.subscriptions_subscription_id_seq OWNER TO postgres;

--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE subscriptions_subscription_id_seq OWNED BY subscriptions.subscription_id;


--
-- Name: sys_audit_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_details (
    sys_audit_trail_id integer NOT NULL,
    old_value text
);


ALTER TABLE public.sys_audit_details OWNER TO postgres;

--
-- Name: sys_audit_trail; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_audit_trail (
    sys_audit_trail_id integer NOT NULL,
    user_id character varying(50) NOT NULL,
    user_ip character varying(50),
    change_date timestamp without time zone DEFAULT now() NOT NULL,
    table_name character varying(50) NOT NULL,
    record_id character varying(50) NOT NULL,
    change_type character varying(50) NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.sys_audit_trail OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_audit_trail_sys_audit_trail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_audit_trail_sys_audit_trail_id_seq OWNER TO postgres;

--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_audit_trail_sys_audit_trail_id_seq OWNED BY sys_audit_trail.sys_audit_trail_id;


--
-- Name: sys_continents; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_continents (
    sys_continent_id character(2) NOT NULL,
    sys_continent_name character varying(120)
);


ALTER TABLE public.sys_continents OWNER TO postgres;

--
-- Name: sys_countrys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_countrys (
    sys_country_id character(2) NOT NULL,
    sys_continent_id character(2),
    sys_country_code character varying(3),
    sys_country_name character varying(120),
    sys_country_number character varying(3),
    sys_country_capital character varying(64),
    sys_phone_code character varying(7),
    sys_currency_name character varying(50),
    sys_currency_code character varying(3),
    sys_currency_cents character varying(50),
    sys_currency_exchange real
);


ALTER TABLE public.sys_countrys OWNER TO postgres;

--
-- Name: sys_dashboard; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_dashboard (
    sys_dashboard_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    narrative character varying(240),
    details text
);


ALTER TABLE public.sys_dashboard OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_dashboard_sys_dashboard_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_dashboard_sys_dashboard_id_seq OWNER TO postgres;

--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_dashboard_sys_dashboard_id_seq OWNED BY sys_dashboard.sys_dashboard_id;


--
-- Name: sys_emailed; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emailed (
    sys_emailed_id integer NOT NULL,
    sys_email_id integer,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    email_type integer DEFAULT 1 NOT NULL,
    emailed boolean DEFAULT false NOT NULL,
    created timestamp without time zone DEFAULT now(),
    narrative character varying(240),
    mail_body text
);


ALTER TABLE public.sys_emailed OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emailed_sys_emailed_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emailed_sys_emailed_id_seq OWNER TO postgres;

--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emailed_sys_emailed_id_seq OWNED BY sys_emailed.sys_emailed_id;


--
-- Name: sys_emails; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_emails (
    sys_email_id integer NOT NULL,
    org_id integer,
    use_type integer DEFAULT 1 NOT NULL,
    sys_email_name character varying(50),
    default_email character varying(320),
    title character varying(240) NOT NULL,
    details text
);


ALTER TABLE public.sys_emails OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_emails_sys_email_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_emails_sys_email_id_seq OWNER TO postgres;

--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_emails_sys_email_id_seq OWNED BY sys_emails.sys_email_id;


--
-- Name: sys_errors; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_errors (
    sys_error_id integer NOT NULL,
    sys_error character varying(240) NOT NULL,
    error_message text NOT NULL
);


ALTER TABLE public.sys_errors OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_errors_sys_error_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_errors_sys_error_id_seq OWNER TO postgres;

--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_errors_sys_error_id_seq OWNED BY sys_errors.sys_error_id;


--
-- Name: sys_files; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_files (
    sys_file_id integer NOT NULL,
    org_id integer,
    table_id integer,
    table_name character varying(50),
    file_name character varying(320),
    file_type character varying(320),
    file_size integer,
    narrative character varying(320),
    details text
);


ALTER TABLE public.sys_files OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_files_sys_file_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_files_sys_file_id_seq OWNER TO postgres;

--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_files_sys_file_id_seq OWNED BY sys_files.sys_file_id;


--
-- Name: sys_logins; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_logins (
    sys_login_id integer NOT NULL,
    entity_id integer,
    login_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_logins OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_logins_sys_login_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_logins_sys_login_id_seq OWNER TO postgres;

--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_logins_sys_login_id_seq OWNED BY sys_logins.sys_login_id;


--
-- Name: sys_menu_msg; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_menu_msg (
    sys_menu_msg_id integer NOT NULL,
    menu_id character varying(16) NOT NULL,
    menu_name character varying(50) NOT NULL,
    xml_file character varying(50) NOT NULL,
    msg text
);


ALTER TABLE public.sys_menu_msg OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_menu_msg_sys_menu_msg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_menu_msg_sys_menu_msg_id_seq OWNER TO postgres;

--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_menu_msg_sys_menu_msg_id_seq OWNED BY sys_menu_msg.sys_menu_msg_id;


--
-- Name: sys_news; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_news (
    sys_news_id integer NOT NULL,
    org_id integer,
    sys_news_group integer,
    sys_news_title character varying(240) NOT NULL,
    publish boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.sys_news OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_news_sys_news_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_news_sys_news_id_seq OWNER TO postgres;

--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_news_sys_news_id_seq OWNED BY sys_news.sys_news_id;


--
-- Name: sys_queries; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_queries (
    sys_queries_id integer NOT NULL,
    org_id integer,
    sys_query_name character varying(50),
    query_date timestamp without time zone DEFAULT now() NOT NULL,
    query_text text,
    query_params text
);


ALTER TABLE public.sys_queries OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_queries_sys_queries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_queries_sys_queries_id_seq OWNER TO postgres;

--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_queries_sys_queries_id_seq OWNED BY sys_queries.sys_queries_id;


--
-- Name: sys_reset; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE sys_reset (
    sys_reset_id integer NOT NULL,
    entity_id integer,
    org_id integer,
    request_email character varying(320),
    request_time timestamp without time zone DEFAULT now(),
    login_ip character varying(64),
    narrative character varying(240)
);


ALTER TABLE public.sys_reset OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE sys_reset_sys_reset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sys_reset_sys_reset_id_seq OWNER TO postgres;

--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE sys_reset_sys_reset_id_seq OWNED BY sys_reset.sys_reset_id;


--
-- Name: tax_rates; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tax_rates (
    tax_rate_id integer NOT NULL,
    tax_type_id integer,
    org_id integer,
    tax_range double precision NOT NULL,
    tax_rate double precision NOT NULL,
    employer_rate integer DEFAULT 0 NOT NULL,
    rate_relief real DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.tax_rates OWNER TO postgres;

--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tax_rates_tax_rate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tax_rates_tax_rate_id_seq OWNER TO postgres;

--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tax_rates_tax_rate_id_seq OWNED BY tax_rates.tax_rate_id;


--
-- Name: tax_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tax_types (
    tax_type_id integer NOT NULL,
    account_id integer,
    currency_id integer,
    use_key_id integer NOT NULL,
    sys_country_id character(2),
    org_id integer,
    tax_type_name character varying(50) NOT NULL,
    tax_type_number character varying(50),
    formural character varying(320),
    tax_relief real DEFAULT 0 NOT NULL,
    employer_relief real DEFAULT 0 NOT NULL,
    tax_type_order integer DEFAULT 0 NOT NULL,
    in_tax boolean DEFAULT false NOT NULL,
    tax_rate real DEFAULT 0 NOT NULL,
    tax_inclusive boolean DEFAULT false NOT NULL,
    linear boolean DEFAULT true,
    percentage boolean DEFAULT true,
    account_number character varying(32),
    limit_employee real,
    employer double precision DEFAULT 0 NOT NULL,
    employer_ps double precision DEFAULT 0 NOT NULL,
    employer_formural character varying(320),
    employer_account character varying(32),
    limit_employer real,
    active boolean DEFAULT true NOT NULL,
    details text
);


ALTER TABLE public.tax_types OWNER TO postgres;

--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tax_types_tax_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tax_types_tax_type_id_seq OWNER TO postgres;

--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tax_types_tax_type_id_seq OWNED BY tax_types.tax_type_id;


--
-- Name: tender_items; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tender_items (
    tender_item_id integer NOT NULL,
    bidder_id integer,
    org_id integer,
    tender_item_name character varying(320) NOT NULL,
    quantity integer,
    item_amount real,
    item_tax real,
    details text
);


ALTER TABLE public.tender_items OWNER TO postgres;

--
-- Name: tender_items_tender_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tender_items_tender_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tender_items_tender_item_id_seq OWNER TO postgres;

--
-- Name: tender_items_tender_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tender_items_tender_item_id_seq OWNED BY tender_items.tender_item_id;


--
-- Name: tender_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tender_types (
    tender_type_id integer NOT NULL,
    org_id integer,
    tender_type_name character varying(50) NOT NULL,
    details text
);


ALTER TABLE public.tender_types OWNER TO postgres;

--
-- Name: tender_types_tender_type_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tender_types_tender_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tender_types_tender_type_id_seq OWNER TO postgres;

--
-- Name: tender_types_tender_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tender_types_tender_type_id_seq OWNED BY tender_types.tender_type_id;


--
-- Name: tenders; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE tenders (
    tender_id integer NOT NULL,
    tender_type_id integer,
    currency_id integer,
    org_id integer,
    tender_name character varying(320) NOT NULL,
    tender_number character varying(64),
    tender_date date NOT NULL,
    tender_end_date date,
    is_completed boolean DEFAULT false NOT NULL,
    details text
);


ALTER TABLE public.tenders OWNER TO postgres;

--
-- Name: tenders_tender_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE tenders_tender_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tenders_tender_id_seq OWNER TO postgres;

--
-- Name: tenders_tender_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE tenders_tender_id_seq OWNED BY tenders.tender_id;


--
-- Name: tomcat_users; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW tomcat_users AS
 SELECT entitys.user_name,
    entitys.entity_password,
    entity_types.entity_role
   FROM ((entity_subscriptions
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
  WHERE (entitys.is_active = true);


ALTER TABLE public.tomcat_users OWNER TO postgres;

--
-- Name: transaction_counters; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_counters (
    transaction_counter_id integer NOT NULL,
    transaction_type_id integer,
    org_id integer,
    document_number integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.transaction_counters OWNER TO postgres;

--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_counters_transaction_counter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_counters_transaction_counter_id_seq OWNER TO postgres;

--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_counters_transaction_counter_id_seq OWNED BY transaction_counters.transaction_counter_id;


--
-- Name: transaction_details; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_details (
    transaction_detail_id integer NOT NULL,
    transaction_id integer,
    account_id integer,
    item_id integer,
    store_id integer,
    org_id integer,
    quantity integer NOT NULL,
    amount real DEFAULT 0 NOT NULL,
    tax_amount real DEFAULT 0 NOT NULL,
    discount real DEFAULT 0 NOT NULL,
    narrative character varying(240),
    purpose character varying(320),
    details text,
    CONSTRAINT transaction_details_discount_check CHECK (((discount >= (0)::double precision) AND (discount <= (100)::double precision)))
);


ALTER TABLE public.transaction_details OWNER TO postgres;

--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_details_transaction_detail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_details_transaction_detail_id_seq OWNER TO postgres;

--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_details_transaction_detail_id_seq OWNED BY transaction_details.transaction_detail_id;


--
-- Name: transaction_links; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_links (
    transaction_link_id integer NOT NULL,
    org_id integer,
    transaction_id integer,
    transaction_to integer,
    transaction_detail_id integer,
    transaction_detail_to integer,
    amount real DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    narrative character varying(240)
);


ALTER TABLE public.transaction_links OWNER TO postgres;

--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transaction_links_transaction_link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transaction_links_transaction_link_id_seq OWNER TO postgres;

--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transaction_links_transaction_link_id_seq OWNED BY transaction_links.transaction_link_id;


--
-- Name: transaction_status; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_status (
    transaction_status_id integer NOT NULL,
    transaction_status_name character varying(50) NOT NULL
);


ALTER TABLE public.transaction_status OWNER TO postgres;

--
-- Name: transaction_types; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transaction_types (
    transaction_type_id integer NOT NULL,
    transaction_type_name character varying(50) NOT NULL,
    document_prefix character varying(16) DEFAULT 'D'::character varying NOT NULL,
    for_sales boolean DEFAULT true NOT NULL,
    for_posting boolean DEFAULT true NOT NULL
);


ALTER TABLE public.transaction_types OWNER TO postgres;

--
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transactions (
    transaction_id integer NOT NULL,
    entity_id integer,
    transaction_type_id integer,
    ledger_type_id integer,
    transaction_status_id integer DEFAULT 1,
    bank_account_id integer,
    journal_id integer,
    currency_id integer,
    department_id integer,
    entered_by integer,
    org_id integer,
    exchange_rate real DEFAULT 1 NOT NULL,
    transaction_date date NOT NULL,
    payment_date date NOT NULL,
    transaction_amount real DEFAULT 0 NOT NULL,
    transaction_tax_amount real DEFAULT 0 NOT NULL,
    document_number integer DEFAULT 1 NOT NULL,
    tx_type integer,
    for_processing boolean DEFAULT false NOT NULL,
    is_cleared boolean DEFAULT false NOT NULL,
    completed boolean DEFAULT false NOT NULL,
    reference_number character varying(50),
    payment_number character varying(50),
    order_number character varying(50),
    payment_terms character varying(50),
    job character varying(240),
    point_of_use character varying(240),
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    narrative character varying(120),
    notes text,
    details text
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transactions_transaction_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transactions_transaction_id_seq OWNED BY transactions.transaction_id;


--
-- Name: transfer_activity; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transfer_activity (
    transfer_activity_id integer NOT NULL,
    transfer_beneficiary_id integer,
    deposit_account_id integer,
    activity_type_id integer,
    activity_frequency_id integer,
    currency_id integer,
    entity_id integer,
    account_activity_id integer,
    org_id integer,
    transfer_amount real NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.transfer_activity OWNER TO postgres;

--
-- Name: transfer_activity_transfer_activity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transfer_activity_transfer_activity_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transfer_activity_transfer_activity_id_seq OWNER TO postgres;

--
-- Name: transfer_activity_transfer_activity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transfer_activity_transfer_activity_id_seq OWNED BY transfer_activity.transfer_activity_id;


--
-- Name: transfer_beneficiary; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE transfer_beneficiary (
    transfer_beneficiary_id integer NOT NULL,
    customer_id integer,
    deposit_account_id integer,
    entity_id integer,
    org_id integer,
    beneficiary_name character varying(150) NOT NULL,
    account_number character varying(32) NOT NULL,
    allow_transfer boolean DEFAULT true NOT NULL,
    application_date timestamp without time zone DEFAULT now(),
    approve_status character varying(16) DEFAULT 'Draft'::character varying NOT NULL,
    workflow_table_id integer,
    action_date timestamp without time zone,
    details text
);


ALTER TABLE public.transfer_beneficiary OWNER TO postgres;

--
-- Name: transfer_beneficiary_transfer_beneficiary_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE transfer_beneficiary_transfer_beneficiary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.transfer_beneficiary_transfer_beneficiary_id_seq OWNER TO postgres;

--
-- Name: transfer_beneficiary_transfer_beneficiary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE transfer_beneficiary_transfer_beneficiary_id_seq OWNED BY transfer_beneficiary.transfer_beneficiary_id;


--
-- Name: use_keys; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE use_keys (
    use_key_id integer NOT NULL,
    use_key_name character varying(32) NOT NULL,
    use_function integer
);


ALTER TABLE public.use_keys OWNER TO postgres;

--
-- Name: vw_account_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_account_types AS
 SELECT account_class.account_class_id,
    account_class.account_class_no,
    account_class.account_class_name,
    account_class.chat_type_id,
    account_class.chat_type_name,
    account_types.account_type_id,
    account_types.account_type_no,
    account_types.org_id,
    account_types.account_type_name,
    account_types.details
   FROM (account_types
     JOIN account_class ON ((account_types.account_class_id = account_class.account_class_id)));


ALTER TABLE public.vw_account_types OWNER TO postgres;

--
-- Name: vw_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_accounts AS
 SELECT vw_account_types.chat_type_id,
    vw_account_types.chat_type_name,
    vw_account_types.account_class_id,
    vw_account_types.account_class_no,
    vw_account_types.account_class_name,
    vw_account_types.account_type_id,
    vw_account_types.account_type_no,
    vw_account_types.account_type_name,
    accounts.account_id,
    accounts.account_no,
    accounts.org_id,
    accounts.account_name,
    accounts.is_header,
    accounts.is_active,
    accounts.details,
    ((((((accounts.account_no || ' : '::text) || (vw_account_types.account_class_name)::text) || ' : '::text) || (vw_account_types.account_type_name)::text) || ' : '::text) || (accounts.account_name)::text) AS account_description
   FROM (accounts
     JOIN vw_account_types ON ((accounts.account_type_id = vw_account_types.account_type_id)));


ALTER TABLE public.vw_accounts OWNER TO postgres;

--
-- Name: vw_activity_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_activity_types AS
 SELECT activity_types.dr_account_id,
    dra.account_no AS dr_account_no,
    dra.account_name AS dr_account_name,
    activity_types.cr_account_id,
    cra.account_no AS cr_account_no,
    cra.account_name AS cr_account_name,
    use_keys.use_key_id,
    use_keys.use_key_name,
    activity_types.org_id,
    activity_types.activity_type_id,
    activity_types.activity_type_name,
    activity_types.is_active,
    activity_types.activity_type_no,
    activity_types.details
   FROM (((activity_types
     JOIN vw_accounts dra ON ((activity_types.dr_account_id = dra.account_id)))
     JOIN vw_accounts cra ON ((activity_types.cr_account_id = cra.account_id)))
     JOIN use_keys ON ((activity_types.use_key_id = use_keys.use_key_id)));


ALTER TABLE public.vw_activity_types OWNER TO postgres;

--
-- Name: vw_deposit_balance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_deposit_balance AS
 SELECT cb.deposit_account_id,
    cb.current_balance,
    COALESCE(ab.c_balance, (0)::real) AS cleared_balance,
    COALESCE(uc.u_credit, (0)::real) AS unprocessed_credit
   FROM ((( SELECT account_activity.deposit_account_id,
            sum(((account_activity.account_credit - account_activity.account_debit) * account_activity.exchange_rate)) AS current_balance
           FROM account_activity
          GROUP BY account_activity.deposit_account_id) cb
     LEFT JOIN ( SELECT account_activity.deposit_account_id,
            sum(((account_activity.account_credit - account_activity.account_debit) * account_activity.exchange_rate)) AS c_balance
           FROM account_activity
          WHERE (account_activity.activity_status_id < 3)
          GROUP BY account_activity.deposit_account_id) ab ON ((cb.deposit_account_id = ab.deposit_account_id)))
     LEFT JOIN ( SELECT account_activity.deposit_account_id,
            sum((account_activity.account_credit * account_activity.exchange_rate)) AS u_credit
           FROM account_activity
          WHERE (account_activity.activity_status_id > 2)
          GROUP BY account_activity.deposit_account_id) uc ON ((cb.deposit_account_id = uc.deposit_account_id)));


ALTER TABLE public.vw_deposit_balance OWNER TO postgres;

--
-- Name: vw_interest_methods; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_interest_methods AS
 SELECT activity_types.activity_type_id,
    activity_types.activity_type_name,
    activity_types.use_key_id,
    interest_methods.org_id,
    interest_methods.interest_method_id,
    interest_methods.interest_method_name,
    interest_methods.reducing_balance,
    interest_methods.formural,
    interest_methods.account_number,
    interest_methods.interest_method_no,
    interest_methods.details
   FROM (interest_methods
     JOIN activity_types ON ((interest_methods.activity_type_id = activity_types.activity_type_id)));


ALTER TABLE public.vw_interest_methods OWNER TO postgres;

--
-- Name: vw_products; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_products AS
 SELECT activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_interest_methods.interest_method_id,
    vw_interest_methods.interest_method_name,
    vw_interest_methods.reducing_balance,
    vw_interest_methods.interest_method_no,
    penalty_methods.penalty_method_id,
    penalty_methods.penalty_method_name,
    penalty_methods.penalty_method_no,
    products.org_id,
    products.product_id,
    products.product_name,
    products.description,
    products.loan_account,
    products.is_active,
    products.interest_rate,
    products.min_opening_balance,
    products.lockin_period_frequency,
    products.minimum_balance,
    products.maximum_balance,
    products.minimum_day,
    products.maximum_day,
    products.minimum_trx,
    products.maximum_trx,
    products.maximum_repayments,
    products.product_no,
    products.application_date,
    products.approve_status,
    products.workflow_table_id,
    products.action_date,
    products.details
   FROM ((((products
     JOIN activity_frequency ON ((products.activity_frequency_id = activity_frequency.activity_frequency_id)))
     JOIN currency ON ((products.currency_id = currency.currency_id)))
     JOIN vw_interest_methods ON ((products.interest_method_id = vw_interest_methods.interest_method_id)))
     JOIN penalty_methods ON ((products.penalty_method_id = penalty_methods.penalty_method_id)));


ALTER TABLE public.vw_products OWNER TO postgres;

--
-- Name: vw_deposit_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_deposit_accounts AS
 SELECT customers.customer_id,
    customers.customer_name,
    customers.business_account,
    vw_products.product_id,
    vw_products.product_name,
    vw_products.currency_id,
    vw_products.currency_name,
    vw_products.currency_symbol,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    orgs.org_id,
    orgs.org_name,
    deposit_accounts.deposit_account_id,
    deposit_accounts.is_active,
    deposit_accounts.account_number,
    deposit_accounts.narrative,
    deposit_accounts.last_closing_date,
    deposit_accounts.credit_limit,
    deposit_accounts.minimum_balance,
    deposit_accounts.maximum_balance,
    deposit_accounts.interest_rate,
    deposit_accounts.lockin_period_frequency,
    deposit_accounts.opening_date,
    deposit_accounts.lockedin_until_date,
    deposit_accounts.application_date,
    deposit_accounts.approve_status,
    deposit_accounts.workflow_table_id,
    deposit_accounts.action_date,
    deposit_accounts.details,
    vw_deposit_balance.current_balance,
    vw_deposit_balance.cleared_balance,
    vw_deposit_balance.unprocessed_credit,
    (vw_deposit_balance.cleared_balance - vw_deposit_balance.unprocessed_credit) AS available_balance
   FROM (((((deposit_accounts
     JOIN customers ON ((deposit_accounts.customer_id = customers.customer_id)))
     JOIN vw_products ON ((deposit_accounts.product_id = vw_products.product_id)))
     JOIN activity_frequency ON ((deposit_accounts.activity_frequency_id = activity_frequency.activity_frequency_id)))
     JOIN orgs ON ((deposit_accounts.org_id = orgs.org_id)))
     LEFT JOIN vw_deposit_balance ON ((deposit_accounts.deposit_account_id = vw_deposit_balance.deposit_account_id)));


ALTER TABLE public.vw_deposit_accounts OWNER TO postgres;

--
-- Name: vw_periods; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_periods AS
 SELECT fiscal_years.fiscal_year_id,
    fiscal_years.fiscal_year,
    fiscal_years.fiscal_year_start,
    fiscal_years.fiscal_year_end,
    fiscal_years.submission_date,
    fiscal_years.year_opened,
    fiscal_years.year_closed,
    periods.period_id,
    periods.org_id,
    periods.start_date,
    periods.end_date,
    periods.opened,
    periods.activated,
    periods.closed,
    periods.overtime_rate,
    periods.per_diem_tax_limit,
    periods.is_posted,
    periods.gl_payroll_account,
    periods.gl_advance_account,
    periods.details,
    date_part('month'::text, periods.start_date) AS month_id,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY'::text) AS period_year,
    to_char((periods.start_date)::timestamp with time zone, 'Month'::text) AS period_month,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY, Month'::text) AS period_disp,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (3)::double precision)) + (1)::double precision) AS quarter,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (6)::double precision)) + (1)::double precision) AS semister,
    to_char((periods.start_date)::timestamp with time zone, 'YYYYMM'::text) AS period_code
   FROM (periods
     LEFT JOIN fiscal_years ON ((periods.fiscal_year_id = fiscal_years.fiscal_year_id)))
  ORDER BY periods.start_date;


ALTER TABLE public.vw_periods OWNER TO postgres;

--
-- Name: vw_account_activity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_account_activity AS
 SELECT vw_deposit_accounts.customer_id,
    vw_deposit_accounts.customer_name,
    vw_deposit_accounts.business_account,
    vw_deposit_accounts.product_id,
    vw_deposit_accounts.product_name,
    vw_deposit_accounts.deposit_account_id,
    vw_deposit_accounts.is_active,
    vw_deposit_accounts.account_number,
    vw_deposit_accounts.last_closing_date,
    vw_activity_types.activity_type_id,
    vw_activity_types.activity_type_name,
    vw_activity_types.dr_account_id,
    vw_activity_types.dr_account_no,
    vw_activity_types.dr_account_name,
    vw_activity_types.cr_account_id,
    vw_activity_types.cr_account_no,
    vw_activity_types.cr_account_name,
    vw_activity_types.use_key_id,
    vw_activity_types.use_key_name,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    activity_status.activity_status_id,
    activity_status.activity_status_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    account_activity.transfer_account_id,
    trnf_accounts.account_number AS trnf_account_number,
    trnf_accounts.customer_id AS trnf_customer_id,
    trnf_accounts.customer_name AS trnf_customer_name,
    trnf_accounts.product_id AS trnf_product_id,
    trnf_accounts.product_name AS trnf_product_name,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.fiscal_year_id,
    vw_periods.fiscal_year,
    account_activity.org_id,
    account_activity.account_activity_id,
    account_activity.activity_date,
    account_activity.value_date,
    account_activity.transfer_account_no,
    account_activity.transfer_link_id,
    account_activity.account_credit,
    account_activity.account_debit,
    account_activity.balance,
    account_activity.exchange_rate,
    account_activity.application_date,
    account_activity.approve_status,
    account_activity.workflow_table_id,
    account_activity.action_date,
    account_activity.details,
    (account_activity.account_credit * account_activity.exchange_rate) AS base_credit,
    (account_activity.account_debit * account_activity.exchange_rate) AS base_debit
   FROM (((((((account_activity
     JOIN vw_deposit_accounts ON ((account_activity.deposit_account_id = vw_deposit_accounts.deposit_account_id)))
     JOIN vw_activity_types ON ((account_activity.activity_type_id = vw_activity_types.activity_type_id)))
     JOIN activity_frequency ON ((account_activity.activity_frequency_id = activity_frequency.activity_frequency_id)))
     JOIN activity_status ON ((account_activity.activity_status_id = activity_status.activity_status_id)))
     JOIN currency ON ((account_activity.currency_id = currency.currency_id)))
     LEFT JOIN vw_periods ON ((account_activity.period_id = vw_periods.period_id)))
     LEFT JOIN vw_deposit_accounts trnf_accounts ON ((account_activity.transfer_account_id = trnf_accounts.deposit_account_id)));


ALTER TABLE public.vw_account_activity OWNER TO postgres;

--
-- Name: vw_account_definations; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_account_definations AS
 SELECT products.product_id,
    products.product_name,
    products.product_no,
    vw_activity_types.activity_type_id,
    vw_activity_types.activity_type_name,
    vw_activity_types.activity_type_no,
    vw_activity_types.use_key_id,
    vw_activity_types.use_key_name,
    account_definations.charge_activity_id,
    charge_activitys.activity_type_name AS charge_activity_name,
    charge_activitys.activity_type_no AS charge_activity_no,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    account_definations.org_id,
    account_definations.account_defination_id,
    account_definations.account_defination_name,
    account_definations.start_date,
    account_definations.end_date,
    account_definations.is_active,
    account_definations.account_number,
    account_definations.fee_amount,
    account_definations.fee_ps,
    account_definations.has_charge,
    account_definations.details
   FROM ((((account_definations
     JOIN vw_activity_types ON ((account_definations.activity_type_id = vw_activity_types.activity_type_id)))
     JOIN products ON ((account_definations.product_id = products.product_id)))
     JOIN activity_frequency ON ((account_definations.activity_frequency_id = activity_frequency.activity_frequency_id)))
     LEFT JOIN activity_types charge_activitys ON ((account_definations.charge_activity_id = charge_activitys.activity_type_id)));


ALTER TABLE public.vw_account_definations OWNER TO postgres;

--
-- Name: vw_account_notes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_account_notes AS
 SELECT vw_deposit_accounts.customer_id,
    vw_deposit_accounts.customer_name,
    vw_deposit_accounts.product_id,
    vw_deposit_accounts.product_name,
    vw_deposit_accounts.deposit_account_id,
    vw_deposit_accounts.is_active,
    vw_deposit_accounts.account_number,
    vw_deposit_accounts.last_closing_date,
    account_notes.org_id,
    account_notes.account_note_id,
    account_notes.comment_date,
    account_notes.narrative,
    account_notes.note
   FROM (account_notes
     JOIN vw_deposit_accounts ON ((account_notes.deposit_account_id = vw_deposit_accounts.deposit_account_id)));


ALTER TABLE public.vw_account_notes OWNER TO postgres;

--
-- Name: vw_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    address.address_id,
    address.org_id,
    address.address_name,
    address.table_name,
    address.table_id,
    address.post_office_box,
    address.postal_code,
    address.premises,
    address.street,
    address.town,
    address.phone_number,
    address.extension,
    address.mobile,
    address.fax,
    address.email,
    address.is_default,
    address.website,
    address.details,
    address_types.address_type_id,
    address_types.address_type_name
   FROM ((address
     JOIN sys_countrys ON ((address.sys_country_id = sys_countrys.sys_country_id)))
     LEFT JOIN address_types ON ((address.address_type_id = address_types.address_type_id)));


ALTER TABLE public.vw_address OWNER TO postgres;

--
-- Name: vw_address_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_address_entitys AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_address_entitys OWNER TO postgres;

--
-- Name: workflows; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflows (
    workflow_id integer NOT NULL,
    source_entity_id integer NOT NULL,
    org_id integer,
    workflow_name character varying(240) NOT NULL,
    table_name character varying(64),
    table_link_field character varying(64),
    table_link_id integer,
    approve_email text NOT NULL,
    reject_email text NOT NULL,
    approve_file character varying(320),
    reject_file character varying(320),
    link_copy integer,
    details text
);


ALTER TABLE public.workflows OWNER TO postgres;

--
-- Name: vw_workflows; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflows AS
 SELECT entity_types.entity_type_id AS source_entity_id,
    entity_types.entity_type_name AS source_entity_name,
    workflows.workflow_id,
    workflows.org_id,
    workflows.workflow_name,
    workflows.table_name,
    workflows.table_link_field,
    workflows.table_link_id,
    workflows.approve_email,
    workflows.reject_email,
    workflows.approve_file,
    workflows.reject_file,
    workflows.details
   FROM (workflows
     JOIN entity_types ON ((workflows.source_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflows OWNER TO postgres;

--
-- Name: workflow_phases; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_phases (
    workflow_phase_id integer NOT NULL,
    workflow_id integer NOT NULL,
    approval_entity_id integer NOT NULL,
    org_id integer,
    approval_level integer DEFAULT 1 NOT NULL,
    return_level integer DEFAULT 1 NOT NULL,
    escalation_days integer DEFAULT 0 NOT NULL,
    escalation_hours integer DEFAULT 3 NOT NULL,
    required_approvals integer DEFAULT 1 NOT NULL,
    reporting_level integer DEFAULT 1 NOT NULL,
    use_reporting boolean DEFAULT false NOT NULL,
    advice boolean DEFAULT false NOT NULL,
    notice boolean DEFAULT false NOT NULL,
    phase_narrative character varying(240) NOT NULL,
    advice_email text,
    notice_email text,
    advice_file character varying(320),
    notice_file character varying(320),
    details text
);


ALTER TABLE public.workflow_phases OWNER TO postgres;

--
-- Name: vw_workflow_phases; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_phases AS
 SELECT vw_workflows.source_entity_id,
    vw_workflows.source_entity_name,
    vw_workflows.workflow_id,
    vw_workflows.workflow_name,
    vw_workflows.table_name,
    vw_workflows.table_link_field,
    vw_workflows.table_link_id,
    vw_workflows.approve_email,
    vw_workflows.reject_email,
    vw_workflows.approve_file,
    vw_workflows.reject_file,
    entity_types.entity_type_id AS approval_entity_id,
    entity_types.entity_type_name AS approval_entity_name,
    workflow_phases.workflow_phase_id,
    workflow_phases.org_id,
    workflow_phases.approval_level,
    workflow_phases.return_level,
    workflow_phases.escalation_days,
    workflow_phases.escalation_hours,
    workflow_phases.notice,
    workflow_phases.notice_email,
    workflow_phases.notice_file,
    workflow_phases.advice,
    workflow_phases.advice_email,
    workflow_phases.advice_file,
    workflow_phases.required_approvals,
    workflow_phases.use_reporting,
    workflow_phases.reporting_level,
    workflow_phases.phase_narrative,
    workflow_phases.details
   FROM ((workflow_phases
     JOIN vw_workflows ON ((workflow_phases.workflow_id = vw_workflows.workflow_id)))
     JOIN entity_types ON ((workflow_phases.approval_entity_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_workflow_phases OWNER TO postgres;

--
-- Name: vw_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.approve_email,
    vw_workflow_phases.reject_email,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    ae.entity_id AS app_entity_id,
    ae.entity_name AS app_entity_name,
    ae.user_name AS app_user_name,
    ae.primary_email AS app_primary_email
   FROM (((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     LEFT JOIN entitys ae ON ((approvals.app_entity_id = ae.entity_id)));


ALTER TABLE public.vw_approvals OWNER TO postgres;

--
-- Name: vw_approvals_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_approvals_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN entity_subscriptions ON ((vw_workflow_phases.approval_entity_id = entity_subscriptions.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
  WHERE ((approvals.forward_id IS NULL) AND (vw_workflow_phases.use_reporting = false))
UNION
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.return_level,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.phase_narrative,
    vw_workflow_phases.use_reporting,
    approvals.approval_id,
    approvals.org_id,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.completion_date,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.application_date,
    approvals.approve_status,
    approvals.action_date,
    approvals.approval_narrative,
    approvals.to_be_done,
    approvals.what_is_done,
    approvals.review_advice,
    approvals.details,
    oe.entity_id AS org_entity_id,
    oe.entity_name AS org_entity_name,
    oe.user_name AS org_user_name,
    oe.primary_email AS org_primary_email,
    entitys.entity_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.primary_email
   FROM ((((vw_workflow_phases
     JOIN approvals ON ((vw_workflow_phases.workflow_phase_id = approvals.workflow_phase_id)))
     JOIN entitys oe ON ((approvals.org_entity_id = oe.entity_id)))
     JOIN reporting ON (((approvals.org_entity_id = reporting.entity_id) AND (vw_workflow_phases.reporting_level = reporting.reporting_level))))
     JOIN entitys ON ((reporting.report_to_id = entitys.entity_id)))
  WHERE ((((approvals.forward_id IS NULL) AND (reporting.primary_report = true)) AND (reporting.is_active = true)) AND (vw_workflow_phases.use_reporting = true));


ALTER TABLE public.vw_approvals_entitys OWNER TO postgres;

--
-- Name: vw_bank_branch; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_bank_branch AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_code,
    sys_countrys.sys_country_name,
    banks.bank_id,
    banks.bank_name,
    banks.bank_code,
    banks.swift_code,
    banks.sort_code,
    bank_branch.bank_branch_id,
    bank_branch.org_id,
    bank_branch.bank_branch_name,
    bank_branch.bank_branch_code,
    bank_branch.narrative,
    (((banks.bank_name)::text || ', '::text) || (bank_branch.bank_branch_name)::text) AS bank_branch_disp
   FROM ((bank_branch
     JOIN banks ON ((bank_branch.bank_id = banks.bank_id)))
     LEFT JOIN sys_countrys ON ((banks.sys_country_id = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_bank_branch OWNER TO postgres;

--
-- Name: vw_bank_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_bank_accounts AS
 SELECT vw_bank_branch.bank_id,
    vw_bank_branch.bank_name,
    vw_bank_branch.bank_branch_id,
    vw_bank_branch.bank_branch_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    bank_accounts.bank_account_id,
    bank_accounts.org_id,
    bank_accounts.bank_account_name,
    bank_accounts.bank_account_number,
    bank_accounts.narrative,
    bank_accounts.is_active,
    bank_accounts.details
   FROM (((bank_accounts
     JOIN vw_bank_branch ON ((bank_accounts.bank_branch_id = vw_bank_branch.bank_branch_id)))
     JOIN vw_accounts ON ((bank_accounts.account_id = vw_accounts.account_id)))
     JOIN currency ON ((bank_accounts.currency_id = currency.currency_id)));


ALTER TABLE public.vw_bank_accounts OWNER TO postgres;

--
-- Name: vw_tenders; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tenders AS
 SELECT tender_types.tender_type_id,
    tender_types.tender_type_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    tenders.org_id,
    tenders.tender_id,
    tenders.tender_name,
    tenders.tender_number,
    tenders.tender_date,
    tenders.tender_end_date,
    tenders.is_completed,
    tenders.details
   FROM ((tenders
     JOIN tender_types ON ((tenders.tender_type_id = tender_types.tender_type_id)))
     JOIN currency ON ((tenders.currency_id = currency.currency_id)));


ALTER TABLE public.vw_tenders OWNER TO postgres;

--
-- Name: vw_bidders; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_bidders AS
 SELECT vw_tenders.tender_type_id,
    vw_tenders.tender_type_name,
    vw_tenders.tender_id,
    vw_tenders.tender_name,
    vw_tenders.tender_number,
    vw_tenders.tender_date,
    vw_tenders.tender_end_date,
    vw_tenders.is_completed,
    entitys.entity_id,
    entitys.entity_name,
    bidders.org_id,
    bidders.bidder_id,
    bidders.tender_amount,
    bidders.bind_bond,
    bidders.bind_bond_amount,
    bidders.return_date,
    bidders.points,
    bidders.is_awarded,
    bidders.award_reference,
    bidders.details
   FROM ((bidders
     JOIN vw_tenders ON ((bidders.tender_id = vw_tenders.tender_id)))
     JOIN entitys ON ((bidders.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_bidders OWNER TO postgres;

--
-- Name: vw_budgets; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budgets AS
 SELECT departments.department_id,
    departments.department_name,
    fiscal_years.fiscal_year_id,
    fiscal_years.fiscal_year_start,
    fiscal_years.fiscal_year,
    fiscal_years.fiscal_year_end,
    fiscal_years.year_opened,
    fiscal_years.year_closed,
    budgets.budget_id,
    budgets.org_id,
    budgets.budget_type,
    budgets.budget_name,
    budgets.application_date,
    budgets.approve_status,
    budgets.workflow_table_id,
    budgets.action_date,
    budgets.details
   FROM ((budgets
     JOIN departments ON ((budgets.department_id = departments.department_id)))
     JOIN fiscal_years ON ((budgets.fiscal_year_id = fiscal_years.fiscal_year_id)));


ALTER TABLE public.vw_budgets OWNER TO postgres;

--
-- Name: vw_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_items AS
 SELECT sales_account.account_id AS sales_account_id,
    sales_account.account_name AS sales_account_name,
    purchase_account.account_id AS purchase_account_id,
    purchase_account.account_name AS purchase_account_name,
    item_category.item_category_id,
    item_category.item_category_name,
    item_units.item_unit_id,
    item_units.item_unit_name,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.account_id AS tax_account_id,
    tax_types.tax_rate,
    tax_types.tax_inclusive,
    items.item_id,
    items.org_id,
    items.item_name,
    items.bar_code,
    items.for_sale,
    items.for_purchase,
    items.for_stock,
    items.inventory,
    items.sales_price,
    items.purchase_price,
    items.reorder_level,
    items.lead_time,
    items.is_active,
    items.details
   FROM (((((items
     JOIN accounts sales_account ON ((items.sales_account_id = sales_account.account_id)))
     JOIN accounts purchase_account ON ((items.purchase_account_id = purchase_account.account_id)))
     JOIN item_category ON ((items.item_category_id = item_category.item_category_id)))
     JOIN item_units ON ((items.item_unit_id = item_units.item_unit_id)))
     JOIN tax_types ON ((items.tax_type_id = tax_types.tax_type_id)));


ALTER TABLE public.vw_items OWNER TO postgres;

--
-- Name: vw_budget_lines; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_lines AS
 SELECT vw_budgets.department_id,
    vw_budgets.department_name,
    vw_budgets.fiscal_year_id,
    vw_budgets.fiscal_year,
    vw_budgets.fiscal_year_start,
    vw_budgets.fiscal_year_end,
    vw_budgets.year_opened,
    vw_budgets.year_closed,
    vw_budgets.budget_id,
    vw_budgets.budget_name,
    vw_budgets.budget_type,
    vw_budgets.approve_status,
    periods.period_id,
    periods.start_date,
    periods.end_date,
    periods.opened,
    periods.activated,
    periods.closed,
    periods.overtime_rate,
    periods.per_diem_tax_limit,
    periods.is_posted,
    date_part('month'::text, periods.start_date) AS month_id,
    to_char((periods.start_date)::timestamp with time zone, 'YYYY'::text) AS period_year,
    to_char((periods.start_date)::timestamp with time zone, 'Month'::text) AS period_month,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (3)::double precision)) + (1)::double precision) AS quarter,
    (trunc(((date_part('month'::text, periods.start_date) - (1)::double precision) / (6)::double precision)) + (1)::double precision) AS semister,
    vw_accounts.account_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.account_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    vw_items.item_id,
    vw_items.item_name,
    vw_items.tax_type_id,
    vw_items.tax_account_id,
    vw_items.tax_type_name,
    vw_items.tax_rate,
    vw_items.tax_inclusive,
    vw_items.sales_account_id,
    vw_items.purchase_account_id,
    budget_lines.budget_line_id,
    budget_lines.org_id,
    budget_lines.transaction_id,
    budget_lines.spend_type,
    budget_lines.quantity,
    budget_lines.amount,
    budget_lines.tax_amount,
    budget_lines.narrative,
    budget_lines.details,
        CASE
            WHEN (budget_lines.spend_type = 1) THEN 'Monthly'::text
            WHEN (budget_lines.spend_type = 2) THEN 'Quaterly'::text
            ELSE 'Once'::text
        END AS spend_type_name,
    budget_lines.income_budget,
        CASE
            WHEN (budget_lines.income_budget = true) THEN 'Income Budget'::text
            ELSE 'Expenditure Budget'::text
        END AS income_expense,
        CASE
            WHEN (budget_lines.income_budget = true) THEN budget_lines.amount
            ELSE (0)::real
        END AS dr_budget,
        CASE
            WHEN (budget_lines.income_budget = false) THEN budget_lines.amount
            ELSE (0)::real
        END AS cr_budget
   FROM ((((budget_lines
     JOIN vw_budgets ON ((budget_lines.budget_id = vw_budgets.budget_id)))
     JOIN periods ON ((budget_lines.period_id = periods.period_id)))
     JOIN vw_accounts ON ((budget_lines.account_id = vw_accounts.account_id)))
     LEFT JOIN vw_items ON ((budget_lines.item_id = vw_items.item_id)));


ALTER TABLE public.vw_budget_lines OWNER TO postgres;

--
-- Name: vw_budget_ads; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_ads AS
 SELECT vw_budget_lines.department_id,
    vw_budget_lines.department_name,
    vw_budget_lines.fiscal_year_id,
    vw_budget_lines.fiscal_year,
    vw_budget_lines.fiscal_year_start,
    vw_budget_lines.fiscal_year_end,
    vw_budget_lines.year_opened,
    vw_budget_lines.year_closed,
    vw_budget_lines.budget_type,
    vw_budget_lines.account_class_id,
    vw_budget_lines.chat_type_id,
    vw_budget_lines.chat_type_name,
    vw_budget_lines.account_class_name,
    vw_budget_lines.account_type_id,
    vw_budget_lines.account_type_name,
    vw_budget_lines.account_id,
    vw_budget_lines.account_name,
    vw_budget_lines.is_header,
    vw_budget_lines.is_active,
    vw_budget_lines.item_id,
    vw_budget_lines.item_name,
    vw_budget_lines.tax_type_id,
    vw_budget_lines.tax_account_id,
    vw_budget_lines.org_id,
    vw_budget_lines.spend_type,
    vw_budget_lines.spend_type_name,
    vw_budget_lines.income_budget,
    vw_budget_lines.income_expense,
    sum(vw_budget_lines.quantity) AS s_quantity,
    sum(vw_budget_lines.amount) AS s_amount,
    sum(vw_budget_lines.tax_amount) AS s_tax_amount,
    sum(vw_budget_lines.dr_budget) AS s_dr_budget,
    sum(vw_budget_lines.cr_budget) AS s_cr_budget,
    sum((vw_budget_lines.dr_budget - vw_budget_lines.cr_budget)) AS budget_diff
   FROM vw_budget_lines
  WHERE ((vw_budget_lines.approve_status)::text = 'Approved'::text)
  GROUP BY vw_budget_lines.department_id, vw_budget_lines.department_name, vw_budget_lines.fiscal_year_id, vw_budget_lines.fiscal_year, vw_budget_lines.fiscal_year_start, vw_budget_lines.fiscal_year_end, vw_budget_lines.year_opened, vw_budget_lines.year_closed, vw_budget_lines.budget_type, vw_budget_lines.account_class_id, vw_budget_lines.chat_type_id, vw_budget_lines.chat_type_name, vw_budget_lines.account_class_name, vw_budget_lines.account_type_id, vw_budget_lines.account_type_name, vw_budget_lines.account_id, vw_budget_lines.account_name, vw_budget_lines.is_header, vw_budget_lines.is_active, vw_budget_lines.item_id, vw_budget_lines.item_name, vw_budget_lines.tax_type_id, vw_budget_lines.tax_account_id, vw_budget_lines.org_id, vw_budget_lines.spend_type, vw_budget_lines.spend_type_name, vw_budget_lines.income_budget, vw_budget_lines.income_expense;


ALTER TABLE public.vw_budget_ads OWNER TO postgres;

--
-- Name: vw_budget_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_ledger AS
 SELECT journals.org_id,
    periods.fiscal_year_id,
    journals.department_id,
    accounts.account_id,
    accounts.account_no,
    accounts.account_type_id,
    accounts.account_name,
    sum((journals.exchange_rate * gls.debit)) AS bl_debit,
    sum((journals.exchange_rate * gls.credit)) AS bl_credit,
    sum((journals.exchange_rate * (gls.debit - gls.credit))) AS bl_diff
   FROM (((journals
     JOIN gls ON ((journals.journal_id = gls.journal_id)))
     JOIN accounts ON ((gls.account_id = accounts.account_id)))
     JOIN periods ON ((journals.period_id = periods.period_id)))
  WHERE (journals.posted = true)
  GROUP BY journals.org_id, periods.fiscal_year_id, journals.department_id, accounts.account_id, accounts.account_no, accounts.account_type_id, accounts.account_name;


ALTER TABLE public.vw_budget_ledger OWNER TO postgres;

--
-- Name: vw_budget_pdc; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_pdc AS
 SELECT vw_budget_ads.department_id,
    vw_budget_ads.department_name,
    vw_budget_ads.fiscal_year_id,
    vw_budget_ads.fiscal_year,
    vw_budget_ads.fiscal_year_start,
    vw_budget_ads.fiscal_year_end,
    vw_budget_ads.year_opened,
    vw_budget_ads.year_closed,
    vw_budget_ads.budget_type,
    vw_budget_ads.account_class_id,
    vw_budget_ads.chat_type_id,
    vw_budget_ads.chat_type_name,
    vw_budget_ads.account_class_name,
    vw_budget_ads.account_type_id,
    vw_budget_ads.account_type_name,
    vw_budget_ads.account_id,
    vw_budget_ads.account_name,
    vw_budget_ads.is_header,
    vw_budget_ads.is_active,
    vw_budget_ads.item_id,
    vw_budget_ads.item_name,
    vw_budget_ads.tax_type_id,
    vw_budget_ads.tax_account_id,
    vw_budget_ads.org_id,
    vw_budget_ads.spend_type,
    vw_budget_ads.spend_type_name,
    vw_budget_ads.income_budget,
    vw_budget_ads.income_expense,
    vw_budget_ads.s_quantity,
    vw_budget_ads.s_amount,
    vw_budget_ads.s_tax_amount,
    vw_budget_ads.s_dr_budget,
    vw_budget_ads.s_cr_budget,
    vw_budget_ledger.bl_debit,
    vw_budget_ledger.bl_credit,
        CASE
            WHEN (vw_budget_ads.income_budget = true) THEN COALESCE((((-1))::double precision * vw_budget_ledger.bl_diff), (0)::double precision)
            ELSE (COALESCE(vw_budget_ledger.bl_diff, (0)::real))::double precision
        END AS amount_used,
        CASE
            WHEN (vw_budget_ads.income_budget = true) THEN (vw_budget_ads.s_amount + COALESCE(vw_budget_ledger.bl_diff, (0)::real))
            ELSE (vw_budget_ads.s_amount - COALESCE(vw_budget_ledger.bl_diff, (0)::real))
        END AS budget_balance
   FROM (vw_budget_ads
     LEFT JOIN vw_budget_ledger ON ((((vw_budget_ads.department_id = vw_budget_ledger.department_id) AND (vw_budget_ads.account_id = vw_budget_ledger.account_id)) AND (vw_budget_ads.fiscal_year_id = vw_budget_ledger.fiscal_year_id))));


ALTER TABLE public.vw_budget_pdc OWNER TO postgres;

--
-- Name: vw_budget_pds; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_budget_pds AS
 SELECT vw_budget_lines.department_id,
    vw_budget_lines.department_name,
    vw_budget_lines.fiscal_year_id,
    vw_budget_lines.fiscal_year,
    vw_budget_lines.fiscal_year_start,
    vw_budget_lines.fiscal_year_end,
    vw_budget_lines.year_opened,
    vw_budget_lines.year_closed,
    vw_budget_lines.period_id,
    vw_budget_lines.start_date,
    vw_budget_lines.end_date,
    vw_budget_lines.opened,
    vw_budget_lines.closed,
    vw_budget_lines.month_id,
    vw_budget_lines.period_year,
    vw_budget_lines.period_month,
    vw_budget_lines.quarter,
    vw_budget_lines.semister,
    vw_budget_lines.budget_type,
    vw_budget_lines.account_class_id,
    vw_budget_lines.chat_type_id,
    vw_budget_lines.chat_type_name,
    vw_budget_lines.account_class_name,
    vw_budget_lines.account_type_id,
    vw_budget_lines.account_type_name,
    vw_budget_lines.account_id,
    vw_budget_lines.account_name,
    vw_budget_lines.is_header,
    vw_budget_lines.is_active,
    vw_budget_lines.item_id,
    vw_budget_lines.item_name,
    vw_budget_lines.tax_type_id,
    vw_budget_lines.tax_account_id,
    vw_budget_lines.tax_type_name,
    vw_budget_lines.tax_rate,
    vw_budget_lines.tax_inclusive,
    vw_budget_lines.sales_account_id,
    vw_budget_lines.purchase_account_id,
    vw_budget_lines.budget_line_id,
    vw_budget_lines.org_id,
    vw_budget_lines.transaction_id,
    vw_budget_lines.spend_type,
    vw_budget_lines.spend_type_name,
    vw_budget_lines.income_budget,
    vw_budget_lines.income_expense,
    sum(vw_budget_lines.quantity) AS s_quantity,
    sum(vw_budget_lines.amount) AS s_amount,
    sum(vw_budget_lines.tax_amount) AS s_tax_amount,
    sum(vw_budget_lines.dr_budget) AS s_dr_budget,
    sum(vw_budget_lines.cr_budget) AS s_cr_budget,
    sum((vw_budget_lines.dr_budget - vw_budget_lines.cr_budget)) AS budget_diff
   FROM vw_budget_lines
  WHERE ((vw_budget_lines.approve_status)::text = 'Approved'::text)
  GROUP BY vw_budget_lines.department_id, vw_budget_lines.department_name, vw_budget_lines.fiscal_year_id, vw_budget_lines.fiscal_year, vw_budget_lines.fiscal_year_start, vw_budget_lines.fiscal_year_end, vw_budget_lines.year_opened, vw_budget_lines.year_closed, vw_budget_lines.period_id, vw_budget_lines.start_date, vw_budget_lines.end_date, vw_budget_lines.opened, vw_budget_lines.closed, vw_budget_lines.month_id, vw_budget_lines.period_year, vw_budget_lines.period_month, vw_budget_lines.quarter, vw_budget_lines.semister, vw_budget_lines.budget_type, vw_budget_lines.account_class_id, vw_budget_lines.chat_type_id, vw_budget_lines.chat_type_name, vw_budget_lines.account_class_name, vw_budget_lines.account_type_id, vw_budget_lines.account_type_name, vw_budget_lines.account_id, vw_budget_lines.account_name, vw_budget_lines.is_header, vw_budget_lines.is_active, vw_budget_lines.item_id, vw_budget_lines.item_name, vw_budget_lines.tax_type_id, vw_budget_lines.tax_account_id, vw_budget_lines.tax_type_name, vw_budget_lines.tax_rate, vw_budget_lines.tax_inclusive, vw_budget_lines.sales_account_id, vw_budget_lines.purchase_account_id, vw_budget_lines.budget_line_id, vw_budget_lines.org_id, vw_budget_lines.transaction_id, vw_budget_lines.spend_type, vw_budget_lines.spend_type_name, vw_budget_lines.income_budget, vw_budget_lines.income_expense;


ALTER TABLE public.vw_budget_pds OWNER TO postgres;

--
-- Name: vw_loan_balance; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_balance AS
 SELECT cb.loan_id,
    cb.loan_balance,
    COALESCE(ab.a_balance, (0)::real) AS actual_balance,
    COALESCE(li.l_intrest, (0)::real) AS loan_intrest,
    COALESCE(lp.l_penalty, (0)::real) AS loan_penalty
   FROM (((( SELECT account_activity.loan_id,
            sum(((account_activity.account_debit - account_activity.account_credit) * account_activity.exchange_rate)) AS loan_balance
           FROM account_activity
          GROUP BY account_activity.loan_id) cb
     LEFT JOIN ( SELECT account_activity.loan_id,
            sum(((account_activity.account_debit - account_activity.account_credit) * account_activity.exchange_rate)) AS a_balance
           FROM account_activity
          WHERE (account_activity.activity_status_id < 3)
          GROUP BY account_activity.loan_id) ab ON ((cb.loan_id = ab.loan_id)))
     LEFT JOIN ( SELECT account_activity.loan_id,
            sum(((account_activity.account_debit - account_activity.account_credit) * account_activity.exchange_rate)) AS l_intrest
           FROM (account_activity
             JOIN activity_types ON ((account_activity.activity_type_id = activity_types.activity_type_id)))
          WHERE (activity_types.use_key_id = 105)
          GROUP BY account_activity.loan_id) li ON ((cb.loan_id = li.loan_id)))
     LEFT JOIN ( SELECT account_activity.loan_id,
            sum(((account_activity.account_debit - account_activity.account_credit) * account_activity.exchange_rate)) AS l_penalty
           FROM (account_activity
             JOIN activity_types ON ((account_activity.activity_type_id = activity_types.activity_type_id)))
          WHERE (activity_types.use_key_id = 106)
          GROUP BY account_activity.loan_id) lp ON ((cb.loan_id = lp.loan_id)));


ALTER TABLE public.vw_loan_balance OWNER TO postgres;

--
-- Name: vw_loans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loans AS
 SELECT customers.customer_id,
    customers.customer_name,
    customers.business_account,
    vw_products.product_id,
    vw_products.product_name,
    vw_products.currency_id,
    vw_products.currency_name,
    vw_products.currency_symbol,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    loans.org_id,
    loans.loan_id,
    loans.account_number,
    loans.principal_amount,
    loans.interest_rate,
    loans.repayment_amount,
    loans.disbursed_date,
    loans.expected_matured_date,
    loans.matured_date,
    loans.repayment_period,
    loans.expected_repayment,
    loans.disburse_account,
    loans.application_date,
    loans.approve_status,
    loans.workflow_table_id,
    loans.action_date,
    loans.details,
    vw_loan_balance.loan_balance,
    vw_loan_balance.actual_balance,
    (vw_loan_balance.actual_balance - vw_loan_balance.loan_balance) AS committed_balance
   FROM ((((loans
     JOIN customers ON ((loans.customer_id = customers.customer_id)))
     JOIN vw_products ON ((loans.product_id = vw_products.product_id)))
     JOIN activity_frequency ON ((loans.activity_frequency_id = activity_frequency.activity_frequency_id)))
     LEFT JOIN vw_loan_balance ON ((loans.loan_id = vw_loan_balance.loan_id)));


ALTER TABLE public.vw_loans OWNER TO postgres;

--
-- Name: vw_collaterals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_collaterals AS
 SELECT vw_loans.customer_id,
    vw_loans.customer_name,
    vw_loans.product_id,
    vw_loans.product_name,
    vw_loans.loan_id,
    vw_loans.principal_amount,
    vw_loans.interest_rate,
    vw_loans.activity_frequency_id,
    vw_loans.activity_frequency_name,
    vw_loans.disbursed_date,
    vw_loans.expected_matured_date,
    vw_loans.matured_date,
    collateral_types.collateral_type_id,
    collateral_types.collateral_type_name,
    collaterals.org_id,
    collaterals.collateral_id,
    collaterals.collateral_amount,
    collaterals.collateral_received,
    collaterals.collateral_released,
    collaterals.application_date,
    collaterals.approve_status,
    collaterals.workflow_table_id,
    collaterals.action_date,
    collaterals.details
   FROM ((collaterals
     JOIN vw_loans ON ((collaterals.loan_id = vw_loans.loan_id)))
     JOIN collateral_types ON ((collaterals.collateral_type_id = collateral_types.collateral_type_id)));


ALTER TABLE public.vw_collaterals OWNER TO postgres;

--
-- Name: vw_contracts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_contracts AS
 SELECT vw_bidders.tender_type_id,
    vw_bidders.tender_type_name,
    vw_bidders.tender_id,
    vw_bidders.tender_name,
    vw_bidders.tender_number,
    vw_bidders.tender_date,
    vw_bidders.tender_end_date,
    vw_bidders.is_completed,
    vw_bidders.entity_id,
    vw_bidders.entity_name,
    vw_bidders.bidder_id,
    vw_bidders.tender_amount,
    vw_bidders.bind_bond,
    vw_bidders.bind_bond_amount,
    vw_bidders.return_date,
    vw_bidders.points,
    vw_bidders.is_awarded,
    vw_bidders.award_reference,
    contracts.org_id,
    contracts.contract_id,
    contracts.contract_name,
    contracts.contract_date,
    contracts.contract_end,
    contracts.contract_amount,
    contracts.contract_tax,
    contracts.details
   FROM (contracts
     JOIN vw_bidders ON ((contracts.bidder_id = vw_bidders.bidder_id)));


ALTER TABLE public.vw_contracts OWNER TO postgres;

--
-- Name: vw_curr_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_curr_orgs AS
 SELECT currency.currency_id AS base_currency_id,
    currency.currency_name AS base_currency_name,
    currency.currency_symbol AS base_currency_symbol,
    orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.cert_number,
    orgs.pin,
    orgs.vat_number,
    orgs.invoice_footer,
    orgs.details
   FROM (orgs
     JOIN currency ON ((orgs.currency_id = currency.currency_id)));


ALTER TABLE public.vw_curr_orgs OWNER TO postgres;

--
-- Name: vw_default_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_default_accounts AS
 SELECT vw_accounts.account_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.account_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    default_accounts.default_account_id,
    default_accounts.org_id,
    default_accounts.narrative
   FROM ((vw_accounts
     JOIN default_accounts ON ((vw_accounts.account_id = default_accounts.account_id)))
     JOIN use_keys ON ((default_accounts.use_key_id = use_keys.use_key_id)));


ALTER TABLE public.vw_default_accounts OWNER TO postgres;

--
-- Name: vw_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tax_types AS
 SELECT vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    tax_types.org_id,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.formural,
    tax_types.tax_relief,
    tax_types.tax_type_order,
    tax_types.in_tax,
    tax_types.tax_rate,
    tax_types.tax_inclusive,
    tax_types.linear,
    tax_types.percentage,
    tax_types.employer,
    tax_types.employer_ps,
    tax_types.account_number,
    tax_types.employer_account,
    tax_types.active,
    tax_types.tax_type_number,
    tax_types.employer_formural,
    tax_types.employer_relief,
    tax_types.details
   FROM (((tax_types
     JOIN currency ON ((tax_types.currency_id = currency.currency_id)))
     JOIN use_keys ON ((tax_types.use_key_id = use_keys.use_key_id)))
     LEFT JOIN vw_accounts ON ((tax_types.account_id = vw_accounts.account_id)));


ALTER TABLE public.vw_tax_types OWNER TO postgres;

--
-- Name: vw_default_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_default_tax_types AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    vw_tax_types.tax_type_id,
    vw_tax_types.tax_type_name,
    vw_tax_types.tax_type_number,
    vw_tax_types.currency_id,
    vw_tax_types.currency_name,
    vw_tax_types.currency_symbol,
    default_tax_types.default_tax_type_id,
    default_tax_types.org_id,
    default_tax_types.tax_identification,
    default_tax_types.active,
    default_tax_types.narrative
   FROM ((default_tax_types
     JOIN entitys ON ((default_tax_types.entity_id = entitys.entity_id)))
     JOIN vw_tax_types ON ((default_tax_types.tax_type_id = vw_tax_types.tax_type_id)));


ALTER TABLE public.vw_default_tax_types OWNER TO postgres;

--
-- Name: vw_departments; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_departments AS
 SELECT departments.ln_department_id,
    p_departments.department_name AS ln_department_name,
    departments.department_id,
    departments.org_id,
    departments.department_name,
    departments.active,
    departments.function_code,
    departments.petty_cash,
    departments.cost_center,
    departments.revenue_center,
    departments.description,
    departments.duties,
    departments.reports,
    departments.details
   FROM (departments
     LEFT JOIN departments p_departments ON ((departments.ln_department_id = p_departments.department_id)));


ALTER TABLE public.vw_departments OWNER TO postgres;

--
-- Name: vw_e_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_e_fields AS
 SELECT orgs.org_id,
    orgs.org_name,
    et_fields.et_field_id,
    et_fields.et_field_name,
    et_fields.table_name,
    et_fields.table_link,
    e_fields.e_field_id,
    e_fields.table_code,
    e_fields.table_id,
    e_fields.e_field_value
   FROM ((e_fields
     JOIN orgs ON ((e_fields.org_id = orgs.org_id)))
     JOIN et_fields ON ((e_fields.et_field_id = et_fields.et_field_id)));


ALTER TABLE public.vw_e_fields OWNER TO postgres;

--
-- Name: vw_entity_accounts; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_accounts AS
 SELECT vw_deposit_accounts.customer_id,
    vw_deposit_accounts.customer_name,
    vw_deposit_accounts.business_account,
    vw_deposit_accounts.product_id,
    vw_deposit_accounts.product_name,
    vw_deposit_accounts.currency_id,
    vw_deposit_accounts.currency_name,
    vw_deposit_accounts.currency_symbol,
    vw_deposit_accounts.activity_frequency_id,
    vw_deposit_accounts.activity_frequency_name,
    vw_deposit_accounts.org_id,
    vw_deposit_accounts.deposit_account_id,
    vw_deposit_accounts.is_active,
    vw_deposit_accounts.account_number,
    vw_deposit_accounts.narrative,
    vw_deposit_accounts.last_closing_date,
    vw_deposit_accounts.credit_limit,
    vw_deposit_accounts.minimum_balance,
    vw_deposit_accounts.maximum_balance,
    vw_deposit_accounts.interest_rate,
    vw_deposit_accounts.lockin_period_frequency,
    vw_deposit_accounts.opening_date,
    vw_deposit_accounts.lockedin_until_date,
    vw_deposit_accounts.application_date,
    vw_deposit_accounts.approve_status,
    vw_deposit_accounts.workflow_table_id,
    vw_deposit_accounts.action_date,
    vw_deposit_accounts.details,
    vw_deposit_accounts.current_balance,
    vw_deposit_accounts.cleared_balance,
    vw_deposit_accounts.unprocessed_credit,
    vw_deposit_accounts.available_balance,
    entitys.entity_id,
    entitys.user_name,
    entitys.entity_name,
    (((((((vw_deposit_accounts.product_name)::text || ', '::text) || (vw_deposit_accounts.account_number)::text) || ', '::text) || (vw_deposit_accounts.currency_symbol)::text) || ', '::text) || btrim(to_char(COALESCE(vw_deposit_accounts.available_balance, (0)::real), '999,999,999,999'::text))) AS deposit_account_disp
   FROM (vw_deposit_accounts
     JOIN entitys ON ((vw_deposit_accounts.customer_id = entitys.customer_id)));


ALTER TABLE public.vw_entity_accounts OWNER TO postgres;

--
-- Name: vw_entity_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_address AS
 SELECT vw_address.address_id,
    vw_address.address_name,
    vw_address.sys_country_id,
    vw_address.sys_country_name,
    vw_address.table_id,
    vw_address.table_name,
    vw_address.is_default,
    vw_address.post_office_box,
    vw_address.postal_code,
    vw_address.premises,
    vw_address.street,
    vw_address.town,
    vw_address.phone_number,
    vw_address.extension,
    vw_address.mobile,
    vw_address.fax,
    vw_address.email,
    vw_address.website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'entitys'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_entity_address OWNER TO postgres;

--
-- Name: vw_entity_loans; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_loans AS
 SELECT vw_loans.customer_id,
    vw_loans.customer_name,
    vw_loans.business_account,
    vw_loans.product_id,
    vw_loans.product_name,
    vw_loans.currency_id,
    vw_loans.currency_name,
    vw_loans.currency_symbol,
    vw_loans.activity_frequency_id,
    vw_loans.activity_frequency_name,
    vw_loans.org_id,
    vw_loans.loan_id,
    vw_loans.account_number,
    vw_loans.principal_amount,
    vw_loans.interest_rate,
    vw_loans.repayment_amount,
    vw_loans.disbursed_date,
    vw_loans.expected_matured_date,
    vw_loans.matured_date,
    vw_loans.repayment_period,
    vw_loans.expected_repayment,
    vw_loans.disburse_account,
    vw_loans.application_date,
    vw_loans.approve_status,
    vw_loans.workflow_table_id,
    vw_loans.action_date,
    vw_loans.details,
    vw_loans.loan_balance,
    vw_loans.actual_balance,
    vw_loans.committed_balance,
    entitys.entity_id,
    entitys.user_name,
    entitys.entity_name
   FROM (vw_loans
     JOIN entitys ON ((vw_loans.customer_id = entitys.customer_id)));


ALTER TABLE public.vw_entity_loans OWNER TO postgres;

--
-- Name: vw_entity_subscriptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_subscriptions AS
 SELECT entity_types.entity_type_id,
    entity_types.entity_type_name,
    entitys.entity_id,
    entitys.entity_name,
    subscription_levels.subscription_level_id,
    subscription_levels.subscription_level_name,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.org_id,
    entity_subscriptions.details
   FROM (((entity_subscriptions
     JOIN entity_types ON ((entity_subscriptions.entity_type_id = entity_types.entity_type_id)))
     JOIN entitys ON ((entity_subscriptions.entity_id = entitys.entity_id)))
     JOIN subscription_levels ON ((entity_subscriptions.subscription_level_id = subscription_levels.subscription_level_id)));


ALTER TABLE public.vw_entity_subscriptions OWNER TO postgres;

--
-- Name: vw_entity_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_types AS
 SELECT use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    entity_types.entity_type_id,
    entity_types.org_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entity_types.start_view,
    entity_types.group_email,
    entity_types.description,
    entity_types.details
   FROM (use_keys
     JOIN entity_types ON ((use_keys.use_key_id = entity_types.use_key_id)));


ALTER TABLE public.vw_entity_types OWNER TO postgres;

--
-- Name: vw_entity_values; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entity_values AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    entity_fields.entity_field_id,
    entity_fields.entity_field_name,
    entity_values.org_id,
    entity_values.entity_value_id,
    entity_values.entity_value
   FROM ((entity_values
     JOIN entitys ON ((entity_values.entity_id = entitys.entity_id)))
     JOIN entity_fields ON ((entity_values.entity_field_id = entity_fields.entity_field_id)));


ALTER TABLE public.vw_entity_values OWNER TO postgres;

--
-- Name: vw_org_address; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_address AS
 SELECT vw_address.sys_country_id AS org_sys_country_id,
    vw_address.sys_country_name AS org_sys_country_name,
    vw_address.address_id AS org_address_id,
    vw_address.table_id AS org_table_id,
    vw_address.table_name AS org_table_name,
    vw_address.post_office_box AS org_post_office_box,
    vw_address.postal_code AS org_postal_code,
    vw_address.premises AS org_premises,
    vw_address.street AS org_street,
    vw_address.town AS org_town,
    vw_address.phone_number AS org_phone_number,
    vw_address.extension AS org_extension,
    vw_address.mobile AS org_mobile,
    vw_address.fax AS org_fax,
    vw_address.email AS org_email,
    vw_address.website AS org_website
   FROM vw_address
  WHERE (((vw_address.table_name)::text = 'orgs'::text) AND (vw_address.is_default = true));


ALTER TABLE public.vw_org_address OWNER TO postgres;

--
-- Name: vw_orgs; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_orgs AS
 SELECT orgs.org_id,
    orgs.org_name,
    orgs.is_default,
    orgs.is_active,
    orgs.logo,
    orgs.org_full_name,
    orgs.pin,
    orgs.pcc,
    orgs.details,
    orgs.cert_number,
    orgs.vat_number,
    orgs.invoice_footer,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_org_address.org_sys_country_id,
    vw_org_address.org_sys_country_name,
    vw_org_address.org_address_id,
    vw_org_address.org_table_name,
    vw_org_address.org_post_office_box,
    vw_org_address.org_postal_code,
    vw_org_address.org_premises,
    vw_org_address.org_street,
    vw_org_address.org_town,
    vw_org_address.org_phone_number,
    vw_org_address.org_extension,
    vw_org_address.org_mobile,
    vw_org_address.org_fax,
    vw_org_address.org_email,
    vw_org_address.org_website
   FROM ((orgs
     JOIN currency ON ((orgs.currency_id = currency.currency_id)))
     LEFT JOIN vw_org_address ON ((orgs.org_id = vw_org_address.org_table_id)));


ALTER TABLE public.vw_orgs OWNER TO postgres;

--
-- Name: vw_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entitys AS
 SELECT vw_orgs.org_id,
    vw_orgs.org_name,
    vw_orgs.is_default AS org_is_default,
    vw_orgs.is_active AS org_is_active,
    vw_orgs.logo AS org_logo,
    vw_orgs.cert_number AS org_cert_number,
    vw_orgs.pin AS org_pin,
    vw_orgs.vat_number AS org_vat_number,
    vw_orgs.invoice_footer AS org_invoice_footer,
    vw_orgs.org_sys_country_id,
    vw_orgs.org_sys_country_name,
    vw_orgs.org_address_id,
    vw_orgs.org_table_name,
    vw_orgs.org_post_office_box,
    vw_orgs.org_postal_code,
    vw_orgs.org_premises,
    vw_orgs.org_street,
    vw_orgs.org_town,
    vw_orgs.org_phone_number,
    vw_orgs.org_extension,
    vw_orgs.org_mobile,
    vw_orgs.org_fax,
    vw_orgs.org_email,
    vw_orgs.org_website,
    addr.address_id,
    addr.address_name,
    addr.sys_country_id,
    addr.sys_country_name,
    addr.table_name,
    addr.is_default,
    addr.post_office_box,
    addr.postal_code,
    addr.premises,
    addr.street,
    addr.town,
    addr.phone_number,
    addr.extension,
    addr.mobile,
    addr.fax,
    addr.email,
    addr.website,
    entity_types.entity_type_id,
    entity_types.entity_type_name,
    entity_types.entity_role,
    entitys.entity_id,
    entitys.use_key_id,
    entitys.entity_name,
    entitys.user_name,
    entitys.super_user,
    entitys.entity_leader,
    entitys.date_enroled,
    entitys.is_active,
    entitys.entity_password,
    entitys.first_password,
    entitys.function_role,
    entitys.attention,
    entitys.primary_email,
    entitys.primary_telephone,
    entitys.credit_limit
   FROM (((entitys
     LEFT JOIN vw_address_entitys addr ON ((entitys.entity_id = addr.table_id)))
     JOIN vw_orgs ON ((entitys.org_id = vw_orgs.org_id)))
     JOIN entity_types ON ((entitys.entity_type_id = entity_types.entity_type_id)));


ALTER TABLE public.vw_entitys OWNER TO postgres;

--
-- Name: vw_entry_forms; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_entry_forms AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    forms.form_id,
    forms.form_name,
    forms.form_number,
    forms.completed,
    forms.is_active,
    forms.use_key,
    entry_forms.org_id,
    entry_forms.entry_form_id,
    entry_forms.approve_status,
    entry_forms.application_date,
    entry_forms.completion_date,
    entry_forms.action_date,
    entry_forms.narrative,
    entry_forms.answer,
    entry_forms.workflow_table_id,
    entry_forms.details
   FROM ((entry_forms
     JOIN entitys ON ((entry_forms.entity_id = entitys.entity_id)))
     JOIN forms ON ((entry_forms.form_id = forms.form_id)));


ALTER TABLE public.vw_entry_forms OWNER TO postgres;

--
-- Name: vw_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_fields AS
 SELECT forms.form_id,
    forms.form_name,
    fields.field_id,
    fields.org_id,
    fields.question,
    fields.field_lookup,
    fields.field_type,
    fields.field_order,
    fields.share_line,
    fields.field_size,
    fields.field_fnct,
    fields.manditory,
    fields.field_bold,
    fields.field_italics
   FROM (fields
     JOIN forms ON ((fields.form_id = forms.form_id)));


ALTER TABLE public.vw_fields OWNER TO postgres;

--
-- Name: vw_leads; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_leads AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    industry.industry_id,
    industry.industry_name,
    sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    leads.org_id,
    leads.lead_id,
    leads.business_name,
    leads.business_address,
    leads.city,
    leads.state,
    leads.country_id,
    leads.number_of_employees,
    leads.telephone,
    leads.website,
    leads.primary_contact,
    leads.job_title,
    leads.primary_email,
    leads.prospect_level,
    leads.contact_date,
    leads.details
   FROM (((leads
     JOIN entitys ON ((leads.entity_id = entitys.entity_id)))
     JOIN industry ON ((leads.industry_id = industry.industry_id)))
     JOIN sys_countrys ON ((leads.country_id = sys_countrys.sys_country_id)));


ALTER TABLE public.vw_leads OWNER TO postgres;

--
-- Name: vw_lead_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_lead_items AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    items.item_id,
    items.item_name,
    vw_leads.industry_id,
    vw_leads.industry_name,
    vw_leads.sys_country_id,
    vw_leads.sys_country_name,
    vw_leads.lead_id,
    vw_leads.business_name,
    vw_leads.business_address,
    vw_leads.city,
    vw_leads.state,
    vw_leads.country_id,
    vw_leads.number_of_employees,
    vw_leads.telephone,
    vw_leads.website,
    vw_leads.primary_contact,
    vw_leads.job_title,
    vw_leads.primary_email,
    vw_leads.prospect_level,
    vw_leads.contact_date,
    lead_items.org_id,
    lead_items.lead_item_id,
    lead_items.pitch_date,
    lead_items.units,
    lead_items.price,
    lead_items.lead_level,
    lead_items.narrative,
    lead_items.details,
    ((lead_items.units)::double precision * lead_items.price) AS lead_value
   FROM (((lead_items
     JOIN vw_leads ON ((lead_items.lead_id = vw_leads.lead_id)))
     JOIN entitys ON ((lead_items.entity_id = entitys.entity_id)))
     JOIN items ON ((lead_items.item_id = items.item_id)));


ALTER TABLE public.vw_lead_items OWNER TO postgres;

--
-- Name: vw_follow_up; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_follow_up AS
 SELECT vw_lead_items.item_id,
    vw_lead_items.item_name,
    vw_lead_items.industry_id,
    vw_lead_items.industry_name,
    vw_lead_items.sys_country_id,
    vw_lead_items.sys_country_name,
    vw_lead_items.lead_id,
    vw_lead_items.business_name,
    vw_lead_items.business_address,
    vw_lead_items.city,
    vw_lead_items.state,
    vw_lead_items.country_id,
    vw_lead_items.number_of_employees,
    vw_lead_items.telephone,
    vw_lead_items.website,
    vw_lead_items.primary_contact,
    vw_lead_items.job_title,
    vw_lead_items.primary_email,
    vw_lead_items.prospect_level,
    vw_lead_items.contact_date,
    vw_lead_items.lead_item_id,
    vw_lead_items.pitch_date,
    vw_lead_items.units,
    vw_lead_items.price,
    vw_lead_items.lead_value,
    vw_lead_items.lead_level,
    entitys.entity_id,
    entitys.entity_name,
    follow_up.org_id,
    follow_up.follow_up_id,
    follow_up.create_time,
    follow_up.follow_date,
    follow_up.follow_time,
    follow_up.done,
    follow_up.narrative,
    follow_up.details
   FROM ((follow_up
     JOIN vw_lead_items ON ((follow_up.lead_item_id = vw_lead_items.lead_item_id)))
     JOIN entitys ON ((follow_up.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_follow_up OWNER TO postgres;

--
-- Name: vw_journals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_journals AS
 SELECT vw_periods.fiscal_year_id,
    vw_periods.fiscal_year_start,
    vw_periods.fiscal_year_end,
    vw_periods.year_opened,
    vw_periods.year_closed,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.opened,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    departments.department_id,
    departments.department_name,
    journals.journal_id,
    journals.org_id,
    journals.journal_date,
    journals.posted,
    journals.year_closing,
    journals.narrative,
    journals.exchange_rate,
    journals.details
   FROM (((journals
     JOIN vw_periods ON ((journals.period_id = vw_periods.period_id)))
     JOIN currency ON ((journals.currency_id = currency.currency_id)))
     LEFT JOIN departments ON ((journals.department_id = departments.department_id)));


ALTER TABLE public.vw_journals OWNER TO postgres;

--
-- Name: vw_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_gls AS
 SELECT vw_accounts.account_class_id,
    vw_accounts.account_class_no,
    vw_accounts.account_class_name,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_no,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    vw_journals.fiscal_year_id,
    vw_journals.fiscal_year_start,
    vw_journals.fiscal_year_end,
    vw_journals.year_opened,
    vw_journals.year_closed,
    vw_journals.period_id,
    vw_journals.start_date,
    vw_journals.end_date,
    vw_journals.opened,
    vw_journals.closed,
    vw_journals.month_id,
    vw_journals.period_year,
    vw_journals.period_month,
    vw_journals.quarter,
    vw_journals.semister,
    vw_journals.currency_id,
    vw_journals.currency_name,
    vw_journals.currency_symbol,
    vw_journals.exchange_rate,
    vw_journals.journal_id,
    vw_journals.journal_date,
    vw_journals.posted,
    vw_journals.year_closing,
    vw_journals.narrative,
    gls.gl_id,
    gls.org_id,
    gls.debit,
    gls.credit,
    gls.gl_narrative,
    (gls.debit * vw_journals.exchange_rate) AS base_debit,
    (gls.credit * vw_journals.exchange_rate) AS base_credit
   FROM ((gls
     JOIN vw_accounts ON ((gls.account_id = vw_accounts.account_id)))
     JOIN vw_journals ON ((gls.journal_id = vw_journals.journal_id)));


ALTER TABLE public.vw_gls OWNER TO postgres;

--
-- Name: vw_guarantees; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_guarantees AS
 SELECT vw_loans.customer_id,
    vw_loans.customer_name,
    vw_loans.product_id,
    vw_loans.product_name,
    vw_loans.loan_id,
    vw_loans.principal_amount,
    vw_loans.interest_rate,
    vw_loans.activity_frequency_id,
    vw_loans.activity_frequency_name,
    vw_loans.disbursed_date,
    vw_loans.expected_matured_date,
    vw_loans.matured_date,
    customers.customer_id AS guarantor_id,
    customers.customer_name AS guarantor_name,
    guarantees.org_id,
    guarantees.guarantee_id,
    guarantees.guarantee_amount,
    guarantees.guarantee_accepted,
    guarantees.accepted_date,
    guarantees.application_date,
    guarantees.approve_status,
    guarantees.workflow_table_id,
    guarantees.action_date,
    guarantees.details
   FROM ((guarantees
     JOIN vw_loans ON ((guarantees.loan_id = vw_loans.loan_id)))
     JOIN customers ON ((guarantees.customer_id = customers.customer_id)));


ALTER TABLE public.vw_guarantees OWNER TO postgres;

--
-- Name: vw_pdefinitions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pdefinitions AS
 SELECT ptypes.ptype_id,
    ptypes.ptype_name,
    pdefinitions.org_id,
    pdefinitions.pdefinition_id,
    pdefinitions.pdefinition_name,
    pdefinitions.description,
    pdefinitions.solution
   FROM (pdefinitions
     JOIN ptypes ON ((pdefinitions.ptype_id = ptypes.ptype_id)));


ALTER TABLE public.vw_pdefinitions OWNER TO postgres;

--
-- Name: vw_helpdesk; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_helpdesk AS
 SELECT vw_pdefinitions.ptype_id,
    vw_pdefinitions.ptype_name,
    vw_pdefinitions.pdefinition_id,
    vw_pdefinitions.pdefinition_name,
    plevels.plevel_id,
    plevels.plevel_name,
    helpdesk.client_id,
    clients.entity_name AS client_name,
    helpdesk.recorded_by,
    recorder.entity_name AS recorder_name,
    helpdesk.closed_by,
    closer.entity_name AS closer_name,
    helpdesk.org_id,
    helpdesk.helpdesk_id,
    helpdesk.description,
    helpdesk.reported_by,
    helpdesk.recoded_time,
    helpdesk.solved_time,
    helpdesk.is_solved,
    helpdesk.curr_action,
    helpdesk.curr_status,
    helpdesk.problem,
    helpdesk.solution
   FROM (((((helpdesk
     JOIN vw_pdefinitions ON ((helpdesk.pdefinition_id = vw_pdefinitions.pdefinition_id)))
     JOIN plevels ON ((helpdesk.plevel_id = plevels.plevel_id)))
     JOIN entitys clients ON ((helpdesk.client_id = clients.entity_id)))
     JOIN entitys recorder ON ((helpdesk.recorded_by = recorder.entity_id)))
     LEFT JOIN entitys closer ON ((helpdesk.closed_by = closer.entity_id)));


ALTER TABLE public.vw_helpdesk OWNER TO postgres;

--
-- Name: vw_sm_gls; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sm_gls AS
 SELECT vw_gls.org_id,
    vw_gls.account_class_id,
    vw_gls.account_class_no,
    vw_gls.account_class_name,
    vw_gls.chat_type_id,
    vw_gls.chat_type_name,
    vw_gls.account_type_id,
    vw_gls.account_type_no,
    vw_gls.account_type_name,
    vw_gls.account_id,
    vw_gls.account_no,
    vw_gls.account_name,
    vw_gls.is_header,
    vw_gls.is_active,
    vw_gls.fiscal_year_id,
    vw_gls.fiscal_year_start,
    vw_gls.fiscal_year_end,
    vw_gls.year_opened,
    vw_gls.year_closed,
    vw_gls.period_id,
    vw_gls.start_date,
    vw_gls.end_date,
    vw_gls.opened,
    vw_gls.closed,
    vw_gls.month_id,
    vw_gls.period_year,
    vw_gls.period_month,
    vw_gls.quarter,
    vw_gls.semister,
    sum(vw_gls.debit) AS acc_debit,
    sum(vw_gls.credit) AS acc_credit,
    sum(vw_gls.base_debit) AS acc_base_debit,
    sum(vw_gls.base_credit) AS acc_base_credit
   FROM vw_gls
  WHERE (vw_gls.posted = true)
  GROUP BY vw_gls.org_id, vw_gls.account_class_id, vw_gls.account_class_no, vw_gls.account_class_name, vw_gls.chat_type_id, vw_gls.chat_type_name, vw_gls.account_type_id, vw_gls.account_type_no, vw_gls.account_type_name, vw_gls.account_id, vw_gls.account_no, vw_gls.account_name, vw_gls.is_header, vw_gls.is_active, vw_gls.fiscal_year_id, vw_gls.fiscal_year_start, vw_gls.fiscal_year_end, vw_gls.year_opened, vw_gls.year_closed, vw_gls.period_id, vw_gls.start_date, vw_gls.end_date, vw_gls.opened, vw_gls.closed, vw_gls.month_id, vw_gls.period_year, vw_gls.period_month, vw_gls.quarter, vw_gls.semister
  ORDER BY vw_gls.account_id;


ALTER TABLE public.vw_sm_gls OWNER TO postgres;

--
-- Name: vw_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ledger AS
 SELECT vw_sm_gls.org_id,
    vw_sm_gls.account_class_id,
    vw_sm_gls.account_class_no,
    vw_sm_gls.account_class_name,
    vw_sm_gls.chat_type_id,
    vw_sm_gls.chat_type_name,
    vw_sm_gls.account_type_id,
    vw_sm_gls.account_type_no,
    vw_sm_gls.account_type_name,
    vw_sm_gls.account_id,
    vw_sm_gls.account_no,
    vw_sm_gls.account_name,
    vw_sm_gls.is_header,
    vw_sm_gls.is_active,
    vw_sm_gls.fiscal_year_id,
    vw_sm_gls.fiscal_year_start,
    vw_sm_gls.fiscal_year_end,
    vw_sm_gls.year_opened,
    vw_sm_gls.year_closed,
    vw_sm_gls.period_id,
    vw_sm_gls.start_date,
    vw_sm_gls.end_date,
    vw_sm_gls.opened,
    vw_sm_gls.closed,
    vw_sm_gls.month_id,
    vw_sm_gls.period_year,
    vw_sm_gls.period_month,
    vw_sm_gls.quarter,
    vw_sm_gls.semister,
    vw_sm_gls.acc_debit,
    vw_sm_gls.acc_credit,
    (vw_sm_gls.acc_debit - vw_sm_gls.acc_credit) AS acc_balance,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_debit > vw_sm_gls.acc_credit) THEN (vw_sm_gls.acc_debit - vw_sm_gls.acc_credit)
            ELSE (0)::real
        END, (0)::real) AS bal_debit,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_debit < vw_sm_gls.acc_credit) THEN (vw_sm_gls.acc_credit - vw_sm_gls.acc_debit)
            ELSE (0)::real
        END, (0)::real) AS bal_credit,
    vw_sm_gls.acc_base_debit,
    vw_sm_gls.acc_base_credit,
    (vw_sm_gls.acc_base_debit - vw_sm_gls.acc_base_credit) AS acc_base_balance,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_base_debit > vw_sm_gls.acc_base_credit) THEN (vw_sm_gls.acc_base_debit - vw_sm_gls.acc_base_credit)
            ELSE (0)::real
        END, (0)::real) AS bal_base_debit,
    COALESCE(
        CASE
            WHEN (vw_sm_gls.acc_base_debit < vw_sm_gls.acc_base_credit) THEN (vw_sm_gls.acc_base_credit - vw_sm_gls.acc_base_debit)
            ELSE (0)::real
        END, (0)::real) AS bal_base_credit
   FROM vw_sm_gls;


ALTER TABLE public.vw_ledger OWNER TO postgres;

--
-- Name: vw_ledger_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ledger_types AS
 SELECT vw_accounts.account_class_id,
    vw_accounts.chat_type_id,
    vw_accounts.chat_type_name,
    vw_accounts.account_class_name,
    vw_accounts.account_type_id,
    vw_accounts.account_type_name,
    vw_accounts.account_id,
    vw_accounts.account_no,
    vw_accounts.account_name,
    vw_accounts.is_header,
    vw_accounts.is_active,
    ta.account_class_id AS t_account_class_id,
    ta.chat_type_id AS t_chat_type_id,
    ta.chat_type_name AS t_chat_type_name,
    ta.account_class_name AS t_account_class_name,
    ta.account_type_id AS t_account_type_id,
    ta.account_type_name AS t_account_type_name,
    ta.account_id AS t_account_id,
    ta.account_no AS t_account_no,
    ta.account_name AS t_account_name,
    ledger_types.org_id,
    ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.ledger_posting,
    ledger_types.income_ledger,
    ledger_types.expense_ledger,
    ledger_types.details
   FROM ((ledger_types
     JOIN vw_accounts ON ((ledger_types.account_id = vw_accounts.account_id)))
     JOIN vw_accounts ta ON ((ledger_types.tax_account_id = ta.account_id)));


ALTER TABLE public.vw_ledger_types OWNER TO postgres;

--
-- Name: vw_loan_activity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_activity AS
 SELECT vw_loans.customer_id,
    vw_loans.customer_name,
    vw_loans.business_account,
    vw_loans.product_id,
    vw_loans.product_name,
    vw_loans.loan_id,
    vw_loans.principal_amount,
    vw_loans.interest_rate,
    vw_loans.disbursed_date,
    vw_loans.expected_matured_date,
    vw_loans.matured_date,
    vw_activity_types.activity_type_id,
    vw_activity_types.activity_type_name,
    vw_activity_types.dr_account_id,
    vw_activity_types.dr_account_no,
    vw_activity_types.dr_account_name,
    vw_activity_types.cr_account_id,
    vw_activity_types.cr_account_no,
    vw_activity_types.cr_account_name,
    vw_activity_types.use_key_id,
    vw_activity_types.use_key_name,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    activity_status.activity_status_id,
    activity_status.activity_status_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    account_activity.transfer_account_id,
    trnf_accounts.account_number AS trnf_account_number,
    trnf_accounts.customer_id AS trnf_customer_id,
    trnf_accounts.customer_name AS trnf_customer_name,
    trnf_accounts.product_id AS trnf_product_id,
    trnf_accounts.product_name AS trnf_product_name,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.fiscal_year_id,
    vw_periods.fiscal_year,
    account_activity.org_id,
    account_activity.account_activity_id,
    account_activity.activity_date,
    account_activity.value_date,
    account_activity.transfer_account_no,
    account_activity.account_credit,
    account_activity.account_debit,
    account_activity.balance,
    account_activity.exchange_rate,
    account_activity.application_date,
    account_activity.approve_status,
    account_activity.workflow_table_id,
    account_activity.action_date,
    account_activity.details,
    (account_activity.account_credit * account_activity.exchange_rate) AS base_credit,
    (account_activity.account_debit * account_activity.exchange_rate) AS base_debit
   FROM (((((((account_activity
     JOIN vw_loans ON ((account_activity.loan_id = vw_loans.loan_id)))
     JOIN vw_activity_types ON ((account_activity.activity_type_id = vw_activity_types.activity_type_id)))
     JOIN activity_frequency ON ((account_activity.activity_frequency_id = activity_frequency.activity_frequency_id)))
     JOIN activity_status ON ((account_activity.activity_status_id = activity_status.activity_status_id)))
     JOIN currency ON ((account_activity.currency_id = currency.currency_id)))
     LEFT JOIN vw_periods ON ((account_activity.period_id = vw_periods.period_id)))
     LEFT JOIN vw_deposit_accounts trnf_accounts ON ((account_activity.transfer_account_id = trnf_accounts.deposit_account_id)));


ALTER TABLE public.vw_loan_activity OWNER TO postgres;

--
-- Name: vw_loan_notes; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_loan_notes AS
 SELECT vw_loans.customer_id,
    vw_loans.customer_name,
    vw_loans.product_id,
    vw_loans.product_name,
    vw_loans.loan_id,
    vw_loans.principal_amount,
    vw_loans.interest_rate,
    vw_loans.activity_frequency_id,
    vw_loans.activity_frequency_name,
    vw_loans.disbursed_date,
    vw_loans.expected_matured_date,
    vw_loans.matured_date,
    loan_notes.org_id,
    loan_notes.loan_note_id,
    loan_notes.comment_date,
    loan_notes.narrative,
    loan_notes.note
   FROM (loan_notes
     JOIN vw_loans ON ((loan_notes.loan_id = vw_loans.loan_id)));


ALTER TABLE public.vw_loan_notes OWNER TO postgres;

--
-- Name: vw_org_select; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_org_select AS
 SELECT orgs.org_id,
    orgs.parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE ((orgs.is_active = true) AND (orgs.org_id <> orgs.parent_org_id))
UNION
 SELECT orgs.org_id,
    orgs.org_id AS parent_org_id,
    orgs.org_name
   FROM orgs
  WHERE (orgs.is_active = true);


ALTER TABLE public.vw_org_select OWNER TO postgres;

--
-- Name: vw_pc_allocations; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pc_allocations AS
 SELECT vw_periods.fiscal_year_id,
    vw_periods.fiscal_year_start,
    vw_periods.fiscal_year_end,
    vw_periods.year_opened,
    vw_periods.year_closed,
    vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.opened,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    departments.department_id,
    departments.department_name,
    pc_allocations.org_id,
    pc_allocations.pc_allocation_id,
    pc_allocations.narrative,
    pc_allocations.approve_status,
    pc_allocations.details,
    ( SELECT sum(((pc_budget.budget_units)::double precision * pc_budget.budget_price)) AS sum
           FROM pc_budget
          WHERE (pc_budget.pc_allocation_id = pc_allocations.pc_allocation_id)) AS sum_budget,
    ( SELECT sum(((pc_expenditure.units)::double precision * pc_expenditure.unit_price)) AS sum
           FROM pc_expenditure
          WHERE (pc_expenditure.pc_allocation_id = pc_allocations.pc_allocation_id)) AS sum_expenditure,
    ( SELECT sum(pc_banking.amount) AS sum
           FROM pc_banking
          WHERE (pc_banking.pc_allocation_id = pc_allocations.pc_allocation_id)) AS sum_banking
   FROM ((pc_allocations
     JOIN vw_periods ON ((pc_allocations.period_id = vw_periods.period_id)))
     JOIN departments ON ((pc_allocations.department_id = departments.department_id)));


ALTER TABLE public.vw_pc_allocations OWNER TO postgres;

--
-- Name: vw_pc_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pc_items AS
 SELECT pc_category.pc_category_id,
    pc_category.pc_category_name,
    pc_items.org_id,
    pc_items.pc_item_id,
    pc_items.pc_item_name,
    pc_items.default_price,
    pc_items.default_units,
    pc_items.details,
    (pc_items.default_price * (pc_items.default_units)::double precision) AS default_cost
   FROM (pc_items
     JOIN pc_category ON ((pc_items.pc_category_id = pc_category.pc_category_id)));


ALTER TABLE public.vw_pc_items OWNER TO postgres;

--
-- Name: vw_pc_budget; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pc_budget AS
 SELECT vw_pc_allocations.fiscal_year_id,
    vw_pc_allocations.fiscal_year_start,
    vw_pc_allocations.fiscal_year_end,
    vw_pc_allocations.year_opened,
    vw_pc_allocations.year_closed,
    vw_pc_allocations.period_id,
    vw_pc_allocations.start_date,
    vw_pc_allocations.end_date,
    vw_pc_allocations.opened,
    vw_pc_allocations.closed,
    vw_pc_allocations.month_id,
    vw_pc_allocations.period_year,
    vw_pc_allocations.period_month,
    vw_pc_allocations.quarter,
    vw_pc_allocations.semister,
    vw_pc_allocations.department_id,
    vw_pc_allocations.department_name,
    vw_pc_allocations.pc_allocation_id,
    vw_pc_allocations.narrative,
    vw_pc_allocations.approve_status,
    vw_pc_items.pc_category_id,
    vw_pc_items.pc_category_name,
    vw_pc_items.pc_item_id,
    vw_pc_items.pc_item_name,
    vw_pc_items.default_price,
    vw_pc_items.default_units,
    vw_pc_items.default_cost,
    pc_budget.org_id,
    pc_budget.pc_budget_id,
    pc_budget.budget_units,
    pc_budget.budget_price,
    ((pc_budget.budget_units)::double precision * pc_budget.budget_price) AS budget_cost,
    pc_budget.details
   FROM ((pc_budget
     JOIN vw_pc_allocations ON ((pc_budget.pc_allocation_id = vw_pc_allocations.pc_allocation_id)))
     JOIN vw_pc_items ON ((pc_budget.pc_item_id = vw_pc_items.pc_item_id)));


ALTER TABLE public.vw_pc_budget OWNER TO postgres;

--
-- Name: vw_pc_expenditure; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_pc_expenditure AS
 SELECT vw_pc_allocations.fiscal_year_id,
    vw_pc_allocations.fiscal_year_start,
    vw_pc_allocations.fiscal_year_end,
    vw_pc_allocations.year_opened,
    vw_pc_allocations.year_closed,
    vw_pc_allocations.period_id,
    vw_pc_allocations.start_date,
    vw_pc_allocations.end_date,
    vw_pc_allocations.opened,
    vw_pc_allocations.closed,
    vw_pc_allocations.month_id,
    vw_pc_allocations.period_year,
    vw_pc_allocations.period_month,
    vw_pc_allocations.quarter,
    vw_pc_allocations.semister,
    vw_pc_allocations.department_id,
    vw_pc_allocations.department_name,
    vw_pc_allocations.pc_allocation_id,
    vw_pc_allocations.narrative,
    vw_pc_items.pc_category_id,
    vw_pc_items.pc_category_name,
    vw_pc_items.pc_item_id,
    vw_pc_items.pc_item_name,
    vw_pc_items.default_price,
    vw_pc_items.default_units,
    vw_pc_items.default_cost,
    pc_types.pc_type_id,
    pc_types.pc_type_name,
    entitys.entity_id,
    entitys.entity_name,
    pc_expenditure.org_id,
    pc_expenditure.pc_expenditure_id,
    pc_expenditure.units,
    pc_expenditure.unit_price,
    pc_expenditure.receipt_number,
    pc_expenditure.exp_date,
    pc_expenditure.is_request,
    pc_expenditure.request_date,
    ((pc_expenditure.units)::double precision * pc_expenditure.unit_price) AS items_cost,
    pc_expenditure.application_date,
    pc_expenditure.approve_status,
    pc_expenditure.workflow_table_id,
    pc_expenditure.action_date,
    pc_expenditure.details
   FROM ((((pc_expenditure
     JOIN vw_pc_allocations ON ((pc_expenditure.pc_allocation_id = vw_pc_allocations.pc_allocation_id)))
     JOIN vw_pc_items ON ((pc_expenditure.pc_item_id = vw_pc_items.pc_item_id)))
     JOIN pc_types ON ((pc_expenditure.pc_type_id = pc_types.pc_type_id)))
     LEFT JOIN entitys ON ((pc_expenditure.entity_id = entitys.entity_id)));


ALTER TABLE public.vw_pc_expenditure OWNER TO postgres;

--
-- Name: vw_penalty_methods; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_penalty_methods AS
 SELECT activity_types.activity_type_id,
    activity_types.activity_type_name,
    activity_types.use_key_id,
    penalty_methods.org_id,
    penalty_methods.penalty_method_id,
    penalty_methods.penalty_method_name,
    penalty_methods.formural,
    penalty_methods.account_number,
    penalty_methods.penalty_method_no,
    penalty_methods.details
   FROM (penalty_methods
     JOIN activity_types ON ((penalty_methods.activity_type_id = activity_types.activity_type_id)));


ALTER TABLE public.vw_penalty_methods OWNER TO postgres;

--
-- Name: vw_period_month; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_month AS
 SELECT vw_periods.org_id,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.month_id, vw_periods.period_year, vw_periods.period_month
  ORDER BY vw_periods.month_id, vw_periods.period_year, vw_periods.period_month;


ALTER TABLE public.vw_period_month OWNER TO postgres;

--
-- Name: vw_period_quarter; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_quarter AS
 SELECT vw_periods.org_id,
    vw_periods.quarter
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.quarter
  ORDER BY vw_periods.quarter;


ALTER TABLE public.vw_period_quarter OWNER TO postgres;

--
-- Name: vw_period_semister; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_semister AS
 SELECT vw_periods.org_id,
    vw_periods.semister
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.semister
  ORDER BY vw_periods.semister;


ALTER TABLE public.vw_period_semister OWNER TO postgres;

--
-- Name: vw_period_tax_rates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_tax_rates AS
 SELECT period_tax_types.period_tax_type_id,
    period_tax_types.period_tax_type_name,
    period_tax_types.tax_type_id,
    period_tax_types.period_id,
    period_tax_rates.period_tax_rate_id,
    get_tax_min(period_tax_rates.tax_range, period_tax_types.period_tax_type_id, 0) AS min_range,
    period_tax_rates.org_id,
    period_tax_rates.tax_range AS max_range,
    period_tax_rates.tax_rate,
    period_tax_rates.employer_rate,
    period_tax_rates.rate_relief,
    period_tax_rates.narrative
   FROM (period_tax_rates
     JOIN period_tax_types ON ((period_tax_rates.period_tax_type_id = period_tax_types.period_tax_type_id)));


ALTER TABLE public.vw_period_tax_rates OWNER TO postgres;

--
-- Name: vw_period_tax_types; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_tax_types AS
 SELECT vw_periods.period_id,
    vw_periods.start_date,
    vw_periods.end_date,
    vw_periods.overtime_rate,
    vw_periods.activated,
    vw_periods.closed,
    vw_periods.month_id,
    vw_periods.period_year,
    vw_periods.period_month,
    vw_periods.quarter,
    vw_periods.semister,
    tax_types.tax_type_id,
    tax_types.tax_type_name,
    period_tax_types.period_tax_type_id,
    tax_types.tax_type_number,
    use_keys.use_key_id,
    use_keys.use_key_name,
    use_keys.use_function,
    period_tax_types.period_tax_type_name,
    period_tax_types.org_id,
    period_tax_types.pay_date,
    period_tax_types.tax_relief,
    period_tax_types.linear,
    period_tax_types.percentage,
    period_tax_types.formural,
    period_tax_types.employer_formural,
    period_tax_types.employer_relief,
    period_tax_types.details
   FROM (((period_tax_types
     JOIN vw_periods ON ((period_tax_types.period_id = vw_periods.period_id)))
     JOIN tax_types ON ((period_tax_types.tax_type_id = tax_types.tax_type_id)))
     JOIN use_keys ON ((tax_types.use_key_id = use_keys.use_key_id)));


ALTER TABLE public.vw_period_tax_types OWNER TO postgres;

--
-- Name: vw_period_year; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_period_year AS
 SELECT vw_periods.org_id,
    vw_periods.period_year
   FROM vw_periods
  GROUP BY vw_periods.org_id, vw_periods.period_year
  ORDER BY vw_periods.period_year;


ALTER TABLE public.vw_period_year OWNER TO postgres;

--
-- Name: vw_quotations; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_quotations AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    items.item_id,
    items.item_name,
    quotations.quotation_id,
    quotations.org_id,
    quotations.active,
    quotations.amount,
    quotations.valid_from,
    quotations.valid_to,
    quotations.lead_time,
    quotations.details
   FROM ((quotations
     JOIN entitys ON ((quotations.entity_id = entitys.entity_id)))
     JOIN items ON ((quotations.item_id = items.item_id)));


ALTER TABLE public.vw_quotations OWNER TO postgres;

--
-- Name: vw_reporting; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_reporting AS
 SELECT entitys.entity_id,
    entitys.entity_name,
    rpt.entity_id AS rpt_id,
    rpt.entity_name AS rpt_name,
    reporting.org_id,
    reporting.reporting_id,
    reporting.date_from,
    reporting.date_to,
    reporting.primary_report,
    reporting.is_active,
    reporting.ps_reporting,
    reporting.reporting_level,
    reporting.details
   FROM ((reporting
     JOIN entitys ON ((reporting.entity_id = entitys.entity_id)))
     JOIN entitys rpt ON ((reporting.report_to_id = rpt.entity_id)));


ALTER TABLE public.vw_reporting OWNER TO postgres;

--
-- Name: vw_ss_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_ss_items AS
 SELECT orgs.org_id,
    orgs.org_name,
    ss_types.ss_type_id,
    ss_types.ss_type_name,
    ss_items.ss_item_id,
    ss_items.ss_item_name,
    ss_items.picture,
    ss_items.description,
    ss_items.purchase_date,
    ss_items.purchase_price,
    ss_items.sale_date,
    ss_items.sale_price,
    ss_items.sold,
    ss_items.details,
    (ss_items.sale_price - ss_items.purchase_price) AS gross_margin
   FROM ((ss_items
     JOIN ss_types ON ((ss_items.ss_type_id = ss_types.ss_type_id)))
     JOIN orgs ON ((ss_items.org_id = orgs.org_id)));


ALTER TABLE public.vw_ss_items OWNER TO postgres;

--
-- Name: vw_stocks; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_stocks AS
 SELECT stores.store_id,
    stores.store_name,
    stocks.stock_id,
    stocks.org_id,
    stocks.stock_name,
    stocks.stock_take_date,
    stocks.details
   FROM (stocks
     JOIN stores ON ((stocks.store_id = stores.store_id)));


ALTER TABLE public.vw_stocks OWNER TO postgres;

--
-- Name: vw_stock_lines; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_stock_lines AS
 SELECT vw_stocks.stock_id,
    vw_stocks.stock_name,
    vw_stocks.stock_take_date,
    vw_stocks.store_id,
    vw_stocks.store_name,
    items.item_id,
    items.item_name,
    stock_lines.stock_line_id,
    stock_lines.org_id,
    stock_lines.quantity,
    stock_lines.narrative
   FROM ((stock_lines
     JOIN vw_stocks ON ((stock_lines.stock_id = vw_stocks.stock_id)))
     JOIN items ON ((stock_lines.item_id = items.item_id)));


ALTER TABLE public.vw_stock_lines OWNER TO postgres;

--
-- Name: vw_transactions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transactions AS
 SELECT transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_posting,
    transaction_types.for_sales,
    entitys.entity_id,
    entitys.entity_name,
    entitys.account_id AS entity_account_id,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    vw_bank_accounts.bank_id,
    vw_bank_accounts.bank_name,
    vw_bank_accounts.bank_branch_name,
    vw_bank_accounts.account_id AS gl_bank_account_id,
    vw_bank_accounts.bank_account_id,
    vw_bank_accounts.bank_account_name,
    vw_bank_accounts.bank_account_number,
    departments.department_id,
    departments.department_name,
    ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.account_id AS ledger_account_id,
    ledger_types.tax_account_id,
    ledger_types.ledger_posting,
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    transactions.journal_id,
    transactions.transaction_id,
    transactions.org_id,
    transactions.transaction_date,
    transactions.transaction_amount,
    transactions.transaction_tax_amount,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.document_number,
    transactions.payment_number,
    transactions.order_number,
    transactions.exchange_rate,
    transactions.payment_terms,
    transactions.job,
    transactions.details,
    transactions.notes,
    (transactions.transaction_amount - transactions.transaction_tax_amount) AS transaction_net_amount,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
        CASE
            WHEN ((((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) OR (transactions.transaction_type_id = 21)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN ((((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) OR (transactions.transaction_type_id = 22)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS credit_amount
   FROM (((((((transactions
     JOIN transaction_types ON ((transactions.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN transaction_status ON ((transactions.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     LEFT JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
     LEFT JOIN vw_bank_accounts ON ((vw_bank_accounts.bank_account_id = transactions.bank_account_id)))
     LEFT JOIN departments ON ((transactions.department_id = departments.department_id)))
     LEFT JOIN ledger_types ON ((transactions.ledger_type_id = ledger_types.ledger_type_id)));


ALTER TABLE public.vw_transactions OWNER TO postgres;

--
-- Name: vw_transaction_details; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transaction_details AS
 SELECT vw_transactions.department_id,
    vw_transactions.department_name,
    vw_transactions.transaction_type_id,
    vw_transactions.transaction_type_name,
    vw_transactions.document_prefix,
    vw_transactions.transaction_id,
    vw_transactions.transaction_date,
    vw_transactions.entity_id,
    vw_transactions.entity_name,
    vw_transactions.document_number,
    vw_transactions.approve_status,
    vw_transactions.workflow_table_id,
    vw_transactions.currency_name,
    vw_transactions.exchange_rate,
    accounts.account_id,
    accounts.account_name,
    stores.store_id,
    stores.store_name,
    vw_items.item_id,
    vw_items.item_name,
    vw_items.tax_type_id,
    vw_items.tax_account_id,
    vw_items.tax_type_name,
    vw_items.tax_rate,
    vw_items.tax_inclusive,
    vw_items.sales_account_id,
    vw_items.purchase_account_id,
    vw_items.for_sale,
    vw_items.for_purchase,
    vw_items.for_stock,
    vw_items.inventory,
    transaction_details.transaction_detail_id,
    transaction_details.org_id,
    transaction_details.quantity,
    transaction_details.amount,
    transaction_details.tax_amount,
    transaction_details.discount,
    transaction_details.narrative,
    transaction_details.details,
    COALESCE(transaction_details.narrative, vw_items.item_name) AS item_description,
    (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.amount) AS full_amount,
    (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.tax_amount) AS full_tax_amount,
    (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * (transaction_details.amount + transaction_details.tax_amount)) AS full_total_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 5) OR (vw_transactions.transaction_type_id = 9)) THEN (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.tax_amount)
            ELSE (0)::double precision
        END AS tax_debit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 10)) THEN (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.tax_amount)
            ELSE (0)::double precision
        END AS tax_credit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 5) OR (vw_transactions.transaction_type_id = 9)) THEN (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.amount)
            ELSE (0)::double precision
        END AS full_debit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 10)) THEN (((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * transaction_details.amount)
            ELSE (0)::double precision
        END AS full_credit_amount,
        CASE
            WHEN ((vw_transactions.transaction_type_id = 2) OR (vw_transactions.transaction_type_id = 9)) THEN vw_items.sales_account_id
            ELSE vw_items.purchase_account_id
        END AS trans_account_id
   FROM ((((transaction_details
     JOIN vw_transactions ON ((transaction_details.transaction_id = vw_transactions.transaction_id)))
     LEFT JOIN vw_items ON ((transaction_details.item_id = vw_items.item_id)))
     LEFT JOIN accounts ON ((transaction_details.account_id = accounts.account_id)))
     LEFT JOIN stores ON ((transaction_details.store_id = stores.store_id)));


ALTER TABLE public.vw_transaction_details OWNER TO postgres;

--
-- Name: vw_stock_movement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_stock_movement AS
 SELECT vw_transaction_details.org_id,
    vw_transaction_details.department_id,
    vw_transaction_details.department_name,
    vw_transaction_details.transaction_type_id,
    vw_transaction_details.transaction_type_name,
    vw_transaction_details.document_prefix,
    vw_transaction_details.document_number,
    vw_transaction_details.transaction_id,
    vw_transaction_details.transaction_date,
    vw_transaction_details.entity_id,
    vw_transaction_details.entity_name,
    vw_transaction_details.approve_status,
    vw_transaction_details.store_id,
    vw_transaction_details.store_name,
    vw_transaction_details.item_id,
    vw_transaction_details.item_name,
        CASE
            WHEN (vw_transaction_details.transaction_type_id = 11) THEN vw_transaction_details.quantity
            ELSE 0
        END AS q_sold,
        CASE
            WHEN (vw_transaction_details.transaction_type_id = 12) THEN vw_transaction_details.quantity
            ELSE 0
        END AS q_purchased,
        CASE
            WHEN (vw_transaction_details.transaction_type_id = 17) THEN vw_transaction_details.quantity
            ELSE 0
        END AS q_used
   FROM vw_transaction_details
  WHERE (((vw_transaction_details.transaction_type_id = ANY (ARRAY[11, 17, 12])) AND (vw_transaction_details.for_stock = true)) AND ((vw_transaction_details.approve_status)::text <> 'Draft'::text));


ALTER TABLE public.vw_stock_movement OWNER TO postgres;

--
-- Name: vw_store_movement; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_store_movement AS
 SELECT items.item_id,
    items.item_name,
    stores.store_id,
    stores.store_name,
    store_to.store_id AS store_to_id,
    stores.store_name AS store_to_name,
    store_movement.org_id,
    store_movement.store_movement_id,
    store_movement.movement_date,
    store_movement.quantity,
    store_movement.narrative
   FROM (((store_movement
     JOIN items ON ((store_movement.item_id = items.item_id)))
     JOIN stores ON ((store_movement.store_id = stores.store_id)))
     JOIN stores store_to ON ((store_movement.store_to_id = store_to.store_id)));


ALTER TABLE public.vw_store_movement OWNER TO postgres;

--
-- Name: vw_sub_fields; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sub_fields AS
 SELECT vw_fields.form_id,
    vw_fields.form_name,
    vw_fields.field_id,
    sub_fields.sub_field_id,
    sub_fields.org_id,
    sub_fields.sub_field_order,
    sub_fields.sub_title_share,
    sub_fields.sub_field_type,
    sub_fields.sub_field_lookup,
    sub_fields.sub_field_size,
    sub_fields.sub_col_spans,
    sub_fields.manditory,
    sub_fields.question
   FROM (sub_fields
     JOIN vw_fields ON ((sub_fields.field_id = vw_fields.field_id)));


ALTER TABLE public.vw_sub_fields OWNER TO postgres;

--
-- Name: vw_subscriptions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_subscriptions AS
 SELECT sys_countrys.sys_country_id,
    sys_countrys.sys_country_name,
    entitys.entity_id,
    entitys.entity_name,
    orgs.org_id,
    orgs.org_name,
    subscriptions.subscription_id,
    subscriptions.business_name,
    subscriptions.business_address,
    subscriptions.city,
    subscriptions.state,
    subscriptions.country_id,
    subscriptions.telephone,
    subscriptions.website,
    subscriptions.primary_contact,
    subscriptions.job_title,
    subscriptions.primary_email,
    subscriptions.approve_status,
    subscriptions.workflow_table_id,
    subscriptions.application_date,
    subscriptions.action_date,
    subscriptions.system_key,
    subscriptions.subscribed,
    subscriptions.subscribed_date,
    subscriptions.details
   FROM (((subscriptions
     JOIN sys_countrys ON ((subscriptions.country_id = sys_countrys.sys_country_id)))
     LEFT JOIN entitys ON ((subscriptions.entity_id = entitys.entity_id)))
     LEFT JOIN orgs ON ((subscriptions.org_id = orgs.org_id)));


ALTER TABLE public.vw_subscriptions OWNER TO postgres;

--
-- Name: vw_sys_countrys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_countrys AS
 SELECT sys_continents.sys_continent_id,
    sys_continents.sys_continent_name,
    sys_countrys.sys_country_id,
    sys_countrys.sys_country_code,
    sys_countrys.sys_country_number,
    sys_countrys.sys_phone_code,
    sys_countrys.sys_country_name
   FROM (sys_continents
     JOIN sys_countrys ON ((sys_continents.sys_continent_id = sys_countrys.sys_continent_id)));


ALTER TABLE public.vw_sys_countrys OWNER TO postgres;

--
-- Name: vw_sys_emailed; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_sys_emailed AS
 SELECT sys_emails.sys_email_id,
    sys_emails.org_id,
    sys_emails.sys_email_name,
    sys_emails.title,
    sys_emails.details,
    sys_emailed.sys_emailed_id,
    sys_emailed.table_id,
    sys_emailed.table_name,
    sys_emailed.email_type,
    sys_emailed.emailed,
    sys_emailed.narrative
   FROM (sys_emails
     RIGHT JOIN sys_emailed ON ((sys_emails.sys_email_id = sys_emailed.sys_email_id)));


ALTER TABLE public.vw_sys_emailed OWNER TO postgres;

--
-- Name: vw_tax_rates; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tax_rates AS
 SELECT tax_types.tax_type_id,
    tax_types.tax_type_name,
    tax_types.tax_relief,
    tax_types.linear,
    tax_types.percentage,
    tax_rates.org_id,
    tax_rates.tax_rate_id,
    tax_rates.tax_range,
    tax_rates.tax_rate,
    tax_rates.employer_rate,
    tax_rates.rate_relief,
    tax_rates.narrative
   FROM (tax_rates
     JOIN tax_types ON ((tax_rates.tax_type_id = tax_types.tax_type_id)));


ALTER TABLE public.vw_tax_rates OWNER TO postgres;

--
-- Name: vw_tender_items; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tender_items AS
 SELECT vw_bidders.tender_type_id,
    vw_bidders.tender_type_name,
    vw_bidders.tender_id,
    vw_bidders.tender_name,
    vw_bidders.tender_number,
    vw_bidders.tender_date,
    vw_bidders.tender_end_date,
    vw_bidders.is_completed,
    vw_bidders.entity_id,
    vw_bidders.entity_name,
    vw_bidders.bidder_id,
    vw_bidders.tender_amount,
    vw_bidders.bind_bond,
    vw_bidders.bind_bond_amount,
    vw_bidders.return_date,
    vw_bidders.points,
    vw_bidders.is_awarded,
    vw_bidders.award_reference,
    tender_items.org_id,
    tender_items.tender_item_id,
    tender_items.tender_item_name,
    tender_items.quantity,
    tender_items.item_amount,
    tender_items.item_tax,
    tender_items.details
   FROM (tender_items
     JOIN vw_bidders ON ((tender_items.bidder_id = vw_bidders.bidder_id)));


ALTER TABLE public.vw_tender_items OWNER TO postgres;

--
-- Name: vw_transaction_counters; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transaction_counters AS
 SELECT transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_posting,
    transaction_types.for_sales,
    transaction_counters.org_id,
    transaction_counters.transaction_counter_id,
    transaction_counters.document_number
   FROM (transaction_counters
     JOIN transaction_types ON ((transaction_counters.transaction_type_id = transaction_types.transaction_type_id)));


ALTER TABLE public.vw_transaction_counters OWNER TO postgres;

--
-- Name: vw_transfer_beneficiary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transfer_beneficiary AS
 SELECT vw_deposit_accounts.customer_id,
    vw_deposit_accounts.customer_name,
    vw_deposit_accounts.business_account,
    vw_deposit_accounts.product_id,
    vw_deposit_accounts.product_name,
    vw_deposit_accounts.currency_id,
    vw_deposit_accounts.currency_name,
    vw_deposit_accounts.currency_symbol,
    vw_deposit_accounts.activity_frequency_id,
    vw_deposit_accounts.activity_frequency_name,
    vw_deposit_accounts.deposit_account_id,
    vw_deposit_accounts.is_active,
    vw_deposit_accounts.approve_status AS account_status,
    transfer_beneficiary.customer_id AS account_customer_id,
    transfer_beneficiary.org_id,
    transfer_beneficiary.transfer_beneficiary_id,
    transfer_beneficiary.beneficiary_name,
    transfer_beneficiary.account_number,
    transfer_beneficiary.allow_transfer,
    transfer_beneficiary.application_date,
    transfer_beneficiary.approve_status,
    transfer_beneficiary.workflow_table_id,
    transfer_beneficiary.action_date,
    transfer_beneficiary.details
   FROM (transfer_beneficiary
     JOIN vw_deposit_accounts ON ((transfer_beneficiary.deposit_account_id = vw_deposit_accounts.deposit_account_id)));


ALTER TABLE public.vw_transfer_beneficiary OWNER TO postgres;

--
-- Name: vw_transfer_activity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_transfer_activity AS
 SELECT vw_transfer_beneficiary.transfer_beneficiary_id,
    vw_transfer_beneficiary.customer_name AS beneficiary_name,
    vw_transfer_beneficiary.account_number AS beneficiary_account_number,
    vw_deposit_accounts.deposit_account_id,
    vw_deposit_accounts.product_id,
    vw_deposit_accounts.product_name,
    vw_deposit_accounts.customer_id,
    vw_deposit_accounts.account_number,
    vw_deposit_accounts.currency_name AS account_currency_name,
    vw_deposit_accounts.currency_symbol AS account_currency_symbol,
    activity_frequency.activity_frequency_id,
    activity_frequency.activity_frequency_name,
    activity_types.activity_type_id,
    activity_types.activity_type_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    transfer_activity.org_id,
    transfer_activity.transfer_activity_id,
    transfer_activity.account_activity_id,
    transfer_activity.entity_id,
    transfer_activity.transfer_amount,
    transfer_activity.application_date,
    transfer_activity.approve_status,
    transfer_activity.workflow_table_id,
    transfer_activity.action_date,
    transfer_activity.details
   FROM (((((transfer_activity
     JOIN vw_transfer_beneficiary ON ((transfer_activity.transfer_beneficiary_id = vw_transfer_beneficiary.transfer_beneficiary_id)))
     JOIN vw_deposit_accounts ON ((transfer_activity.deposit_account_id = vw_deposit_accounts.deposit_account_id)))
     JOIN activity_frequency ON ((transfer_activity.activity_frequency_id = activity_frequency.activity_frequency_id)))
     JOIN activity_types ON ((transfer_activity.activity_type_id = activity_types.activity_type_id)))
     JOIN currency ON ((transfer_activity.currency_id = currency.currency_id)));


ALTER TABLE public.vw_transfer_activity OWNER TO postgres;

--
-- Name: vw_trx; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_trx AS
 SELECT vw_orgs.org_id,
    vw_orgs.org_name,
    vw_orgs.is_default AS org_is_default,
    vw_orgs.is_active AS org_is_active,
    vw_orgs.logo AS org_logo,
    vw_orgs.cert_number AS org_cert_number,
    vw_orgs.pin AS org_pin,
    vw_orgs.vat_number AS org_vat_number,
    vw_orgs.invoice_footer AS org_invoice_footer,
    vw_orgs.org_sys_country_id,
    vw_orgs.org_sys_country_name,
    vw_orgs.org_address_id,
    vw_orgs.org_table_name,
    vw_orgs.org_post_office_box,
    vw_orgs.org_postal_code,
    vw_orgs.org_premises,
    vw_orgs.org_street,
    vw_orgs.org_town,
    vw_orgs.org_phone_number,
    vw_orgs.org_extension,
    vw_orgs.org_mobile,
    vw_orgs.org_fax,
    vw_orgs.org_email,
    vw_orgs.org_website,
    vw_entitys.address_id,
    vw_entitys.address_name,
    vw_entitys.sys_country_id,
    vw_entitys.sys_country_name,
    vw_entitys.table_name,
    vw_entitys.is_default,
    vw_entitys.post_office_box,
    vw_entitys.postal_code,
    vw_entitys.premises,
    vw_entitys.street,
    vw_entitys.town,
    vw_entitys.phone_number,
    vw_entitys.extension,
    vw_entitys.mobile,
    vw_entitys.fax,
    vw_entitys.email,
    vw_entitys.website,
    vw_entitys.entity_id,
    vw_entitys.entity_name,
    vw_entitys.user_name,
    vw_entitys.super_user,
    vw_entitys.attention,
    vw_entitys.date_enroled,
    vw_entitys.is_active,
    vw_entitys.entity_type_id,
    vw_entitys.entity_type_name,
    vw_entitys.entity_role,
    vw_entitys.use_key_id,
    transaction_types.transaction_type_id,
    transaction_types.transaction_type_name,
    transaction_types.document_prefix,
    transaction_types.for_sales,
    transaction_types.for_posting,
    transaction_status.transaction_status_id,
    transaction_status.transaction_status_name,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    departments.department_id,
    departments.department_name,
    transactions.journal_id,
    transactions.bank_account_id,
    transactions.ledger_type_id,
    transactions.transaction_id,
    transactions.transaction_date,
    transactions.transaction_amount,
    transactions.transaction_tax_amount,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.document_number,
    transactions.payment_number,
    transactions.order_number,
    transactions.exchange_rate,
    transactions.payment_terms,
    transactions.job,
    transactions.details,
    transactions.notes,
    (transactions.transaction_amount - transactions.transaction_tax_amount) AS transaction_net_amount,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
        CASE
            WHEN (((transactions.transaction_type_id = 2) OR (transactions.transaction_type_id = 8)) OR (transactions.transaction_type_id = 10)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS debit_amount,
        CASE
            WHEN (((transactions.transaction_type_id = 5) OR (transactions.transaction_type_id = 7)) OR (transactions.transaction_type_id = 9)) THEN transactions.transaction_amount
            ELSE (0)::real
        END AS credit_amount
   FROM ((((((transactions
     JOIN transaction_types ON ((transactions.transaction_type_id = transaction_types.transaction_type_id)))
     JOIN vw_orgs ON ((transactions.org_id = vw_orgs.org_id)))
     JOIN transaction_status ON ((transactions.transaction_status_id = transaction_status.transaction_status_id)))
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     LEFT JOIN vw_entitys ON ((transactions.entity_id = vw_entitys.entity_id)))
     LEFT JOIN departments ON ((transactions.department_id = departments.department_id)));


ALTER TABLE public.vw_trx OWNER TO postgres;

--
-- Name: vw_trx_sum; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_trx_sum AS
 SELECT transaction_details.transaction_id,
    sum(((((transaction_details.quantity)::double precision * transaction_details.amount) * ((100)::double precision - transaction_details.discount)) / (100)::double precision)) AS total_amount,
    sum(((((transaction_details.quantity)::double precision * transaction_details.tax_amount) * ((100)::double precision - transaction_details.discount)) / (100)::double precision)) AS total_tax_amount,
    sum((((transaction_details.quantity)::double precision * (((100)::double precision - transaction_details.discount) / (100)::double precision)) * (transaction_details.amount + transaction_details.tax_amount))) AS total_sale_amount
   FROM transaction_details
  GROUP BY transaction_details.transaction_id;


ALTER TABLE public.vw_trx_sum OWNER TO postgres;

--
-- Name: vw_tx_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_tx_ledger AS
 SELECT ledger_types.ledger_type_id,
    ledger_types.ledger_type_name,
    ledger_types.account_id,
    ledger_types.ledger_posting,
    currency.currency_id,
    currency.currency_name,
    currency.currency_symbol,
    entitys.entity_id,
    entitys.entity_name,
    bank_accounts.bank_account_id,
    bank_accounts.bank_account_name,
    transactions.org_id,
    transactions.transaction_id,
    transactions.journal_id,
    transactions.exchange_rate,
    transactions.tx_type,
    transactions.transaction_date,
    transactions.payment_date,
    transactions.transaction_amount,
    transactions.transaction_tax_amount,
    transactions.reference_number,
    transactions.payment_number,
    transactions.for_processing,
    transactions.completed,
    transactions.is_cleared,
    transactions.application_date,
    transactions.approve_status,
    transactions.workflow_table_id,
    transactions.action_date,
    transactions.narrative,
    transactions.details,
        CASE
            WHEN (transactions.journal_id IS NULL) THEN 'Not Posted'::text
            ELSE 'Posted'::text
        END AS posted,
    to_char((transactions.payment_date)::timestamp with time zone, 'YYYY.MM'::text) AS ledger_period,
    to_char((transactions.payment_date)::timestamp with time zone, 'YYYY'::text) AS ledger_year,
    to_char((transactions.payment_date)::timestamp with time zone, 'Month'::text) AS ledger_month,
    ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount) AS base_amount,
    ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_tax_amount) AS base_tax_amount,
        CASE
            WHEN (transactions.completed = true) THEN ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount)
            ELSE ((0)::real)::double precision
        END AS base_balance,
        CASE
            WHEN (transactions.is_cleared = true) THEN ((transactions.exchange_rate * (transactions.tx_type)::double precision) * transactions.transaction_amount)
            ELSE ((0)::real)::double precision
        END AS cleared_balance,
        CASE
            WHEN (transactions.tx_type = 1) THEN (transactions.exchange_rate * transactions.transaction_amount)
            ELSE (0)::real
        END AS dr_amount,
        CASE
            WHEN (transactions.tx_type = (-1)) THEN (transactions.exchange_rate * transactions.transaction_amount)
            ELSE (0)::real
        END AS cr_amount
   FROM ((((transactions
     JOIN currency ON ((transactions.currency_id = currency.currency_id)))
     JOIN entitys ON ((transactions.entity_id = entitys.entity_id)))
     LEFT JOIN bank_accounts ON ((transactions.bank_account_id = bank_accounts.bank_account_id)))
     LEFT JOIN ledger_types ON ((transactions.ledger_type_id = ledger_types.ledger_type_id)))
  WHERE (transactions.tx_type IS NOT NULL);


ALTER TABLE public.vw_tx_ledger OWNER TO postgres;

--
-- Name: vw_workflow_approvals; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_approvals AS
 SELECT vw_approvals.workflow_id,
    vw_approvals.org_id,
    vw_approvals.workflow_name,
    vw_approvals.approve_email,
    vw_approvals.reject_email,
    vw_approvals.source_entity_id,
    vw_approvals.source_entity_name,
    vw_approvals.table_name,
    vw_approvals.table_id,
    vw_approvals.org_entity_id,
    vw_approvals.org_entity_name,
    vw_approvals.org_user_name,
    vw_approvals.org_primary_email,
    rt.rejected_count,
        CASE
            WHEN (rt.rejected_count IS NULL) THEN ((vw_approvals.workflow_name)::text || ' Approved'::text)
            ELSE ((vw_approvals.workflow_name)::text || ' declined'::text)
        END AS workflow_narrative
   FROM (vw_approvals
     LEFT JOIN ( SELECT approvals.table_id,
            count(approvals.approval_id) AS rejected_count
           FROM approvals
          WHERE (((approvals.approve_status)::text = 'Rejected'::text) AND (approvals.forward_id IS NULL))
          GROUP BY approvals.table_id) rt ON ((vw_approvals.table_id = rt.table_id)))
  GROUP BY vw_approvals.workflow_id, vw_approvals.org_id, vw_approvals.workflow_name, vw_approvals.approve_email, vw_approvals.reject_email, vw_approvals.source_entity_id, vw_approvals.source_entity_name, vw_approvals.table_name, vw_approvals.table_id, vw_approvals.org_entity_id, vw_approvals.org_entity_name, vw_approvals.org_user_name, vw_approvals.org_primary_email, rt.rejected_count;


ALTER TABLE public.vw_workflow_approvals OWNER TO postgres;

--
-- Name: vw_workflow_entitys; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_entitys AS
 SELECT vw_workflow_phases.workflow_id,
    vw_workflow_phases.org_id,
    vw_workflow_phases.workflow_name,
    vw_workflow_phases.table_name,
    vw_workflow_phases.table_link_id,
    vw_workflow_phases.source_entity_id,
    vw_workflow_phases.source_entity_name,
    vw_workflow_phases.approval_entity_id,
    vw_workflow_phases.approval_entity_name,
    vw_workflow_phases.workflow_phase_id,
    vw_workflow_phases.approval_level,
    vw_workflow_phases.return_level,
    vw_workflow_phases.escalation_days,
    vw_workflow_phases.escalation_hours,
    vw_workflow_phases.notice,
    vw_workflow_phases.notice_email,
    vw_workflow_phases.notice_file,
    vw_workflow_phases.advice,
    vw_workflow_phases.advice_email,
    vw_workflow_phases.advice_file,
    vw_workflow_phases.required_approvals,
    vw_workflow_phases.use_reporting,
    vw_workflow_phases.phase_narrative,
    entity_subscriptions.entity_subscription_id,
    entity_subscriptions.entity_id,
    entity_subscriptions.subscription_level_id
   FROM (vw_workflow_phases
     JOIN entity_subscriptions ON ((vw_workflow_phases.source_entity_id = entity_subscriptions.entity_type_id)));


ALTER TABLE public.vw_workflow_entitys OWNER TO postgres;

--
-- Name: workflow_sql; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_sql (
    workflow_sql_id integer NOT NULL,
    workflow_phase_id integer NOT NULL,
    org_id integer,
    workflow_sql_name character varying(50),
    is_condition boolean DEFAULT false,
    is_action boolean DEFAULT false,
    message text NOT NULL,
    sql text NOT NULL
);


ALTER TABLE public.workflow_sql OWNER TO postgres;

--
-- Name: vw_workflow_sql; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vw_workflow_sql AS
 SELECT workflow_sql.org_id,
    workflow_sql.workflow_sql_id,
    workflow_sql.workflow_phase_id,
    workflow_sql.workflow_sql_name,
    workflow_sql.is_condition,
    workflow_sql.is_action,
    workflow_sql.message,
    workflow_sql.sql,
    approvals.approval_id,
    approvals.org_entity_id,
    approvals.app_entity_id,
    approvals.approval_level,
    approvals.escalation_days,
    approvals.escalation_hours,
    approvals.escalation_time,
    approvals.forward_id,
    approvals.table_name,
    approvals.table_id,
    approvals.application_date,
    approvals.completion_date,
    approvals.action_date,
    approvals.approve_status,
    approvals.approval_narrative
   FROM (workflow_sql
     JOIN approvals ON ((workflow_sql.workflow_phase_id = approvals.workflow_phase_id)));


ALTER TABLE public.vw_workflow_sql OWNER TO postgres;

--
-- Name: vws_pc_expenditure; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vws_pc_expenditure AS
 SELECT a.period_id,
    a.period_year,
    a.period_month,
    a.department_id,
    a.department_name,
    a.pc_allocation_id,
    a.pc_category_id,
    a.pc_category_name,
    a.pc_item_id,
    a.pc_item_name,
    a.sum_units,
    a.avg_unit_price,
    a.sum_items_cost,
    pc_budget.budget_units,
    pc_budget.budget_price,
    ((pc_budget.budget_units)::double precision * pc_budget.budget_price) AS budget_cost,
    (COALESCE(pc_budget.budget_units, 0) - a.sum_units) AS unit_diff,
    (COALESCE(((pc_budget.budget_units)::double precision * pc_budget.budget_price), (0)::double precision) - a.sum_items_cost) AS budget_diff
   FROM (( SELECT vw_pc_expenditure.period_id,
            vw_pc_expenditure.period_year,
            vw_pc_expenditure.period_month,
            vw_pc_expenditure.department_id,
            vw_pc_expenditure.department_name,
            vw_pc_expenditure.pc_allocation_id,
            vw_pc_expenditure.pc_category_id,
            vw_pc_expenditure.pc_category_name,
            vw_pc_expenditure.pc_item_id,
            vw_pc_expenditure.pc_item_name,
            sum(vw_pc_expenditure.units) AS sum_units,
            avg(vw_pc_expenditure.unit_price) AS avg_unit_price,
            sum(((vw_pc_expenditure.units)::double precision * vw_pc_expenditure.unit_price)) AS sum_items_cost
           FROM vw_pc_expenditure
          GROUP BY vw_pc_expenditure.period_id, vw_pc_expenditure.period_year, vw_pc_expenditure.period_month, vw_pc_expenditure.department_id, vw_pc_expenditure.department_name, vw_pc_expenditure.pc_allocation_id, vw_pc_expenditure.pc_category_id, vw_pc_expenditure.pc_category_name, vw_pc_expenditure.pc_item_id, vw_pc_expenditure.pc_item_name) a
     LEFT JOIN pc_budget ON (((a.pc_allocation_id = pc_budget.pc_allocation_id) AND (a.pc_item_id = pc_budget.pc_item_id))));


ALTER TABLE public.vws_pc_expenditure OWNER TO postgres;

--
-- Name: vws_pc_budget_diff; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vws_pc_budget_diff AS
 SELECT a.period_id,
    a.period_year,
    a.period_month,
    a.department_id,
    a.department_name,
    a.pc_allocation_id,
    a.pc_category_id,
    a.pc_category_name,
    a.pc_item_id,
    a.pc_item_name,
    a.sum_units,
    a.avg_unit_price,
    a.sum_items_cost,
    a.budget_units,
    a.budget_price,
    a.budget_cost,
    a.unit_diff,
    a.budget_diff
   FROM vws_pc_expenditure a
UNION
 SELECT a.period_id,
    a.period_year,
    a.period_month,
    a.department_id,
    a.department_name,
    a.pc_allocation_id,
    a.pc_category_id,
    a.pc_category_name,
    a.pc_item_id,
    a.pc_item_name,
    0 AS sum_units,
    0 AS avg_unit_price,
    0 AS sum_items_cost,
    a.budget_units,
    a.budget_price,
    a.budget_cost,
    a.budget_units AS unit_diff,
    a.budget_cost AS budget_diff
   FROM (vw_pc_budget a
     LEFT JOIN pc_expenditure ON (((a.pc_allocation_id = pc_expenditure.pc_allocation_id) AND (a.pc_item_id = pc_expenditure.pc_item_id))))
  WHERE (pc_expenditure.pc_item_id IS NULL);


ALTER TABLE public.vws_pc_budget_diff OWNER TO postgres;

--
-- Name: vws_tx_ledger; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW vws_tx_ledger AS
 SELECT vw_tx_ledger.org_id,
    vw_tx_ledger.ledger_period,
    vw_tx_ledger.ledger_year,
    vw_tx_ledger.ledger_month,
    sum(vw_tx_ledger.base_amount) AS sum_base_amount,
    sum(vw_tx_ledger.base_tax_amount) AS sum_base_tax_amount,
    sum(vw_tx_ledger.base_balance) AS sum_base_balance,
    sum(vw_tx_ledger.cleared_balance) AS sum_cleared_balance,
    sum(vw_tx_ledger.dr_amount) AS sum_dr_amount,
    sum(vw_tx_ledger.cr_amount) AS sum_cr_amount,
    to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text) AS start_date,
    (sum(vw_tx_ledger.base_amount) + prev_balance(to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text))) AS prev_balance_amount,
    (sum(vw_tx_ledger.cleared_balance) + prev_clear_balance(to_date((vw_tx_ledger.ledger_period || '.01'::text), 'YYYY.MM.DD'::text))) AS prev_clear_balance_amount
   FROM vw_tx_ledger
  GROUP BY vw_tx_ledger.org_id, vw_tx_ledger.ledger_period, vw_tx_ledger.ledger_year, vw_tx_ledger.ledger_month;


ALTER TABLE public.vws_tx_ledger OWNER TO postgres;

--
-- Name: workflow_logs; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE workflow_logs (
    workflow_log_id integer NOT NULL,
    org_id integer,
    table_name character varying(64),
    table_id integer,
    table_old_id integer
);


ALTER TABLE public.workflow_logs OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_logs_workflow_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_logs_workflow_log_id_seq OWNER TO postgres;

--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_logs_workflow_log_id_seq OWNED BY workflow_logs.workflow_log_id;


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_phases_workflow_phase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_phases_workflow_phase_id_seq OWNER TO postgres;

--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_phases_workflow_phase_id_seq OWNED BY workflow_phases.workflow_phase_id;


--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_sql_workflow_sql_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_sql_workflow_sql_id_seq OWNER TO postgres;

--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflow_sql_workflow_sql_id_seq OWNED BY workflow_sql.workflow_sql_id;


--
-- Name: workflow_table_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflow_table_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflow_table_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE workflows_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.workflows_workflow_id_seq OWNER TO postgres;

--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE workflows_workflow_id_seq OWNED BY workflows.workflow_id;


SET search_path = logs, pg_catalog;

--
-- Name: lg_account_activity_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_account_activity ALTER COLUMN lg_account_activity_id SET DEFAULT nextval('lg_account_activity_lg_account_activity_id_seq'::regclass);


--
-- Name: lg_collateral_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_collaterals ALTER COLUMN lg_collateral_id SET DEFAULT nextval('lg_collaterals_lg_collateral_id_seq'::regclass);


--
-- Name: lg_customer_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_customers ALTER COLUMN lg_customer_id SET DEFAULT nextval('lg_customers_lg_customer_id_seq'::regclass);


--
-- Name: lg_deposit_account_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_deposit_accounts ALTER COLUMN lg_deposit_account_id SET DEFAULT nextval('lg_deposit_accounts_lg_deposit_account_id_seq'::regclass);


--
-- Name: lg_guarantee_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_guarantees ALTER COLUMN lg_guarantee_id SET DEFAULT nextval('lg_guarantees_lg_guarantee_id_seq'::regclass);


--
-- Name: lg_loan_id; Type: DEFAULT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_loans ALTER COLUMN lg_loan_id SET DEFAULT nextval('lg_loans_lg_loan_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: account_activity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity ALTER COLUMN account_activity_id SET DEFAULT nextval('account_activity_account_activity_id_seq'::regclass);


--
-- Name: account_class_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_class ALTER COLUMN account_class_id SET DEFAULT nextval('account_class_account_class_id_seq'::regclass);


--
-- Name: account_defination_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations ALTER COLUMN account_defination_id SET DEFAULT nextval('account_definations_account_defination_id_seq'::regclass);


--
-- Name: account_note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_notes ALTER COLUMN account_note_id SET DEFAULT nextval('account_notes_account_note_id_seq'::regclass);


--
-- Name: account_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types ALTER COLUMN account_type_id SET DEFAULT nextval('account_types_account_type_id_seq'::regclass);


--
-- Name: account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts ALTER COLUMN account_id SET DEFAULT nextval('accounts_account_id_seq'::regclass);


--
-- Name: activity_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY activity_types ALTER COLUMN activity_type_id SET DEFAULT nextval('activity_types_activity_type_id_seq'::regclass);


--
-- Name: address_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address ALTER COLUMN address_id SET DEFAULT nextval('address_address_id_seq'::regclass);


--
-- Name: address_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types ALTER COLUMN address_type_id SET DEFAULT nextval('address_types_address_type_id_seq'::regclass);


--
-- Name: applicant_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants ALTER COLUMN applicant_id SET DEFAULT nextval('applicants_applicant_id_seq'::regclass);


--
-- Name: approval_checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists ALTER COLUMN approval_checklist_id SET DEFAULT nextval('approval_checklists_approval_checklist_id_seq'::regclass);


--
-- Name: approval_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals ALTER COLUMN approval_id SET DEFAULT nextval('approvals_approval_id_seq'::regclass);


--
-- Name: bank_account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts ALTER COLUMN bank_account_id SET DEFAULT nextval('bank_accounts_bank_account_id_seq'::regclass);


--
-- Name: bank_branch_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch ALTER COLUMN bank_branch_id SET DEFAULT nextval('bank_branch_bank_branch_id_seq'::regclass);


--
-- Name: bank_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks ALTER COLUMN bank_id SET DEFAULT nextval('banks_bank_id_seq'::regclass);


--
-- Name: bidder_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bidders ALTER COLUMN bidder_id SET DEFAULT nextval('bidders_bidder_id_seq'::regclass);


--
-- Name: budget_line_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines ALTER COLUMN budget_line_id SET DEFAULT nextval('budget_lines_budget_line_id_seq'::regclass);


--
-- Name: budget_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets ALTER COLUMN budget_id SET DEFAULT nextval('budgets_budget_id_seq'::regclass);


--
-- Name: checklist_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists ALTER COLUMN checklist_id SET DEFAULT nextval('checklists_checklist_id_seq'::regclass);


--
-- Name: collateral_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collateral_types ALTER COLUMN collateral_type_id SET DEFAULT nextval('collateral_types_collateral_type_id_seq'::regclass);


--
-- Name: collateral_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collaterals ALTER COLUMN collateral_id SET DEFAULT nextval('collaterals_collateral_id_seq'::regclass);


--
-- Name: contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contracts ALTER COLUMN contract_id SET DEFAULT nextval('contracts_contract_id_seq'::regclass);


--
-- Name: currency_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency ALTER COLUMN currency_id SET DEFAULT nextval('currency_currency_id_seq'::regclass);


--
-- Name: currency_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates ALTER COLUMN currency_rate_id SET DEFAULT nextval('currency_rates_currency_rate_id_seq'::regclass);


--
-- Name: customer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customers ALTER COLUMN customer_id SET DEFAULT nextval('customers_customer_id_seq'::regclass);


--
-- Name: default_account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts ALTER COLUMN default_account_id SET DEFAULT nextval('default_accounts_default_account_id_seq'::regclass);


--
-- Name: default_tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types ALTER COLUMN default_tax_type_id SET DEFAULT nextval('default_tax_types_default_tax_type_id_seq'::regclass);


--
-- Name: department_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments ALTER COLUMN department_id SET DEFAULT nextval('departments_department_id_seq'::regclass);


--
-- Name: deposit_account_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts ALTER COLUMN deposit_account_id SET DEFAULT nextval('deposit_accounts_deposit_account_id_seq'::regclass);


--
-- Name: e_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields ALTER COLUMN e_field_id SET DEFAULT nextval('e_fields_e_field_id_seq'::regclass);


--
-- Name: entity_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields ALTER COLUMN entity_field_id SET DEFAULT nextval('entity_fields_entity_field_id_seq'::regclass);


--
-- Name: entity_subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions ALTER COLUMN entity_subscription_id SET DEFAULT nextval('entity_subscriptions_entity_subscription_id_seq'::regclass);


--
-- Name: entity_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types ALTER COLUMN entity_type_id SET DEFAULT nextval('entity_types_entity_type_id_seq'::regclass);


--
-- Name: entity_value_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values ALTER COLUMN entity_value_id SET DEFAULT nextval('entity_values_entity_value_id_seq'::regclass);


--
-- Name: entity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys ALTER COLUMN entity_id SET DEFAULT nextval('entitys_entity_id_seq'::regclass);


--
-- Name: entry_form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms ALTER COLUMN entry_form_id SET DEFAULT nextval('entry_forms_entry_form_id_seq'::regclass);


--
-- Name: et_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY et_fields ALTER COLUMN et_field_id SET DEFAULT nextval('et_fields_et_field_id_seq'::regclass);


--
-- Name: field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields ALTER COLUMN field_id SET DEFAULT nextval('fields_field_id_seq'::regclass);


--
-- Name: fiscal_year_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fiscal_years ALTER COLUMN fiscal_year_id SET DEFAULT nextval('fiscal_years_fiscal_year_id_seq'::regclass);


--
-- Name: follow_up_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY follow_up ALTER COLUMN follow_up_id SET DEFAULT nextval('follow_up_follow_up_id_seq'::regclass);


--
-- Name: form_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms ALTER COLUMN form_id SET DEFAULT nextval('forms_form_id_seq'::regclass);


--
-- Name: gl_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls ALTER COLUMN gl_id SET DEFAULT nextval('gls_gl_id_seq'::regclass);


--
-- Name: guarantee_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guarantees ALTER COLUMN guarantee_id SET DEFAULT nextval('guarantees_guarantee_id_seq'::regclass);


--
-- Name: helpdesk_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk ALTER COLUMN helpdesk_id SET DEFAULT nextval('helpdesk_helpdesk_id_seq'::regclass);


--
-- Name: holiday_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays ALTER COLUMN holiday_id SET DEFAULT nextval('holidays_holiday_id_seq'::regclass);


--
-- Name: industry_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY industry ALTER COLUMN industry_id SET DEFAULT nextval('industry_industry_id_seq'::regclass);


--
-- Name: interest_method_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY interest_methods ALTER COLUMN interest_method_id SET DEFAULT nextval('interest_methods_interest_method_id_seq'::regclass);


--
-- Name: item_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_category ALTER COLUMN item_category_id SET DEFAULT nextval('item_category_item_category_id_seq'::regclass);


--
-- Name: item_unit_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_units ALTER COLUMN item_unit_id SET DEFAULT nextval('item_units_item_unit_id_seq'::regclass);


--
-- Name: item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items ALTER COLUMN item_id SET DEFAULT nextval('items_item_id_seq'::regclass);


--
-- Name: journal_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals ALTER COLUMN journal_id SET DEFAULT nextval('journals_journal_id_seq'::regclass);


--
-- Name: lead_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lead_items ALTER COLUMN lead_item_id SET DEFAULT nextval('lead_items_lead_item_id_seq'::regclass);


--
-- Name: lead_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY leads ALTER COLUMN lead_id SET DEFAULT nextval('leads_lead_id_seq'::regclass);


--
-- Name: ledger_link_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links ALTER COLUMN ledger_link_id SET DEFAULT nextval('ledger_links_ledger_link_id_seq'::regclass);


--
-- Name: ledger_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types ALTER COLUMN ledger_type_id SET DEFAULT nextval('ledger_types_ledger_type_id_seq'::regclass);


--
-- Name: loan_note_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_notes ALTER COLUMN loan_note_id SET DEFAULT nextval('loan_notes_loan_note_id_seq'::regclass);


--
-- Name: loan_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans ALTER COLUMN loan_id SET DEFAULT nextval('loans_loan_id_seq'::regclass);


--
-- Name: location_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations ALTER COLUMN location_id SET DEFAULT nextval('locations_location_id_seq'::regclass);


--
-- Name: mpesa_api_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mpesa_api ALTER COLUMN mpesa_api_id SET DEFAULT nextval('mpesa_api_mpesa_api_id_seq'::regclass);


--
-- Name: mpesa_trx_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mpesa_trxs ALTER COLUMN mpesa_trx_id SET DEFAULT nextval('mpesa_trxs_mpesa_trx_id_seq'::regclass);


--
-- Name: org_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs ALTER COLUMN org_id SET DEFAULT nextval('orgs_org_id_seq'::regclass);


--
-- Name: pc_allocation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_allocations ALTER COLUMN pc_allocation_id SET DEFAULT nextval('pc_allocations_pc_allocation_id_seq'::regclass);


--
-- Name: pc_banking_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_banking ALTER COLUMN pc_banking_id SET DEFAULT nextval('pc_banking_pc_banking_id_seq'::regclass);


--
-- Name: pc_budget_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_budget ALTER COLUMN pc_budget_id SET DEFAULT nextval('pc_budget_pc_budget_id_seq'::regclass);


--
-- Name: pc_category_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_category ALTER COLUMN pc_category_id SET DEFAULT nextval('pc_category_pc_category_id_seq'::regclass);


--
-- Name: pc_expenditure_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure ALTER COLUMN pc_expenditure_id SET DEFAULT nextval('pc_expenditure_pc_expenditure_id_seq'::regclass);


--
-- Name: pc_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_items ALTER COLUMN pc_item_id SET DEFAULT nextval('pc_items_pc_item_id_seq'::regclass);


--
-- Name: pc_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_types ALTER COLUMN pc_type_id SET DEFAULT nextval('pc_types_pc_type_id_seq'::regclass);


--
-- Name: pdefinition_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions ALTER COLUMN pdefinition_id SET DEFAULT nextval('pdefinitions_pdefinition_id_seq'::regclass);


--
-- Name: penalty_method_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty_methods ALTER COLUMN penalty_method_id SET DEFAULT nextval('penalty_methods_penalty_method_id_seq'::regclass);


--
-- Name: period_tax_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates ALTER COLUMN period_tax_rate_id SET DEFAULT nextval('period_tax_rates_period_tax_rate_id_seq'::regclass);


--
-- Name: period_tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types ALTER COLUMN period_tax_type_id SET DEFAULT nextval('period_tax_types_period_tax_type_id_seq'::regclass);


--
-- Name: period_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods ALTER COLUMN period_id SET DEFAULT nextval('periods_period_id_seq'::regclass);


--
-- Name: plevel_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY plevels ALTER COLUMN plevel_id SET DEFAULT nextval('plevels_plevel_id_seq'::regclass);


--
-- Name: product_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products ALTER COLUMN product_id SET DEFAULT nextval('products_product_id_seq'::regclass);


--
-- Name: ptype_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ptypes ALTER COLUMN ptype_id SET DEFAULT nextval('ptypes_ptype_id_seq'::regclass);


--
-- Name: quotation_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations ALTER COLUMN quotation_id SET DEFAULT nextval('quotations_quotation_id_seq'::regclass);


--
-- Name: reporting_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting ALTER COLUMN reporting_id SET DEFAULT nextval('reporting_reporting_id_seq'::regclass);


--
-- Name: sms_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sms ALTER COLUMN sms_id SET DEFAULT nextval('sms_sms_id_seq'::regclass);


--
-- Name: ss_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ss_items ALTER COLUMN ss_item_id SET DEFAULT nextval('ss_items_ss_item_id_seq'::regclass);


--
-- Name: ss_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ss_types ALTER COLUMN ss_type_id SET DEFAULT nextval('ss_types_ss_type_id_seq'::regclass);


--
-- Name: stock_line_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stock_lines ALTER COLUMN stock_line_id SET DEFAULT nextval('stock_lines_stock_line_id_seq'::regclass);


--
-- Name: stock_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stocks ALTER COLUMN stock_id SET DEFAULT nextval('stocks_stock_id_seq'::regclass);


--
-- Name: store_movement_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store_movement ALTER COLUMN store_movement_id SET DEFAULT nextval('store_movement_store_movement_id_seq'::regclass);


--
-- Name: store_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stores ALTER COLUMN store_id SET DEFAULT nextval('stores_store_id_seq'::regclass);


--
-- Name: sub_field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields ALTER COLUMN sub_field_id SET DEFAULT nextval('sub_fields_sub_field_id_seq'::regclass);


--
-- Name: subscription_level_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels ALTER COLUMN subscription_level_id SET DEFAULT nextval('subscription_levels_subscription_level_id_seq'::regclass);


--
-- Name: subscription_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions ALTER COLUMN subscription_id SET DEFAULT nextval('subscriptions_subscription_id_seq'::regclass);


--
-- Name: sys_audit_trail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_trail ALTER COLUMN sys_audit_trail_id SET DEFAULT nextval('sys_audit_trail_sys_audit_trail_id_seq'::regclass);


--
-- Name: sys_dashboard_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard ALTER COLUMN sys_dashboard_id SET DEFAULT nextval('sys_dashboard_sys_dashboard_id_seq'::regclass);


--
-- Name: sys_emailed_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed ALTER COLUMN sys_emailed_id SET DEFAULT nextval('sys_emailed_sys_emailed_id_seq'::regclass);


--
-- Name: sys_email_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails ALTER COLUMN sys_email_id SET DEFAULT nextval('sys_emails_sys_email_id_seq'::regclass);


--
-- Name: sys_error_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_errors ALTER COLUMN sys_error_id SET DEFAULT nextval('sys_errors_sys_error_id_seq'::regclass);


--
-- Name: sys_file_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files ALTER COLUMN sys_file_id SET DEFAULT nextval('sys_files_sys_file_id_seq'::regclass);


--
-- Name: sys_login_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins ALTER COLUMN sys_login_id SET DEFAULT nextval('sys_logins_sys_login_id_seq'::regclass);


--
-- Name: sys_menu_msg_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_menu_msg ALTER COLUMN sys_menu_msg_id SET DEFAULT nextval('sys_menu_msg_sys_menu_msg_id_seq'::regclass);


--
-- Name: sys_news_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news ALTER COLUMN sys_news_id SET DEFAULT nextval('sys_news_sys_news_id_seq'::regclass);


--
-- Name: sys_queries_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries ALTER COLUMN sys_queries_id SET DEFAULT nextval('sys_queries_sys_queries_id_seq'::regclass);


--
-- Name: sys_reset_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset ALTER COLUMN sys_reset_id SET DEFAULT nextval('sys_reset_sys_reset_id_seq'::regclass);


--
-- Name: tax_rate_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates ALTER COLUMN tax_rate_id SET DEFAULT nextval('tax_rates_tax_rate_id_seq'::regclass);


--
-- Name: tax_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types ALTER COLUMN tax_type_id SET DEFAULT nextval('tax_types_tax_type_id_seq'::regclass);


--
-- Name: tender_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tender_items ALTER COLUMN tender_item_id SET DEFAULT nextval('tender_items_tender_item_id_seq'::regclass);


--
-- Name: tender_type_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tender_types ALTER COLUMN tender_type_id SET DEFAULT nextval('tender_types_tender_type_id_seq'::regclass);


--
-- Name: tender_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tenders ALTER COLUMN tender_id SET DEFAULT nextval('tenders_tender_id_seq'::regclass);


--
-- Name: transaction_counter_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters ALTER COLUMN transaction_counter_id SET DEFAULT nextval('transaction_counters_transaction_counter_id_seq'::regclass);


--
-- Name: transaction_detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details ALTER COLUMN transaction_detail_id SET DEFAULT nextval('transaction_details_transaction_detail_id_seq'::regclass);


--
-- Name: transaction_link_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links ALTER COLUMN transaction_link_id SET DEFAULT nextval('transaction_links_transaction_link_id_seq'::regclass);


--
-- Name: transaction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions ALTER COLUMN transaction_id SET DEFAULT nextval('transactions_transaction_id_seq'::regclass);


--
-- Name: transfer_activity_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity ALTER COLUMN transfer_activity_id SET DEFAULT nextval('transfer_activity_transfer_activity_id_seq'::regclass);


--
-- Name: transfer_beneficiary_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_beneficiary ALTER COLUMN transfer_beneficiary_id SET DEFAULT nextval('transfer_beneficiary_transfer_beneficiary_id_seq'::regclass);


--
-- Name: workflow_log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs ALTER COLUMN workflow_log_id SET DEFAULT nextval('workflow_logs_workflow_log_id_seq'::regclass);


--
-- Name: workflow_phase_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases ALTER COLUMN workflow_phase_id SET DEFAULT nextval('workflow_phases_workflow_phase_id_seq'::regclass);


--
-- Name: workflow_sql_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql ALTER COLUMN workflow_sql_id SET DEFAULT nextval('workflow_sql_workflow_sql_id_seq'::regclass);


--
-- Name: workflow_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows ALTER COLUMN workflow_id SET DEFAULT nextval('workflows_workflow_id_seq'::regclass);


SET search_path = logs, pg_catalog;

--
-- Data for Name: lg_account_activity; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_account_activity_lg_account_activity_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_account_activity_lg_account_activity_id_seq', 1, false);


--
-- Data for Name: lg_collaterals; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_collaterals_lg_collateral_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_collaterals_lg_collateral_id_seq', 1, false);


--
-- Data for Name: lg_customers; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_customers_lg_customer_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_customers_lg_customer_id_seq', 1, false);


--
-- Data for Name: lg_deposit_accounts; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_deposit_accounts_lg_deposit_account_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_deposit_accounts_lg_deposit_account_id_seq', 1, false);


--
-- Data for Name: lg_guarantees; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_guarantees_lg_guarantee_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_guarantees_lg_guarantee_id_seq', 1, false);


--
-- Data for Name: lg_loans; Type: TABLE DATA; Schema: logs; Owner: postgres
--



--
-- Name: lg_loans_lg_loan_id_seq; Type: SEQUENCE SET; Schema: logs; Owner: postgres
--

SELECT pg_catalog.setval('lg_loans_lg_loan_id_seq', 1, false);


SET search_path = public, pg_catalog;

--
-- Data for Name: account_activity; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: account_activity_account_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_activity_account_activity_id_seq', 1, false);


--
-- Data for Name: account_class; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO account_class VALUES (10, 10, 0, 1, 'ASSETS', 'FIXED ASSETS', NULL);
INSERT INTO account_class VALUES (20, 20, 0, 1, 'ASSETS', 'INTANGIBLE ASSETS', NULL);
INSERT INTO account_class VALUES (30, 30, 0, 1, 'ASSETS', 'CURRENT ASSETS', NULL);
INSERT INTO account_class VALUES (40, 40, 0, 2, 'LIABILITIES', 'CURRENT LIABILITIES', NULL);
INSERT INTO account_class VALUES (50, 50, 0, 2, 'LIABILITIES', 'LONG TERM LIABILITIES', NULL);
INSERT INTO account_class VALUES (60, 60, 0, 3, 'EQUITY', 'EQUITY AND RESERVES', NULL);
INSERT INTO account_class VALUES (70, 70, 0, 4, 'REVENUE', 'REVENUE AND OTHER INCOME', NULL);
INSERT INTO account_class VALUES (80, 80, 0, 5, 'COST OF REVENUE', 'COST OF REVENUE', NULL);
INSERT INTO account_class VALUES (90, 90, 0, 6, 'EXPENSES', 'EXPENSES', NULL);
INSERT INTO account_class VALUES (100, 90, 1, 6, 'EXPENSES', 'EXPENSES', NULL);
INSERT INTO account_class VALUES (101, 80, 1, 5, 'COST OF REVENUE', 'COST OF REVENUE', NULL);
INSERT INTO account_class VALUES (102, 70, 1, 4, 'REVENUE', 'REVENUE AND OTHER INCOME', NULL);
INSERT INTO account_class VALUES (103, 60, 1, 3, 'EQUITY', 'EQUITY AND RESERVES', NULL);
INSERT INTO account_class VALUES (104, 50, 1, 2, 'LIABILITIES', 'LONG TERM LIABILITIES', NULL);
INSERT INTO account_class VALUES (105, 40, 1, 2, 'LIABILITIES', 'CURRENT LIABILITIES', NULL);
INSERT INTO account_class VALUES (106, 30, 1, 1, 'ASSETS', 'CURRENT ASSETS', NULL);
INSERT INTO account_class VALUES (107, 20, 1, 1, 'ASSETS', 'INTANGIBLE ASSETS', NULL);
INSERT INTO account_class VALUES (108, 10, 1, 1, 'ASSETS', 'FIXED ASSETS', NULL);


--
-- Name: account_class_account_class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_class_account_class_id_seq', 108, true);


--
-- Data for Name: account_definations; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO account_definations VALUES (1, 0, 2, 1, 1, 0, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (2, 0, 3, 1, 1, 0, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (3, 0, 4, 1, 1, 0, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (4, 0, 5, 1, 1, 0, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (5, 0, 6, 1, 1, 0, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (6, 0, 7, 1, 1, 0, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (7, 1, 2, 1, 1, 0, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (8, 1, 3, 1, 1, 0, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (9, 1, 4, 1, 1, 0, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (10, 1, 5, 1, 1, 0, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (11, 1, 6, 1, 1, 0, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (12, 1, 7, 1, 1, 0, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (13, 1, 12, 22, 1, 0, 'Transfer', '2017-01-01', NULL, 0, 1, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (14, 1, 21, 1, 1, 0, 'Opening account', '2017-01-01', NULL, 1000, 0, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (15, 2, 21, 1, 1, 0, 'Opening account', '2017-01-01', NULL, 2000, 0, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (16, 2, 11, 1, 1, 0, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (17, 2, 10, 1, 1, 0, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (18, 3, 2, 1, 1, 0, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (19, 3, 3, 1, 1, 0, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (20, 3, 4, 1, 1, 0, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (21, 3, 5, 1, 1, 0, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (22, 3, 6, 1, 1, 0, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (23, 3, 7, 1, 1, 0, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (24, 3, 12, 22, 1, 0, 'Transfer', '2017-01-01', NULL, 0, 1, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (25, 4, 21, 1, 1, 0, 'Opening account', '2017-01-01', NULL, 1500, 0, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (26, 4, 11, 1, 1, 0, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (27, 4, 10, 1, 1, 0, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (28, 5, 21, 1, 1, 0, 'Opening account', '2017-01-01', NULL, 1500, 0, true, true, '400000002', NULL);
INSERT INTO account_definations VALUES (29, 5, 11, 1, 1, 0, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (30, 5, 10, 1, 1, 0, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '400000001', NULL);
INSERT INTO account_definations VALUES (31, 11, 37, 23, 1, 1, 'Opening account', '2017-01-01', NULL, 1500, 0, true, true, '2', NULL);
INSERT INTO account_definations VALUES (32, 10, 37, 23, 1, 1, 'Opening account', '2017-01-01', NULL, 1500, 0, true, true, '2', NULL);
INSERT INTO account_definations VALUES (33, 8, 37, 23, 1, 1, 'Opening account', '2017-01-01', NULL, 2000, 0, true, true, '2', NULL);
INSERT INTO account_definations VALUES (34, 7, 37, 23, 1, 1, 'Opening account', '2017-01-01', NULL, 1000, 0, true, true, '2', NULL);
INSERT INTO account_definations VALUES (35, 9, 34, 38, 1, 1, 'Transfer', '2017-01-01', NULL, 0, 1, true, true, '2', NULL);
INSERT INTO account_definations VALUES (36, 7, 34, 38, 1, 1, 'Transfer', '2017-01-01', NULL, 0, 1, true, true, '2', NULL);
INSERT INTO account_definations VALUES (37, 11, 33, 23, 1, 1, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (38, 10, 33, 23, 1, 1, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (39, 8, 33, 23, 1, 1, 'Loan Disbursement', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (40, 11, 32, 23, 1, 1, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (41, 10, 32, 23, 1, 1, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (42, 8, 32, 23, 1, 1, 'Loan Payment', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (43, 9, 29, 23, 1, 1, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (44, 7, 29, 23, 1, 1, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (45, 6, 29, 23, 1, 1, 'MPESA Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (46, 9, 28, 23, 1, 1, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (47, 7, 28, 23, 1, 1, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (48, 6, 28, 23, 1, 1, 'Cheque Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (49, 9, 27, 23, 1, 1, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (50, 7, 27, 23, 1, 1, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (51, 6, 27, 23, 1, 1, 'Cash Withdraw', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (52, 9, 26, 23, 1, 1, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (53, 7, 26, 23, 1, 1, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (54, 6, 26, 23, 1, 1, 'MPESA Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (55, 9, 25, 23, 1, 1, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (56, 7, 25, 23, 1, 1, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (57, 6, 25, 23, 1, 1, 'Cheque Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (58, 9, 24, 23, 1, 1, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (59, 7, 24, 23, 1, 1, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);
INSERT INTO account_definations VALUES (60, 6, 24, 23, 1, 1, 'Cash Deposit', '2017-01-01', NULL, 0, 0, false, true, '1', NULL);


--
-- Name: account_definations_account_defination_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_definations_account_defination_id_seq', 60, true);


--
-- Data for Name: account_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: account_notes_account_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_notes_account_note_id_seq', 1, false);


--
-- Data for Name: account_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO account_types VALUES (100, 100, 10, 0, 'COST', NULL);
INSERT INTO account_types VALUES (110, 110, 10, 0, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types VALUES (200, 200, 20, 0, 'COST', NULL);
INSERT INTO account_types VALUES (210, 210, 20, 0, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types VALUES (300, 300, 30, 0, 'DEBTORS', NULL);
INSERT INTO account_types VALUES (310, 310, 30, 0, 'INVESTMENTS', NULL);
INSERT INTO account_types VALUES (320, 320, 30, 0, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types VALUES (330, 330, 30, 0, 'CASH ON HAND', NULL);
INSERT INTO account_types VALUES (340, 340, 30, 0, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types VALUES (400, 400, 40, 0, 'CREDITORS', NULL);
INSERT INTO account_types VALUES (410, 410, 40, 0, 'ADVANCED BILLING', NULL);
INSERT INTO account_types VALUES (420, 420, 40, 0, 'TAX', NULL);
INSERT INTO account_types VALUES (430, 430, 40, 0, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types VALUES (500, 500, 50, 0, 'LOANS', NULL);
INSERT INTO account_types VALUES (600, 600, 60, 0, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types VALUES (610, 610, 60, 0, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types VALUES (700, 700, 70, 0, 'SALES REVENUE', NULL);
INSERT INTO account_types VALUES (710, 710, 70, 0, 'OTHER INCOME', NULL);
INSERT INTO account_types VALUES (800, 800, 80, 0, 'COST OF REVENUE', NULL);
INSERT INTO account_types VALUES (900, 900, 90, 0, 'STAFF COSTS', NULL);
INSERT INTO account_types VALUES (905, 905, 90, 0, 'COMMUNICATIONS', NULL);
INSERT INTO account_types VALUES (910, 910, 90, 0, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types VALUES (915, 915, 90, 0, 'TRANSPORT', NULL);
INSERT INTO account_types VALUES (920, 920, 90, 0, 'TRAVEL', NULL);
INSERT INTO account_types VALUES (925, 925, 90, 0, 'POSTAL and COURIER', NULL);
INSERT INTO account_types VALUES (930, 930, 90, 0, 'ICT PROJECT', NULL);
INSERT INTO account_types VALUES (935, 935, 90, 0, 'STATIONERY', NULL);
INSERT INTO account_types VALUES (940, 940, 90, 0, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types VALUES (945, 945, 90, 0, 'REPAIRS', NULL);
INSERT INTO account_types VALUES (950, 950, 90, 0, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types VALUES (955, 955, 90, 0, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types VALUES (960, 960, 90, 0, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types VALUES (965, 965, 90, 0, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types VALUES (970, 970, 90, 0, 'DEPRECIATION', NULL);
INSERT INTO account_types VALUES (975, 975, 90, 0, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types VALUES (980, 980, 90, 0, 'FINANCE COSTS', NULL);
INSERT INTO account_types VALUES (985, 985, 90, 0, 'TAXES', NULL);
INSERT INTO account_types VALUES (990, 990, 90, 0, 'INSURANCE', NULL);
INSERT INTO account_types VALUES (995, 995, 90, 0, 'OTHER EXPENSES', NULL);
INSERT INTO account_types VALUES (1000, 110, 108, 1, 'ACCUMULATED DEPRECIATION', NULL);
INSERT INTO account_types VALUES (1001, 100, 108, 1, 'COST', NULL);
INSERT INTO account_types VALUES (1002, 210, 107, 1, 'ACCUMULATED AMORTISATION', NULL);
INSERT INTO account_types VALUES (1003, 200, 107, 1, 'COST', NULL);
INSERT INTO account_types VALUES (1004, 340, 106, 1, 'PRE-PAYMMENTS', NULL);
INSERT INTO account_types VALUES (1005, 330, 106, 1, 'CASH ON HAND', NULL);
INSERT INTO account_types VALUES (1006, 320, 106, 1, 'CURRENT BANK ACCOUNTS', NULL);
INSERT INTO account_types VALUES (1007, 310, 106, 1, 'INVESTMENTS', NULL);
INSERT INTO account_types VALUES (1008, 300, 106, 1, 'DEBTORS', NULL);
INSERT INTO account_types VALUES (1009, 430, 105, 1, 'WITHHOLDING TAX', NULL);
INSERT INTO account_types VALUES (1010, 420, 105, 1, 'TAX', NULL);
INSERT INTO account_types VALUES (1011, 410, 105, 1, 'ADVANCED BILLING', NULL);
INSERT INTO account_types VALUES (1012, 400, 105, 1, 'CREDITORS', NULL);
INSERT INTO account_types VALUES (1013, 500, 104, 1, 'LOANS', NULL);
INSERT INTO account_types VALUES (1014, 610, 103, 1, 'ACCUMULATED SURPLUS', NULL);
INSERT INTO account_types VALUES (1015, 600, 103, 1, 'CAPITAL GRANTS', NULL);
INSERT INTO account_types VALUES (1016, 710, 102, 1, 'OTHER INCOME', NULL);
INSERT INTO account_types VALUES (1017, 700, 102, 1, 'SALES REVENUE', NULL);
INSERT INTO account_types VALUES (1018, 800, 101, 1, 'COST OF REVENUE', NULL);
INSERT INTO account_types VALUES (1019, 995, 100, 1, 'OTHER EXPENSES', NULL);
INSERT INTO account_types VALUES (1020, 990, 100, 1, 'INSURANCE', NULL);
INSERT INTO account_types VALUES (1021, 985, 100, 1, 'TAXES', NULL);
INSERT INTO account_types VALUES (1022, 980, 100, 1, 'FINANCE COSTS', NULL);
INSERT INTO account_types VALUES (1023, 975, 100, 1, 'CORPORATE SOCIAL INVESTMENT', NULL);
INSERT INTO account_types VALUES (1024, 970, 100, 1, 'DEPRECIATION', NULL);
INSERT INTO account_types VALUES (1025, 965, 100, 1, 'STRATEGIC PLANNING', NULL);
INSERT INTO account_types VALUES (1026, 960, 100, 1, 'MARKETING EXPENSES', NULL);
INSERT INTO account_types VALUES (1027, 955, 100, 1, 'OFFICE EXPENSES', NULL);
INSERT INTO account_types VALUES (1028, 950, 100, 1, 'PROFESSIONAL FEES', NULL);
INSERT INTO account_types VALUES (1029, 945, 100, 1, 'REPAIRS', NULL);
INSERT INTO account_types VALUES (1030, 940, 100, 1, 'SUBSCRIPTION FEES', NULL);
INSERT INTO account_types VALUES (1031, 935, 100, 1, 'STATIONERY', NULL);
INSERT INTO account_types VALUES (1032, 930, 100, 1, 'ICT PROJECT', NULL);
INSERT INTO account_types VALUES (1033, 925, 100, 1, 'POSTAL and COURIER', NULL);
INSERT INTO account_types VALUES (1034, 920, 100, 1, 'TRAVEL', NULL);
INSERT INTO account_types VALUES (1035, 915, 100, 1, 'TRANSPORT', NULL);
INSERT INTO account_types VALUES (1036, 910, 100, 1, 'DIRECTORS ALLOWANCES', NULL);
INSERT INTO account_types VALUES (1037, 905, 100, 1, 'COMMUNICATIONS', NULL);
INSERT INTO account_types VALUES (1038, 900, 100, 1, 'STAFF COSTS', NULL);


--
-- Name: account_types_account_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('account_types_account_type_id_seq', 1038, true);


--
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO accounts VALUES (10000, 10000, 100, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (10005, 10005, 100, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (11000, 11000, 110, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (11005, 11005, 110, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (20000, 20000, 200, 0, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (20005, 20005, 200, 0, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts VALUES (20010, 20010, 200, 0, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts VALUES (21000, 21000, 210, 0, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts VALUES (30000, 30000, 300, 0, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (30005, 30005, 300, 0, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (30010, 30010, 300, 0, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (30015, 30015, 300, 0, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (30020, 30020, 300, 0, 'INVENTORY', false, true, NULL);
INSERT INTO accounts VALUES (30025, 30025, 300, 0, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts VALUES (30030, 30030, 300, 0, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (31005, 31005, 310, 0, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts VALUES (32000, 32000, 320, 0, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts VALUES (32005, 32005, 320, 0, 'MPESA', false, true, NULL);
INSERT INTO accounts VALUES (33000, 33000, 330, 0, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (33005, 33005, 330, 0, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts VALUES (34000, 34000, 340, 0, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts VALUES (34005, 34005, 340, 0, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts VALUES (34010, 34010, 340, 0, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts VALUES (34015, 34015, 340, 0, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts VALUES (40000, 40000, 400, 0, 'TRADE CREDITORS', false, true, NULL);
INSERT INTO accounts VALUES (40005, 40005, 400, 0, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts VALUES (40010, 40010, 400, 0, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts VALUES (40015, 40015, 400, 0, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts VALUES (40020, 40020, 400, 0, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts VALUES (40025, 40025, 400, 0, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts VALUES (40030, 40030, 400, 0, 'NSSF', false, true, NULL);
INSERT INTO accounts VALUES (40035, 40035, 400, 0, 'NHIF', false, true, NULL);
INSERT INTO accounts VALUES (40040, 40040, 400, 0, 'HELB', false, true, NULL);
INSERT INTO accounts VALUES (40045, 40045, 400, 0, 'PAYE', false, true, NULL);
INSERT INTO accounts VALUES (40050, 40050, 400, 0, 'PENSION', false, true, NULL);
INSERT INTO accounts VALUES (40055, 40055, 400, 0, 'PAYROLL LIABILITIES', false, true, NULL);
INSERT INTO accounts VALUES (41000, 41000, 410, 0, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts VALUES (42000, 42000, 420, 0, 'Value Added Tax (VAT)', false, true, NULL);
INSERT INTO accounts VALUES (42010, 42010, 420, 0, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts VALUES (43000, 43000, 430, 0, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts VALUES (50000, 50000, 500, 0, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts VALUES (60000, 60000, 600, 0, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts VALUES (60005, 60005, 600, 0, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts VALUES (60010, 60010, 600, 0, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts VALUES (61000, 61000, 610, 0, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts VALUES (61005, 61005, 610, 0, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts VALUES (61010, 61010, 610, 0, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts VALUES (70005, 70005, 700, 0, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts VALUES (70010, 70010, 700, 0, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts VALUES (70015, 70015, 700, 0, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts VALUES (70020, 70020, 700, 0, 'CHARGES INCOME', false, true, NULL);
INSERT INTO accounts VALUES (70025, 70025, 700, 0, 'PENALTY INCOME', false, true, NULL);
INSERT INTO accounts VALUES (71000, 71000, 710, 0, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts VALUES (71005, 71005, 710, 0, 'DONATION', false, true, NULL);
INSERT INTO accounts VALUES (71010, 71010, 710, 0, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts VALUES (71015, 71015, 710, 0, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts VALUES (71020, 71020, 710, 0, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (71025, 71025, 710, 0, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts VALUES (71030, 71030, 710, 0, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts VALUES (71035, 71035, 710, 0, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts VALUES (80000, 80000, 800, 0, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts VALUES (90000, 90000, 900, 0, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts VALUES (90005, 90005, 900, 0, 'STAFF ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (90010, 90010, 900, 0, 'AIRTIME', false, true, NULL);
INSERT INTO accounts VALUES (90012, 90012, 900, 0, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts VALUES (90015, 90015, 900, 0, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts VALUES (90020, 90020, 900, 0, 'EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts VALUES (90025, 90025, 900, 0, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts VALUES (90035, 90035, 900, 0, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (90040, 90040, 900, 0, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (90045, 90045, 900, 0, 'BONUSES', false, true, NULL);
INSERT INTO accounts VALUES (90050, 90050, 900, 0, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts VALUES (90055, 90055, 900, 0, 'WELFARE', false, true, NULL);
INSERT INTO accounts VALUES (90056, 90056, 900, 0, 'STAFF WELLFARE: CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (90060, 90060, 900, 0, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts VALUES (90065, 90065, 900, 0, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts VALUES (90070, 90070, 900, 0, 'STAFF EXPENDITURE', false, true, NULL);
INSERT INTO accounts VALUES (90075, 90075, 900, 0, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts VALUES (90500, 90500, 905, 0, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts VALUES (90505, 90505, 905, 0, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts VALUES (90510, 90510, 905, 0, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts VALUES (90515, 90515, 905, 0, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts VALUES (90520, 90520, 905, 0, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts VALUES (91000, 91000, 910, 0, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (91005, 91005, 910, 0, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts VALUES (91010, 91010, 910, 0, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts VALUES (91500, 91500, 915, 0, 'CAB FARE', false, true, NULL);
INSERT INTO accounts VALUES (91505, 91505, 915, 0, 'FUEL', false, true, NULL);
INSERT INTO accounts VALUES (91510, 91510, 915, 0, 'BUS FARE', false, true, NULL);
INSERT INTO accounts VALUES (91515, 91515, 915, 0, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts VALUES (92000, 92000, 920, 0, 'TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (92005, 92005, 920, 0, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts VALUES (92505, 92505, 925, 0, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts VALUES (92510, 92510, 925, 0, 'COURIER', false, true, NULL);
INSERT INTO accounts VALUES (93000, 93000, 930, 0, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (93010, 93010, 930, 0, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts VALUES (93500, 93500, 935, 0, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts VALUES (93505, 93505, 935, 0, 'PAPER', false, true, NULL);
INSERT INTO accounts VALUES (93510, 93510, 935, 0, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (93515, 93515, 935, 0, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts VALUES (93520, 93520, 935, 0, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts VALUES (94010, 94010, 940, 0, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts VALUES (94015, 94015, 940, 0, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts VALUES (94500, 94500, 945, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (94505, 94505, 945, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (94510, 94510, 945, 0, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts VALUES (95000, 95000, 950, 0, 'AUDIT', false, true, NULL);
INSERT INTO accounts VALUES (95005, 95005, 950, 0, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts VALUES (95010, 95010, 950, 0, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts VALUES (95015, 95015, 950, 0, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts VALUES (95020, 95020, 950, 0, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts VALUES (95025, 95025, 950, 0, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts VALUES (95030, 95030, 950, 0, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts VALUES (95035, 95035, 950, 0, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts VALUES (95040, 95040, 950, 0, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts VALUES (95045, 95045, 950, 0, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts VALUES (95500, 95500, 955, 0, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts VALUES (95502, 95502, 955, 0, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts VALUES (95505, 95505, 955, 0, 'CLEANING', false, true, NULL);
INSERT INTO accounts VALUES (95510, 95510, 955, 0, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts VALUES (95515, 95515, 955, 0, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (95520, 95520, 955, 0, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts VALUES (96005, 96005, 960, 0, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts VALUES (96505, 96505, 965, 0, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts VALUES (96510, 96510, 965, 0, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts VALUES (97000, 97000, 970, 0, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (97005, 97005, 970, 0, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (97010, 97010, 970, 0, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (97500, 97500, 975, 0, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts VALUES (97505, 97505, 975, 0, 'DONATION', false, true, NULL);
INSERT INTO accounts VALUES (98000, 98000, 980, 0, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts VALUES (98005, 98005, 980, 0, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts VALUES (98010, 98010, 980, 0, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts VALUES (98015, 98015, 980, 0, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts VALUES (98020, 98020, 980, 0, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts VALUES (98025, 98025, 980, 0, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts VALUES (98030, 98030, 980, 0, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts VALUES (98035, 98035, 980, 0, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts VALUES (98040, 98040, 980, 0, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts VALUES (98500, 98500, 985, 0, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts VALUES (98505, 98505, 985, 0, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts VALUES (98510, 98510, 985, 0, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts VALUES (98515, 98515, 985, 0, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts VALUES (99000, 99000, 990, 0, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts VALUES (99005, 99005, 990, 0, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts VALUES (99010, 99010, 990, 0, 'BURGLARY', false, true, NULL);
INSERT INTO accounts VALUES (99015, 99015, 990, 0, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts VALUES (99500, 99500, 995, 0, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts VALUES (99505, 99505, 995, 0, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (99510, 99510, 995, 0, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts VALUES (99515, 99515, 995, 0, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts VALUES (99999, 99999, 995, 0, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts VALUES (100000, 90075, 1038, 1, 'GROUP LIFE INSURANCE', false, true, NULL);
INSERT INTO accounts VALUES (100001, 90070, 1038, 1, 'STAFF EXPENDITURE', false, true, NULL);
INSERT INTO accounts VALUES (100002, 90065, 1038, 1, 'GROUP PERSONAL ACCIDENT AND WIBA', false, true, NULL);
INSERT INTO accounts VALUES (100003, 90060, 1038, 1, 'MEDICAL INSURANCE', false, true, NULL);
INSERT INTO accounts VALUES (100004, 90056, 1038, 1, 'STAFF WELLFARE: CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (100005, 90055, 1038, 1, 'WELFARE', false, true, NULL);
INSERT INTO accounts VALUES (100006, 90050, 1038, 1, 'LEAVE ACCRUAL', false, true, NULL);
INSERT INTO accounts VALUES (100007, 90045, 1038, 1, 'BONUSES', false, true, NULL);
INSERT INTO accounts VALUES (100008, 90040, 1038, 1, 'INTERNSHIP ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (100009, 90035, 1038, 1, 'CAPACITY BUILDING - TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (100010, 90025, 1038, 1, 'NSSF EMPLOYER CONTRIBUTION', false, true, NULL);
INSERT INTO accounts VALUES (100011, 90020, 1038, 1, 'EMPLOYER PENSION CONTRIBUTION', false, true, NULL);
INSERT INTO accounts VALUES (100012, 90015, 1038, 1, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts VALUES (100013, 90012, 1038, 1, 'TRANSPORT ALLOWANCE', false, true, NULL);
INSERT INTO accounts VALUES (100014, 90010, 1038, 1, 'AIRTIME', false, true, NULL);
INSERT INTO accounts VALUES (100015, 90005, 1038, 1, 'STAFF ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (100016, 90000, 1038, 1, 'BASIC SALARY', false, true, NULL);
INSERT INTO accounts VALUES (100017, 90520, 1037, 1, 'LEASE LINE', false, true, NULL);
INSERT INTO accounts VALUES (100018, 90515, 1037, 1, 'REMOTE ACCESS', false, true, NULL);
INSERT INTO accounts VALUES (100019, 90510, 1037, 1, 'LEASE LINES', false, true, NULL);
INSERT INTO accounts VALUES (100020, 90505, 1037, 1, 'CALLING CARDS', false, true, NULL);
INSERT INTO accounts VALUES (100021, 90500, 1037, 1, 'FIXED LINES', false, true, NULL);
INSERT INTO accounts VALUES (100022, 91010, 1036, 1, 'WORKSHOPS and SEMINARS', false, true, NULL);
INSERT INTO accounts VALUES (100023, 91005, 1036, 1, 'HONORARIUM', false, true, NULL);
INSERT INTO accounts VALUES (100024, 91000, 1036, 1, 'SITTING ALLOWANCES', false, true, NULL);
INSERT INTO accounts VALUES (100025, 91515, 1035, 1, 'POSTAGE and BOX RENTAL', false, true, NULL);
INSERT INTO accounts VALUES (100026, 91510, 1035, 1, 'BUS FARE', false, true, NULL);
INSERT INTO accounts VALUES (100027, 91505, 1035, 1, 'FUEL', false, true, NULL);
INSERT INTO accounts VALUES (100028, 91500, 1035, 1, 'CAB FARE', false, true, NULL);
INSERT INTO accounts VALUES (100029, 92005, 1034, 1, 'BUSINESS PROSPECTING', false, true, NULL);
INSERT INTO accounts VALUES (100030, 92000, 1034, 1, 'TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (100031, 92510, 1033, 1, 'COURIER', false, true, NULL);
INSERT INTO accounts VALUES (100032, 92505, 1033, 1, 'DIRECTORY LISTING', false, true, NULL);
INSERT INTO accounts VALUES (100033, 93010, 1032, 1, 'COMPUTER SUPPORT', false, true, NULL);
INSERT INTO accounts VALUES (100034, 93000, 1032, 1, 'IP TRAINING', false, true, NULL);
INSERT INTO accounts VALUES (100035, 93520, 1031, 1, 'COMPUTER ACCESSORIES', false, true, NULL);
INSERT INTO accounts VALUES (100036, 93515, 1031, 1, 'TONER and CATRIDGE', false, true, NULL);
INSERT INTO accounts VALUES (100037, 93510, 1031, 1, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (100038, 93505, 1031, 1, 'PAPER', false, true, NULL);
INSERT INTO accounts VALUES (100039, 93500, 1031, 1, 'PRINTED MATTER', false, true, NULL);
INSERT INTO accounts VALUES (100040, 94015, 1030, 1, 'SYSTEM SUPPORT FEES', false, true, NULL);
INSERT INTO accounts VALUES (100041, 94010, 1030, 1, 'LICENSE FEE', false, true, NULL);
INSERT INTO accounts VALUES (100042, 94510, 1029, 1, 'JANITORIAL', false, true, NULL);
INSERT INTO accounts VALUES (100043, 94505, 1029, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (100044, 94500, 1029, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (100045, 95045, 1028, 1, 'SEMINARS, WORKSHOPS and MEETINGS', false, true, NULL);
INSERT INTO accounts VALUES (100046, 95040, 1028, 1, 'ANNUAL GENERAL MEETING', false, true, NULL);
INSERT INTO accounts VALUES (100047, 95035, 1028, 1, 'RECRUITMENT', false, true, NULL);
INSERT INTO accounts VALUES (100048, 95030, 1028, 1, 'PROMOTIONAL MATERIALS', false, true, NULL);
INSERT INTO accounts VALUES (100049, 95025, 1028, 1, 'MARKETING CAMPAIGN', false, true, NULL);
INSERT INTO accounts VALUES (100050, 95020, 1028, 1, 'TAX CONSULTANCY', false, true, NULL);
INSERT INTO accounts VALUES (100051, 95015, 1028, 1, 'CONSULTANCY', false, true, NULL);
INSERT INTO accounts VALUES (100052, 95010, 1028, 1, 'ADVERTISING', false, true, NULL);
INSERT INTO accounts VALUES (100053, 95005, 1028, 1, 'MARKETING AGENCY', false, true, NULL);
INSERT INTO accounts VALUES (100054, 95000, 1028, 1, 'AUDIT', false, true, NULL);
INSERT INTO accounts VALUES (100055, 95520, 1027, 1, 'ADMINISTRATIVE EXPENSES', false, true, NULL);
INSERT INTO accounts VALUES (100056, 95515, 1027, 1, 'OTHER CONSUMABLES', false, true, NULL);
INSERT INTO accounts VALUES (100057, 95510, 1027, 1, 'NEWSPAPERS', false, true, NULL);
INSERT INTO accounts VALUES (100058, 95505, 1027, 1, 'CLEANING', false, true, NULL);
INSERT INTO accounts VALUES (100059, 95502, 1027, 1, 'OFFICE COSTS', false, true, NULL);
INSERT INTO accounts VALUES (100060, 95500, 1027, 1, 'OFFICE RENT', false, true, NULL);
INSERT INTO accounts VALUES (100061, 96005, 1026, 1, 'WEBSITE REVAMPING COSTS', false, true, NULL);
INSERT INTO accounts VALUES (100062, 96510, 1025, 1, 'MONITORING and EVALUATION', false, true, NULL);
INSERT INTO accounts VALUES (100063, 96505, 1025, 1, 'STRATEGIC PLANNING', false, true, NULL);
INSERT INTO accounts VALUES (100064, 97010, 1024, 1, 'AMMORTISATION OF INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (100065, 97005, 1024, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (100066, 97000, 1024, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (100067, 97505, 1023, 1, 'DONATION', false, true, NULL);
INSERT INTO accounts VALUES (100068, 97500, 1023, 1, 'CORPORATE SOCIAL INVESTMENT', false, true, NULL);
INSERT INTO accounts VALUES (100069, 98040, 1022, 1, 'PROFESSIONAL FEES: MANAGEMENT FEES', false, true, NULL);
INSERT INTO accounts VALUES (100070, 98035, 1022, 1, 'CUSTODY FEES', false, true, NULL);
INSERT INTO accounts VALUES (100071, 98030, 1022, 1, 'MPESA TRANSFERS', false, true, NULL);
INSERT INTO accounts VALUES (100072, 98025, 1022, 1, 'SAFETY DEPOSIT BOX', false, true, NULL);
INSERT INTO accounts VALUES (100073, 98020, 1022, 1, 'UPCOUNTRY CHEQUES', false, true, NULL);
INSERT INTO accounts VALUES (100074, 98015, 1022, 1, 'SALARY TRANSFERS', false, true, NULL);
INSERT INTO accounts VALUES (100075, 98010, 1022, 1, 'OTHER FEES', false, true, NULL);
INSERT INTO accounts VALUES (100076, 98005, 1022, 1, 'BOUNCED CHEQUE CHARGES', false, true, NULL);
INSERT INTO accounts VALUES (100077, 98000, 1022, 1, 'LEDGER FEES', false, true, NULL);
INSERT INTO accounts VALUES (100078, 98515, 1021, 1, 'FRINGE BENEFIT TAX', false, true, NULL);
INSERT INTO accounts VALUES (100079, 98510, 1021, 1, 'CORPORATE TAX', false, true, NULL);
INSERT INTO accounts VALUES (100080, 98505, 1021, 1, 'FINES and PENALTIES', false, true, NULL);
INSERT INTO accounts VALUES (100081, 98500, 1021, 1, 'EXCISE DUTY', false, true, NULL);
INSERT INTO accounts VALUES (100082, 99015, 1020, 1, 'COMPUTER POLICY', false, true, NULL);
INSERT INTO accounts VALUES (100083, 99010, 1020, 1, 'BURGLARY', false, true, NULL);
INSERT INTO accounts VALUES (100084, 99005, 1020, 1, 'FIRE and PERILS', false, true, NULL);
INSERT INTO accounts VALUES (100085, 99000, 1020, 1, 'ALL RISKS', false, true, NULL);
INSERT INTO accounts VALUES (100086, 99999, 1019, 1, 'SURPLUS/DEFICIT', false, true, NULL);
INSERT INTO accounts VALUES (100087, 99515, 1019, 1, 'PURCHASE PRICE VARIANCE', false, true, NULL);
INSERT INTO accounts VALUES (100088, 99510, 1019, 1, 'COST OF GOODS SOLD (COGS)', false, true, NULL);
INSERT INTO accounts VALUES (100089, 99505, 1019, 1, 'PURCHASE DISCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (100090, 99500, 1019, 1, 'BAD DEBTS WRITTEN OFF', false, true, NULL);
INSERT INTO accounts VALUES (100091, 80000, 1018, 1, 'COST OF GOODS', false, true, NULL);
INSERT INTO accounts VALUES (100092, 70025, 1017, 1, 'PENALTY INCOME', false, true, NULL);
INSERT INTO accounts VALUES (100093, 70020, 1017, 1, 'CHARGES INCOME', false, true, NULL);
INSERT INTO accounts VALUES (100094, 70015, 1017, 1, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts VALUES (100095, 70010, 1017, 1, 'SERVICE SALES', false, true, NULL);
INSERT INTO accounts VALUES (100096, 70005, 1017, 1, 'GOODS SALES', false, true, NULL);
INSERT INTO accounts VALUES (100097, 71035, 1016, 1, 'TRAINING, FORUM, MEETINGS and WORKSHOPS', false, true, NULL);
INSERT INTO accounts VALUES (100098, 71030, 1016, 1, 'INTEREST INCOME', false, true, NULL);
INSERT INTO accounts VALUES (100099, 71025, 1016, 1, 'DIVIDEND INCOME', false, true, NULL);
INSERT INTO accounts VALUES (100100, 71020, 1016, 1, 'DISPOSAL OF ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (100101, 71015, 1016, 1, 'REGISTRAR TRAINING FEES', false, true, NULL);
INSERT INTO accounts VALUES (100102, 71010, 1016, 1, 'EXCHANGE GAIN(LOSS)', false, true, NULL);
INSERT INTO accounts VALUES (100103, 71005, 1016, 1, 'DONATION', false, true, NULL);
INSERT INTO accounts VALUES (100104, 71000, 1016, 1, 'FAIR VALUE GAIN/LOSS IN INVESTMENTS', false, true, NULL);
INSERT INTO accounts VALUES (100105, 60010, 1015, 1, 'DIVIDEND', false, true, NULL);
INSERT INTO accounts VALUES (100106, 60005, 1015, 1, 'ACCUMULATED AMORTISATION OF CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts VALUES (100107, 60000, 1015, 1, 'CAPITAL GRANTS', false, true, NULL);
INSERT INTO accounts VALUES (100108, 61010, 1014, 1, 'ASSET REVALUATION GAIN / LOSS', false, true, NULL);
INSERT INTO accounts VALUES (100109, 61005, 1014, 1, 'ACCUMULATED SURPLUS', false, true, NULL);
INSERT INTO accounts VALUES (100110, 61000, 1014, 1, 'RETAINED EARNINGS', false, true, NULL);
INSERT INTO accounts VALUES (100111, 50000, 1013, 1, 'BANK LOANS', false, true, NULL);
INSERT INTO accounts VALUES (100112, 40055, 1012, 1, 'PAYROLL LIABILITIES', false, true, NULL);
INSERT INTO accounts VALUES (100113, 40050, 1012, 1, 'PENSION', false, true, NULL);
INSERT INTO accounts VALUES (100114, 40045, 1012, 1, 'PAYE', false, true, NULL);
INSERT INTO accounts VALUES (100115, 40040, 1012, 1, 'HELB', false, true, NULL);
INSERT INTO accounts VALUES (100116, 40035, 1012, 1, 'NHIF', false, true, NULL);
INSERT INTO accounts VALUES (100117, 40030, 1012, 1, 'NSSF', false, true, NULL);
INSERT INTO accounts VALUES (100118, 40025, 1012, 1, 'PROVISION FOR CREDIT NOTES', false, true, NULL);
INSERT INTO accounts VALUES (100119, 40020, 1012, 1, 'OTHER ACCRUALS', false, true, NULL);
INSERT INTO accounts VALUES (100120, 40015, 1012, 1, 'ACCRUED LIABILITIES: CORPORATE TAX', false, true, NULL);
INSERT INTO accounts VALUES (100121, 40010, 1012, 1, 'LEAVE - ACCRUALS', false, true, NULL);
INSERT INTO accounts VALUES (100122, 40005, 1012, 1, 'ADVANCE BILLING', false, true, NULL);
INSERT INTO accounts VALUES (100123, 40000, 1012, 1, 'TRADE CREDITORS', false, true, NULL);
INSERT INTO accounts VALUES (100124, 41000, 1011, 1, 'ADVANCED BILLING', false, true, NULL);
INSERT INTO accounts VALUES (100125, 42010, 1010, 1, 'REMITTANCE', false, true, NULL);
INSERT INTO accounts VALUES (100126, 42000, 1010, 1, 'Value Added Tax (VAT)', false, true, NULL);
INSERT INTO accounts VALUES (100127, 43000, 1009, 1, 'WITHHOLDING TAX', false, true, NULL);
INSERT INTO accounts VALUES (100128, 30030, 1008, 1, 'GOODS RECEIVED CLEARING ACCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (100129, 30025, 1008, 1, 'INVENTORY WORK IN PROGRESS', false, true, NULL);
INSERT INTO accounts VALUES (100130, 30020, 1008, 1, 'INVENTORY', false, true, NULL);
INSERT INTO accounts VALUES (100131, 30015, 1008, 1, 'DEBTORS PROMPT PAYMENT DISCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (100132, 30010, 1008, 1, 'OTHER DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (100133, 30005, 1008, 1, 'STAFF DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (100134, 30000, 1008, 1, 'TRADE DEBTORS', false, true, NULL);
INSERT INTO accounts VALUES (100135, 31005, 1007, 1, 'UNIT TRUST INVESTMENTS', false, true, NULL);
INSERT INTO accounts VALUES (100136, 32005, 1006, 1, 'MPESA', false, true, NULL);
INSERT INTO accounts VALUES (100137, 32000, 1006, 1, 'COMMERCIAL BANK', false, true, NULL);
INSERT INTO accounts VALUES (100138, 33005, 1005, 1, 'PETTY CASH', false, true, NULL);
INSERT INTO accounts VALUES (100139, 33000, 1005, 1, 'CASH ACCOUNT', false, true, NULL);
INSERT INTO accounts VALUES (100140, 34015, 1004, 1, 'TOTAL REGISTRAR DEPOSITS', false, true, NULL);
INSERT INTO accounts VALUES (100141, 34010, 1004, 1, 'TAX RECOVERABLE', false, true, NULL);
INSERT INTO accounts VALUES (100142, 34005, 1004, 1, 'DEPOSITS', false, true, NULL);
INSERT INTO accounts VALUES (100143, 34000, 1004, 1, 'PREPAYMENTS', false, true, NULL);
INSERT INTO accounts VALUES (100144, 20010, 1003, 1, 'INTANGIBLE ASSETS: ACCOUNTING PACKAGE', false, true, NULL);
INSERT INTO accounts VALUES (100145, 20005, 1003, 1, 'NON CURRENT ASSETS: DEFFERED TAX', false, true, NULL);
INSERT INTO accounts VALUES (100146, 20000, 1003, 1, 'INTANGIBLE ASSETS', false, true, NULL);
INSERT INTO accounts VALUES (100147, 21000, 1002, 1, 'ACCUMULATED AMORTISATION', false, true, NULL);
INSERT INTO accounts VALUES (100148, 10005, 1001, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (100149, 10000, 1001, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);
INSERT INTO accounts VALUES (100150, 11005, 1000, 1, 'FURNITURE', false, true, NULL);
INSERT INTO accounts VALUES (100151, 11000, 1000, 1, 'COMPUTERS and EQUIPMENT', false, true, NULL);


--
-- Name: accounts_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('accounts_account_id_seq', 100151, true);


--
-- Data for Name: activity_frequency; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO activity_frequency VALUES (1, 'Once');
INSERT INTO activity_frequency VALUES (4, 'Monthly');


--
-- Data for Name: activity_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO activity_status VALUES (1, 'Completed');
INSERT INTO activity_status VALUES (2, 'UnCleared');
INSERT INTO activity_status VALUES (3, 'Processing');
INSERT INTO activity_status VALUES (4, 'Commited');


--
-- Data for Name: activity_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO activity_types VALUES (1, 34005, 34005, 202, 0, 'No Charges', true, 1, NULL);
INSERT INTO activity_types VALUES (2, 34005, 34005, 101, 0, 'Cash Deposits', true, 2, NULL);
INSERT INTO activity_types VALUES (3, 34005, 34005, 101, 0, 'Cheque Deposits', true, 3, NULL);
INSERT INTO activity_types VALUES (4, 34005, 34005, 101, 0, 'MPESA Deposits', true, 4, NULL);
INSERT INTO activity_types VALUES (5, 34005, 34005, 102, 0, 'Cash Withdrawal', true, 5, NULL);
INSERT INTO activity_types VALUES (6, 34005, 34005, 102, 0, 'Cheque Withdrawal', true, 6, NULL);
INSERT INTO activity_types VALUES (7, 34005, 34005, 102, 0, 'MPESA Withdrawal', true, 7, NULL);
INSERT INTO activity_types VALUES (8, 34005, 70015, 105, 0, 'Loan Intrests', true, 8, NULL);
INSERT INTO activity_types VALUES (9, 34005, 70025, 106, 0, 'Loan Penalty', true, 9, NULL);
INSERT INTO activity_types VALUES (10, 34005, 34005, 107, 0, 'Loan Payment', true, 10, NULL);
INSERT INTO activity_types VALUES (11, 34005, 34005, 108, 0, 'Loan Disbursement', true, 11, NULL);
INSERT INTO activity_types VALUES (12, 34005, 34005, 104, 0, 'Account Transfer', true, 12, NULL);
INSERT INTO activity_types VALUES (14, 34005, 70015, 109, 0, 'Account Intrests', true, 14, NULL);
INSERT INTO activity_types VALUES (15, 34005, 70025, 110, 0, 'Account Penalty', true, 15, NULL);
INSERT INTO activity_types VALUES (21, 34005, 70020, 201, 0, 'Account opening charges', true, 21, NULL);
INSERT INTO activity_types VALUES (22, 34005, 70020, 202, 0, 'Transfer fees', true, 22, NULL);
INSERT INTO activity_types VALUES (23, 100142, 100142, 202, 1, 'No Charges', true, 1, NULL);
INSERT INTO activity_types VALUES (24, 100142, 100142, 101, 1, 'Cash Deposits', true, 2, NULL);
INSERT INTO activity_types VALUES (25, 100142, 100142, 101, 1, 'Cheque Deposits', true, 3, NULL);
INSERT INTO activity_types VALUES (26, 100142, 100142, 101, 1, 'MPESA Deposits', true, 4, NULL);
INSERT INTO activity_types VALUES (27, 100142, 100142, 102, 1, 'Cash Withdrawal', true, 5, NULL);
INSERT INTO activity_types VALUES (28, 100142, 100142, 102, 1, 'Cheque Withdrawal', true, 6, NULL);
INSERT INTO activity_types VALUES (29, 100142, 100142, 102, 1, 'MPESA Withdrawal', true, 7, NULL);
INSERT INTO activity_types VALUES (30, 100094, 100142, 105, 1, 'Loan Intrests', true, 8, NULL);
INSERT INTO activity_types VALUES (31, 100092, 100142, 106, 1, 'Loan Penalty', true, 9, NULL);
INSERT INTO activity_types VALUES (32, 100142, 100142, 107, 1, 'Loan Payment', true, 10, NULL);
INSERT INTO activity_types VALUES (33, 100142, 100142, 108, 1, 'Loan Disbursement', true, 11, NULL);
INSERT INTO activity_types VALUES (34, 100142, 100142, 104, 1, 'Account Transfer', true, 12, NULL);
INSERT INTO activity_types VALUES (35, 100094, 100142, 109, 1, 'Account Intrests', true, 14, NULL);
INSERT INTO activity_types VALUES (36, 100092, 100142, 110, 1, 'Account Penalty', true, 15, NULL);
INSERT INTO activity_types VALUES (37, 100093, 100142, 201, 1, 'Account opening charges', true, 21, NULL);
INSERT INTO activity_types VALUES (38, 100093, 100142, 202, 1, 'Transfer fees', true, 22, NULL);


--
-- Name: activity_types_activity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('activity_types_activity_type_id_seq', 38, true);


--
-- Data for Name: address; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_address_id_seq', 1, false);


--
-- Data for Name: address_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: address_types_address_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('address_types_address_type_id_seq', 1, false);


--
-- Data for Name: applicants; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: applicants_applicant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('applicants_applicant_id_seq', 1, false);


--
-- Data for Name: approval_checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approval_checklists_approval_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approval_checklists_approval_checklist_id_seq', 1, false);


--
-- Data for Name: approvals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: approvals_approval_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('approvals_approval_id_seq', 1, false);


--
-- Data for Name: bank_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO bank_accounts VALUES (0, 0, 0, 33000, 1, 'Cash Account', NULL, NULL, true, true, NULL);


--
-- Name: bank_accounts_bank_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bank_accounts_bank_account_id_seq', 1, false);


--
-- Data for Name: bank_branch; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO bank_branch VALUES (0, 0, 0, 'Cash', NULL, NULL);


--
-- Name: bank_branch_bank_branch_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bank_branch_bank_branch_id_seq', 1, false);


--
-- Data for Name: banks; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO banks VALUES (0, NULL, 0, 'Cash', NULL, NULL, NULL, NULL);


--
-- Name: banks_bank_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('banks_bank_id_seq', 1, false);


--
-- Data for Name: bidders; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: bidders_bidder_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('bidders_bidder_id_seq', 1, false);


--
-- Data for Name: budget_lines; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: budget_lines_budget_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('budget_lines_budget_line_id_seq', 1, false);


--
-- Data for Name: budgets; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: budgets_budget_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('budgets_budget_id_seq', 1, false);


--
-- Data for Name: checklists; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: checklists_checklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('checklists_checklist_id_seq', 1, false);


--
-- Data for Name: collateral_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO collateral_types VALUES (1, 0, 'Land Title', NULL);
INSERT INTO collateral_types VALUES (2, 0, 'Car Log book', NULL);
INSERT INTO collateral_types VALUES (3, 1, 'Property Title Deed', NULL);


--
-- Name: collateral_types_collateral_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('collateral_types_collateral_type_id_seq', 3, true);


--
-- Data for Name: collaterals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: collaterals_collateral_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('collaterals_collateral_id_seq', 1, false);


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('contracts_contract_id_seq', 1, false);


--
-- Data for Name: currency; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency VALUES (1, 'Kenya Shillings', 'KES', 0);
INSERT INTO currency VALUES (2, 'US Dollar', 'USD', 0);
INSERT INTO currency VALUES (3, 'British Pound', 'BPD', 0);
INSERT INTO currency VALUES (4, 'Euro', 'ERO', 0);
INSERT INTO currency VALUES (5, 'Kenya Shillings', 'KES', 1);


--
-- Name: currency_currency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_currency_id_seq', 5, true);


--
-- Data for Name: currency_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO currency_rates VALUES (0, 1, 0, '2018-02-06', 1);
INSERT INTO currency_rates VALUES (1, 5, 1, '2018-03-20', 1);


--
-- Name: currency_rates_currency_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('currency_rates_currency_rate_id_seq', 1, true);


--
-- Data for Name: customers; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO customers VALUES (0, NULL, 0, 2, NULL, 'OpenBaraza Bank', '0', 'Org', 'info@openbaraza.org', '+254', NULL, NULL, NULL, NULL, '2018-03-20', NULL, 'KE', NULL, NULL, true, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);


--
-- Name: customers_customer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('customers_customer_id_seq', 1, false);


--
-- Data for Name: default_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO default_accounts VALUES (1, 90012, 23, 0, NULL);
INSERT INTO default_accounts VALUES (2, 30005, 24, 0, NULL);
INSERT INTO default_accounts VALUES (3, 40045, 25, 0, NULL);
INSERT INTO default_accounts VALUES (4, 40055, 26, 0, NULL);
INSERT INTO default_accounts VALUES (5, 90000, 27, 0, NULL);
INSERT INTO default_accounts VALUES (6, 40055, 28, 0, NULL);
INSERT INTO default_accounts VALUES (7, 90005, 29, 0, NULL);
INSERT INTO default_accounts VALUES (8, 40055, 30, 0, NULL);
INSERT INTO default_accounts VALUES (9, 90070, 31, 0, NULL);
INSERT INTO default_accounts VALUES (10, 30000, 51, 0, NULL);
INSERT INTO default_accounts VALUES (11, 40000, 52, 0, NULL);
INSERT INTO default_accounts VALUES (12, 70005, 53, 0, NULL);
INSERT INTO default_accounts VALUES (13, 80000, 54, 0, NULL);
INSERT INTO default_accounts VALUES (14, 42000, 55, 0, NULL);
INSERT INTO default_accounts VALUES (15, 99999, 56, 0, NULL);
INSERT INTO default_accounts VALUES (16, 61000, 57, 0, NULL);
INSERT INTO default_accounts VALUES (17, 100110, 57, 1, NULL);
INSERT INTO default_accounts VALUES (18, 100086, 56, 1, NULL);
INSERT INTO default_accounts VALUES (19, 100126, 55, 1, NULL);
INSERT INTO default_accounts VALUES (20, 100091, 54, 1, NULL);
INSERT INTO default_accounts VALUES (21, 100096, 53, 1, NULL);
INSERT INTO default_accounts VALUES (22, 100123, 52, 1, NULL);
INSERT INTO default_accounts VALUES (23, 100134, 51, 1, NULL);
INSERT INTO default_accounts VALUES (24, 100001, 31, 1, NULL);
INSERT INTO default_accounts VALUES (25, 100112, 30, 1, NULL);
INSERT INTO default_accounts VALUES (26, 100015, 29, 1, NULL);
INSERT INTO default_accounts VALUES (27, 100112, 28, 1, NULL);
INSERT INTO default_accounts VALUES (28, 100016, 27, 1, NULL);
INSERT INTO default_accounts VALUES (29, 100112, 26, 1, NULL);
INSERT INTO default_accounts VALUES (30, 100114, 25, 1, NULL);
INSERT INTO default_accounts VALUES (31, 100133, 24, 1, NULL);
INSERT INTO default_accounts VALUES (32, 100013, 23, 1, NULL);


--
-- Name: default_accounts_default_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('default_accounts_default_account_id_seq', 32, true);


--
-- Data for Name: default_tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: default_tax_types_default_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('default_tax_types_default_tax_type_id_seq', 1, false);


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO departments VALUES (0, 0, 0, 'Board of Directors', NULL, NULL, true, false, true, true, NULL, NULL, NULL, NULL);
INSERT INTO departments VALUES (1, NULL, 0, 'Board of Directors', NULL, NULL, true, false, true, true, NULL, NULL, NULL, NULL);
INSERT INTO departments VALUES (2, NULL, 1, 'Board of Directors', NULL, NULL, true, false, true, true, NULL, NULL, NULL, NULL);


--
-- Name: departments_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('departments_department_id_seq', 2, true);


--
-- Data for Name: deposit_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO deposit_accounts VALUES (1, 0, 0, 4, NULL, 0, true, '400000001', 'Deposits', '2018-03-20', NULL, NULL, -9.9999998e+10, 0, 0, 0, NULL, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO deposit_accounts VALUES (2, 0, 0, 4, NULL, 0, true, '400000002', 'Charges', '2018-03-20', NULL, NULL, -9.9999998e+10, 0, 0, 0, NULL, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO deposit_accounts VALUES (3, 0, 0, 4, NULL, 0, true, '400000003', 'Interest', '2018-03-20', NULL, NULL, -9.9999998e+10, 0, 0, 0, NULL, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO deposit_accounts VALUES (4, 0, 0, 4, NULL, 0, true, '400000004', 'Penalty', '2018-03-20', NULL, NULL, -9.9999998e+10, 0, 0, 0, NULL, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);


--
-- Name: deposit_accounts_deposit_account_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('deposit_accounts_deposit_account_id_seq', 4, true);


--
-- Data for Name: e_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: e_fields_e_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('e_fields_e_field_id_seq', 1, false);


--
-- Data for Name: entity_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entity_fields_entity_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_fields_entity_field_id_seq', 1, false);


--
-- Data for Name: entity_subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entity_subscriptions VALUES (1, 0, 0, 0, 0, NULL);
INSERT INTO entity_subscriptions VALUES (2, 0, 1, 0, 0, NULL);


--
-- Name: entity_subscriptions_entity_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_subscriptions_entity_subscription_id_seq', 2, true);


--
-- Data for Name: entity_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entity_types VALUES (0, 0, 0, 'Users', 'user', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (1, 1, 0, 'Staff', 'staff', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (2, 2, 0, 'Client', 'client', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (3, 3, 0, 'Supplier', 'supplier', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (4, 4, 0, 'Applicant', 'applicant', '10:0', NULL, NULL, NULL);
INSERT INTO entity_types VALUES (5, 5, 0, 'Subscription', 'subscription', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (6, 100, 0, 'Bank Customers', 'client', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (7, 0, 1, 'Users', 'user', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (8, 1, 1, 'Staff', 'staff', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (9, 2, 1, 'Client', 'client', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (10, 3, 1, 'Supplier', 'supplier', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (11, 4, 1, 'Applicant', 'applicant', NULL, NULL, NULL, NULL);
INSERT INTO entity_types VALUES (12, 100, 1, 'Bank Customers', 'client', NULL, NULL, NULL, NULL);


--
-- Name: entity_types_entity_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_types_entity_type_id_seq', 12, true);


--
-- Data for Name: entity_values; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entity_values_entity_value_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entity_values_entity_value_id_seq', 1, false);


--
-- Data for Name: entitys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO entitys VALUES (0, 0, 0, 0, 'root', 'root', 'root@localhost', NULL, true, true, false, NULL, '2018-02-06 06:05:57.387873', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 0, NULL, NULL);
INSERT INTO entitys VALUES (1, 0, 0, 0, 'repository', 'repository', 'repository@localhost', NULL, false, true, false, NULL, '2018-02-06 06:05:57.387873', true, 'b6f0038dfd42f8aa6ca25354cd2e3660', 'baraza', NULL, NULL, false, NULL, NULL, 0, NULL, NULL);


--
-- Name: entitys_entity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entitys_entity_id_seq', 1, true);


--
-- Data for Name: entry_forms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: entry_forms_entry_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('entry_forms_entry_form_id_seq', 1, false);


--
-- Data for Name: et_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: et_fields_et_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('et_fields_et_field_id_seq', 1, false);


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fields_field_id_seq', 1, false);


--
-- Data for Name: fiscal_years; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: fiscal_years_fiscal_year_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('fiscal_years_fiscal_year_id_seq', 1, false);


--
-- Data for Name: follow_up; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: follow_up_follow_up_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('follow_up_follow_up_id_seq', 1, false);


--
-- Data for Name: forms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: forms_form_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('forms_form_id_seq', 1, false);


--
-- Data for Name: gls; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: gls_gl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('gls_gl_id_seq', 1, false);


--
-- Data for Name: guarantees; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: guarantees_guarantee_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('guarantees_guarantee_id_seq', 1, false);


--
-- Data for Name: helpdesk; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: helpdesk_helpdesk_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('helpdesk_helpdesk_id_seq', 1, false);


--
-- Data for Name: holidays; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('holidays_holiday_id_seq', 1, false);


--
-- Data for Name: industry; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: industry_industry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('industry_industry_id_seq', 1, false);


--
-- Data for Name: interest_methods; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO interest_methods VALUES (0, 8, 0, 'No Intrest', false, false, NULL, '400000003', 0, NULL);
INSERT INTO interest_methods VALUES (1, 8, 0, 'Loan reducing balance', true, false, 'get_intrest(1, loan_id, period_id)', '400000003', 1, NULL);
INSERT INTO interest_methods VALUES (2, 8, 0, 'Loan Fixed Intrest', false, false, 'get_intrest(2, loan_id, period_id)', '400000003', 2, NULL);
INSERT INTO interest_methods VALUES (3, 14, 0, 'Savings intrest', false, false, 'get_intrest(3, deposit_account_id, period_id)', '400000003', 3, NULL);
INSERT INTO interest_methods VALUES (4, 8, 0, 'Loan reducing balance and payments', true, true, 'get_intrest(1, loan_id, period_id)', '400000003', 4, NULL);
INSERT INTO interest_methods VALUES (5, 30, 1, 'No Intrest', false, false, NULL, '400000003', 0, NULL);
INSERT INTO interest_methods VALUES (6, 30, 1, 'Loan reducing balance', true, false, 'get_intrest(1, loan_id, period_id)', '400000003', 1, NULL);
INSERT INTO interest_methods VALUES (7, 30, 1, 'Loan Fixed Intrest', false, false, 'get_intrest(2, loan_id, period_id)', '400000003', 2, NULL);
INSERT INTO interest_methods VALUES (8, 35, 1, 'Savings intrest', false, false, 'get_intrest(3, deposit_account_id, period_id)', '400000003', 3, NULL);
INSERT INTO interest_methods VALUES (9, 30, 1, 'Loan reducing balance and payments', true, true, 'get_intrest(1, loan_id, period_id)', '400000003', 4, NULL);


--
-- Name: interest_methods_interest_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('interest_methods_interest_method_id_seq', 9, true);


--
-- Data for Name: item_category; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO item_category VALUES (1, 0, 'Services', NULL);
INSERT INTO item_category VALUES (2, 0, 'Goods', NULL);
INSERT INTO item_category VALUES (3, 0, 'Utilities', NULL);


--
-- Name: item_category_item_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('item_category_item_category_id_seq', 3, true);


--
-- Data for Name: item_units; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO item_units VALUES (1, 0, 'Each', NULL);
INSERT INTO item_units VALUES (2, 0, 'Man Hours', NULL);
INSERT INTO item_units VALUES (3, 0, '100KG', NULL);


--
-- Name: item_units_item_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('item_units_item_unit_id_seq', 3, true);


--
-- Data for Name: items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: items_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('items_item_id_seq', 1, false);


--
-- Data for Name: journals; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: journals_journal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('journals_journal_id_seq', 1, false);


--
-- Data for Name: lead_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: lead_items_lead_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('lead_items_lead_item_id_seq', 1, false);


--
-- Data for Name: leads; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: leads_lead_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('leads_lead_id_seq', 1, false);


--
-- Data for Name: ledger_links; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ledger_links_ledger_link_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ledger_links_ledger_link_id_seq', 1, false);


--
-- Data for Name: ledger_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ledger_types_ledger_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ledger_types_ledger_type_id_seq', 1, false);


--
-- Name: link_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('link_activity_id_seq', 101, false);


--
-- Data for Name: loan_notes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: loan_notes_loan_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('loan_notes_loan_note_id_seq', 1, false);


--
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: loans_loan_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('loans_loan_id_seq', 1, false);


--
-- Data for Name: locations; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO locations VALUES (1, 0, 'Head Office', NULL);
INSERT INTO locations VALUES (2, 1, 'Head Office', NULL);


--
-- Name: locations_location_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('locations_location_id_seq', 2, true);


--
-- Data for Name: mpesa_api; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: mpesa_api_mpesa_api_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('mpesa_api_mpesa_api_id_seq', 1, false);


--
-- Data for Name: mpesa_trxs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: mpesa_trxs_mpesa_trx_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('mpesa_trxs_mpesa_trx_id_seq', 1, false);


--
-- Data for Name: orgs; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO orgs VALUES (0, 1, NULL, NULL, 'default', NULL, 'dc', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, NULL, true, NULL, 100, 1000);
INSERT INTO orgs VALUES (1, 5, 'KE', NULL, 'Open Baraza', NULL, 'ob', true, true, 'logo.png', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, NULL, NULL, true, NULL, 100, 1000);


--
-- Name: orgs_org_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('orgs_org_id_seq', 1, true);


--
-- Data for Name: pc_allocations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_allocations_pc_allocation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_allocations_pc_allocation_id_seq', 1, false);


--
-- Data for Name: pc_banking; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_banking_pc_banking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_banking_pc_banking_id_seq', 1, false);


--
-- Data for Name: pc_budget; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_budget_pc_budget_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_budget_pc_budget_id_seq', 1, false);


--
-- Data for Name: pc_category; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_category_pc_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_category_pc_category_id_seq', 1, false);


--
-- Data for Name: pc_expenditure; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_expenditure_pc_expenditure_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_expenditure_pc_expenditure_id_seq', 1, false);


--
-- Data for Name: pc_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_items_pc_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_items_pc_item_id_seq', 1, false);


--
-- Data for Name: pc_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pc_types_pc_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pc_types_pc_type_id_seq', 1, false);


--
-- Data for Name: pdefinitions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: pdefinitions_pdefinition_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('pdefinitions_pdefinition_id_seq', 1, false);


--
-- Data for Name: penalty_methods; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO penalty_methods VALUES (0, 9, 0, 'No penalty', NULL, '400000004', 0, NULL);
INSERT INTO penalty_methods VALUES (1, 9, 0, 'Loan Penalty 15', 'get_penalty(1, loan_id, period_id, 15)', '400000004', 1, NULL);
INSERT INTO penalty_methods VALUES (2, 15, 0, 'Account Penalty 15', 'get_penalty(1, deposit_account_id, period_id, 15)', '400000004', 2, NULL);
INSERT INTO penalty_methods VALUES (3, 31, 1, 'No penalty', NULL, '400000004', 0, NULL);
INSERT INTO penalty_methods VALUES (4, 31, 1, 'Loan Penalty 15', 'get_penalty(1, loan_id, period_id, 15)', '400000004', 1, NULL);
INSERT INTO penalty_methods VALUES (5, 36, 1, 'Account Penalty 15', 'get_penalty(1, deposit_account_id, period_id, 15)', '400000004', 2, NULL);


--
-- Name: penalty_methods_penalty_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('penalty_methods_penalty_method_id_seq', 5, true);


--
-- Data for Name: period_tax_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: period_tax_rates_period_tax_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('period_tax_rates_period_tax_rate_id_seq', 1, false);


--
-- Data for Name: period_tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: period_tax_types_period_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('period_tax_types_period_tax_type_id_seq', 1, false);


--
-- Data for Name: periods; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: periods_period_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('periods_period_id_seq', 1, false);


--
-- Name: picture_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('picture_id_seq', 1, false);


--
-- Data for Name: plevels; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: plevels_plevel_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('plevels_plevel_id_seq', 1, false);


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO products VALUES (0, 0, 0, 4, 1, NULL, 0, 'Banking', 'Banking', false, false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 0, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (1, 0, 0, 4, 1, NULL, 0, 'Transaction account', 'Account to handle transactions', false, true, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 1, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (2, 1, 1, 4, 1, NULL, 0, 'Basic loans', 'Basic loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 2, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (3, 3, 0, 4, 1, NULL, 0, 'Savings account', 'Account to handle savings', false, true, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 3, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (4, 2, 1, 4, 1, NULL, 0, 'Compound loans', 'Compound loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, true, 4, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (5, 4, 1, 4, 1, NULL, 0, 'Reducing balance loans', 'Reducing balance loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, true, 5, '2018-03-20 06:02:26.653657', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (6, 5, 3, 4, 5, NULL, 1, 'Banking', 'Banking', false, false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 0, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (7, 5, 3, 4, 5, NULL, 1, 'Transaction account', 'Account to handle transactions', false, true, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 1, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (8, 6, 4, 4, 5, NULL, 1, 'Basic loans', 'Basic loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 2, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (9, 8, 3, 4, 5, NULL, 1, 'Savings account', 'Account to handle savings', false, true, 3, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 3, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (10, 7, 4, 4, 5, NULL, 1, 'Compound loans', 'Compound loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 4, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);
INSERT INTO products VALUES (11, 9, 4, 4, 5, NULL, 1, 'Reducing balance loans', 'Reducing balance loans', true, true, 12, 0, 0, 0, 0, 0, 0, 0, 0, 100, false, 5, '2018-03-20 06:02:26.699119', 'Approved', NULL, NULL, NULL);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('products_product_id_seq', 11, true);


--
-- Data for Name: ptypes; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ptypes_ptype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ptypes_ptype_id_seq', 1, false);


--
-- Data for Name: quotations; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: quotations_quotation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('quotations_quotation_id_seq', 1, false);


--
-- Data for Name: reporting; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: reporting_reporting_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('reporting_reporting_id_seq', 1, false);


--
-- Data for Name: sms; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sms_sms_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sms_sms_id_seq', 1, false);


--
-- Data for Name: ss_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ss_items_ss_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ss_items_ss_item_id_seq', 1, false);


--
-- Data for Name: ss_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: ss_types_ss_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('ss_types_ss_type_id_seq', 1, false);


--
-- Data for Name: stock_lines; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: stock_lines_stock_line_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stock_lines_stock_line_id_seq', 1, false);


--
-- Data for Name: stocks; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: stocks_stock_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stocks_stock_id_seq', 1, false);


--
-- Data for Name: store_movement; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: store_movement_store_movement_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('store_movement_store_movement_id_seq', 1, false);


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO stores VALUES (1, 0, 'Main Store', NULL);


--
-- Name: stores_store_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('stores_store_id_seq', 1, true);


--
-- Data for Name: sub_fields; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sub_fields_sub_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sub_fields_sub_field_id_seq', 1, false);


--
-- Data for Name: subscription_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO subscription_levels VALUES (0, 0, 'Basic', NULL);
INSERT INTO subscription_levels VALUES (1, 0, 'Consumer', NULL);
INSERT INTO subscription_levels VALUES (2, 0, 'Manager', NULL);
INSERT INTO subscription_levels VALUES (4, 1, 'Basic', NULL);
INSERT INTO subscription_levels VALUES (5, 1, 'Consumer', NULL);
INSERT INTO subscription_levels VALUES (6, 1, 'Manager', NULL);


--
-- Name: subscription_levels_subscription_level_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscription_levels_subscription_level_id_seq', 6, true);


--
-- Data for Name: subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: subscriptions_subscription_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('subscriptions_subscription_id_seq', 1, false);


--
-- Data for Name: sys_audit_details; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: sys_audit_trail; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_audit_trail_sys_audit_trail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_audit_trail_sys_audit_trail_id_seq', 1, false);


--
-- Data for Name: sys_continents; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_continents VALUES ('AF', 'Africa');
INSERT INTO sys_continents VALUES ('AS', 'Asia');
INSERT INTO sys_continents VALUES ('EU', 'Europe');
INSERT INTO sys_continents VALUES ('NA', 'North America');
INSERT INTO sys_continents VALUES ('SA', 'South America');
INSERT INTO sys_continents VALUES ('OC', 'Oceania');
INSERT INTO sys_continents VALUES ('AN', 'Antarctica');


--
-- Data for Name: sys_countrys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_countrys VALUES ('AO', 'AF', 'AGO', 'Angola', '024', 'Luanda', '+244', 'kwanza', 'AOA', 'lwei', NULL);
INSERT INTO sys_countrys VALUES ('BF', 'AF', 'BFA', 'Burkina Faso', '854', 'Ouagadougou', '+226', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('BI', 'AF', 'BDI', 'Burundi', '108', 'Bujumbura', '+257', 'Burundi franc', 'BIF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('BJ', 'AF', 'BEN', 'Benin', '204', 'Porto Novo13', '+229', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('BW', 'AF', 'BWA', 'Botswana', '072', 'Gaborone', '', 'pula', 'BWP', 'thebe', NULL);
INSERT INTO sys_countrys VALUES ('CD', 'AF', 'COD', 'Democratic Republic of Congo', '180', 'Kinshasa', '+243', 'Congolese franc', 'CDF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CF', 'AF', 'CAF', 'Central African Republic', '140', 'Bangui', '+236', 'CFA franc', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CG', 'AF', 'COG', 'Republic of Congo', '178', 'Brazzaville', '+242', 'CFA franc', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CI', 'AF', 'CIV', 'Cote d Ivoire', '384', 'Yamoussoukro30', '+225', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CM', 'AF', 'CMR', 'Cameroon', '120', 'Yaoundé', '+237', 'CFA franc', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CV', 'AF', 'CPV', 'Cape Verde', '132', 'Praia', '+238', 'Cape Verde escudo', 'CVE', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('DJ', 'AF', 'DJI', 'Djibouti', '262', 'Djibouti', '+253', 'Djibouti franc', 'DJF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('DZ', 'AF', 'DZA', 'Algeria', '012', 'Algiers', '+213', 'Algerian dinar', 'DZD', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('EG', 'AF', 'EGY', 'Egypt', '818', 'Cairo', '+20', 'Egyptian pound', 'EGP', 'piastre', NULL);
INSERT INTO sys_countrys VALUES ('EH', 'AF', 'ESH', 'Western Sahara', '732', 'Al aaiun', '', 'Moroccan dirham', 'MAD', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('ER', 'AF', 'ERI', 'Eritrea', '232', 'Asmara', '+291', 'nakfa', 'ERN', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('ET', 'AF', 'ETH', 'Ethiopia', '231', 'Addis Ababa', '+251', 'Ethiopian birr', 'ETB', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GA', 'AF', 'GAB', 'Gabon', '266', 'Libreville', '+241', 'CFA franc39', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('GH', 'AF', 'GHA', 'Ghana', '288', 'Accra', '+233', 'cedi', 'GHC', 'pesewa', NULL);
INSERT INTO sys_countrys VALUES ('GM', 'AF', 'GMB', 'Gambia', '270', 'Banjul', '+220', 'dalasi', 'GMD', 'butut', NULL);
INSERT INTO sys_countrys VALUES ('GN', 'AF', 'GIN', 'Guinea', '324', 'Conakry', '+224', 'Guinean franc', 'GNF', '-', NULL);
INSERT INTO sys_countrys VALUES ('GQ', 'AF', 'GNQ', 'Equatorial Guinea', '226', 'Malabo', '+240', 'CFA franc', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('GW', 'AF', 'GNB', 'Guinea-Bissau', '624', 'Bissau', '+245', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('KE', 'AF', 'KEN', 'Kenya', '404', 'Nairobi', '+254', 'Kenyan shilling', 'KES', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('KM', 'AF', 'COM', 'Comoros', '174', 'Moroni', '+269', 'Comorian franc', 'KMF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('LR', 'AF', 'LBR', 'Liberia', '430', 'Monrovia', '+231', 'Liberian dollar', 'LRD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('LS', 'AF', 'LSO', 'Lesotho', '426', 'Maseru', '+266', 'loti', 'LSL', 'sente', NULL);
INSERT INTO sys_countrys VALUES ('LY', 'AF', 'LBY', 'Libyan Arab Jamahiriya', '434', 'Tripoli', '+218', 'Libyan dinar', 'LYD', 'dirham', NULL);
INSERT INTO sys_countrys VALUES ('MA', 'AF', 'MAR', 'Morocco', '504', 'Rabat', '+212', 'Moroccan dirham', 'MAD', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('MG', 'AF', 'MDG', 'Madagascar', '450', 'Antananarivo', '+261', 'Malagasy franc', 'MGF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('ML', 'AF', 'MLI', 'Mali', '466', 'Bamako', '+223', 'CFA franc47', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('MR', 'AF', 'MRT', 'Mauritania', '478', 'Nouakchott', '+222', 'Mauritanian ouguiya', 'MRO', 'khoum', NULL);
INSERT INTO sys_countrys VALUES ('MU', 'AF', 'MUS', 'Mauritius', '480', 'Port Louis', '+230', 'Mauritian rupee', 'MUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MW', 'AF', 'MWI', 'Malawi', '454', 'Lilongwe', '+265', 'Malawian kwacha', 'MWK', 'tambala', NULL);
INSERT INTO sys_countrys VALUES ('MZ', 'AF', 'MOZ', 'Mozambique', '508', 'Maputo', '+258', 'metical', 'MZM', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('NA', 'AF', 'NAM', 'Namibia', '516', 'Windhoek', '+264', 'Namibian dollar', 'NAD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NE', 'AF', 'NER', 'Niger', '562', 'Niamey', '+227', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('NG', 'AF', 'NGA', 'Nigeria', '566', 'Abuja58', '+234', 'naira', 'NGN', 'kobo', NULL);
INSERT INTO sys_countrys VALUES ('RE', 'AF', 'REU', 'Reunion', '638', 'Saint-Denis', '+262', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('RW', 'AF', 'RWA', 'Rwanda', '646', 'Kigali', '+250', 'Rwandese franc', 'RWF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('SC', 'AF', 'SYC', 'Seychelles', '690', 'Victoria', '+248', 'Seychelles rupee', 'SCR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SD', 'AF', 'SDN', 'Sudan', '736', 'Khartoum', '+249', 'Sudanese dinar', 'SDD', 'piastre', NULL);
INSERT INTO sys_countrys VALUES ('SH', 'AF', 'SHN', 'Saint Helena', '654', 'Jamestown', '+290', 'Saint Helena pound', 'SHP', 'penny', NULL);
INSERT INTO sys_countrys VALUES ('SL', 'AF', 'SLE', 'Sierra Leone', '694', 'Freetown', '+232', 'leone', 'SLL', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SN', 'AF', 'SEN', 'Senegal', '686', 'Dakar', '+221', 'CFA franc', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('SO', 'AF', 'SOM', 'Somalia', '706', 'Mogadishu', '+252', 'Somali shilling', 'SOS', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SS', 'AF', 'SSN', 'South Sudan', '737', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('ST', 'AF', 'STP', 'Sao Tome and Principe', '678', 'São Tomé', '+239', 'dobra', 'STD', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('SZ', 'AF', 'SWZ', 'Swaziland', '748', 'Mbabane', '+268', 'lilangeni', 'SZL', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('TD', 'AF', 'TCD', 'Chad', '148', 'NDjamena', '+235', 'CFA franc', 'XAF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('TG', 'AF', 'TGO', 'Togo', '768', 'Lomé', '', 'CFA franc79', 'XOF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('TN', 'AF', 'TUN', 'Tunisia', '788', 'Tunis', '+216', 'Tunisian dinar', 'TND', 'millime', NULL);
INSERT INTO sys_countrys VALUES ('TZ', 'AF', 'TZA', 'Tanzania', '834', 'Dodoma78', '+255', 'Tanzanian shilling', 'TZS', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('UG', 'AF', 'UGA', 'Uganda', '800', 'Kampala', '+256', 'Ugandan shilling', 'UGX', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('YT', 'AF', 'MYT', 'Mayotte', '175', 'Mamoudzou', '+269', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('ZA', 'AF', 'ZAF', 'South Africa', '710', 'Pretoria73', '', 'rand', 'ZAR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('ZM', 'AF', 'ZMB', 'Zambia', '894', 'Lusaka', '+260', 'Zambian kwacha', 'ZMK', 'ngwee', NULL);
INSERT INTO sys_countrys VALUES ('ZW', 'AF', 'ZWE', 'Zimbabwe', '716', 'Harare', '+263', 'Zimbabwe dollar', 'ZWD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AQ', 'AN', 'ATA', 'Antarctica', '010', '', '+672', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('BV', 'AN', 'BVT', 'Bouvet Island', '074', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('GS', 'AN', 'SGS', 'South Georgia and the South Sandwich Islands', '239', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('HM', 'AN', 'HMD', 'Heard Island and McDonald Islands', '334', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('TF', 'AN', 'ATF', 'French Southern Territories', '260', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('AE', 'AS', 'ARE', 'United Arab Emirates', '784', 'Abu Dhabi', '+971', 'UAE dirham', 'AED', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('AF', 'AS', 'AFG', 'Afghanistan', '004', 'Kabul', '+93', 'afghani', 'AFN', 'pul', NULL);
INSERT INTO sys_countrys VALUES ('AM', 'AS', 'ARM', 'Armenia', '051', 'Yerevan', '+374', 'dram', 'AMD', 'luma', NULL);
INSERT INTO sys_countrys VALUES ('AZ', 'AS', 'AZE', 'Azerbaijan', '031', 'Baku', '+994', 'Azerbaijani manat', 'AZM', 'kepik', NULL);
INSERT INTO sys_countrys VALUES ('BD', 'AS', 'BGD', 'Bangladesh', '050', 'Dhaka', '+880', 'taka', 'BDT', 'poisha', NULL);
INSERT INTO sys_countrys VALUES ('BH', 'AS', 'BHR', 'Bahrain', '048', 'Manama', '+973', 'Bahraini dinar', 'BHD', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('BN', 'AS', 'BRN', 'Brunei Darussalam', '096', 'Bandar Seri Begawan', '+673', 'Brunei dollar', 'BND', 'sen', NULL);
INSERT INTO sys_countrys VALUES ('BT', 'AS', 'BTN', 'Bhutan', '064', 'Thimphu', '+975', 'ngultrum', 'BTN', 'chhetrum', NULL);
INSERT INTO sys_countrys VALUES ('CC', 'AS', 'CCK', 'Cocos Keeling Islands', '166', 'Bantam', '+61', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('CN', 'AS', 'CHN', 'China', '156', 'Beijing', '+86', 'renminbi-yuan', 'CNY', 'jiao,  fen', NULL);
INSERT INTO sys_countrys VALUES ('CX', 'AS', 'CXR', 'Christmas Island', '162', 'Flying Fish Cove', '+53', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('CY', 'AS', 'CYP', 'Cyprus', '196', 'Nicosia', '+357', 'Cyprus pound', 'CYP', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GE', 'AS', 'GEO', 'Georgia', '268', 'Tbilisi', '+995', 'lari', 'GEL', 'tetri', NULL);
INSERT INTO sys_countrys VALUES ('HK', 'AS', 'HKG', 'Hong Kong', '344', '-', '+852', 'Hong Kong dollar', 'HKD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('ID', 'AS', 'IDN', 'Indonesia', '360', 'Jakarta', '+62', 'Indonesian rupiah', 'IDR', 'sen', NULL);
INSERT INTO sys_countrys VALUES ('IL', 'AS', 'ISR', 'Israel', '376', '-44', '+972', 'new shekel', 'ILS', 'agora', NULL);
INSERT INTO sys_countrys VALUES ('IN', 'AS', 'IND', 'India', '356', 'New Delhi', '+91', 'Indian rupee', 'INR', 'paisa', NULL);
INSERT INTO sys_countrys VALUES ('IO', 'AS', 'IOT', 'British Indian Ocean Territory', '086', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('IQ', 'AS', 'IRQ', 'Iraq', '368', 'Baghdad', '+964', 'Iraqi dinar', 'IQD', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('IR', 'AS', 'IRN', 'Iran', '364', 'Tehran', '+98', 'Iranian rial', 'IRR', '-', NULL);
INSERT INTO sys_countrys VALUES ('JO', 'AS', 'JOR', 'Jordan', '400', 'Amman', '+962', 'Jordanian dinar', 'JOD', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('JP', 'AS', 'JPN', 'Japan', '392', 'Tokyo', '+81', 'yen', 'JPY', 'sen', NULL);
INSERT INTO sys_countrys VALUES ('KG', 'AS', 'KGZ', 'Kyrgyz Republic', '417', 'Bishkek', '+996', 'som', 'KGS', 'tyiyn', NULL);
INSERT INTO sys_countrys VALUES ('KH', 'AS', 'KHM', 'Cambodia', '116', 'Phnom Penh', '+855', 'riel', 'KHR', 'sen', NULL);
INSERT INTO sys_countrys VALUES ('KP', 'AS', 'PRK', 'North Korea', '408', 'Pyongyang', '+850', 'North Korean won', 'KPW', 'chun', NULL);
INSERT INTO sys_countrys VALUES ('KR', 'AS', 'KOR', 'South Korea', '410', 'Seoul', '+82', 'South Korean won', 'KRW', 'chun', NULL);
INSERT INTO sys_countrys VALUES ('KW', 'AS', 'KWT', 'Kuwait', '414', 'Kuwait City', '+965', 'Kuwaiti dinar', 'KWD', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('KZ', 'AS', 'KAZ', 'Kazakhstan', '398', 'Astana', '+7', 'tenge', 'KZT', 'tiyn', NULL);
INSERT INTO sys_countrys VALUES ('LA', 'AS', 'LAO', 'Lao Peoples Democratic Republic', '418', 'Vientiane', '+856', 'kip', 'LAK', 'at', NULL);
INSERT INTO sys_countrys VALUES ('LB', 'AS', 'LBN', 'Lebanon', '422', 'Beirut', '+961', 'Lebanese pound', 'LBP', 'piastre', NULL);
INSERT INTO sys_countrys VALUES ('LK', 'AS', 'LKA', 'Sri Lanka', '144', 'Colombo', '+94', 'Sri Lankan rupee', 'LKR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MM', 'AS', 'MMR', 'Myanmar', '104', 'Yangon52', '+95', 'kyat', 'MMK', 'pya', NULL);
INSERT INTO sys_countrys VALUES ('MN', 'AS', 'MNG', 'Mongolia', '496', 'Ulan Bator', '+976', 'tugrik', 'MNT', 'möngö', NULL);
INSERT INTO sys_countrys VALUES ('MO', 'AS', 'MAC', 'Macao', '446', 'Macau', '+853', 'pataca', 'MOP', 'avo', NULL);
INSERT INTO sys_countrys VALUES ('MV', 'AS', 'MDV', 'Maldives', '462', 'Malé', '+960', 'rufiyaa', 'MVR', 'laari', NULL);
INSERT INTO sys_countrys VALUES ('MY', 'AS', 'MYS', 'Malaysia', '458', 'Kuala Lumpur', '+60', 'Malaysian ringgit', 'MYR', 'sen', NULL);
INSERT INTO sys_countrys VALUES ('NP', 'AS', 'NPL', 'Nepal', '524', 'Kathmandu', '+977', 'Nepalese rupee', 'NPR', 'paisa', NULL);
INSERT INTO sys_countrys VALUES ('OM', 'AS', 'OMN', 'Oman', '512', 'Muscat', '+968', 'Omani rial', 'OMR', 'baiza', NULL);
INSERT INTO sys_countrys VALUES ('PH', 'AS', 'PHL', 'Philippines', '608', 'Manila', '', 'Philippine peso', 'PHP', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('PK', 'AS', 'PAK', 'Pakistan', '586', 'Islamabad', '+92', 'Pakistani rupee', 'PKR', 'paisa', NULL);
INSERT INTO sys_countrys VALUES ('PS', 'AS', 'PSE', 'Palestinian Territory', '275', '', '+970', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('QA', 'AS', 'QAT', 'Qatar', '634', 'Doha', '+974 ', 'Qatari riyal', 'QAR', 'dirham', NULL);
INSERT INTO sys_countrys VALUES ('SA', 'AS', 'SAU', 'Saudi Arabia', '682', 'Riyadh', '', 'Saudi riyal', 'SAR', 'halala', NULL);
INSERT INTO sys_countrys VALUES ('SG', 'AS', 'SGP', 'Singapore', '702', 'Singapore', '+65', 'Singapore dollar', 'SGD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SY', 'AS', 'SYR', 'Syrian Arab Republic', '760', 'Damascus', '+963', 'Syrian pound', 'SYP', 'piastre', NULL);
INSERT INTO sys_countrys VALUES ('TH', 'AS', 'THA', 'Thailand', '764', 'Bangkok', '', 'baht', 'THB', 'satang', NULL);
INSERT INTO sys_countrys VALUES ('TJ', 'AS', 'TJK', 'Tajikistan', '762', 'Dushanbe', '+992', 'somoni', 'TJS', 'diram', NULL);
INSERT INTO sys_countrys VALUES ('TL', 'AS', 'TLS', 'Timor-Leste', '626', 'Dili', '', 'US dollar', 'USD', '-', NULL);
INSERT INTO sys_countrys VALUES ('TM', 'AS', 'TKM', 'Turkmenistan', '795', 'Ashgabat', '+993', 'Turkmen manat', 'TMM', 'tenge', NULL);
INSERT INTO sys_countrys VALUES ('TR', 'AS', 'TUR', 'Turkey', '792', 'Ankara', '+90', 'Turkish lira', 'TRL', 'kurus', NULL);
INSERT INTO sys_countrys VALUES ('TW', 'AS', 'TWN', 'Taiwan', '158', 'Taipei', '+886', 'new Taiwan dollar', 'TWD', 'fen', NULL);
INSERT INTO sys_countrys VALUES ('UZ', 'AS', 'UZB', 'Uzbekistan', '860', 'Tashkent', '+998', 'sum', 'UZS', 'tiyin', NULL);
INSERT INTO sys_countrys VALUES ('VN', 'AS', 'VNM', 'Vietnam', '704', 'Hanoi', '+84', 'dong', 'VND', '-', NULL);
INSERT INTO sys_countrys VALUES ('YE', 'AS', 'YEM', 'Yemen', '887', 'Sana', '', 'Yemeni rial', 'YER', 'fils', NULL);
INSERT INTO sys_countrys VALUES ('AD', 'EU', 'AND', 'Andorra', '020', 'Andorra la Vella', '+376', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AL', 'EU', 'ALB', 'Albania', '008', 'Tirana', '+355', 'lek', 'ALL', 'qindar', NULL);
INSERT INTO sys_countrys VALUES ('AT', 'EU', 'AUT', 'Austria', '040', 'Vienna', '+43', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AX', 'EU', 'ALA', 'Aland Islands', '248', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('BA', 'EU', 'BIH', 'Bosnia and Herzegovina', '070', 'Sarajevo', '+387', 'Bosnian convertible mark', 'BAM', 'fening', NULL);
INSERT INTO sys_countrys VALUES ('BE', 'EU', 'BEL', 'Belgium', '056', 'Brussels', '+32', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('BG', 'EU', 'BGR', 'Bulgaria', '100', 'Sofia', '+359', 'lev', 'BGN', 'stotinka', NULL);
INSERT INTO sys_countrys VALUES ('BY', 'EU', 'BLR', 'Belarus', '112', 'Minsk', '+375', 'Belarusian rouble', 'BYR', 'kopek', NULL);
INSERT INTO sys_countrys VALUES ('CH', 'EU', 'CHE', 'Switzerland', '756', 'Berne', '+41', 'Swiss franc', 'CHF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('CZ', 'EU', 'CZE', 'Czech Republic', '203', 'Prague', '', 'Czech koruna', 'CZK', 'halér', NULL);
INSERT INTO sys_countrys VALUES ('DE', 'EU', 'DEU', 'Germany', '276', 'Berlin', '+49', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('DK', 'EU', 'DNK', 'Denmark', '208', 'Copenhagen', '+45', 'Danish krone', 'DKK', 'øre', NULL);
INSERT INTO sys_countrys VALUES ('EE', 'EU', 'EST', 'Estonia', '233', 'Tallinn', '+372', 'Estonian kroon', 'EEK', 'sent', NULL);
INSERT INTO sys_countrys VALUES ('ES', 'EU', 'ESP', 'Spain', '724', 'Madrid', '+34', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('FI', 'EU', 'FIN', 'Finland', '246', 'Helsinki', '+358', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('FO', 'EU', 'FRO', 'Faroe Islands', '234', 'Thorshavn', '+298', 'Danish krone', 'DKK', 'øre', NULL);
INSERT INTO sys_countrys VALUES ('FR', 'EU', 'FRA', 'France', '250', 'Paris', '+33', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GB', 'EU', 'GBR', 'United Kingdom of Great Britain & Northern Ireland', '826', 'London', '+44', 'pound sterling', 'GBP', 'penny', NULL);
INSERT INTO sys_countrys VALUES ('GG', 'EU', 'GGY', 'Guernsey', '831', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('GI', 'EU', 'GIB', 'Gibraltar', '292', 'Gibraltar', '', 'Gibraltar pound', 'GIP', 'penny', NULL);
INSERT INTO sys_countrys VALUES ('GR', 'EU', 'GRC', 'Greece', '300', 'Athens', '+30', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('HR', 'EU', 'HRV', 'Croatia', '191', 'Zagreb', '+385', 'kuna', 'HRK', 'lipa', NULL);
INSERT INTO sys_countrys VALUES ('HU', 'EU', 'HUN', 'Hungary', '348', 'Budapest', '+36', 'forint', 'HUF', '-', NULL);
INSERT INTO sys_countrys VALUES ('IE', 'EU', 'IRL', 'Ireland', '372', 'Dublin', '+353', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('IM', 'EU', 'IMN', 'Isle of Man', '833', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('IS', 'EU', 'ISL', 'Iceland', '352', 'Reykjavik', '+354', 'Icelandic króna', 'ISK', 'eyrir', NULL);
INSERT INTO sys_countrys VALUES ('IT', 'EU', 'ITA', 'Italy', '380', 'Rome', '+39', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('JE', 'EU', 'JEY', 'Bailiwick of Jersey', '832', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('LI', 'EU', 'LIE', 'Liechtenstein', '438', 'Vaduz', '+423', 'Swiss franc', 'CHF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('LT', 'EU', 'LTU', 'Lithuania', '440', 'Vilnius', '+370', 'litas', 'LTL', 'centas', NULL);
INSERT INTO sys_countrys VALUES ('LU', 'EU', 'LUX', 'Luxembourg', '442', 'Luxembourg', '+352', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('LV', 'EU', 'LVA', 'Latvia', '428', 'Riga', '+371', 'lats', 'LVL', 'santims', NULL);
INSERT INTO sys_countrys VALUES ('MC', 'EU', 'MCO', 'Monaco', '492', 'Monaco', '+377', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MD', 'EU', 'MDA', 'Moldova', '498', 'Chisinau', '+373', 'Moldovan leu', 'MDL', 'ban', NULL);
INSERT INTO sys_countrys VALUES ('ME', 'EU', 'MNE', 'Montenegro', '499', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('MK', 'EU', 'MKD', 'Macedonia', '807', 'Skopje', '+389', 'denar', 'MKD', 'deni', NULL);
INSERT INTO sys_countrys VALUES ('MT', 'EU', 'MLT', 'Malta', '470', 'Valletta', '+356', 'Maltese lira', 'MTL', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NL', 'EU', 'NLD', 'Netherlands', '528', 'Amsterdam54', '+31', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NO', 'EU', 'NOR', 'Norway', '578', 'Oslo', '+47', 'Norwegian krone', 'NOK', 'øre', NULL);
INSERT INTO sys_countrys VALUES ('PL', 'EU', 'POL', 'Poland', '616', 'Warsaw', '+48', 'zloty', 'PLN', 'grosz', NULL);
INSERT INTO sys_countrys VALUES ('PT', 'EU', 'PRT', 'Portugal', '620', 'Lisbon', '+351', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('RO', 'EU', 'ROU', 'Romania', '642', 'Bucharest', '', 'Romanian leu', 'ROL', 'ban', NULL);
INSERT INTO sys_countrys VALUES ('RS', 'EU', 'SRB', 'Serbia', '688', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('RU', 'EU', 'RUS', 'Russian Federation', '643', 'Moscow', '+7', 'rouble', 'RUB', 'kopek', NULL);
INSERT INTO sys_countrys VALUES ('SE', 'EU', 'SWE', 'Sweden', '752', 'Stockholm', '+46', 'Swedish krona', 'SEK', 'öre', NULL);
INSERT INTO sys_countrys VALUES ('SI', 'EU', 'SVN', 'Slovenia', '705', 'Ljubljana', '+386', 'tolar', 'SIT', 'stotin', NULL);
INSERT INTO sys_countrys VALUES ('SJ', 'EU', 'SJM', 'Svalbard & Jan Mayen Islands', '744', 'Longyearbyen76', '', 'Norwegian krone', 'NOK', 'øre', NULL);
INSERT INTO sys_countrys VALUES ('SK', 'EU', 'SVK', 'Slovakia', '703', 'Bratislava', '+421', 'Slovak koruna', 'SKK', 'halier', NULL);
INSERT INTO sys_countrys VALUES ('SM', 'EU', 'SMR', 'San Marino', '674', 'San Marino', '+378', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('UA', 'EU', 'UKR', 'Ukraine', '804', 'Kiev', '+380', 'hryvnia', 'UAH', 'kopiyka', NULL);
INSERT INTO sys_countrys VALUES ('VA', 'EU', 'VAT', 'Vatican City State', '336', 'Vatican City', '+418', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('VE', 'SA', 'VEN', 'Venezuela', '862', 'Caracas', '+58', 'bolívar', 'VEB', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('AG', 'NA', 'ATG', 'Antigua and Barbuda', '028', 'St Johns', '+1-268', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AI', 'NA', 'AIA', 'Anguilla', '660', 'The Valley', '+1-264', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AN', 'NA', 'ANT', 'Netherlands Antilles', '530', 'Willemstad', '+599', 'Netherlands Antillean guilder', 'ANG', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AW', 'NA', 'ABW', 'Aruba', '533', 'Oranjestad', '+297', 'Aruban guilder', 'AWG', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('BB', 'NA', 'BRB', 'Barbados', '052', 'Bridgetown', '+1-246', 'Barbados dollar', 'BBD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('BL', 'NA', 'BLM', 'Saint Barthelemy', '652', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('BM', 'NA', 'BMU', 'Bermuda', '060', 'Hamilton', '+1-441', 'Bermuda dollar', 'BMD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('BS', 'NA', 'BHS', 'Bahamas', '044', 'Nassau', '+1-242', 'Bahamian dollar', 'BSD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('BZ', 'NA', 'BLZ', 'Belize', '084', 'Belmopan', '+501', 'Belize dollar', 'BZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('CA', 'NA', 'CAN', 'Canada', '124', 'Ottawa', '+1', 'Canadian dollar', 'CAD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('CR', 'NA', 'CRI', 'Costa Rica', '188', 'San José', '+506', 'Costa Rican colón', 'CRC', 'céntimo', NULL);
INSERT INTO sys_countrys VALUES ('CU', 'NA', 'CUB', 'Cuba', '192', 'Havana', '+53', 'Cuban peso', 'CUP', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('DM', 'NA', 'DMA', 'Dominica', '212', 'Roseau', '+1-767', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('DO', 'NA', 'DOM', 'Dominican Republic', '214', 'Santo Domingo', '+1-809', 'Dominican peso', 'DOP', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('GD', 'NA', 'GRD', 'Grenada', '308', 'St Georges', '+1-473', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GL', 'NA', 'GRL', 'Greenland', '304', 'Nuuk', '+299', 'Danish krone', 'DKK', 'øre', NULL);
INSERT INTO sys_countrys VALUES ('GP', 'NA', 'GLP', 'Guadeloupe', '312', 'Basse Terre', '+590', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GT', 'NA', 'GTM', 'Guatemala', '320', 'Guatemala City', '+502', 'Guatemalan quetzal', 'GTQ', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('HN', 'NA', 'HND', 'Honduras', '340', 'Tegucigalpa', '+504', 'lempira', 'HNL', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('HT', 'NA', 'HTI', 'Haiti', '332', 'Port-au-Prince', '', 'gourde', 'HTG', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('JM', 'NA', 'JAM', 'Jamaica', '388', 'Kingston', '+1-876', 'Jamaica dollar', 'JMD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('KN', 'NA', 'KNA', 'Saint Kitts and Nevis', '659', 'Basseterre', '+1-869', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('KY', 'NA', 'CYM', 'Cayman Islands', '136', 'George Town', '+1-345', 'Cayman Islands dollar', 'KYD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('LC', 'NA', 'LCA', 'Saint Lucia', '662', 'Castries', '+1-758', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MF', 'NA', 'MAF', 'Saint Martin', '663', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('MQ', 'NA', 'MTQ', 'Martinique', '474', 'Fort-de-France', '+596', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MS', 'NA', 'MSR', 'Montserrat', '500', 'Plymouth', '+1-664', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MX', 'NA', 'MEX', 'Mexico', '484', 'Mexico City', '+52', 'Mexican peso', 'MXN', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('NI', 'NA', 'NIC', 'Nicaragua', '558', 'Managua', '+505', 'córdoba', 'NIO', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('PA', 'NA', 'PAN', 'Panama', '591', 'Panama City', '+507', 'balboa', 'PAB', 'centésimo', NULL);
INSERT INTO sys_countrys VALUES ('PM', 'NA', 'SPM', 'Saint Pierre and Miquelon', '666', 'Saint-Pierre', '+508', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('PR', 'NA', 'PRI', 'Puerto Rico', '630', 'San Juan', '+1-787', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SV', 'NA', 'SLV', 'El Salvador', '222', 'San Salvador', '+503', 'US dollar', 'USD', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('TC', 'NA', 'TCA', 'Turks and Caicos Islands', '796', 'Cockburn Town', '+1-649', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('TT', 'NA', 'TTO', 'Trinidad and Tobago', '780', 'Port of Spain', '', 'Trinidad and Tobago dollar', 'TTD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('US', 'NA', 'USA', 'United States of America', '840', 'Washington DC', '', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('VC', 'NA', 'VCT', 'Saint Vincent and the Grenadines', '670', 'Kingstown', '+1-784', 'Eastern Caribbean dollar', 'XCD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('VG', 'NA', 'VGB', 'British Virgin Islands', '092', 'Road Town', '', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('VI', 'NA', 'VIR', 'United States Virgin Islands', '850', 'Charlotte Amalie', '+1-284', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AS', 'OC', 'ASM', 'American Samoa', '016', 'Pago Pago', '+1-684', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('AU', 'OC', 'AUS', 'Australia', '036', 'Canberra', '+61', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('CK', 'OC', 'COK', 'Cook Islands', '184', 'Avarua', '+682', 'New Zealand dollar', 'NZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('FJ', 'OC', 'FJI', 'Fiji', '242', 'Suva', '+679', 'Fiji dollar', 'FJD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('FM', 'OC', 'FSM', 'Micronesia', '583', 'Palikir', '+691', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GU', 'OC', 'GUM', 'Guam', '316', 'Hagåtña', '+1-671', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('KI', 'OC', 'KIR', 'Kiribati', '296', 'Tarawa', '+686', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MH', 'OC', 'MHL', 'Marshall Islands', '584', 'Majuro', '+692', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('MP', 'OC', 'MNP', 'Northern Mariana Islands', '580', 'Garapan62', '+1-670', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NC', 'OC', 'NCL', 'New Caledonia', '540', 'Nouméa', '+687', 'CFP franc', 'XPF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('NF', 'OC', 'NFK', 'Norfolk Island', '574', 'Kingston', '+672', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NR', 'OC', 'NRU', 'Nauru', '520', 'Yaren', '+674', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NU', 'OC', 'NIU', 'Niue', '570', 'Alofi', '+683', 'New Zealand dollar', 'NZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('NZ', 'OC', 'NZL', 'New Zealand', '554', 'Wellington', '+64', 'New Zealand dollar', 'NZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('PF', 'OC', 'PYF', 'French Polynesia', '258', 'Papeete', '', 'CFP franc', 'XPF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('PG', 'OC', 'PNG', 'Papua New Guinea', '598', 'Port Moresby', '+675', 'kina', 'PGK', 'toea', NULL);
INSERT INTO sys_countrys VALUES ('PN', 'OC', 'PCN', 'Pitcairn Islands', '612', 'Adamstown', '', 'New Zealand dollar', 'NZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('PW', 'OC', 'PLW', 'Palau', '585', 'Koror', '+680', 'US dollar', 'USD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('SB', 'OC', 'SLB', 'Solomon Islands', '090', 'Honiara', '+677', 'Solomon Islands dollar', 'SBD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('TK', 'OC', 'TKL', 'Tokelau', '772', 'Fakaofo', '+690', 'New Zealand dollar', 'NZD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('TO', 'OC', 'TON', 'Tonga', '776', 'Nukualofa', '+676', 'paanga', 'TOP', 'seniti', NULL);
INSERT INTO sys_countrys VALUES ('TV', 'OC', 'TUV', 'Tuvalu', '798', 'Fongafale82', '+688', 'Australian dollar', 'AUD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('UM', 'OC', 'UMI', 'United States Minor Outlying Islands', '581', '', '', '', '', '', NULL);
INSERT INTO sys_countrys VALUES ('VU', 'OC', 'VUT', 'Vanuatu', '548', 'Port Vila', '+678', 'vatu', 'VUV', '-', NULL);
INSERT INTO sys_countrys VALUES ('WF', 'OC', 'WLF', 'Wallis and Futuna', '876', 'Mata-Utu', '', 'CFP franc', 'XPF', 'centime', NULL);
INSERT INTO sys_countrys VALUES ('WS', 'OC', 'WSM', 'Samoa', '882', 'Apia', '+685', 'tala', 'WST', 'sene', NULL);
INSERT INTO sys_countrys VALUES ('AR', 'SA', 'ARG', 'Argentina', '032', 'Buenos Aires', '+54', 'Argentine peso', 'ARS', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('BO', 'SA', 'BOL', 'Bolivia', '068', 'Sucre16', '+591', 'boliviano', 'BOB', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('BR', 'SA', 'BRA', 'Brazil', '076', 'Brasilia', '', 'Brazilian real', 'BRL', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('CL', 'SA', 'CHL', 'Chile', '152', 'Santiago', '+56', 'Chilean peso', 'CLP', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('CO', 'SA', 'COL', 'Colombia', '170', 'Santa Fe de Bogotá', '+57', 'Colombian peso', 'COP', 'centavo', NULL);
INSERT INTO sys_countrys VALUES ('EC', 'SA', 'ECU', 'Ecuador', '218', 'Quito', '+593', 'US dollar', 'USD', '-', NULL);
INSERT INTO sys_countrys VALUES ('FK', 'SA', 'FLK', 'Falkland Islands', '238', 'Stanley', '+500', 'Falkland Islands pound', 'FKP', 'new penny', NULL);
INSERT INTO sys_countrys VALUES ('GF', 'SA', 'GUF', 'French Guiana', '254', 'Cayenne', '+594', 'euro', 'EUR', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('GY', 'SA', 'GUY', 'Guyana', '328', 'Georgetown', '+592', 'Guyanese dollar', 'GYD', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('PE', 'SA', 'PER', 'Peru', '604', 'Lima', '+51', 'new sol', 'PEN', 'céntimo', NULL);
INSERT INTO sys_countrys VALUES ('PY', 'SA', 'PRY', 'Paraguay', '600', 'Asunción', '+595', 'guaraní', 'PYG', 'céntimo', NULL);
INSERT INTO sys_countrys VALUES ('SR', 'SA', 'SUR', 'Suriname', '740', 'Paramaribo', '', 'Suriname guilder', 'SRG', 'cent', NULL);
INSERT INTO sys_countrys VALUES ('UY', 'SA', 'URY', 'Uruguay', '858', 'Montevideo', '+598', 'Uruguayan peso', 'UYU', 'centésimo', NULL);


--
-- Data for Name: sys_dashboard; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_dashboard_sys_dashboard_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_dashboard_sys_dashboard_id_seq', 1, false);


--
-- Data for Name: sys_emailed; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_emailed_sys_emailed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emailed_sys_emailed_id_seq', 1, false);


--
-- Data for Name: sys_emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO sys_emails VALUES (1, 0, 1, 'Application', NULL, 'Thank you for your Application', 'Thank you {{name}} for your application.<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (2, 0, 2, 'New Customer', NULL, 'Your credentials ', 'Hello {{name}},<br><br>
Your credentials to the banking system have been created.<br>
Your user name is {{username}}<br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (3, 0, 3, 'Password reset', NULL, 'Password reset', 'Hello {{name}},<br><br>
Your password has been reset to:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (4, 0, 4, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Your password is:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (5, 0, 5, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Your OpenBaraza SaaS Platform application has been approved<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (6, 1, 5, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Your OpenBaraza SaaS Platform application has been approved<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (7, 1, 4, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Your password is:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (8, 1, 3, 'Password reset', NULL, 'Password reset', 'Hello {{name}},<br><br>
Your password has been reset to:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (9, 1, 2, 'New Customer', NULL, 'Your credentials ', 'Hello {{name}},<br><br>
Your credentials to the banking system have been created.<br>
Your user name is {{username}}<br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (10, 1, 1, 'Application', NULL, 'Thank you for your Application', 'Thank you {{name}} for your application.<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (11, 1, 5, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Your OpenBaraza SaaS Platform application has been approved<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (12, 1, 4, 'Subscription', NULL, 'Subscription', 'Hello {{name}},<br><br>
Welcome to OpenBaraza SaaS Platform<br><br>
Your password is:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards,<br>
OpenBaraza<br>');
INSERT INTO sys_emails VALUES (13, 1, 3, 'Password reset', NULL, 'Password reset', 'Hello {{name}},<br><br>
Your password has been reset to:<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (14, 1, 2, 'New Customer', NULL, 'Your credentials ', 'Hello {{name}},<br><br>
Your credentials to the banking system have been created.<br>
Your user name is {{username}}<br>
Regards<br>
Human Resources Manager<br>');
INSERT INTO sys_emails VALUES (15, 1, 1, 'Application', NULL, 'Thank you for your Application', 'Thank you {{name}} for your application.<br><br>
Your user name is {{username}}<br> 
Your password is {{password}}<br><br>
Regards<br>
Human Resources Manager<br>');


--
-- Name: sys_emails_sys_email_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_emails_sys_email_id_seq', 15, true);


--
-- Data for Name: sys_errors; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_errors_sys_error_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_errors_sys_error_id_seq', 1, false);


--
-- Data for Name: sys_files; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_files_sys_file_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_files_sys_file_id_seq', 1, false);


--
-- Data for Name: sys_logins; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_logins_sys_login_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_logins_sys_login_id_seq', 1, false);


--
-- Data for Name: sys_menu_msg; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_menu_msg_sys_menu_msg_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_menu_msg_sys_menu_msg_id_seq', 1, false);


--
-- Data for Name: sys_news; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_news_sys_news_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_news_sys_news_id_seq', 1, false);


--
-- Data for Name: sys_queries; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_queries_sys_queries_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_queries_sys_queries_id_seq', 1, false);


--
-- Data for Name: sys_reset; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: sys_reset_sys_reset_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('sys_reset_sys_reset_id_seq', 1, false);


--
-- Data for Name: tax_rates; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tax_rates_tax_rate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tax_rates_tax_rate_id_seq', 1, false);


--
-- Data for Name: tax_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO tax_types VALUES (1, 42000, 1, 15, NULL, 0, 'Exempt', NULL, NULL, 0, 0, 0, false, 0, false, true, true, NULL, NULL, 0, 0, NULL, NULL, NULL, true, NULL);
INSERT INTO tax_types VALUES (2, 42000, 1, 15, NULL, 0, 'VAT', NULL, NULL, 0, 0, 0, false, 16, false, true, true, NULL, NULL, 0, 0, NULL, NULL, NULL, true, NULL);
INSERT INTO tax_types VALUES (11, 42000, NULL, 15, NULL, 1, 'Exempt', NULL, NULL, 0, 0, 0, false, 0, false, true, true, NULL, NULL, 0, 0, NULL, NULL, NULL, true, NULL);
INSERT INTO tax_types VALUES (12, 42000, NULL, 15, NULL, 1, 'VAT', NULL, NULL, 0, 0, 0, false, 16, false, true, true, NULL, NULL, 0, 0, NULL, NULL, NULL, true, NULL);


--
-- Name: tax_types_tax_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tax_types_tax_type_id_seq', 12, true);


--
-- Data for Name: tender_items; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tender_items_tender_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tender_items_tender_item_id_seq', 1, false);


--
-- Data for Name: tender_types; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tender_types_tender_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tender_types_tender_type_id_seq', 1, false);


--
-- Data for Name: tenders; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: tenders_tender_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('tenders_tender_id_seq', 1, false);


--
-- Data for Name: transaction_counters; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_counters VALUES (1, 16, 0, 10001);
INSERT INTO transaction_counters VALUES (2, 14, 0, 10001);
INSERT INTO transaction_counters VALUES (3, 15, 0, 10001);
INSERT INTO transaction_counters VALUES (4, 1, 0, 10001);
INSERT INTO transaction_counters VALUES (5, 2, 0, 10001);
INSERT INTO transaction_counters VALUES (6, 3, 0, 10001);
INSERT INTO transaction_counters VALUES (7, 4, 0, 10001);
INSERT INTO transaction_counters VALUES (8, 5, 0, 10001);
INSERT INTO transaction_counters VALUES (9, 6, 0, 10001);
INSERT INTO transaction_counters VALUES (10, 7, 0, 10001);
INSERT INTO transaction_counters VALUES (11, 8, 0, 10001);
INSERT INTO transaction_counters VALUES (12, 9, 0, 10001);
INSERT INTO transaction_counters VALUES (13, 10, 0, 10001);
INSERT INTO transaction_counters VALUES (14, 11, 0, 10001);
INSERT INTO transaction_counters VALUES (15, 12, 0, 10001);
INSERT INTO transaction_counters VALUES (16, 17, 0, 10001);
INSERT INTO transaction_counters VALUES (17, 21, 0, 10001);
INSERT INTO transaction_counters VALUES (18, 22, 0, 10001);


--
-- Name: transaction_counters_transaction_counter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_counters_transaction_counter_id_seq', 18, true);


--
-- Data for Name: transaction_details; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transaction_details_transaction_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_details_transaction_detail_id_seq', 1, false);


--
-- Data for Name: transaction_links; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transaction_links_transaction_link_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transaction_links_transaction_link_id_seq', 1, false);


--
-- Data for Name: transaction_status; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_status VALUES (1, 'Draft');
INSERT INTO transaction_status VALUES (2, 'Completed');
INSERT INTO transaction_status VALUES (3, 'Processed');
INSERT INTO transaction_status VALUES (4, 'Archive');


--
-- Data for Name: transaction_types; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO transaction_types VALUES (16, 'Requisitions', 'D', false, false);
INSERT INTO transaction_types VALUES (14, 'Sales Quotation', 'D', true, false);
INSERT INTO transaction_types VALUES (15, 'Purchase Quotation', 'D', false, false);
INSERT INTO transaction_types VALUES (1, 'Sales Order', 'D', true, false);
INSERT INTO transaction_types VALUES (2, 'Sales Invoice', 'D', true, true);
INSERT INTO transaction_types VALUES (3, 'Sales Template', 'D', true, false);
INSERT INTO transaction_types VALUES (4, 'Purchase Order', 'D', false, false);
INSERT INTO transaction_types VALUES (5, 'Purchase Invoice', 'D', false, true);
INSERT INTO transaction_types VALUES (6, 'Purchase Template', 'D', false, false);
INSERT INTO transaction_types VALUES (7, 'Receipts', 'D', true, true);
INSERT INTO transaction_types VALUES (8, 'Payments', 'D', false, true);
INSERT INTO transaction_types VALUES (9, 'Credit Note', 'D', true, true);
INSERT INTO transaction_types VALUES (10, 'Debit Note', 'D', false, true);
INSERT INTO transaction_types VALUES (11, 'Delivery Note', 'D', true, false);
INSERT INTO transaction_types VALUES (12, 'Receipt Note', 'D', false, false);
INSERT INTO transaction_types VALUES (17, 'Work Use', 'D', true, false);
INSERT INTO transaction_types VALUES (21, 'Direct Expenditure', 'D', true, true);
INSERT INTO transaction_types VALUES (22, 'Direct Income', 'D', false, true);


--
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transactions_transaction_id_seq', 1, false);


--
-- Data for Name: transfer_activity; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transfer_activity_transfer_activity_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transfer_activity_transfer_activity_id_seq', 1, false);


--
-- Data for Name: transfer_beneficiary; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: transfer_beneficiary_transfer_beneficiary_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('transfer_beneficiary_transfer_beneficiary_id_seq', 1, false);


--
-- Data for Name: use_keys; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO use_keys VALUES (0, 'Users', 0);
INSERT INTO use_keys VALUES (1, 'Staff', 0);
INSERT INTO use_keys VALUES (2, 'Client', 0);
INSERT INTO use_keys VALUES (3, 'Supplier', 0);
INSERT INTO use_keys VALUES (4, 'Applicant', 0);
INSERT INTO use_keys VALUES (5, 'Subscription', 0);
INSERT INTO use_keys VALUES (15, 'Transaction Tax', 2);
INSERT INTO use_keys VALUES (23, 'Travel Cost', 3);
INSERT INTO use_keys VALUES (24, 'Travel Payment', 3);
INSERT INTO use_keys VALUES (25, 'Travel Tax', 3);
INSERT INTO use_keys VALUES (26, 'Salary Payment', 3);
INSERT INTO use_keys VALUES (27, 'Basic Salary', 3);
INSERT INTO use_keys VALUES (28, 'Payroll Advance', 3);
INSERT INTO use_keys VALUES (29, 'Staff Allowance', 3);
INSERT INTO use_keys VALUES (30, 'Staff Remitance', 3);
INSERT INTO use_keys VALUES (31, 'Staff Expenditure', 3);
INSERT INTO use_keys VALUES (51, 'Client Account', 3);
INSERT INTO use_keys VALUES (52, 'Supplier Account', 3);
INSERT INTO use_keys VALUES (53, 'Sales Account', 3);
INSERT INTO use_keys VALUES (54, 'Purchase Account', 3);
INSERT INTO use_keys VALUES (55, 'VAT Account', 3);
INSERT INTO use_keys VALUES (56, 'Suplus/Deficit', 3);
INSERT INTO use_keys VALUES (57, 'Retained Earnings', 3);
INSERT INTO use_keys VALUES (100, 'Customers', 0);
INSERT INTO use_keys VALUES (101, 'Receipts', 4);
INSERT INTO use_keys VALUES (102, 'Payments', 4);
INSERT INTO use_keys VALUES (103, 'Opening Account', 4);
INSERT INTO use_keys VALUES (104, 'Transfer', 4);
INSERT INTO use_keys VALUES (105, 'Loan Intrests', 4);
INSERT INTO use_keys VALUES (106, 'Loan Penalty', 4);
INSERT INTO use_keys VALUES (107, 'Loan Payment', 4);
INSERT INTO use_keys VALUES (108, 'Loan Disbursement', 4);
INSERT INTO use_keys VALUES (109, 'Account Intrests', 4);
INSERT INTO use_keys VALUES (110, 'Account Penalty', 4);
INSERT INTO use_keys VALUES (201, 'Initial Charges', 4);
INSERT INTO use_keys VALUES (202, 'Transaction Charges', 4);


--
-- Data for Name: workflow_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: workflow_logs_workflow_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_logs_workflow_log_id_seq', 1, false);


--
-- Data for Name: workflow_phases; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO workflow_phases VALUES (1, 1, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (2, 2, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (3, 3, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (4, 4, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (5, 5, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (6, 6, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (7, 7, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (8, 8, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (9, 8, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (10, 10, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (11, 11, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (12, 12, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (13, 13, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (14, 14, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (20, 20, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (21, 21, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (22, 22, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (23, 23, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (24, 24, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (25, 25, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (26, 26, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (27, 27, 0, 0, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (31, 51, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (32, 50, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (33, 49, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (34, 48, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (35, 47, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (36, 46, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (37, 45, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (38, 44, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (39, 43, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (40, 42, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (41, 41, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (42, 40, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (43, 39, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (44, 37, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (45, 37, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (46, 36, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (47, 35, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (48, 34, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (49, 33, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (50, 32, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);
INSERT INTO workflow_phases VALUES (51, 31, 7, 1, 1, 0, 0, 3, 1, 1, false, false, false, 'Approve', 'For your approval', 'Phase approved', NULL, NULL, NULL);


--
-- Name: workflow_phases_workflow_phase_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_phases_workflow_phase_id_seq', 51, true);


--
-- Data for Name: workflow_sql; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Name: workflow_sql_workflow_sql_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_sql_workflow_sql_id_seq', 1, false);


--
-- Name: workflow_table_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflow_table_id_seq', 1, false);


--
-- Data for Name: workflows; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO workflows VALUES (1, 0, 0, 'Budget', 'budgets', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (2, 0, 0, 'Requisition', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (3, 3, 0, 'Purchase Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (4, 2, 0, 'Sales Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (5, 1, 0, 'Leave', 'employee_leave', NULL, NULL, 'Leave approved', 'Leave rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (6, 5, 0, 'subscriptions', 'subscriptions', NULL, NULL, 'subscription approved', 'subscription rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (7, 1, 0, 'Claims', 'claims', NULL, NULL, 'Claims approved', 'Claims rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (8, 1, 0, 'Loan', 'loans', NULL, NULL, 'Loan approved', 'Loan rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (9, 1, 0, 'Advances', 'employee_advances', NULL, NULL, 'Advance approved', 'Advance rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (10, 4, 0, 'Hire', 'applications', NULL, NULL, 'Hire approved', 'Hire rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (11, 1, 0, 'Contract', 'applications', NULL, NULL, 'Contract approved', 'Contract rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (12, 1, 0, 'Employee Objectives', 'employee_objectives', NULL, NULL, 'Objectives approved', 'Objectives rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (13, 1, 0, 'Review Objectives', 'job_reviews', NULL, NULL, 'Review approved', 'Review rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (14, 1, 0, 'Employee Travels', 'employee_travels', NULL, NULL, 'Review approved', 'Review rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (20, 0, 0, 'Customer Application', 'customers', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (21, 0, 0, 'Account opening', 'deposit_accounts', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (22, 0, 0, 'Loan Application', 'loans', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (23, 0, 0, 'Guarantees Application', 'guarantees', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (24, 0, 0, 'Collaterals Application', 'collaterals', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (25, 0, 0, 'Customer Application', 'applicants', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (26, 6, 0, 'Account opening - Customer', 'deposit_accounts', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (27, 6, 0, 'Loan Application - Customer', 'loans', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, NULL, NULL);
INSERT INTO workflows VALUES (31, 7, 1, 'Budget', 'budgets', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 1, NULL);
INSERT INTO workflows VALUES (32, 7, 1, 'Requisition', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 2, NULL);
INSERT INTO workflows VALUES (33, 10, 1, 'Purchase Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 3, NULL);
INSERT INTO workflows VALUES (34, 9, 1, 'Sales Transactions', 'transactions', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 4, NULL);
INSERT INTO workflows VALUES (35, 8, 1, 'Leave', 'employee_leave', NULL, NULL, 'Leave approved', 'Leave rejected', NULL, NULL, 5, NULL);
INSERT INTO workflows VALUES (36, 8, 1, 'Claims', 'claims', NULL, NULL, 'Claims approved', 'Claims rejected', NULL, NULL, 7, NULL);
INSERT INTO workflows VALUES (37, 8, 1, 'Loan', 'loans', NULL, NULL, 'Loan approved', 'Loan rejected', NULL, NULL, 8, NULL);
INSERT INTO workflows VALUES (38, 8, 1, 'Advances', 'employee_advances', NULL, NULL, 'Advance approved', 'Advance rejected', NULL, NULL, 9, NULL);
INSERT INTO workflows VALUES (39, 11, 1, 'Hire', 'applications', NULL, NULL, 'Hire approved', 'Hire rejected', NULL, NULL, 10, NULL);
INSERT INTO workflows VALUES (40, 8, 1, 'Contract', 'applications', NULL, NULL, 'Contract approved', 'Contract rejected', NULL, NULL, 11, NULL);
INSERT INTO workflows VALUES (41, 8, 1, 'Employee Objectives', 'employee_objectives', NULL, NULL, 'Objectives approved', 'Objectives rejected', NULL, NULL, 12, NULL);
INSERT INTO workflows VALUES (42, 8, 1, 'Review Objectives', 'job_reviews', NULL, NULL, 'Review approved', 'Review rejected', NULL, NULL, 13, NULL);
INSERT INTO workflows VALUES (43, 8, 1, 'Employee Travels', 'employee_travels', NULL, NULL, 'Review approved', 'Review rejected', NULL, NULL, 14, NULL);
INSERT INTO workflows VALUES (44, 7, 1, 'Customer Application', 'customers', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 20, NULL);
INSERT INTO workflows VALUES (45, 7, 1, 'Account opening', 'deposit_accounts', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 21, NULL);
INSERT INTO workflows VALUES (46, 7, 1, 'Loan Application', 'loans', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 22, NULL);
INSERT INTO workflows VALUES (47, 7, 1, 'Guarantees Application', 'guarantees', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 23, NULL);
INSERT INTO workflows VALUES (48, 7, 1, 'Collaterals Application', 'collaterals', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 24, NULL);
INSERT INTO workflows VALUES (49, 7, 1, 'Customer Application', 'applicants', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 25, NULL);
INSERT INTO workflows VALUES (50, 12, 1, 'Account opening - Customer', 'deposit_accounts', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 26, NULL);
INSERT INTO workflows VALUES (51, 12, 1, 'Loan Application - Customer', 'loans', NULL, NULL, 'Request approved', 'Request rejected', NULL, NULL, 27, NULL);


--
-- Name: workflows_workflow_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('workflows_workflow_id_seq', 51, true);


SET search_path = logs, pg_catalog;

--
-- Name: lg_account_activity_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_account_activity
    ADD CONSTRAINT lg_account_activity_pkey PRIMARY KEY (lg_account_activity_id);


--
-- Name: lg_collaterals_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_collaterals
    ADD CONSTRAINT lg_collaterals_pkey PRIMARY KEY (lg_collateral_id);


--
-- Name: lg_customers_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_customers
    ADD CONSTRAINT lg_customers_pkey PRIMARY KEY (lg_customer_id);


--
-- Name: lg_deposit_accounts_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_deposit_accounts
    ADD CONSTRAINT lg_deposit_accounts_pkey PRIMARY KEY (lg_deposit_account_id);


--
-- Name: lg_guarantees_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_guarantees
    ADD CONSTRAINT lg_guarantees_pkey PRIMARY KEY (lg_guarantee_id);


--
-- Name: lg_loans_pkey; Type: CONSTRAINT; Schema: logs; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lg_loans
    ADD CONSTRAINT lg_loans_pkey PRIMARY KEY (lg_loan_id);


SET search_path = public, pg_catalog;

--
-- Name: account_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_pkey PRIMARY KEY (account_activity_id);


--
-- Name: account_class_account_class_name_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_class
    ADD CONSTRAINT account_class_account_class_name_org_id_key UNIQUE (account_class_name, org_id);


--
-- Name: account_class_account_class_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_class
    ADD CONSTRAINT account_class_account_class_no_org_id_key UNIQUE (account_class_no, org_id);


--
-- Name: account_class_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_class
    ADD CONSTRAINT account_class_pkey PRIMARY KEY (account_class_id);


--
-- Name: account_definations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_pkey PRIMARY KEY (account_defination_id);


--
-- Name: account_definations_product_id_activity_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_product_id_activity_type_id_key UNIQUE (product_id, activity_type_id);


--
-- Name: account_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_notes
    ADD CONSTRAINT account_notes_pkey PRIMARY KEY (account_note_id);


--
-- Name: account_types_account_type_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_account_type_no_org_id_key UNIQUE (account_type_no, org_id);


--
-- Name: account_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_pkey PRIMARY KEY (account_type_id);


--
-- Name: accounts_account_no_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_account_no_org_id_key UNIQUE (account_no, org_id);


--
-- Name: accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (account_id);


--
-- Name: activity_frequency_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY activity_frequency
    ADD CONSTRAINT activity_frequency_pkey PRIMARY KEY (activity_frequency_id);


--
-- Name: activity_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY activity_status
    ADD CONSTRAINT activity_status_pkey PRIMARY KEY (activity_status_id);


--
-- Name: activity_types_org_id_activity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_org_id_activity_type_name_key UNIQUE (org_id, activity_type_name);


--
-- Name: activity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_pkey PRIMARY KEY (activity_type_id);


--
-- Name: address_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- Name: address_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_pkey PRIMARY KEY (address_type_id);


--
-- Name: applicants_org_id_identification_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_org_id_identification_number_key UNIQUE (org_id, identification_number);


--
-- Name: applicants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_pkey PRIMARY KEY (applicant_id);


--
-- Name: approval_checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_pkey PRIMARY KEY (approval_checklist_id);


--
-- Name: approvals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_pkey PRIMARY KEY (approval_id);


--
-- Name: bank_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_pkey PRIMARY KEY (bank_account_id);


--
-- Name: bank_branch_bank_id_bank_branch_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_bank_id_bank_branch_name_key UNIQUE (bank_id, bank_branch_name);


--
-- Name: bank_branch_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_pkey PRIMARY KEY (bank_branch_id);


--
-- Name: banks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (bank_id);


--
-- Name: bidders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bidders
    ADD CONSTRAINT bidders_pkey PRIMARY KEY (bidder_id);


--
-- Name: bidders_tender_id_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY bidders
    ADD CONSTRAINT bidders_tender_id_entity_id_key UNIQUE (tender_id, entity_id);


--
-- Name: budget_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_pkey PRIMARY KEY (budget_line_id);


--
-- Name: budgets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_pkey PRIMARY KEY (budget_id);


--
-- Name: checklists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_pkey PRIMARY KEY (checklist_id);


--
-- Name: collateral_types_org_id_collateral_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY collateral_types
    ADD CONSTRAINT collateral_types_org_id_collateral_type_name_key UNIQUE (org_id, collateral_type_name);


--
-- Name: collateral_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY collateral_types
    ADD CONSTRAINT collateral_types_pkey PRIMARY KEY (collateral_type_id);


--
-- Name: collaterals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY collaterals
    ADD CONSTRAINT collaterals_pkey PRIMARY KEY (collateral_id);


--
-- Name: contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- Name: currency_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_pkey PRIMARY KEY (currency_id);


--
-- Name: currency_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_pkey PRIMARY KEY (currency_rate_id);


--
-- Name: customers_org_id_identification_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_org_id_identification_number_key UNIQUE (org_id, identification_number);


--
-- Name: customers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- Name: default_accounts_account_id_use_key_id_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_account_id_use_key_id_org_id_key UNIQUE (account_id, use_key_id, org_id);


--
-- Name: default_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_pkey PRIMARY KEY (default_account_id);


--
-- Name: default_tax_types_entity_id_tax_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_entity_id_tax_type_id_key UNIQUE (entity_id, tax_type_id);


--
-- Name: default_tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_pkey PRIMARY KEY (default_tax_type_id);


--
-- Name: departments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: deposit_accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_account_number_key UNIQUE (account_number);


--
-- Name: deposit_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_pkey PRIMARY KEY (deposit_account_id);


--
-- Name: e_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_pkey PRIMARY KEY (e_field_id);


--
-- Name: entity_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_pkey PRIMARY KEY (entity_field_id);


--
-- Name: entity_subscriptions_entity_id_entity_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_entity_type_id_key UNIQUE (entity_id, entity_type_id);


--
-- Name: entity_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_pkey PRIMARY KEY (entity_subscription_id);


--
-- Name: entity_types_org_id_entity_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_entity_type_name_key UNIQUE (org_id, entity_type_name);


--
-- Name: entity_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_pkey PRIMARY KEY (entity_type_id);


--
-- Name: entity_values_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_pkey PRIMARY KEY (entity_value_id);


--
-- Name: entitys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_pkey PRIMARY KEY (entity_id);


--
-- Name: entitys_user_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_user_name_key UNIQUE (user_name);


--
-- Name: entry_forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_pkey PRIMARY KEY (entry_form_id);


--
-- Name: et_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY et_fields
    ADD CONSTRAINT et_fields_pkey PRIMARY KEY (et_field_id);


--
-- Name: fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: fiscal_years_fiscal_year_org_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_fiscal_year_org_id_key UNIQUE (fiscal_year, org_id);


--
-- Name: fiscal_years_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_pkey PRIMARY KEY (fiscal_year_id);


--
-- Name: follow_up_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY follow_up
    ADD CONSTRAINT follow_up_pkey PRIMARY KEY (follow_up_id);


--
-- Name: forms_form_name_version_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_form_name_version_key UNIQUE (form_name, version);


--
-- Name: forms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_pkey PRIMARY KEY (form_id);


--
-- Name: gls_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_pkey PRIMARY KEY (gl_id);


--
-- Name: guarantees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY guarantees
    ADD CONSTRAINT guarantees_pkey PRIMARY KEY (guarantee_id);


--
-- Name: helpdesk_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_pkey PRIMARY KEY (helpdesk_id);


--
-- Name: holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (holiday_id);


--
-- Name: industry_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY industry
    ADD CONSTRAINT industry_pkey PRIMARY KEY (industry_id);


--
-- Name: interest_methods_org_id_interest_method_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY interest_methods
    ADD CONSTRAINT interest_methods_org_id_interest_method_name_key UNIQUE (org_id, interest_method_name);


--
-- Name: interest_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY interest_methods
    ADD CONSTRAINT interest_methods_pkey PRIMARY KEY (interest_method_id);


--
-- Name: item_category_org_id_item_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_org_id_item_category_name_key UNIQUE (org_id, item_category_name);


--
-- Name: item_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_pkey PRIMARY KEY (item_category_id);


--
-- Name: item_units_org_id_item_unit_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_org_id_item_unit_name_key UNIQUE (org_id, item_unit_name);


--
-- Name: item_units_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_pkey PRIMARY KEY (item_unit_id);


--
-- Name: items_org_id_item_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_org_id_item_name_key UNIQUE (org_id, item_name);


--
-- Name: items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_pkey PRIMARY KEY (item_id);


--
-- Name: journals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_pkey PRIMARY KEY (journal_id);


--
-- Name: lead_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY lead_items
    ADD CONSTRAINT lead_items_pkey PRIMARY KEY (lead_item_id);


--
-- Name: leads_business_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_business_name_key UNIQUE (business_name);


--
-- Name: leads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_pkey PRIMARY KEY (lead_id);


--
-- Name: ledger_links_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_pkey PRIMARY KEY (ledger_link_id);


--
-- Name: ledger_types_org_id_ledger_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_org_id_ledger_type_name_key UNIQUE (org_id, ledger_type_name);


--
-- Name: ledger_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_pkey PRIMARY KEY (ledger_type_id);


--
-- Name: loan_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loan_notes
    ADD CONSTRAINT loan_notes_pkey PRIMARY KEY (loan_note_id);


--
-- Name: loans_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_account_number_key UNIQUE (account_number);


--
-- Name: loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (loan_id);


--
-- Name: locations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (location_id);


--
-- Name: mpesa_api_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mpesa_api
    ADD CONSTRAINT mpesa_api_pkey PRIMARY KEY (mpesa_api_id);


--
-- Name: mpesa_trxs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_pkey PRIMARY KEY (mpesa_trx_id);


--
-- Name: orgs_org_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_name_key UNIQUE (org_name);


--
-- Name: orgs_org_sufix_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_sufix_key UNIQUE (org_sufix);


--
-- Name: orgs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_pkey PRIMARY KEY (org_id);


--
-- Name: pc_allocations_period_id_department_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_period_id_department_id_key UNIQUE (period_id, department_id);


--
-- Name: pc_allocations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_pkey PRIMARY KEY (pc_allocation_id);


--
-- Name: pc_banking_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_banking
    ADD CONSTRAINT pc_banking_pkey PRIMARY KEY (pc_banking_id);


--
-- Name: pc_budget_pc_allocation_id_pc_item_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_budget
    ADD CONSTRAINT pc_budget_pc_allocation_id_pc_item_id_key UNIQUE (pc_allocation_id, pc_item_id);


--
-- Name: pc_budget_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_budget
    ADD CONSTRAINT pc_budget_pkey PRIMARY KEY (pc_budget_id);


--
-- Name: pc_category_pc_category_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_category
    ADD CONSTRAINT pc_category_pc_category_name_key UNIQUE (pc_category_name);


--
-- Name: pc_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_category
    ADD CONSTRAINT pc_category_pkey PRIMARY KEY (pc_category_id);


--
-- Name: pc_expenditure_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_pkey PRIMARY KEY (pc_expenditure_id);


--
-- Name: pc_items_pc_item_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_items
    ADD CONSTRAINT pc_items_pc_item_name_key UNIQUE (pc_item_name);


--
-- Name: pc_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_items
    ADD CONSTRAINT pc_items_pkey PRIMARY KEY (pc_item_id);


--
-- Name: pc_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pc_types
    ADD CONSTRAINT pc_types_pkey PRIMARY KEY (pc_type_id);


--
-- Name: pdefinitions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_pkey PRIMARY KEY (pdefinition_id);


--
-- Name: penalty_methods_org_id_penalty_method_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY penalty_methods
    ADD CONSTRAINT penalty_methods_org_id_penalty_method_name_key UNIQUE (org_id, penalty_method_name);


--
-- Name: penalty_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY penalty_methods
    ADD CONSTRAINT penalty_methods_pkey PRIMARY KEY (penalty_method_id);


--
-- Name: period_tax_rates_period_tax_type_id_tax_rate_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_period_tax_type_id_tax_rate_id_key UNIQUE (period_tax_type_id, tax_rate_id);


--
-- Name: period_tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_pkey PRIMARY KEY (period_tax_rate_id);


--
-- Name: period_tax_types_period_id_tax_type_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_period_id_tax_type_id_key UNIQUE (period_id, tax_type_id);


--
-- Name: period_tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_pkey PRIMARY KEY (period_tax_type_id);


--
-- Name: periods_org_id_start_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_org_id_start_date_key UNIQUE (org_id, start_date);


--
-- Name: periods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_pkey PRIMARY KEY (period_id);


--
-- Name: plevels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_pkey PRIMARY KEY (plevel_id);


--
-- Name: plevels_plevel_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_plevel_name_key UNIQUE (plevel_name);


--
-- Name: products_org_id_product_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_org_id_product_name_key UNIQUE (org_id, product_name);


--
-- Name: products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: ptypes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ptypes
    ADD CONSTRAINT ptypes_pkey PRIMARY KEY (ptype_id);


--
-- Name: quotations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_pkey PRIMARY KEY (quotation_id);


--
-- Name: reporting_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_pkey PRIMARY KEY (reporting_id);


--
-- Name: sms_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_pkey PRIMARY KEY (sms_id);


--
-- Name: ss_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ss_items
    ADD CONSTRAINT ss_items_pkey PRIMARY KEY (ss_item_id);


--
-- Name: ss_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY ss_types
    ADD CONSTRAINT ss_types_pkey PRIMARY KEY (ss_type_id);


--
-- Name: stock_lines_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stock_lines
    ADD CONSTRAINT stock_lines_pkey PRIMARY KEY (stock_line_id);


--
-- Name: stocks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stocks
    ADD CONSTRAINT stocks_pkey PRIMARY KEY (stock_id);


--
-- Name: store_movement_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY store_movement
    ADD CONSTRAINT store_movement_pkey PRIMARY KEY (store_movement_id);


--
-- Name: stores_org_id_store_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_org_id_store_name_key UNIQUE (org_id, store_name);


--
-- Name: stores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (store_id);


--
-- Name: sub_fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_pkey PRIMARY KEY (sub_field_id);


--
-- Name: subscription_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_pkey PRIMARY KEY (subscription_level_id);


--
-- Name: subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (subscription_id);


--
-- Name: sys_audit_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_audit_trail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_audit_trail
    ADD CONSTRAINT sys_audit_trail_pkey PRIMARY KEY (sys_audit_trail_id);


--
-- Name: sys_continents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_pkey PRIMARY KEY (sys_continent_id);


--
-- Name: sys_continents_sys_continent_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_continents
    ADD CONSTRAINT sys_continents_sys_continent_name_key UNIQUE (sys_continent_name);


--
-- Name: sys_countrys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_pkey PRIMARY KEY (sys_country_id);


--
-- Name: sys_countrys_sys_country_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_country_name_key UNIQUE (sys_country_name);


--
-- Name: sys_dashboard_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_pkey PRIMARY KEY (sys_dashboard_id);


--
-- Name: sys_emailed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_pkey PRIMARY KEY (sys_emailed_id);


--
-- Name: sys_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_pkey PRIMARY KEY (sys_email_id);


--
-- Name: sys_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_errors
    ADD CONSTRAINT sys_errors_pkey PRIMARY KEY (sys_error_id);


--
-- Name: sys_files_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_pkey PRIMARY KEY (sys_file_id);


--
-- Name: sys_logins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_pkey PRIMARY KEY (sys_login_id);


--
-- Name: sys_menu_msg_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_menu_msg
    ADD CONSTRAINT sys_menu_msg_pkey PRIMARY KEY (sys_menu_msg_id);


--
-- Name: sys_news_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_pkey PRIMARY KEY (sys_news_id);


--
-- Name: sys_queries_org_id_sys_query_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_sys_query_name_key UNIQUE (org_id, sys_query_name);


--
-- Name: sys_queries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_pkey PRIMARY KEY (sys_queries_id);


--
-- Name: sys_reset_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_pkey PRIMARY KEY (sys_reset_id);


--
-- Name: tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_pkey PRIMARY KEY (tax_rate_id);


--
-- Name: tax_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_pkey PRIMARY KEY (tax_type_id);


--
-- Name: tax_types_tax_type_name_org_id_sys_country_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_tax_type_name_org_id_sys_country_id_key UNIQUE (tax_type_name, org_id, sys_country_id);


--
-- Name: tender_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tender_items
    ADD CONSTRAINT tender_items_pkey PRIMARY KEY (tender_item_id);


--
-- Name: tender_types_org_id_tender_type_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tender_types
    ADD CONSTRAINT tender_types_org_id_tender_type_name_key UNIQUE (org_id, tender_type_name);


--
-- Name: tender_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tender_types
    ADD CONSTRAINT tender_types_pkey PRIMARY KEY (tender_type_id);


--
-- Name: tenders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY tenders
    ADD CONSTRAINT tenders_pkey PRIMARY KEY (tender_id);


--
-- Name: transaction_counters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_pkey PRIMARY KEY (transaction_counter_id);


--
-- Name: transaction_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_pkey PRIMARY KEY (transaction_detail_id);


--
-- Name: transaction_links_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_pkey PRIMARY KEY (transaction_link_id);


--
-- Name: transaction_status_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_status
    ADD CONSTRAINT transaction_status_pkey PRIMARY KEY (transaction_status_id);


--
-- Name: transaction_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transaction_types
    ADD CONSTRAINT transaction_types_pkey PRIMARY KEY (transaction_type_id);


--
-- Name: transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: transfer_activity_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_pkey PRIMARY KEY (transfer_activity_id);


--
-- Name: transfer_beneficiary_customer_id_deposit_account_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_customer_id_deposit_account_id_key UNIQUE (customer_id, deposit_account_id);


--
-- Name: transfer_beneficiary_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_pkey PRIMARY KEY (transfer_beneficiary_id);


--
-- Name: use_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY use_keys
    ADD CONSTRAINT use_keys_pkey PRIMARY KEY (use_key_id);


--
-- Name: workflow_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_pkey PRIMARY KEY (workflow_log_id);


--
-- Name: workflow_phases_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_pkey PRIMARY KEY (workflow_phase_id);


--
-- Name: workflow_sql_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_pkey PRIMARY KEY (workflow_sql_id);


--
-- Name: workflows_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_pkey PRIMARY KEY (workflow_id);


--
-- Name: account_activity_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_activity_frequency_id ON account_activity USING btree (activity_frequency_id);


--
-- Name: account_activity_activity_status_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_activity_status_id ON account_activity USING btree (activity_status_id);


--
-- Name: account_activity_activity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_activity_type_id ON account_activity USING btree (activity_type_id);


--
-- Name: account_activity_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_currency_id ON account_activity USING btree (currency_id);


--
-- Name: account_activity_deposit_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_deposit_account_id ON account_activity USING btree (deposit_account_id);


--
-- Name: account_activity_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_entity_id ON account_activity USING btree (entity_id);


--
-- Name: account_activity_link_activity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_link_activity_id ON account_activity USING btree (link_activity_id);


--
-- Name: account_activity_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_loan_id ON account_activity USING btree (loan_id);


--
-- Name: account_activity_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_org_id ON account_activity USING btree (org_id);


--
-- Name: account_activity_transfer_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_transfer_account_id ON account_activity USING btree (transfer_account_id);


--
-- Name: account_activity_transfer_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_activity_transfer_loan_id ON account_activity USING btree (transfer_loan_id);


--
-- Name: account_class_chat_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_class_chat_type_id ON account_class USING btree (chat_type_id);


--
-- Name: account_class_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_class_org_id ON account_class USING btree (org_id);


--
-- Name: account_definations_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_definations_activity_frequency_id ON account_definations USING btree (activity_frequency_id);


--
-- Name: account_definations_activity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_definations_activity_type_id ON account_definations USING btree (activity_type_id);


--
-- Name: account_definations_charge_activity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_definations_charge_activity_id ON account_definations USING btree (charge_activity_id);


--
-- Name: account_definations_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_definations_org_id ON account_definations USING btree (org_id);


--
-- Name: account_definations_product_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_definations_product_id ON account_definations USING btree (product_id);


--
-- Name: account_notes_deposit_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_notes_deposit_account_id ON account_notes USING btree (deposit_account_id);


--
-- Name: account_notes_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_notes_org_id ON account_notes USING btree (org_id);


--
-- Name: account_types_account_class_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_types_account_class_id ON account_types USING btree (account_class_id);


--
-- Name: account_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX account_types_org_id ON account_types USING btree (org_id);


--
-- Name: accounts_account_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_account_type_id ON accounts USING btree (account_type_id);


--
-- Name: accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX accounts_org_id ON accounts USING btree (org_id);


--
-- Name: activity_types_cr_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX activity_types_cr_account_id ON activity_types USING btree (cr_account_id);


--
-- Name: activity_types_dr_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX activity_types_dr_account_id ON activity_types USING btree (dr_account_id);


--
-- Name: activity_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX activity_types_org_id ON activity_types USING btree (org_id);


--
-- Name: activity_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX activity_types_use_key_id ON activity_types USING btree (use_key_id);


--
-- Name: address_address_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_address_type_id ON address USING btree (address_type_id);


--
-- Name: address_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_org_id ON address USING btree (org_id);


--
-- Name: address_sys_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_sys_country_id ON address USING btree (sys_country_id);


--
-- Name: address_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_id ON address USING btree (table_id);


--
-- Name: address_table_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_table_name ON address USING btree (table_name);


--
-- Name: address_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX address_types_org_id ON address_types USING btree (org_id);


--
-- Name: applicants_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applicants_customer_id ON applicants USING btree (customer_id);


--
-- Name: applicants_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applicants_entity_id ON applicants USING btree (entity_id);


--
-- Name: applicants_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX applicants_org_id ON applicants USING btree (org_id);


--
-- Name: approval_checklists_approval_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_approval_id ON approval_checklists USING btree (approval_id);


--
-- Name: approval_checklists_checklist_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_checklist_id ON approval_checklists USING btree (checklist_id);


--
-- Name: approval_checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approval_checklists_org_id ON approval_checklists USING btree (org_id);


--
-- Name: approvals_app_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_app_entity_id ON approvals USING btree (app_entity_id);


--
-- Name: approvals_approve_status; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_approve_status ON approvals USING btree (approve_status);


--
-- Name: approvals_forward_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_forward_id ON approvals USING btree (forward_id);


--
-- Name: approvals_org_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_entity_id ON approvals USING btree (org_entity_id);


--
-- Name: approvals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_org_id ON approvals USING btree (org_id);


--
-- Name: approvals_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_table_id ON approvals USING btree (table_id);


--
-- Name: approvals_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX approvals_workflow_phase_id ON approvals USING btree (workflow_phase_id);


--
-- Name: bank_accounts_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_account_id ON bank_accounts USING btree (account_id);


--
-- Name: bank_accounts_bank_branch_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_bank_branch_id ON bank_accounts USING btree (bank_branch_id);


--
-- Name: bank_accounts_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_currency_id ON bank_accounts USING btree (currency_id);


--
-- Name: bank_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_accounts_org_id ON bank_accounts USING btree (org_id);


--
-- Name: bank_branch_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bank_branch_org_id ON bank_branch USING btree (org_id);


--
-- Name: banks_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX banks_org_id ON banks USING btree (org_id);


--
-- Name: bidders_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bidders_entity_id ON bidders USING btree (entity_id);


--
-- Name: bidders_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bidders_org_id ON bidders USING btree (org_id);


--
-- Name: bidders_tender_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX bidders_tender_id ON bidders USING btree (tender_id);


--
-- Name: branch_bankid; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX branch_bankid ON bank_branch USING btree (bank_id);


--
-- Name: budget_lines_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_account_id ON budget_lines USING btree (account_id);


--
-- Name: budget_lines_budget_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_budget_id ON budget_lines USING btree (budget_id);


--
-- Name: budget_lines_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_item_id ON budget_lines USING btree (item_id);


--
-- Name: budget_lines_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_org_id ON budget_lines USING btree (org_id);


--
-- Name: budget_lines_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_period_id ON budget_lines USING btree (period_id);


--
-- Name: budget_lines_transaction_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budget_lines_transaction_id ON budget_lines USING btree (transaction_id);


--
-- Name: budgets_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budgets_department_id ON budgets USING btree (department_id);


--
-- Name: budgets_fiscal_year_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budgets_fiscal_year_id ON budgets USING btree (fiscal_year_id);


--
-- Name: budgets_link_budget_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budgets_link_budget_id ON budgets USING btree (link_budget_id);


--
-- Name: budgets_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX budgets_org_id ON budgets USING btree (org_id);


--
-- Name: checklists_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_org_id ON checklists USING btree (org_id);


--
-- Name: checklists_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX checklists_workflow_phase_id ON checklists USING btree (workflow_phase_id);


--
-- Name: collateral_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX collateral_types_org_id ON collateral_types USING btree (org_id);


--
-- Name: collaterals_collateral_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX collaterals_collateral_type_id ON collaterals USING btree (collateral_type_id);


--
-- Name: collaterals_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX collaterals_entity_id ON collaterals USING btree (entity_id);


--
-- Name: collaterals_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX collaterals_loan_id ON collaterals USING btree (loan_id);


--
-- Name: collaterals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX collaterals_org_id ON collaterals USING btree (org_id);


--
-- Name: contracts_bidder_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contracts_bidder_id ON contracts USING btree (bidder_id);


--
-- Name: contracts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX contracts_org_id ON contracts USING btree (org_id);


--
-- Name: currency_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_org_id ON currency USING btree (org_id);


--
-- Name: currency_rates_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_currency_id ON currency_rates USING btree (currency_id);


--
-- Name: currency_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX currency_rates_org_id ON currency_rates USING btree (org_id);


--
-- Name: customers_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customers_entity_id ON customers USING btree (entity_id);


--
-- Name: customers_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX customers_org_id ON customers USING btree (org_id);


--
-- Name: default_accounts_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_account_id ON default_accounts USING btree (account_id);


--
-- Name: default_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_org_id ON default_accounts USING btree (org_id);


--
-- Name: default_accounts_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_accounts_use_key_id ON default_accounts USING btree (use_key_id);


--
-- Name: default_tax_types_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_entity_id ON default_tax_types USING btree (entity_id);


--
-- Name: default_tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_org_id ON default_tax_types USING btree (org_id);


--
-- Name: default_tax_types_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX default_tax_types_tax_type_id ON default_tax_types USING btree (tax_type_id);


--
-- Name: departments_ln_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX departments_ln_department_id ON departments USING btree (ln_department_id);


--
-- Name: departments_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX departments_org_id ON departments USING btree (org_id);


--
-- Name: deposit_accounts_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deposit_accounts_activity_frequency_id ON deposit_accounts USING btree (activity_frequency_id);


--
-- Name: deposit_accounts_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deposit_accounts_customer_id ON deposit_accounts USING btree (customer_id);


--
-- Name: deposit_accounts_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deposit_accounts_entity_id ON deposit_accounts USING btree (entity_id);


--
-- Name: deposit_accounts_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deposit_accounts_org_id ON deposit_accounts USING btree (org_id);


--
-- Name: deposit_accounts_product_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX deposit_accounts_product_id ON deposit_accounts USING btree (product_id);


--
-- Name: e_fields_et_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_et_field_id ON e_fields USING btree (et_field_id);


--
-- Name: e_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_org_id ON e_fields USING btree (org_id);


--
-- Name: e_fields_table_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_table_code ON e_fields USING btree (table_code);


--
-- Name: e_fields_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX e_fields_table_id ON e_fields USING btree (table_id);


--
-- Name: entity_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_fields_org_id ON entity_fields USING btree (org_id);


--
-- Name: entity_subscriptions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_id ON entity_subscriptions USING btree (entity_id);


--
-- Name: entity_subscriptions_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_entity_type_id ON entity_subscriptions USING btree (entity_type_id);


--
-- Name: entity_subscriptions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_org_id ON entity_subscriptions USING btree (org_id);


--
-- Name: entity_subscriptions_subscription_level_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_subscriptions_subscription_level_id ON entity_subscriptions USING btree (subscription_level_id);


--
-- Name: entity_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_org_id ON entity_types USING btree (org_id);


--
-- Name: entity_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_types_use_key_id ON entity_types USING btree (use_key_id);


--
-- Name: entity_values_entity_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_field_id ON entity_values USING btree (entity_field_id);


--
-- Name: entity_values_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_entity_id ON entity_values USING btree (entity_id);


--
-- Name: entity_values_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entity_values_org_id ON entity_values USING btree (org_id);


--
-- Name: entitys_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_account_id ON entitys USING btree (account_id);


--
-- Name: entitys_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_customer_id ON entitys USING btree (customer_id);


--
-- Name: entitys_entity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_entity_type_id ON entitys USING btree (entity_type_id);


--
-- Name: entitys_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_org_id ON entitys USING btree (org_id);


--
-- Name: entitys_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_use_key_id ON entitys USING btree (use_key_id);


--
-- Name: entitys_user_name; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entitys_user_name ON entitys USING btree (user_name);


--
-- Name: entry_forms_entered_by_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entered_by_id ON entry_forms USING btree (entered_by_id);


--
-- Name: entry_forms_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_entity_id ON entry_forms USING btree (entity_id);


--
-- Name: entry_forms_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_form_id ON entry_forms USING btree (form_id);


--
-- Name: entry_forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX entry_forms_org_id ON entry_forms USING btree (org_id);


--
-- Name: et_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_org_id ON et_fields USING btree (org_id);


--
-- Name: et_fields_table_code; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_table_code ON et_fields USING btree (table_code);


--
-- Name: et_fields_table_link; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX et_fields_table_link ON et_fields USING btree (table_link);


--
-- Name: fields_form_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_form_id ON fields USING btree (form_id);


--
-- Name: fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fields_org_id ON fields USING btree (org_id);


--
-- Name: fiscal_years_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX fiscal_years_org_id ON fiscal_years USING btree (org_id);


--
-- Name: follow_up_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX follow_up_entity_id ON follow_up USING btree (entity_id);


--
-- Name: follow_up_lead_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX follow_up_lead_item_id ON follow_up USING btree (lead_item_id);


--
-- Name: follow_up_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX follow_up_org_id ON follow_up USING btree (org_id);


--
-- Name: forms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX forms_org_id ON forms USING btree (org_id);


--
-- Name: gls_account_activity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_account_activity_id ON gls USING btree (account_activity_id);


--
-- Name: gls_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_account_id ON gls USING btree (account_id);


--
-- Name: gls_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_journal_id ON gls USING btree (journal_id);


--
-- Name: gls_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX gls_org_id ON gls USING btree (org_id);


--
-- Name: guarantees_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX guarantees_customer_id ON guarantees USING btree (customer_id);


--
-- Name: guarantees_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX guarantees_entity_id ON guarantees USING btree (entity_id);


--
-- Name: guarantees_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX guarantees_loan_id ON guarantees USING btree (loan_id);


--
-- Name: guarantees_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX guarantees_org_id ON guarantees USING btree (org_id);


--
-- Name: helpdesk_client_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_client_id ON helpdesk USING btree (client_id);


--
-- Name: helpdesk_closed_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_closed_by ON helpdesk USING btree (closed_by);


--
-- Name: helpdesk_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_org_id ON helpdesk USING btree (org_id);


--
-- Name: helpdesk_pdefinition_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_pdefinition_id ON helpdesk USING btree (pdefinition_id);


--
-- Name: helpdesk_plevel_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_plevel_id ON helpdesk USING btree (plevel_id);


--
-- Name: helpdesk_recorded_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX helpdesk_recorded_by ON helpdesk USING btree (recorded_by);


--
-- Name: holidays_holiday_date; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX holidays_holiday_date ON holidays USING btree (holiday_date);


--
-- Name: holidays_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX holidays_org_id ON holidays USING btree (org_id);


--
-- Name: industry_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX industry_org_id ON industry USING btree (org_id);


--
-- Name: interest_methods_activity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX interest_methods_activity_type_id ON interest_methods USING btree (activity_type_id);


--
-- Name: interest_methods_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX interest_methods_org_id ON interest_methods USING btree (org_id);


--
-- Name: item_category_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX item_category_org_id ON item_category USING btree (org_id);


--
-- Name: item_units_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX item_units_org_id ON item_units USING btree (org_id);


--
-- Name: items_item_category_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_item_category_id ON items USING btree (item_category_id);


--
-- Name: items_item_unit_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_item_unit_id ON items USING btree (item_unit_id);


--
-- Name: items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_org_id ON items USING btree (org_id);


--
-- Name: items_purchase_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_purchase_account_id ON items USING btree (purchase_account_id);


--
-- Name: items_sales_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_sales_account_id ON items USING btree (sales_account_id);


--
-- Name: items_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX items_tax_type_id ON items USING btree (tax_type_id);


--
-- Name: journals_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_currency_id ON journals USING btree (currency_id);


--
-- Name: journals_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_department_id ON journals USING btree (department_id);


--
-- Name: journals_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_org_id ON journals USING btree (org_id);


--
-- Name: journals_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX journals_period_id ON journals USING btree (period_id);


--
-- Name: lead_items_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX lead_items_entity_id ON lead_items USING btree (entity_id);


--
-- Name: lead_items_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX lead_items_item_id ON lead_items USING btree (item_id);


--
-- Name: lead_items_lead_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX lead_items_lead_id ON lead_items USING btree (lead_id);


--
-- Name: lead_items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX lead_items_org_id ON lead_items USING btree (org_id);


--
-- Name: leads_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX leads_country_id ON leads USING btree (country_id);


--
-- Name: leads_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX leads_entity_id ON leads USING btree (entity_id);


--
-- Name: leads_industry_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX leads_industry_id ON leads USING btree (industry_id);


--
-- Name: leads_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX leads_org_id ON leads USING btree (org_id);


--
-- Name: ledger_links_ledger_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_links_ledger_type_id ON ledger_links USING btree (ledger_type_id);


--
-- Name: ledger_links_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_links_org_id ON ledger_links USING btree (org_id);


--
-- Name: ledger_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_account_id ON ledger_types USING btree (account_id);


--
-- Name: ledger_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_org_id ON ledger_types USING btree (org_id);


--
-- Name: ledger_types_tax_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ledger_types_tax_account_id ON ledger_types USING btree (tax_account_id);


--
-- Name: loan_notes_loan_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_notes_loan_id ON loan_notes USING btree (loan_id);


--
-- Name: loan_notes_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loan_notes_org_id ON loan_notes USING btree (org_id);


--
-- Name: loans_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_activity_frequency_id ON loans USING btree (activity_frequency_id);


--
-- Name: loans_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_customer_id ON loans USING btree (customer_id);


--
-- Name: loans_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_entity_id ON loans USING btree (entity_id);


--
-- Name: loans_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_org_id ON loans USING btree (org_id);


--
-- Name: loans_product_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX loans_product_id ON loans USING btree (product_id);


--
-- Name: locations_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX locations_org_id ON locations USING btree (org_id);


--
-- Name: mpesa_api_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX mpesa_api_org_id ON mpesa_api USING btree (org_id);


--
-- Name: mpesa_trxs_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX mpesa_trxs_org_id ON mpesa_trxs USING btree (org_id);


--
-- Name: orgs_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_currency_id ON orgs USING btree (currency_id);


--
-- Name: orgs_default_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_default_country_id ON orgs USING btree (default_country_id);


--
-- Name: orgs_parent_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX orgs_parent_org_id ON orgs USING btree (parent_org_id);


--
-- Name: pc_allocations_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_allocations_department_id ON pc_allocations USING btree (department_id);


--
-- Name: pc_allocations_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_allocations_entity_id ON pc_allocations USING btree (entity_id);


--
-- Name: pc_allocations_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_allocations_org_id ON pc_allocations USING btree (org_id);


--
-- Name: pc_allocations_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_allocations_period_id ON pc_allocations USING btree (period_id);


--
-- Name: pc_banking_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_banking_org_id ON pc_banking USING btree (org_id);


--
-- Name: pc_banking_pc_allocation_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_banking_pc_allocation_id ON pc_banking USING btree (pc_allocation_id);


--
-- Name: pc_budget_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_budget_org_id ON pc_budget USING btree (org_id);


--
-- Name: pc_budget_pc_allocation_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_budget_pc_allocation_id ON pc_budget USING btree (pc_allocation_id);


--
-- Name: pc_budget_pc_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_budget_pc_item_id ON pc_budget USING btree (pc_item_id);


--
-- Name: pc_category_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_category_org_id ON pc_category USING btree (org_id);


--
-- Name: pc_expenditure_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_expenditure_org_id ON pc_expenditure USING btree (org_id);


--
-- Name: pc_expenditure_pc_allocation_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_expenditure_pc_allocation_id ON pc_expenditure USING btree (pc_allocation_id);


--
-- Name: pc_expenditure_pc_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_expenditure_pc_item_id ON pc_expenditure USING btree (pc_item_id);


--
-- Name: pc_items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_items_org_id ON pc_items USING btree (org_id);


--
-- Name: pc_items_pc_category_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_items_pc_category_id ON pc_items USING btree (pc_category_id);


--
-- Name: pc_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pc_types_org_id ON pc_types USING btree (org_id);


--
-- Name: pdefinitions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pdefinitions_org_id ON pdefinitions USING btree (org_id);


--
-- Name: pdefinitions_ptype_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX pdefinitions_ptype_id ON pdefinitions USING btree (ptype_id);


--
-- Name: penalty_methods_activity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_methods_activity_type_id ON penalty_methods USING btree (activity_type_id);


--
-- Name: penalty_methods_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX penalty_methods_org_id ON penalty_methods USING btree (org_id);


--
-- Name: period_tax_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_rates_org_id ON period_tax_rates USING btree (org_id);


--
-- Name: period_tax_rates_period_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_rates_period_tax_type_id ON period_tax_rates USING btree (period_tax_type_id);


--
-- Name: period_tax_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_account_id ON period_tax_types USING btree (account_id);


--
-- Name: period_tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_org_id ON period_tax_types USING btree (org_id);


--
-- Name: period_tax_types_period_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_period_id ON period_tax_types USING btree (period_id);


--
-- Name: period_tax_types_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX period_tax_types_tax_type_id ON period_tax_types USING btree (tax_type_id);


--
-- Name: periods_fiscal_year_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX periods_fiscal_year_id ON periods USING btree (fiscal_year_id);


--
-- Name: periods_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX periods_org_id ON periods USING btree (org_id);


--
-- Name: plevels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX plevels_org_id ON plevels USING btree (org_id);


--
-- Name: products_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_activity_frequency_id ON products USING btree (activity_frequency_id);


--
-- Name: products_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_currency_id ON products USING btree (currency_id);


--
-- Name: products_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_entity_id ON products USING btree (entity_id);


--
-- Name: products_interest_method_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_interest_method_id ON products USING btree (interest_method_id);


--
-- Name: products_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX products_org_id ON products USING btree (org_id);


--
-- Name: ptypes_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ptypes_org_id ON ptypes USING btree (org_id);


--
-- Name: quotations_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_entity_id ON quotations USING btree (entity_id);


--
-- Name: quotations_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_item_id ON quotations USING btree (item_id);


--
-- Name: quotations_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX quotations_org_id ON quotations USING btree (org_id);


--
-- Name: reporting_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_entity_id ON reporting USING btree (entity_id);


--
-- Name: reporting_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_org_id ON reporting USING btree (org_id);


--
-- Name: reporting_report_to_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX reporting_report_to_id ON reporting USING btree (report_to_id);


--
-- Name: sms_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sms_entity_id ON sms USING btree (entity_id);


--
-- Name: sms_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sms_org_id ON sms USING btree (org_id);


--
-- Name: ss_items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ss_items_org_id ON ss_items USING btree (org_id);


--
-- Name: ss_items_ss_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ss_items_ss_type_id ON ss_items USING btree (ss_type_id);


--
-- Name: ss_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX ss_types_org_id ON ss_types USING btree (org_id);


--
-- Name: stock_lines_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stock_lines_item_id ON stock_lines USING btree (item_id);


--
-- Name: stock_lines_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stock_lines_org_id ON stock_lines USING btree (org_id);


--
-- Name: stock_lines_stock_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stock_lines_stock_id ON stock_lines USING btree (stock_id);


--
-- Name: stocks_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stocks_org_id ON stocks USING btree (org_id);


--
-- Name: stocks_store_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stocks_store_id ON stocks USING btree (store_id);


--
-- Name: store_movement_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX store_movement_item_id ON store_movement USING btree (item_id);


--
-- Name: store_movement_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX store_movement_org_id ON store_movement USING btree (org_id);


--
-- Name: store_movement_store_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX store_movement_store_id ON store_movement USING btree (store_id);


--
-- Name: store_movement_store_to_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX store_movement_store_to_id ON store_movement USING btree (store_to_id);


--
-- Name: stores_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX stores_org_id ON stores USING btree (org_id);


--
-- Name: sub_fields_field_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_field_id ON sub_fields USING btree (field_id);


--
-- Name: sub_fields_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sub_fields_org_id ON sub_fields USING btree (org_id);


--
-- Name: subscription_levels_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscription_levels_org_id ON subscription_levels USING btree (org_id);


--
-- Name: subscriptions_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_country_id ON subscriptions USING btree (country_id);


--
-- Name: subscriptions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_entity_id ON subscriptions USING btree (entity_id);


--
-- Name: subscriptions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX subscriptions_org_id ON subscriptions USING btree (org_id);


--
-- Name: sys_countrys_sys_continent_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_countrys_sys_continent_id ON sys_countrys USING btree (sys_continent_id);


--
-- Name: sys_dashboard_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_entity_id ON sys_dashboard USING btree (entity_id);


--
-- Name: sys_dashboard_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_dashboard_org_id ON sys_dashboard USING btree (org_id);


--
-- Name: sys_emailed_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_org_id ON sys_emailed USING btree (org_id);


--
-- Name: sys_emailed_sys_email_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_sys_email_id ON sys_emailed USING btree (sys_email_id);


--
-- Name: sys_emailed_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emailed_table_id ON sys_emailed USING btree (table_id);


--
-- Name: sys_emails_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_emails_org_id ON sys_emails USING btree (org_id);


--
-- Name: sys_files_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_org_id ON sys_files USING btree (org_id);


--
-- Name: sys_files_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_files_table_id ON sys_files USING btree (table_id);


--
-- Name: sys_logins_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_logins_entity_id ON sys_logins USING btree (entity_id);


--
-- Name: sys_news_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_news_org_id ON sys_news USING btree (org_id);


--
-- Name: sys_queries_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_queries_org_id ON sys_queries USING btree (org_id);


--
-- Name: sys_reset_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_entity_id ON sys_reset USING btree (entity_id);


--
-- Name: sys_reset_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX sys_reset_org_id ON sys_reset USING btree (org_id);


--
-- Name: tax_rates_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_rates_org_id ON tax_rates USING btree (org_id);


--
-- Name: tax_rates_tax_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_rates_tax_type_id ON tax_rates USING btree (tax_type_id);


--
-- Name: tax_types_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_account_id ON tax_types USING btree (account_id);


--
-- Name: tax_types_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_currency_id ON tax_types USING btree (currency_id);


--
-- Name: tax_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_org_id ON tax_types USING btree (org_id);


--
-- Name: tax_types_sys_country_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_sys_country_id ON tax_types USING btree (sys_country_id);


--
-- Name: tax_types_use_key_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tax_types_use_key_id ON tax_types USING btree (use_key_id);


--
-- Name: tender_items_bidder_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tender_items_bidder_id ON tender_items USING btree (bidder_id);


--
-- Name: tender_items_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tender_items_org_id ON tender_items USING btree (org_id);


--
-- Name: tender_types_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tender_types_org_id ON tender_types USING btree (org_id);


--
-- Name: tenders_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tenders_org_id ON tenders USING btree (org_id);


--
-- Name: tenders_tender_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX tenders_tender_type_id ON tenders USING btree (tender_type_id);


--
-- Name: transaction_counters_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_counters_org_id ON transaction_counters USING btree (org_id);


--
-- Name: transaction_counters_transaction_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_counters_transaction_type_id ON transaction_counters USING btree (transaction_type_id);


--
-- Name: transaction_details_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_account_id ON transaction_details USING btree (account_id);


--
-- Name: transaction_details_item_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_item_id ON transaction_details USING btree (item_id);


--
-- Name: transaction_details_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_org_id ON transaction_details USING btree (org_id);


--
-- Name: transaction_details_transaction_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_details_transaction_id ON transaction_details USING btree (transaction_id);


--
-- Name: transaction_links_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_org_id ON transaction_links USING btree (org_id);


--
-- Name: transaction_links_transaction_detail_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_detail_id ON transaction_links USING btree (transaction_detail_id);


--
-- Name: transaction_links_transaction_detail_to; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_detail_to ON transaction_links USING btree (transaction_detail_to);


--
-- Name: transaction_links_transaction_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_id ON transaction_links USING btree (transaction_id);


--
-- Name: transaction_links_transaction_to; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transaction_links_transaction_to ON transaction_links USING btree (transaction_to);


--
-- Name: transactions_bank_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_bank_account_id ON transactions USING btree (bank_account_id);


--
-- Name: transactions_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_currency_id ON transactions USING btree (currency_id);


--
-- Name: transactions_department_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_department_id ON transactions USING btree (department_id);


--
-- Name: transactions_entered_by; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_entered_by ON transactions USING btree (entered_by);


--
-- Name: transactions_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_entity_id ON transactions USING btree (entity_id);


--
-- Name: transactions_journal_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_journal_id ON transactions USING btree (journal_id);


--
-- Name: transactions_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_org_id ON transactions USING btree (org_id);


--
-- Name: transactions_transaction_status_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_transaction_status_id ON transactions USING btree (transaction_status_id);


--
-- Name: transactions_transaction_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_transaction_type_id ON transactions USING btree (transaction_type_id);


--
-- Name: transactions_workflow_table_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transactions_workflow_table_id ON transactions USING btree (workflow_table_id);


--
-- Name: transfer_activity_account_activity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_account_activity_id ON transfer_activity USING btree (account_activity_id);


--
-- Name: transfer_activity_activity_frequency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_activity_frequency_id ON transfer_activity USING btree (activity_frequency_id);


--
-- Name: transfer_activity_activity_type_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_activity_type_id ON transfer_activity USING btree (activity_type_id);


--
-- Name: transfer_activity_currency_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_currency_id ON transfer_activity USING btree (currency_id);


--
-- Name: transfer_activity_deposit_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_deposit_account_id ON transfer_activity USING btree (deposit_account_id);


--
-- Name: transfer_activity_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_entity_id ON transfer_activity USING btree (entity_id);


--
-- Name: transfer_activity_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_org_id ON transfer_activity USING btree (org_id);


--
-- Name: transfer_activity_transfer_beneficiary_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_activity_transfer_beneficiary_id ON transfer_activity USING btree (transfer_beneficiary_id);


--
-- Name: transfer_beneficiary_customer_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_beneficiary_customer_id ON transfer_beneficiary USING btree (customer_id);


--
-- Name: transfer_beneficiary_deposit_account_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_beneficiary_deposit_account_id ON transfer_beneficiary USING btree (deposit_account_id);


--
-- Name: transfer_beneficiary_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_beneficiary_entity_id ON transfer_beneficiary USING btree (entity_id);


--
-- Name: transfer_beneficiary_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX transfer_beneficiary_org_id ON transfer_beneficiary USING btree (org_id);


--
-- Name: workflow_logs_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_logs_org_id ON workflow_logs USING btree (org_id);


--
-- Name: workflow_phases_approval_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_approval_entity_id ON workflow_phases USING btree (approval_entity_id);


--
-- Name: workflow_phases_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_org_id ON workflow_phases USING btree (org_id);


--
-- Name: workflow_phases_workflow_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_phases_workflow_id ON workflow_phases USING btree (workflow_id);


--
-- Name: workflow_sql_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_org_id ON workflow_sql USING btree (org_id);


--
-- Name: workflow_sql_workflow_phase_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflow_sql_workflow_phase_id ON workflow_sql USING btree (workflow_phase_id);


--
-- Name: workflows_org_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_org_id ON workflows USING btree (org_id);


--
-- Name: workflows_source_entity_id; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX workflows_source_entity_id ON workflows USING btree (source_entity_id);


--
-- Name: af_upd_transaction_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER af_upd_transaction_details AFTER INSERT OR DELETE OR UPDATE ON transaction_details FOR EACH ROW EXECUTE PROCEDURE af_upd_transaction_details();


--
-- Name: aft_account_activity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aft_account_activity AFTER INSERT ON account_activity FOR EACH ROW EXECUTE PROCEDURE aft_account_activity();


--
-- Name: aft_customers; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER aft_customers AFTER INSERT OR UPDATE ON customers FOR EACH ROW EXECUTE PROCEDURE aft_customers();


--
-- Name: ins_account_activity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_account_activity BEFORE INSERT ON account_activity FOR EACH ROW EXECUTE PROCEDURE ins_account_activity();


--
-- Name: ins_accounts_limit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_accounts_limit BEFORE INSERT ON deposit_accounts FOR EACH ROW EXECUTE PROCEDURE ins_accounts_limit();


--
-- Name: ins_activity_limit; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_activity_limit BEFORE INSERT ON account_activity FOR EACH ROW EXECUTE PROCEDURE ins_activity_limit();


--
-- Name: ins_address; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_address BEFORE INSERT OR UPDATE ON address FOR EACH ROW EXECUTE PROCEDURE ins_address();


--
-- Name: ins_applicants; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_applicants BEFORE INSERT OR UPDATE ON applicants FOR EACH ROW EXECUTE PROCEDURE ins_applicants();


--
-- Name: ins_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_approvals BEFORE INSERT ON approvals FOR EACH ROW EXECUTE PROCEDURE ins_approvals();


--
-- Name: ins_deposit_accounts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_deposit_accounts BEFORE INSERT OR UPDATE ON deposit_accounts FOR EACH ROW EXECUTE PROCEDURE ins_deposit_accounts();


--
-- Name: ins_entitys; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entitys AFTER INSERT ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_entitys();


--
-- Name: ins_entry_forms; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_entry_forms BEFORE INSERT ON entry_forms FOR EACH ROW EXECUTE PROCEDURE ins_entry_forms();


--
-- Name: ins_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_fields BEFORE INSERT ON fields FOR EACH ROW EXECUTE PROCEDURE ins_fields();


--
-- Name: ins_loans; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_loans BEFORE INSERT OR UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE ins_loans();


--
-- Name: ins_mpesa_api; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_mpesa_api BEFORE INSERT ON mpesa_api FOR EACH ROW EXECUTE PROCEDURE ins_mpesa_api();


--
-- Name: ins_password; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_password BEFORE INSERT OR UPDATE ON entitys FOR EACH ROW EXECUTE PROCEDURE ins_password();


--
-- Name: ins_periods; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_periods BEFORE INSERT OR UPDATE ON periods FOR EACH ROW EXECUTE PROCEDURE ins_periods();


--
-- Name: ins_sub_fields; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sub_fields BEFORE INSERT ON sub_fields FOR EACH ROW EXECUTE PROCEDURE ins_sub_fields();


--
-- Name: ins_subscriptions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_subscriptions BEFORE INSERT OR UPDATE ON subscriptions FOR EACH ROW EXECUTE PROCEDURE ins_subscriptions();


--
-- Name: ins_sys_reset; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_sys_reset AFTER INSERT ON sys_reset FOR EACH ROW EXECUTE PROCEDURE ins_sys_reset();


--
-- Name: ins_transactions; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_transactions BEFORE INSERT OR UPDATE ON transactions FOR EACH ROW EXECUTE PROCEDURE ins_transactions();


--
-- Name: ins_transfer_beneficiary; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ins_transfer_beneficiary BEFORE INSERT OR UPDATE ON transfer_beneficiary FOR EACH ROW EXECUTE PROCEDURE ins_transfer_beneficiary();


--
-- Name: log_account_activity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_account_activity AFTER DELETE OR UPDATE ON account_activity FOR EACH ROW EXECUTE PROCEDURE log_account_activity();


--
-- Name: log_collaterals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_collaterals AFTER DELETE OR UPDATE ON collaterals FOR EACH ROW EXECUTE PROCEDURE log_collaterals();


--
-- Name: log_customers; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_customers AFTER DELETE OR UPDATE ON customers FOR EACH ROW EXECUTE PROCEDURE log_customers();


--
-- Name: log_deposit_accounts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_deposit_accounts AFTER DELETE OR UPDATE ON deposit_accounts FOR EACH ROW EXECUTE PROCEDURE log_deposit_accounts();


--
-- Name: log_guarantees; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_guarantees AFTER DELETE OR UPDATE ON guarantees FOR EACH ROW EXECUTE PROCEDURE log_guarantees();


--
-- Name: log_loans; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER log_loans AFTER DELETE OR UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE log_loans();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON entry_forms FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON periods FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON transactions FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON budgets FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON pc_allocations FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON pc_expenditure FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON customers FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON products FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON deposit_accounts FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON transfer_beneficiary FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON account_activity FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON loans FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON guarantees FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON collaterals FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON subscriptions FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_action; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_action BEFORE INSERT OR UPDATE ON applicants FOR EACH ROW EXECUTE PROCEDURE upd_action();


--
-- Name: upd_approvals; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_approvals AFTER INSERT OR UPDATE ON approvals FOR EACH ROW EXECUTE PROCEDURE upd_approvals();


--
-- Name: upd_budget_lines; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_budget_lines BEFORE INSERT OR UPDATE ON budget_lines FOR EACH ROW EXECUTE PROCEDURE upd_budget_lines();


--
-- Name: upd_gls; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_gls BEFORE INSERT OR UPDATE ON gls FOR EACH ROW EXECUTE PROCEDURE upd_gls();


--
-- Name: upd_transaction_details; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER upd_transaction_details BEFORE INSERT OR UPDATE ON transaction_details FOR EACH ROW EXECUTE PROCEDURE upd_transaction_details();


SET search_path = logs, pg_catalog;

--
-- Name: lg_account_activity_account_activity_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_account_activity
    ADD CONSTRAINT lg_account_activity_account_activity_id_fkey FOREIGN KEY (account_activity_id) REFERENCES public.account_activity(account_activity_id);


--
-- Name: lg_account_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_account_activity
    ADD CONSTRAINT lg_account_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.orgs(org_id);


--
-- Name: lg_collaterals_org_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_collaterals
    ADD CONSTRAINT lg_collaterals_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.orgs(org_id);


--
-- Name: lg_customers_nationality_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_customers
    ADD CONSTRAINT lg_customers_nationality_fkey FOREIGN KEY (nationality) REFERENCES public.sys_countrys(sys_country_id);


--
-- Name: lg_customers_org_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_customers
    ADD CONSTRAINT lg_customers_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.orgs(org_id);


--
-- Name: lg_deposit_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_deposit_accounts
    ADD CONSTRAINT lg_deposit_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.orgs(org_id);


--
-- Name: lg_loans_org_id_fkey; Type: FK CONSTRAINT; Schema: logs; Owner: postgres
--

ALTER TABLE ONLY lg_loans
    ADD CONSTRAINT lg_loans_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.orgs(org_id);


SET search_path = public, pg_catalog;

--
-- Name: account_activity_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: account_activity_activity_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_activity_status_id_fkey FOREIGN KEY (activity_status_id) REFERENCES activity_status(activity_status_id);


--
-- Name: account_activity_activity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES activity_types(activity_type_id);


--
-- Name: account_activity_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: account_activity_deposit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_deposit_account_id_fkey FOREIGN KEY (deposit_account_id) REFERENCES deposit_accounts(deposit_account_id);


--
-- Name: account_activity_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: account_activity_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES loans(loan_id);


--
-- Name: account_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: account_activity_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: account_activity_transfer_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_transfer_account_id_fkey FOREIGN KEY (transfer_account_id) REFERENCES deposit_accounts(deposit_account_id);


--
-- Name: account_activity_transfer_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_activity
    ADD CONSTRAINT account_activity_transfer_loan_id_fkey FOREIGN KEY (transfer_loan_id) REFERENCES loans(loan_id);


--
-- Name: account_class_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_class
    ADD CONSTRAINT account_class_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: account_definations_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: account_definations_activity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES activity_types(activity_type_id);


--
-- Name: account_definations_charge_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_charge_activity_id_fkey FOREIGN KEY (charge_activity_id) REFERENCES activity_types(activity_type_id);


--
-- Name: account_definations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: account_definations_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_definations
    ADD CONSTRAINT account_definations_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id);


--
-- Name: account_notes_deposit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_notes
    ADD CONSTRAINT account_notes_deposit_account_id_fkey FOREIGN KEY (deposit_account_id) REFERENCES deposit_accounts(deposit_account_id);


--
-- Name: account_notes_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_notes
    ADD CONSTRAINT account_notes_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: account_types_account_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_account_class_id_fkey FOREIGN KEY (account_class_id) REFERENCES account_class(account_class_id);


--
-- Name: account_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY account_types
    ADD CONSTRAINT account_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: accounts_account_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_account_type_id_fkey FOREIGN KEY (account_type_id) REFERENCES account_types(account_type_id);


--
-- Name: accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY accounts
    ADD CONSTRAINT accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: activity_types_cr_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_cr_account_id_fkey FOREIGN KEY (cr_account_id) REFERENCES accounts(account_id);


--
-- Name: activity_types_dr_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_dr_account_id_fkey FOREIGN KEY (dr_account_id) REFERENCES accounts(account_id);


--
-- Name: activity_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: activity_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY activity_types
    ADD CONSTRAINT activity_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: address_address_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_address_type_id_fkey FOREIGN KEY (address_type_id) REFERENCES address_types(address_type_id);


--
-- Name: address_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: address_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address
    ADD CONSTRAINT address_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: address_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY address_types
    ADD CONSTRAINT address_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: applicants_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: applicants_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: applicants_nationality_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_nationality_fkey FOREIGN KEY (nationality) REFERENCES sys_countrys(sys_country_id);


--
-- Name: applicants_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY applicants
    ADD CONSTRAINT applicants_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approval_checklists_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES approvals(approval_id);


--
-- Name: approval_checklists_checklist_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_checklist_id_fkey FOREIGN KEY (checklist_id) REFERENCES checklists(checklist_id);


--
-- Name: approval_checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approval_checklists
    ADD CONSTRAINT approval_checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_app_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_app_entity_id_fkey FOREIGN KEY (app_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_entity_id_fkey FOREIGN KEY (org_entity_id) REFERENCES entitys(entity_id);


--
-- Name: approvals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: approvals_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY approvals
    ADD CONSTRAINT approvals_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: bank_accounts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: bank_accounts_bank_branch_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_bank_branch_id_fkey FOREIGN KEY (bank_branch_id) REFERENCES bank_branch(bank_branch_id);


--
-- Name: bank_accounts_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: bank_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_accounts
    ADD CONSTRAINT bank_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: bank_branch_bank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_bank_id_fkey FOREIGN KEY (bank_id) REFERENCES banks(bank_id);


--
-- Name: bank_branch_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bank_branch
    ADD CONSTRAINT bank_branch_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: banks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: banks_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY banks
    ADD CONSTRAINT banks_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: bidders_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bidders
    ADD CONSTRAINT bidders_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: bidders_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bidders
    ADD CONSTRAINT bidders_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: bidders_tender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY bidders
    ADD CONSTRAINT bidders_tender_id_fkey FOREIGN KEY (tender_id) REFERENCES tenders(tender_id);


--
-- Name: budget_lines_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: budget_lines_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_budget_id_fkey FOREIGN KEY (budget_id) REFERENCES budgets(budget_id);


--
-- Name: budget_lines_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: budget_lines_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: budget_lines_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: budget_lines_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budget_lines
    ADD CONSTRAINT budget_lines_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id);


--
-- Name: budgets_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: budgets_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: budgets_fiscal_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_fiscal_year_id_fkey FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(fiscal_year_id);


--
-- Name: budgets_link_budget_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_link_budget_id_fkey FOREIGN KEY (link_budget_id) REFERENCES budgets(budget_id);


--
-- Name: budgets_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY budgets
    ADD CONSTRAINT budgets_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: checklists_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: checklists_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY checklists
    ADD CONSTRAINT checklists_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: collateral_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collateral_types
    ADD CONSTRAINT collateral_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: collaterals_collateral_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collaterals
    ADD CONSTRAINT collaterals_collateral_type_id_fkey FOREIGN KEY (collateral_type_id) REFERENCES collateral_types(collateral_type_id);


--
-- Name: collaterals_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collaterals
    ADD CONSTRAINT collaterals_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: collaterals_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collaterals
    ADD CONSTRAINT collaterals_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES loans(loan_id);


--
-- Name: collaterals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY collaterals
    ADD CONSTRAINT collaterals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: contracts_bidder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contracts
    ADD CONSTRAINT contracts_bidder_id_fkey FOREIGN KEY (bidder_id) REFERENCES bidders(bidder_id);


--
-- Name: contracts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY contracts
    ADD CONSTRAINT contracts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: currency_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency
    ADD CONSTRAINT currency_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: currency_rates_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: currency_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY currency_rates
    ADD CONSTRAINT currency_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: customers_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: customers_nationality_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_nationality_fkey FOREIGN KEY (nationality) REFERENCES sys_countrys(sys_country_id);


--
-- Name: customers_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY customers
    ADD CONSTRAINT customers_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_accounts_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: default_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_accounts_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_accounts
    ADD CONSTRAINT default_accounts_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: default_tax_types_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: default_tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: default_tax_types_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY default_tax_types
    ADD CONSTRAINT default_tax_types_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: departments_ln_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_ln_department_id_fkey FOREIGN KEY (ln_department_id) REFERENCES departments(department_id);


--
-- Name: departments_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY departments
    ADD CONSTRAINT departments_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: deposit_accounts_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: deposit_accounts_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: deposit_accounts_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: deposit_accounts_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: deposit_accounts_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY deposit_accounts
    ADD CONSTRAINT deposit_accounts_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id);


--
-- Name: e_fields_et_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_et_field_id_fkey FOREIGN KEY (et_field_id) REFERENCES et_fields(et_field_id);


--
-- Name: e_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY e_fields
    ADD CONSTRAINT e_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_fields
    ADD CONSTRAINT entity_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_subscriptions_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entity_subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_subscriptions_subscription_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_subscriptions
    ADD CONSTRAINT entity_subscriptions_subscription_level_id_fkey FOREIGN KEY (subscription_level_id) REFERENCES subscription_levels(subscription_level_id);


--
-- Name: entity_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entity_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_types
    ADD CONSTRAINT entity_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entity_values_entity_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_field_id_fkey FOREIGN KEY (entity_field_id) REFERENCES entity_fields(entity_field_id);


--
-- Name: entity_values_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entity_values_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entity_values
    ADD CONSTRAINT entity_values_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: entitys_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: entitys_entity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_entity_type_id_fkey FOREIGN KEY (entity_type_id) REFERENCES entity_types(entity_type_id);


--
-- Name: entitys_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: entitys_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entitys
    ADD CONSTRAINT entitys_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: entry_forms_entered_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entered_by_id_fkey FOREIGN KEY (entered_by_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: entry_forms_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: entry_forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY entry_forms
    ADD CONSTRAINT entry_forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: et_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY et_fields
    ADD CONSTRAINT et_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fields_form_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_form_id_fkey FOREIGN KEY (form_id) REFERENCES forms(form_id);


--
-- Name: fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fields
    ADD CONSTRAINT fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: fiscal_years_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY fiscal_years
    ADD CONSTRAINT fiscal_years_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: follow_up_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY follow_up
    ADD CONSTRAINT follow_up_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: follow_up_lead_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY follow_up
    ADD CONSTRAINT follow_up_lead_item_id_fkey FOREIGN KEY (lead_item_id) REFERENCES lead_items(lead_item_id);


--
-- Name: follow_up_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY follow_up
    ADD CONSTRAINT follow_up_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: forms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY forms
    ADD CONSTRAINT forms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: gls_account_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_account_activity_id_fkey FOREIGN KEY (account_activity_id) REFERENCES account_activity(account_activity_id);


--
-- Name: gls_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: gls_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: gls_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY gls
    ADD CONSTRAINT gls_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: guarantees_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guarantees
    ADD CONSTRAINT guarantees_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: guarantees_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guarantees
    ADD CONSTRAINT guarantees_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: guarantees_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guarantees
    ADD CONSTRAINT guarantees_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES loans(loan_id);


--
-- Name: guarantees_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY guarantees
    ADD CONSTRAINT guarantees_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: helpdesk_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_client_id_fkey FOREIGN KEY (client_id) REFERENCES entitys(entity_id);


--
-- Name: helpdesk_closed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_closed_by_fkey FOREIGN KEY (closed_by) REFERENCES entitys(entity_id);


--
-- Name: helpdesk_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: helpdesk_pdefinition_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_pdefinition_id_fkey FOREIGN KEY (pdefinition_id) REFERENCES pdefinitions(pdefinition_id);


--
-- Name: helpdesk_plevel_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_plevel_id_fkey FOREIGN KEY (plevel_id) REFERENCES plevels(plevel_id);


--
-- Name: helpdesk_recorded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY helpdesk
    ADD CONSTRAINT helpdesk_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES entitys(entity_id);


--
-- Name: holidays_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY holidays
    ADD CONSTRAINT holidays_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: industry_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY industry
    ADD CONSTRAINT industry_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: interest_methods_activity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY interest_methods
    ADD CONSTRAINT interest_methods_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES activity_types(activity_type_id);


--
-- Name: interest_methods_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY interest_methods
    ADD CONSTRAINT interest_methods_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: item_category_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_category
    ADD CONSTRAINT item_category_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: item_units_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY item_units
    ADD CONSTRAINT item_units_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: items_item_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_item_category_id_fkey FOREIGN KEY (item_category_id) REFERENCES item_category(item_category_id);


--
-- Name: items_item_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_item_unit_id_fkey FOREIGN KEY (item_unit_id) REFERENCES item_units(item_unit_id);


--
-- Name: items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: items_purchase_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_purchase_account_id_fkey FOREIGN KEY (purchase_account_id) REFERENCES accounts(account_id);


--
-- Name: items_sales_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_sales_account_id_fkey FOREIGN KEY (sales_account_id) REFERENCES accounts(account_id);


--
-- Name: items_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY items
    ADD CONSTRAINT items_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: journals_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: journals_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: journals_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: journals_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY journals
    ADD CONSTRAINT journals_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: lead_items_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lead_items
    ADD CONSTRAINT lead_items_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: lead_items_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lead_items
    ADD CONSTRAINT lead_items_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: lead_items_lead_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lead_items
    ADD CONSTRAINT lead_items_lead_id_fkey FOREIGN KEY (lead_id) REFERENCES leads(lead_id);


--
-- Name: lead_items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY lead_items
    ADD CONSTRAINT lead_items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: leads_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_country_id_fkey FOREIGN KEY (country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: leads_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: leads_industry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_industry_id_fkey FOREIGN KEY (industry_id) REFERENCES industry(industry_id);


--
-- Name: leads_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY leads
    ADD CONSTRAINT leads_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ledger_links_ledger_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_ledger_type_id_fkey FOREIGN KEY (ledger_type_id) REFERENCES ledger_types(ledger_type_id);


--
-- Name: ledger_links_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_links
    ADD CONSTRAINT ledger_links_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ledger_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: ledger_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ledger_types_tax_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ledger_types
    ADD CONSTRAINT ledger_types_tax_account_id_fkey FOREIGN KEY (tax_account_id) REFERENCES accounts(account_id);


--
-- Name: loan_notes_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_notes
    ADD CONSTRAINT loan_notes_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES loans(loan_id);


--
-- Name: loan_notes_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loan_notes
    ADD CONSTRAINT loan_notes_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: loans_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: loans_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: loans_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: loans_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES products(product_id);


--
-- Name: locations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY locations
    ADD CONSTRAINT locations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: mpesa_api_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mpesa_api
    ADD CONSTRAINT mpesa_api_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: mpesa_trxs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY mpesa_trxs
    ADD CONSTRAINT mpesa_trxs_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: orgs_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: orgs_default_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_default_country_id_fkey FOREIGN KEY (default_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: orgs_org_client_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_org_client_id_fkey FOREIGN KEY (org_client_id) REFERENCES entitys(entity_id);


--
-- Name: orgs_parent_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY orgs
    ADD CONSTRAINT orgs_parent_org_id_fkey FOREIGN KEY (parent_org_id) REFERENCES orgs(org_id);


--
-- Name: pc_allocations_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: pc_allocations_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: pc_allocations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_allocations_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_allocations
    ADD CONSTRAINT pc_allocations_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: pc_banking_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_banking
    ADD CONSTRAINT pc_banking_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_banking_pc_allocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_banking
    ADD CONSTRAINT pc_banking_pc_allocation_id_fkey FOREIGN KEY (pc_allocation_id) REFERENCES pc_allocations(pc_allocation_id);


--
-- Name: pc_budget_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_budget
    ADD CONSTRAINT pc_budget_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_budget_pc_allocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_budget
    ADD CONSTRAINT pc_budget_pc_allocation_id_fkey FOREIGN KEY (pc_allocation_id) REFERENCES pc_allocations(pc_allocation_id);


--
-- Name: pc_budget_pc_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_budget
    ADD CONSTRAINT pc_budget_pc_item_id_fkey FOREIGN KEY (pc_item_id) REFERENCES pc_items(pc_item_id);


--
-- Name: pc_category_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_category
    ADD CONSTRAINT pc_category_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_expenditure_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: pc_expenditure_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_expenditure_pc_allocation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_pc_allocation_id_fkey FOREIGN KEY (pc_allocation_id) REFERENCES pc_allocations(pc_allocation_id);


--
-- Name: pc_expenditure_pc_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_pc_item_id_fkey FOREIGN KEY (pc_item_id) REFERENCES pc_items(pc_item_id);


--
-- Name: pc_expenditure_pc_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_expenditure
    ADD CONSTRAINT pc_expenditure_pc_type_id_fkey FOREIGN KEY (pc_type_id) REFERENCES pc_types(pc_type_id);


--
-- Name: pc_items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_items
    ADD CONSTRAINT pc_items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pc_items_pc_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_items
    ADD CONSTRAINT pc_items_pc_category_id_fkey FOREIGN KEY (pc_category_id) REFERENCES pc_category(pc_category_id);


--
-- Name: pc_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pc_types
    ADD CONSTRAINT pc_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pdefinitions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: pdefinitions_ptype_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY pdefinitions
    ADD CONSTRAINT pdefinitions_ptype_id_fkey FOREIGN KEY (ptype_id) REFERENCES ptypes(ptype_id);


--
-- Name: penalty_methods_activity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty_methods
    ADD CONSTRAINT penalty_methods_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES activity_types(activity_type_id);


--
-- Name: penalty_methods_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY penalty_methods
    ADD CONSTRAINT penalty_methods_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_tax_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_tax_rates_period_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_period_tax_type_id_fkey FOREIGN KEY (period_tax_type_id) REFERENCES period_tax_types(period_tax_type_id);


--
-- Name: period_tax_rates_tax_rate_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_rates
    ADD CONSTRAINT period_tax_rates_tax_rate_id_fkey FOREIGN KEY (tax_rate_id) REFERENCES tax_rates(tax_rate_id);


--
-- Name: period_tax_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: period_tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: period_tax_types_period_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_period_id_fkey FOREIGN KEY (period_id) REFERENCES periods(period_id);


--
-- Name: period_tax_types_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY period_tax_types
    ADD CONSTRAINT period_tax_types_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: periods_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: periods_fiscal_year_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_fiscal_year_id_fkey FOREIGN KEY (fiscal_year_id) REFERENCES fiscal_years(fiscal_year_id);


--
-- Name: periods_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY periods
    ADD CONSTRAINT periods_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: plevels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY plevels
    ADD CONSTRAINT plevels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: products_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: products_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: products_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: products_interest_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_interest_method_id_fkey FOREIGN KEY (interest_method_id) REFERENCES interest_methods(interest_method_id);


--
-- Name: products_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: products_penalty_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY products
    ADD CONSTRAINT products_penalty_method_id_fkey FOREIGN KEY (penalty_method_id) REFERENCES penalty_methods(penalty_method_id);


--
-- Name: ptypes_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ptypes
    ADD CONSTRAINT ptypes_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: quotations_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: quotations_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: quotations_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY quotations
    ADD CONSTRAINT quotations_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: reporting_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: reporting_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: reporting_report_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY reporting
    ADD CONSTRAINT reporting_report_to_id_fkey FOREIGN KEY (report_to_id) REFERENCES entitys(entity_id);


--
-- Name: sms_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sms_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sms
    ADD CONSTRAINT sms_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ss_items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ss_items
    ADD CONSTRAINT ss_items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: ss_items_ss_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ss_items
    ADD CONSTRAINT ss_items_ss_type_id_fkey FOREIGN KEY (ss_type_id) REFERENCES ss_types(ss_type_id);


--
-- Name: ss_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY ss_types
    ADD CONSTRAINT ss_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: stock_lines_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stock_lines
    ADD CONSTRAINT stock_lines_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: stock_lines_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stock_lines
    ADD CONSTRAINT stock_lines_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: stock_lines_stock_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stock_lines
    ADD CONSTRAINT stock_lines_stock_id_fkey FOREIGN KEY (stock_id) REFERENCES stocks(stock_id);


--
-- Name: stocks_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stocks
    ADD CONSTRAINT stocks_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: stocks_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stocks
    ADD CONSTRAINT stocks_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(store_id);


--
-- Name: store_movement_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store_movement
    ADD CONSTRAINT store_movement_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: store_movement_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store_movement
    ADD CONSTRAINT store_movement_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: store_movement_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store_movement
    ADD CONSTRAINT store_movement_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(store_id);


--
-- Name: store_movement_store_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY store_movement
    ADD CONSTRAINT store_movement_store_to_id_fkey FOREIGN KEY (store_to_id) REFERENCES stores(store_id);


--
-- Name: stores_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY stores
    ADD CONSTRAINT stores_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sub_fields_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_field_id_fkey FOREIGN KEY (field_id) REFERENCES fields(field_id);


--
-- Name: sub_fields_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sub_fields
    ADD CONSTRAINT sub_fields_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscription_levels_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscription_levels
    ADD CONSTRAINT subscription_levels_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: subscriptions_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_country_id_fkey FOREIGN KEY (country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: subscriptions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: subscriptions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY subscriptions
    ADD CONSTRAINT subscriptions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_audit_details_sys_audit_trail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_audit_details
    ADD CONSTRAINT sys_audit_details_sys_audit_trail_id_fkey FOREIGN KEY (sys_audit_trail_id) REFERENCES sys_audit_trail(sys_audit_trail_id);


--
-- Name: sys_countrys_sys_continent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_countrys
    ADD CONSTRAINT sys_countrys_sys_continent_id_fkey FOREIGN KEY (sys_continent_id) REFERENCES sys_continents(sys_continent_id);


--
-- Name: sys_dashboard_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_dashboard_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_dashboard
    ADD CONSTRAINT sys_dashboard_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_emailed_sys_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emailed
    ADD CONSTRAINT sys_emailed_sys_email_id_fkey FOREIGN KEY (sys_email_id) REFERENCES sys_emails(sys_email_id);


--
-- Name: sys_emails_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_emails
    ADD CONSTRAINT sys_emails_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_files_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_files
    ADD CONSTRAINT sys_files_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_logins_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_logins
    ADD CONSTRAINT sys_logins_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_news_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_news
    ADD CONSTRAINT sys_news_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_queries_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_queries
    ADD CONSTRAINT sys_queries_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: sys_reset_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: sys_reset_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY sys_reset
    ADD CONSTRAINT sys_reset_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_rates_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_rates_tax_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_rates
    ADD CONSTRAINT tax_rates_tax_type_id_fkey FOREIGN KEY (tax_type_id) REFERENCES tax_types(tax_type_id);


--
-- Name: tax_types_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: tax_types_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: tax_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tax_types_sys_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_sys_country_id_fkey FOREIGN KEY (sys_country_id) REFERENCES sys_countrys(sys_country_id);


--
-- Name: tax_types_use_key_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tax_types
    ADD CONSTRAINT tax_types_use_key_id_fkey FOREIGN KEY (use_key_id) REFERENCES use_keys(use_key_id);


--
-- Name: tender_items_bidder_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tender_items
    ADD CONSTRAINT tender_items_bidder_id_fkey FOREIGN KEY (bidder_id) REFERENCES bidders(bidder_id);


--
-- Name: tender_items_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tender_items
    ADD CONSTRAINT tender_items_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tender_types_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tender_types
    ADD CONSTRAINT tender_types_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tenders_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tenders
    ADD CONSTRAINT tenders_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: tenders_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tenders
    ADD CONSTRAINT tenders_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: tenders_tender_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY tenders
    ADD CONSTRAINT tenders_tender_type_id_fkey FOREIGN KEY (tender_type_id) REFERENCES tender_types(tender_type_id);


--
-- Name: transaction_counters_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_counters_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_counters
    ADD CONSTRAINT transaction_counters_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(transaction_type_id);


--
-- Name: transaction_details_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_account_id_fkey FOREIGN KEY (account_id) REFERENCES accounts(account_id);


--
-- Name: transaction_details_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_item_id_fkey FOREIGN KEY (item_id) REFERENCES items(item_id);


--
-- Name: transaction_details_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_details_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_store_id_fkey FOREIGN KEY (store_id) REFERENCES stores(store_id);


--
-- Name: transaction_details_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_details
    ADD CONSTRAINT transaction_details_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id);


--
-- Name: transaction_links_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transaction_links_transaction_detail_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_detail_id_fkey FOREIGN KEY (transaction_detail_id) REFERENCES transaction_details(transaction_detail_id);


--
-- Name: transaction_links_transaction_detail_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_detail_to_fkey FOREIGN KEY (transaction_detail_to) REFERENCES transaction_details(transaction_detail_id);


--
-- Name: transaction_links_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id);


--
-- Name: transaction_links_transaction_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transaction_links
    ADD CONSTRAINT transaction_links_transaction_to_fkey FOREIGN KEY (transaction_to) REFERENCES transactions(transaction_id);


--
-- Name: transactions_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(bank_account_id);


--
-- Name: transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: transactions_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(department_id);


--
-- Name: transactions_entered_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES entitys(entity_id);


--
-- Name: transactions_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: transactions_journal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_journal_id_fkey FOREIGN KEY (journal_id) REFERENCES journals(journal_id);


--
-- Name: transactions_ledger_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_ledger_type_id_fkey FOREIGN KEY (ledger_type_id) REFERENCES ledger_types(ledger_type_id);


--
-- Name: transactions_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transactions_transaction_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_transaction_status_id_fkey FOREIGN KEY (transaction_status_id) REFERENCES transaction_status(transaction_status_id);


--
-- Name: transactions_transaction_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transactions
    ADD CONSTRAINT transactions_transaction_type_id_fkey FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(transaction_type_id);


--
-- Name: transfer_activity_account_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_account_activity_id_fkey FOREIGN KEY (account_activity_id) REFERENCES account_activity(account_activity_id);


--
-- Name: transfer_activity_activity_frequency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_activity_frequency_id_fkey FOREIGN KEY (activity_frequency_id) REFERENCES activity_frequency(activity_frequency_id);


--
-- Name: transfer_activity_activity_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_activity_type_id_fkey FOREIGN KEY (activity_type_id) REFERENCES activity_types(activity_type_id);


--
-- Name: transfer_activity_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES currency(currency_id);


--
-- Name: transfer_activity_deposit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_deposit_account_id_fkey FOREIGN KEY (deposit_account_id) REFERENCES deposit_accounts(deposit_account_id);


--
-- Name: transfer_activity_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: transfer_activity_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: transfer_activity_transfer_beneficiary_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_activity
    ADD CONSTRAINT transfer_activity_transfer_beneficiary_id_fkey FOREIGN KEY (transfer_beneficiary_id) REFERENCES transfer_beneficiary(transfer_beneficiary_id);


--
-- Name: transfer_beneficiary_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES customers(customer_id);


--
-- Name: transfer_beneficiary_deposit_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_deposit_account_id_fkey FOREIGN KEY (deposit_account_id) REFERENCES deposit_accounts(deposit_account_id);


--
-- Name: transfer_beneficiary_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES entitys(entity_id);


--
-- Name: transfer_beneficiary_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY transfer_beneficiary
    ADD CONSTRAINT transfer_beneficiary_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_logs_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_logs
    ADD CONSTRAINT workflow_logs_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_approval_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_approval_entity_id_fkey FOREIGN KEY (approval_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: workflow_phases_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_phases_workflow_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_phases
    ADD CONSTRAINT workflow_phases_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES workflows(workflow_id);


--
-- Name: workflow_sql_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflow_sql_workflow_phase_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflow_sql
    ADD CONSTRAINT workflow_sql_workflow_phase_id_fkey FOREIGN KEY (workflow_phase_id) REFERENCES workflow_phases(workflow_phase_id);


--
-- Name: workflows_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_org_id_fkey FOREIGN KEY (org_id) REFERENCES orgs(org_id);


--
-- Name: workflows_source_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY workflows
    ADD CONSTRAINT workflows_source_entity_id_fkey FOREIGN KEY (source_entity_id) REFERENCES entity_types(entity_type_id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

