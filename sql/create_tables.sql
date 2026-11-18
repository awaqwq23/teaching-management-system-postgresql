BEGIN;

CREATE TABLE departments (
    department_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_code varchar(12) NOT NULL UNIQUE CHECK (btrim(department_code) <> ''),
    department_name varchar(80) NOT NULL UNIQUE CHECK (btrim(department_name) <> '')
);

CREATE TABLE students (
    student_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_no varchar(20) NOT NULL UNIQUE CHECK (btrim(student_no) <> ''),
    student_name varchar(60) NOT NULL CHECK (btrim(student_name) <> ''),
    department_id bigint NOT NULL REFERENCES departments ON DELETE RESTRICT,
    email varchar(120) UNIQUE CHECK (email IS NULL OR btrim(email) <> ''),
    admission_year smallint NOT NULL CHECK (admission_year BETWEEN 2000 AND 2100)
);

CREATE TABLE teachers (
    teacher_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    teacher_no varchar(20) NOT NULL UNIQUE CHECK (btrim(teacher_no) <> ''),
    teacher_name varchar(60) NOT NULL CHECK (btrim(teacher_name) <> ''),
    department_id bigint NOT NULL REFERENCES departments ON DELETE RESTRICT
);

CREATE TABLE courses (
    course_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_code varchar(20) NOT NULL UNIQUE CHECK (btrim(course_code) <> ''),
    course_name varchar(100) NOT NULL CHECK (btrim(course_name) <> ''),
    credits numeric(3,1) NOT NULL CHECK (credits > 0 AND credits <= 10),
    department_id bigint NOT NULL REFERENCES departments ON DELETE RESTRICT
);

CREATE TABLE teaching_classes (
    class_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    class_code varchar(24) NOT NULL UNIQUE CHECK (btrim(class_code) <> ''),
    course_id bigint NOT NULL REFERENCES courses ON DELETE RESTRICT,
    teacher_id bigint NOT NULL REFERENCES teachers ON DELETE RESTRICT,
    semester varchar(11) NOT NULL CHECK (
        CASE WHEN semester ~ '^[0-9]{4}-[0-9]{4}-[12]$'
        THEN substring(semester, 6, 4)::integer = substring(semester, 1, 4)::integer + 1
        ELSE false END
    ),
    capacity integer NOT NULL CHECK (capacity BETWEEN 1 AND 500),
    enrolled_count integer NOT NULL DEFAULT 0 CHECK (enrolled_count BETWEEN 0 AND capacity)
);

CREATE TABLE enrollments (
    student_id bigint NOT NULL REFERENCES students ON DELETE RESTRICT,
    class_id bigint NOT NULL REFERENCES teaching_classes ON DELETE RESTRICT,
    enrolled_at timestamptz NOT NULL DEFAULT current_timestamp,
    grade numeric(5,2) CHECK (grade BETWEEN 0 AND 100),
    PRIMARY KEY (student_id, class_id)
);

CREATE INDEX idx_students_department ON students(department_id);
CREATE INDEX idx_teachers_department ON teachers(department_id);
CREATE INDEX idx_courses_department ON courses(department_id);
CREATE INDEX idx_classes_course ON teaching_classes(course_id);
CREATE INDEX idx_classes_teacher ON teaching_classes(teacher_id);
CREATE INDEX idx_classes_semester ON teaching_classes(semester);
CREATE INDEX idx_enrollments_class ON enrollments(class_id);

CREATE FUNCTION maintain_enrollment_count() RETURNS trigger LANGUAGE plpgsql AS $$
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

CREATE TRIGGER trg_enrollment_count
BEFORE INSERT OR DELETE OR UPDATE ON enrollments
FOR EACH ROW EXECUTE FUNCTION maintain_enrollment_count();

CREATE FUNCTION verify_enrollment_count() RETURNS trigger LANGUAGE plpgsql AS $$
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

CREATE CONSTRAINT TRIGGER trg_verify_enrollment_count
AFTER INSERT OR UPDATE ON teaching_classes
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION verify_enrollment_count();

COMMIT;
