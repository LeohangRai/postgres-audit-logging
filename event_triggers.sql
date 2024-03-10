-- log table where all the logs will be stored
CREATE TABLE log_table (
	id serial PRIMARY KEY,
	table_name varchar(255),
	operation varchar(255),
	old_value jsonb,
	new_value jsonb,
	timestamp timestamp DEFAULT current_timestamp
);


-- the trigger function that must be attached to each table in the database
CREATE OR REPLACE FUNCTION log_changes()
RETURNS TRIGGER  AS 
$$
BEGIN 
	IF TG_OP = 'INSERT' THEN
		INSERT INTO log_table (table_name, operation, new_value, "timestamp")
		VALUES (TG_TABLE_NAME, TG_OP, to_json(NEW), current_timestamp);
		RETURN NEW;
	ELSIF TG_OP = 'UPDATE' THEN
		INSERT INTO log_table (table_name, operation, new_value, old_value, "timestamp")
		VALUES (TG_TABLE_NAME, TG_OP, to_json(NEW), to_json(OLD), current_timestamp);
		RETURN NEW;
	ELSE 
		INSERT INTO log_table (table_name, operation, old_value, "timestamp")
		VALUES (TG_TABLE_NAME, TG_OP, to_json(OLD), current_timestamp);
		RETURN OLD;
	END IF;
END;
$$
LANGUAGE plpgsql;


-- function that will be used as the event trigger function that will automatically attach the log_changes() trigger to any new table created in the database
CREATE OR REPLACE FUNCTION create_log_trigger_for_new_table()
RETURNS event_trigger AS 
$$
DECLARE 
	command_record RECORD;
BEGIN
	SELECT * INTO command_record FROM pg_event_trigger_ddl_commands() WHERE object_type = 'table';
	EXECUTE format('
		CREATE TRIGGER log_changes
		AFTER INSERT OR UPDATE OR DELETE ON %I
		FOR EACH ROW EXECUTE FUNCTION log_changes()
	', SPLIT_PART(command_record.object_identity, '.', 2));  -- command_record.object_identity gives the TABLE name IN TEXT format 
END;
$$
LANGUAGE plpgsql;


-- event trigger for ddl command end
CREATE EVENT TRIGGER attach_log_trigger_to_new_table
ON ddl_command_end
WHEN tag IN ('CREATE TABLE')
EXECUTE FUNCTION create_log_trigger_for_new_table();

-- function that will delete the oldest record from the log_table if the count of rows is greater than 10000 on the next INSERT operation
CREATE OR REPLACE FUNCTION delete_ten_thousandth_row_from_log_table()
RETURNS TRIGGER AS 
$$
DECLARE rows_count int;
BEGIN
	SELECT count(*) INTO rows_count FROM log_table;
	IF rows_count > 10000 THEN
		DELETE FROM log_table WHERE id = (
			SELECT id FROM log_table ORDER BY log_table."timestamp" LIMIT 1
		);
	END IF;
	RETURN NEW;
END
$$
LANGUAGE plpgsql; 


-- attach the delete_ten_thousandth_row_from_log_table function as trigger to the log_table on 'AFTER INSERT' operation
CREATE TRIGGER delete_ten_thousandth_row
AFTER INSERT ON public.log_table 
FOR EACH ROW EXECUTE FUNCTION delete_ten_thousandth_row_from_log_table();



-- test
CREATE TABLE test (
	id serial PRIMARY KEY,
	topic varchar(255) NOT NULL,
	description TEXT,
	created_at timestamp DEFAULT current_timestamp,
	updated_at timestamp DEFAULT current_timestamp
);

-- test
CREATE TABLE todos (
	id serial PRIMARY KEY,
	task varchar(255) NOT NULL,
	description TEXT,
	deadline date,
	is_complete boolean DEFAULT FALSE,
	created_at timestamp DEFAULT current_timestamp,
	updated_at timestamp DEFAULT current_timestamp
);


-- test
INSERT INTO test (topic, description)
VALUES ('Test 1', 'This is a test data');

INSERT INTO todos (task, deadline, is_complete)
VALUES ('Task 1', CURRENT_DATE, false);


-- test
CREATE TABLE test_table (
	id serial PRIMARY KEY,
	name varchar(255)
);

INSERT INTO test_table (name)
VALUES ('Jeeten');

DELETE FROM test_table WHERE id = 1;