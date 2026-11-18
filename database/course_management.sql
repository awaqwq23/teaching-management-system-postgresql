--
-- PostgreSQL database dump
--

-- Dumped from database version 16.16
-- Dumped by pg_dump version 16.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: maintain_enrollment_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.maintain_enrollment_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE teaching_classes SET enrolled_count = enrolled_count + 1
        WHERE class_id = NEW.class_id AND enrolled_count < capacity;
        IF NOT FOUND THEN
            IF NOT EXISTS (SELECT 1 FROM teaching_classes WHERE class_id = NEW.class_id) THEN
                RAISE EXCEPTION 'Teaching class does not exist' USING ERRCODE = '23503';
            END IF;
            RAISE EXCEPTION 'Teaching class is full' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE teaching_classes SET enrolled_count = enrolled_count - 1 WHERE class_id = OLD.class_id;
        RETURN OLD;
    END IF;
    IF NEW.student_id <> OLD.student_id OR NEW.class_id <> OLD.class_id THEN
        RAISE EXCEPTION 'Withdraw and enroll instead of changing enrollment identity'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END $$;


--
-- Name: verify_enrollment_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_enrollment_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    cached integer;
    actual bigint;
BEGIN
    SELECT enrolled_count INTO cached FROM teaching_classes WHERE class_id = NEW.class_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    SELECT count(*) INTO actual FROM enrollments WHERE class_id = NEW.class_id;
    IF cached <> actual THEN
        RAISE EXCEPTION 'Enrollment count mismatch: class %, cached %, actual %', NEW.class_id, cached, actual
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courses (
    course_id bigint NOT NULL,
    course_code character varying(20) NOT NULL,
    course_name character varying(100) NOT NULL,
    credits numeric(3,1) NOT NULL,
    department_id bigint NOT NULL,
    CONSTRAINT courses_course_code_check CHECK ((btrim((course_code)::text) <> ''::text)),
    CONSTRAINT courses_course_name_check CHECK ((btrim((course_name)::text) <> ''::text)),
    CONSTRAINT courses_credits_check CHECK (((credits > (0)::numeric) AND (credits <= (10)::numeric)))
);
ALTER TABLE ONLY public.courses ALTER COLUMN course_id SET (pg_attver=32154480);
ALTER TABLE ONLY public.courses ALTER COLUMN course_code SET (pg_attver=32154480);
ALTER TABLE ONLY public.courses ALTER COLUMN course_name SET (pg_attver=32154480);
ALTER TABLE ONLY public.courses ALTER COLUMN credits SET (pg_attver=32154480);
ALTER TABLE ONLY public.courses ALTER COLUMN department_id SET (pg_attver=32154480);


--
-- Name: courses_course_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.courses ALTER COLUMN course_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.courses_course_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    department_id bigint NOT NULL,
    department_code character varying(12) NOT NULL,
    department_name character varying(80) NOT NULL,
    CONSTRAINT departments_department_code_check CHECK ((btrim((department_code)::text) <> ''::text)),
    CONSTRAINT departments_department_name_check CHECK ((btrim((department_name)::text) <> ''::text))
);
ALTER TABLE ONLY public.departments ALTER COLUMN department_id SET (pg_attver=32075848);
ALTER TABLE ONLY public.departments ALTER COLUMN department_code SET (pg_attver=32075848);
ALTER TABLE ONLY public.departments ALTER COLUMN department_name SET (pg_attver=32075848);


--
-- Name: departments_department_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.departments ALTER COLUMN department_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.departments_department_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enrollments (
    student_id bigint NOT NULL,
    class_id bigint NOT NULL,
    enrolled_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    grade numeric(5,2),
    CONSTRAINT enrollments_grade_check CHECK (((grade >= (0)::numeric) AND (grade <= (100)::numeric)))
);
ALTER TABLE ONLY public.enrollments ALTER COLUMN student_id SET (pg_attver=32210024);
ALTER TABLE ONLY public.enrollments ALTER COLUMN class_id SET (pg_attver=32210024);
ALTER TABLE ONLY public.enrollments ALTER COLUMN enrolled_at SET (pg_attver=32210024);
ALTER TABLE ONLY public.enrollments ALTER COLUMN grade SET (pg_attver=32210024);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    student_id bigint NOT NULL,
    student_no character varying(20) NOT NULL,
    student_name character varying(60) NOT NULL,
    department_id bigint NOT NULL,
    email character varying(120),
    admission_year smallint NOT NULL,
    CONSTRAINT students_admission_year_check CHECK (((admission_year >= 2000) AND (admission_year <= 2100))),
    CONSTRAINT students_email_check CHECK (((email IS NULL) OR (btrim((email)::text) <> ''::text))),
    CONSTRAINT students_student_name_check CHECK ((btrim((student_name)::text) <> ''::text)),
    CONSTRAINT students_student_no_check CHECK ((btrim((student_no)::text) <> ''::text))
);
ALTER TABLE ONLY public.students ALTER COLUMN student_id SET (pg_attver=32095632);
ALTER TABLE ONLY public.students ALTER COLUMN student_no SET (pg_attver=32095632);
ALTER TABLE ONLY public.students ALTER COLUMN student_name SET (pg_attver=32095632);
ALTER TABLE ONLY public.students ALTER COLUMN department_id SET (pg_attver=32095632);
ALTER TABLE ONLY public.students ALTER COLUMN email SET (pg_attver=32095632);
ALTER TABLE ONLY public.students ALTER COLUMN admission_year SET (pg_attver=32095632);


--
-- Name: students_student_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.students ALTER COLUMN student_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.students_student_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: teachers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teachers (
    teacher_id bigint NOT NULL,
    teacher_no character varying(20) NOT NULL,
    teacher_name character varying(60) NOT NULL,
    department_id bigint NOT NULL,
    CONSTRAINT teachers_teacher_name_check CHECK ((btrim((teacher_name)::text) <> ''::text)),
    CONSTRAINT teachers_teacher_no_check CHECK ((btrim((teacher_no)::text) <> ''::text))
);
ALTER TABLE ONLY public.teachers ALTER COLUMN teacher_id SET (pg_attver=32124504);
ALTER TABLE ONLY public.teachers ALTER COLUMN teacher_no SET (pg_attver=32124504);
ALTER TABLE ONLY public.teachers ALTER COLUMN teacher_name SET (pg_attver=32124504);
ALTER TABLE ONLY public.teachers ALTER COLUMN department_id SET (pg_attver=32124504);


--
-- Name: teachers_teacher_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.teachers ALTER COLUMN teacher_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.teachers_teacher_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: teaching_classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teaching_classes (
    class_id bigint NOT NULL,
    class_code character varying(24) NOT NULL,
    course_id bigint NOT NULL,
    teacher_id bigint NOT NULL,
    semester character varying(11) NOT NULL,
    capacity integer NOT NULL,
    enrolled_count integer DEFAULT 0 NOT NULL,
    CONSTRAINT teaching_classes_capacity_check CHECK (((capacity >= 1) AND (capacity <= 500))),
    CONSTRAINT teaching_classes_check CHECK (((enrolled_count >= 0) AND (enrolled_count <= capacity))),
    CONSTRAINT teaching_classes_class_code_check CHECK ((btrim((class_code)::text) <> ''::text)),
    CONSTRAINT teaching_classes_semester_check CHECK (
CASE
    WHEN ((semester)::text ~ '^[0-9]{4}-[0-9]{4}-[12]$'::text) THEN (("substring"((semester)::text, 6, 4))::integer = (("substring"((semester)::text, 1, 4))::integer + 1))
    ELSE false
END)
);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN class_id SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN class_code SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN course_id SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN teacher_id SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN semester SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN capacity SET (pg_attver=32178368);
ALTER TABLE ONLY public.teaching_classes ALTER COLUMN enrolled_count SET (pg_attver=32178368);


--
-- Name: teaching_classes_class_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.teaching_classes ALTER COLUMN class_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.teaching_classes_class_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.courses (course_id, course_code, course_name, credits, department_id) FROM stdin;
1	C001	数据库系统	4.0	1
2	C002	Java程序设计	4.0	2
3	C003	高等数学	4.0	3
4	C004	大学物理	2.0	4
5	C005	大学英语	2.0	5
6	C006	微观经济学	2.0	6
7	C007	管理学原理	2.0	7
8	C008	法学导论	2.0	8
9	C009	大学语文	2.0	9
10	C010	生命科学导论	2.0	10
\.


--
-- Data for Name: departments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.departments (department_id, department_code, department_name) FROM stdin;
1	D01	计算机学院
2	D02	软件学院
3	D03	数学学院
4	D04	物理学院
5	D05	外语学院
6	D06	经济学院
7	D07	管理学院
8	D08	法学院
9	D09	文学院
10	D10	生命科学学院
\.


--
-- Data for Name: enrollments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.enrollments (student_id, class_id, enrolled_at, grade) FROM stdin;
1	1	2026-11-18 09:39:53.983393+08	71.00
2	2	2026-11-18 09:39:53.983393+08	72.00
3	3	2026-11-18 09:39:53.983393+08	73.00
4	4	2026-11-18 09:39:53.983393+08	\N
5	5	2026-11-18 09:39:53.983393+08	75.00
6	6	2026-11-18 09:39:53.983393+08	76.00
7	7	2026-11-18 09:39:53.983393+08	77.00
8	8	2026-11-18 09:39:53.983393+08	\N
9	9	2026-11-18 09:39:53.983393+08	79.00
10	10	2026-11-18 09:39:53.983393+08	80.00
11	11	2026-11-18 09:39:53.983393+08	81.00
12	12	2026-11-18 09:39:53.983393+08	\N
13	1	2026-11-18 09:39:53.983393+08	83.00
14	2	2026-11-18 09:39:53.983393+08	84.00
15	3	2026-11-18 09:39:53.983393+08	85.00
16	4	2026-11-18 09:39:53.983393+08	\N
17	5	2026-11-18 09:39:53.983393+08	87.00
18	6	2026-11-18 09:39:53.983393+08	88.00
19	7	2026-11-18 09:39:53.983393+08	89.00
20	8	2026-11-18 09:39:53.983393+08	\N
1	9	2026-11-18 09:39:53.983393+08	91.00
2	10	2026-11-18 09:39:53.983393+08	92.00
3	11	2026-11-18 09:39:53.983393+08	93.00
4	12	2026-11-18 09:39:53.983393+08	\N
\.


--
-- Data for Name: students; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.students (student_id, student_no, student_name, department_id, email, admission_year) FROM stdin;
1	S2026001	学生01	1	student1@example.invalid	2026
2	S2026002	学生02	2	student2@example.invalid	2026
3	S2026003	学生03	3	student3@example.invalid	2026
4	S2026004	学生04	4	student4@example.invalid	2026
5	S2026005	学生05	5	student5@example.invalid	2026
6	S2026006	学生06	6	student6@example.invalid	2026
7	S2026007	学生07	7	student7@example.invalid	2026
8	S2026008	学生08	8	student8@example.invalid	2026
9	S2026009	学生09	9	student9@example.invalid	2026
10	S2026010	学生10	10	student10@example.invalid	2026
11	S2026011	学生11	1	student11@example.invalid	2026
12	S2026012	学生12	2	student12@example.invalid	2026
13	S2026013	学生13	3	student13@example.invalid	2026
14	S2026014	学生14	4	student14@example.invalid	2026
15	S2026015	学生15	5	student15@example.invalid	2026
16	S2026016	学生16	6	student16@example.invalid	2026
17	S2026017	学生17	7	student17@example.invalid	2026
18	S2026018	学生18	8	student18@example.invalid	2026
19	S2026019	学生19	9	student19@example.invalid	2026
20	S2026020	学生20	10	student20@example.invalid	2026
\.


--
-- Data for Name: teachers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.teachers (teacher_id, teacher_no, teacher_name, department_id) FROM stdin;
1	T001	教师01	1
2	T002	教师02	2
3	T003	教师03	3
4	T004	教师04	4
5	T005	教师05	5
6	T006	教师06	6
7	T007	教师07	7
8	T008	教师08	8
9	T009	教师09	9
10	T010	教师10	10
\.


--
-- Data for Name: teaching_classes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.teaching_classes (class_id, class_code, course_id, teacher_id, semester, capacity, enrolled_count) FROM stdin;
1	CLS2026001	1	1	2026-2027-1	30	2
2	CLS2026002	2	2	2026-2027-1	30	2
3	CLS2026003	3	3	2026-2027-1	30	2
4	CLS2026004	4	4	2026-2027-1	30	2
5	CLS2026005	5	5	2026-2027-1	30	2
6	CLS2026006	6	6	2026-2027-1	30	2
7	CLS2026007	7	7	2026-2027-1	30	2
8	CLS2026008	8	8	2026-2027-1	30	2
9	CLS2026009	9	9	2026-2027-1	30	2
10	CLS2026010	10	10	2026-2027-1	30	2
11	CLS2026011	1	1	2026-2027-1	30	2
12	CLS2026012	2	2	2026-2027-1	2	2
\.


--
-- Name: courses_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.courses_course_id_seq', 10, true);


--
-- Name: departments_department_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.departments_department_id_seq', 10, true);


--
-- Name: students_student_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.students_student_id_seq', 20, true);


--
-- Name: teachers_teacher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.teachers_teacher_id_seq', 10, true);


--
-- Name: teaching_classes_class_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.teaching_classes_class_id_seq', 12, true);


--
-- Name: courses courses_course_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_course_code_key UNIQUE (course_code);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (course_id);


--
-- Name: departments departments_department_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_department_code_key UNIQUE (department_code);


--
-- Name: departments departments_department_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_department_name_key UNIQUE (department_name);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (department_id);


--
-- Name: enrollments enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_pkey PRIMARY KEY (student_id, class_id);


--
-- Name: students students_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_email_key UNIQUE (email);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (student_id);


--
-- Name: students students_student_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_student_no_key UNIQUE (student_no);


--
-- Name: teachers teachers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_pkey PRIMARY KEY (teacher_id);


--
-- Name: teachers teachers_teacher_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_teacher_no_key UNIQUE (teacher_no);


--
-- Name: teaching_classes teaching_classes_class_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_classes
    ADD CONSTRAINT teaching_classes_class_code_key UNIQUE (class_code);


--
-- Name: teaching_classes teaching_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_classes
    ADD CONSTRAINT teaching_classes_pkey PRIMARY KEY (class_id);


--
-- Name: idx_classes_course; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_classes_course ON public.teaching_classes USING btree (course_id);


--
-- Name: idx_classes_semester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_classes_semester ON public.teaching_classes USING btree (semester);


--
-- Name: idx_classes_teacher; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_classes_teacher ON public.teaching_classes USING btree (teacher_id);


--
-- Name: idx_courses_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_department ON public.courses USING btree (department_id);


--
-- Name: idx_enrollments_class; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_enrollments_class ON public.enrollments USING btree (class_id);


--
-- Name: idx_students_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_department ON public.students USING btree (department_id);


--
-- Name: idx_teachers_department; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_teachers_department ON public.teachers USING btree (department_id);


--
-- Name: enrollments trg_enrollment_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enrollment_count BEFORE INSERT OR DELETE OR UPDATE ON public.enrollments FOR EACH ROW EXECUTE FUNCTION public.maintain_enrollment_count();


--
-- Name: teaching_classes trg_verify_enrollment_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER trg_verify_enrollment_count AFTER INSERT OR UPDATE ON public.teaching_classes DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.verify_enrollment_count();


--
-- Name: courses courses_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE RESTRICT;


--
-- Name: enrollments enrollments_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.teaching_classes(class_id) ON DELETE RESTRICT;


--
-- Name: enrollments enrollments_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enrollments
    ADD CONSTRAINT enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(student_id) ON DELETE RESTRICT;


--
-- Name: students students_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE RESTRICT;


--
-- Name: teachers teachers_department_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teachers
    ADD CONSTRAINT teachers_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.departments(department_id) ON DELETE RESTRICT;


--
-- Name: teaching_classes teaching_classes_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_classes
    ADD CONSTRAINT teaching_classes_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(course_id) ON DELETE RESTRICT;


--
-- Name: teaching_classes teaching_classes_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teaching_classes
    ADD CONSTRAINT teaching_classes_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teachers(teacher_id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

