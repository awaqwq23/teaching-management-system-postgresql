\set ON_ERROR_STOP on
SELECT 'CREATE DATABASE course_management ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'course_management')
\gexec
