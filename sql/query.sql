\set ON_ERROR_STOP on
\echo Q1: single-table condition and ordering
SELECT student_no, student_name, admission_year
FROM students WHERE admission_year = 2026 ORDER BY student_no;

\echo Q2: course condition and ordering
SELECT course_code, course_name, credits
FROM courses WHERE credits >= 3 ORDER BY credits DESC, course_code;

\echo Q3: INNER JOIN student enrollment transcript
SELECT s.student_no, s.student_name, c.course_name, tc.class_code,
       t.teacher_name, e.grade
FROM enrollments e
INNER JOIN students s USING (student_id)
INNER JOIN teaching_classes tc USING (class_id)
INNER JOIN courses c USING (course_id)
INNER JOIN teachers t USING (teacher_id)
WHERE s.student_no = 'S2026001' ORDER BY tc.class_code;

\echo Q4: LEFT JOIN includes students without enrollment
SELECT s.student_no, s.student_name, count(e.class_id) AS class_count
FROM students s LEFT JOIN enrollments e USING (student_id)
GROUP BY s.student_id ORDER BY s.student_no;

\echo Q5: GROUP BY with HAVING
SELECT c.course_code, c.course_name, count(e.student_id) AS enrollment_count,
       round(avg(e.grade), 2) AS average_grade
FROM courses c
INNER JOIN teaching_classes tc USING (course_id)
INNER JOIN enrollments e USING (class_id)
GROUP BY c.course_id HAVING count(e.student_id) >= 3 ORDER BY c.course_code;

\echo Q6: IN nested query
SELECT student_no, student_name FROM students
WHERE student_id IN (
    SELECT e.student_id FROM enrollments e
    INNER JOIN teaching_classes tc USING (class_id)
    WHERE tc.course_id = (SELECT course_id FROM courses WHERE course_code = 'C001')
) ORDER BY student_no;

\echo Q7: EXISTS nested query
SELECT t.teacher_no, t.teacher_name FROM teachers t
WHERE EXISTS (
    SELECT 1 FROM teaching_classes tc
    INNER JOIN enrollments e USING (class_id)
    WHERE tc.teacher_id = t.teacher_id AND e.grade IS NULL
) ORDER BY t.teacher_no;

\echo Q8: complex business statistics across four tables
SELECT d.department_code, d.department_name,
       count(DISTINCT c.course_id) AS course_count,
       count(DISTINCT tc.class_id) AS class_count,
       count(e.student_id) AS enrollment_count,
       round(avg(e.grade), 2) AS average_grade,
       round(100.0 * count(*) FILTER (WHERE e.grade >= 60) /
             nullif(count(e.grade), 0), 2) AS pass_rate_percent
FROM departments d
LEFT JOIN courses c USING (department_id)
LEFT JOIN teaching_classes tc USING (course_id)
LEFT JOIN enrollments e USING (class_id)
GROUP BY d.department_id ORDER BY d.department_code;
