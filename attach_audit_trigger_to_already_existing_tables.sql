-- populate the 'tables_that_should_not_have_logger' array with all the tables that should not have logger trigger attached to them 
-- depending upon your use case

DO $$ 
DECLARE 
    current_table_name TEXT;
   	tables_that_should_not_have_logger TEXT[] := ARRAY['log_table'];
BEGIN
    FOR current_table_name IN 
    (
		SELECT
			table_name
		FROM
			information_schema.tables
		WHERE
			table_schema = 'public'
			AND table_type = 'BASE TABLE'
			AND table_name NOT IN (SELECT UNNEST(tables_that_should_not_have_logger))
    ) 
    LOOP
        EXECUTE format('
			DROP TRIGGER IF EXISTS log_changes ON %I;
            CREATE TRIGGER log_changes
            AFTER INSERT OR UPDATE OR DELETE ON %I
            FOR EACH ROW EXECUTE FUNCTION log_changes()
        ', current_table_name, current_table_name);
	END LOOP;
END $$;