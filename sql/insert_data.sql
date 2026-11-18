BEGIN;

INSERT INTO departments(department_code, department_name)
SELECT 'D' || lpad(series::text, 2, '0'),
       (ARRAY['计算机学院','软件学院','数学学院','物理学院','外语学院',
              '经济学院','管理学院','法学院','文学院','生命科学学院'])[series]
FROM generate_series(1, 10) AS series;

INSERT INTO students(student_no, student_name, department_id, email, admission_year)
SELECT 'S2026' || lpad(series::text, 3, '0'), '学生' || lpad(series::text, 2, '0'),
       (series - 1) % 10 + 1, 'student' || series || '@example.invalid', 2026
FROM generate_series(1, 20) AS series;

INSERT INTO teachers(teacher_no, teacher_name, department_id)
SELECT 'T' || lpad(series::text, 3, '0'), '教师' || lpad(series::text, 2, '0'), series
FROM generate_series(1, 10) AS series;

INSERT INTO courses(course_code, course_name, credits, department_id)
SELECT 'C' || lpad(series::text, 3, '0'),
       (ARRAY['数据库系统','Java程序设计','高等数学','大学物理','大学英语',
              '微观经济学','管理学原理','法学导论','大学语文','生命科学导论'])[series],
       CASE WHEN series <= 3 THEN 4.0 ELSE 2.0 END, series
FROM generate_series(1, 10) AS series;

INSERT INTO teaching_classes(class_code, course_id, teacher_id, semester, capacity)
SELECT 'CLS2026' || lpad(series::text, 3, '0'), (series - 1) % 10 + 1,
       (series - 1) % 10 + 1, '2026-2027-1',
       CASE WHEN series = 12 THEN 2 ELSE 30 END
FROM generate_series(1, 12) AS series;

INSERT INTO enrollments(student_id, class_id, grade)
SELECT (series - 1) % 20 + 1, (series - 1) % 12 + 1,
       CASE WHEN series % 4 = 0 THEN NULL ELSE 70 + series % 30 END
FROM generate_series(1, 24) AS series;

COMMIT;
