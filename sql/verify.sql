\set ON_ERROR_STOP on
DO $$
DECLARE
    table_name text;
    row_count integer;
BEGIN
    FOREACH table_name IN ARRAY ARRAY['departments','students','teachers','courses','teaching_classes','enrollments'] LOOP
        EXECUTE format('SELECT count(*) FROM %I', table_name) INTO row_count;
        IF row_count < 10 THEN
            RAISE EXCEPTION '% has only % rows; at least 10 required', table_name, row_count;
        END IF;
        RAISE NOTICE '%: % rows', table_name, row_count;
    END LOOP;
    IF EXISTS (
        SELECT 1 FROM teaching_classes tc
        LEFT JOIN (SELECT class_id, count(*) AS actual FROM enrollments GROUP BY class_id) e USING (class_id)
        WHERE tc.enrolled_count <> coalesce(e.actual, 0)
    ) THEN
        RAISE EXCEPTION 'Enrollment counter differs from enrollment records';
    END IF;
END $$;
