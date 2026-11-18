package cn.edu.coursework;

import cn.edu.coursework.dao.ReportDAO;
import cn.edu.coursework.dao.StudentDAO;
import cn.edu.coursework.service.EnrollmentService;
import cn.edu.coursework.util.DBUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

class ApplicationTest {
    private final StudentDAO students = new StudentDAO();
    private final EnrollmentService enrollment = new EnrollmentService();

    @BeforeEach
    void resetTestDatabase() throws Exception {
        assertTrue(System.getenv("DB_URL").endsWith("/course_management_test"),
                "Tests only run against the dedicated course_management_test database");
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            statement.execute("TRUNCATE enrollments, teaching_classes, courses, teachers, students, departments RESTART IDENTITY");
            statement.execute(Files.readString(Path.of("sql/insert_data.sql")));
        }
    }

    private long scalar(String sql) throws SQLException {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement();
             var rows = statement.executeQuery(sql)) {
            assertTrue(rows.next());
            return rows.getLong(1);
        }
    }

    @Test
    void studentCrudRoundTrip() throws Exception {
        long studentId = students.add("T001", "测试学生", 1, "test001@example.invalid", 2026);
        assertEquals("测试学生", students.find("T001").orElseThrow().studentName());
        assertTrue(students.update(studentId, "修改姓名", "changed@example.invalid"));
        assertEquals("修改姓名", students.find("T001").orElseThrow().studentName());
        assertTrue(students.delete(studentId));
        assertTrue(students.find("T001").isEmpty());
    }

    @Test
    void duplicateStudentNumberIsRejected() throws Exception {
        var error = assertThrows(SQLException.class,
                () -> students.add("S2026001", "重复学号", 1, null, 2026));
        assertEquals("23505", error.getSQLState());
    }

    @Test
    void missingStudentReturnsEmpty() throws Exception {
        assertTrue(students.find("UNKNOWN").isEmpty());
        assertFalse(students.update(999999, "不存在", null));
        assertFalse(students.delete(999999));
    }

    @Test
    void referencedStudentCannotBeDeleted() {
        var error = assertThrows(SQLException.class, () -> students.delete(1));
        assertEquals("23503", error.getSQLState());
    }

    @Test
    void unknownDepartmentIsRejected() {
        var error = assertThrows(SQLException.class,
                () -> students.add("T002", "未知院系", 999999, null, 2026));
        assertEquals("23503", error.getSQLState());
    }

    @Test
    void blankStudentNameIsRejected() {
        var error = assertThrows(SQLException.class,
                () -> students.add("T003", "  ", 1, null, 2026));
        assertEquals("23514", error.getSQLState());
    }

    @Test
    void sqlInjectionInputIsTreatedAsData() throws Exception {
        assertTrue(students.find("' OR 1=1 --").isEmpty());
        assertEquals(20, scalar("SELECT count(*) FROM students"));
    }

    @Test
    void successfulEnrollmentUpdatesRecordAndCounter() throws Exception {
        enrollment.enroll(20, 1);
        assertEquals(1, scalar("SELECT count(*) FROM enrollments WHERE student_id=20 AND class_id=1"));
        assertEquals(3, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
    }

    @Test
    void duplicateEnrollmentDoesNotLeakCapacity() throws Exception {
        var error = assertThrows(SQLException.class, () -> enrollment.enroll(1, 1));
        assertEquals("23505", error.getSQLState());
        assertEquals(2, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
    }

    @Test
    void fullClassRejectsEnrollment() throws Exception {
        var error = assertThrows(SQLException.class, () -> enrollment.enroll(20, 12));
        assertEquals("23514", error.getSQLState());
        assertEquals(2, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=12"));
        assertEquals(0, scalar("SELECT count(*) FROM enrollments WHERE student_id=20 AND class_id=12"));
    }

    @Test
    void batchFailureRollsBackEarlierEnrollmentAndCounter() throws Exception {
        assertThrows(SQLException.class, () -> enrollment.enroll(20, 1, 12));
        assertEquals(0, scalar("SELECT count(*) FROM enrollments WHERE student_id=20 AND class_id=1"));
        assertEquals(2, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
    }

    @Test
    void missingClassRollsBackWholeBatch() throws Exception {
        var error = assertThrows(SQLException.class, () -> enrollment.enroll(20, 1, 999999));
        assertEquals("23503", error.getSQLState());
        assertEquals(2, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
    }

    @Test
    void withdrawalReleasesCapacity() throws Exception {
        assertTrue(enrollment.withdraw(1, 1));
        assertEquals(1, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
        assertFalse(enrollment.withdraw(1, 1));
    }

    @Test
    void gradeAcceptsBothBoundaries() throws Exception {
        assertTrue(enrollment.recordGrade(1, 1, BigDecimal.ZERO));
        assertEquals(0, scalar("SELECT grade FROM enrollments WHERE student_id=1 AND class_id=1"));
        assertTrue(enrollment.recordGrade(1, 1, new BigDecimal("100")));
        assertEquals(100, scalar("SELECT grade FROM enrollments WHERE student_id=1 AND class_id=1"));
    }

    @Test
    void invalidGradeRollsBack() throws Exception {
        var error = assertThrows(SQLException.class,
                () -> enrollment.recordGrade(1, 1, new BigDecimal("100.01")));
        assertEquals("23514", error.getSQLState());
        assertEquals(71, scalar("SELECT grade FROM enrollments WHERE student_id=1 AND class_id=1"));
    }

    @Test
    void reportsJoinRealBusinessData() throws Exception {
        var reports = new ReportDAO();
        var transcript = reports.transcript("S2026001");
        assertEquals(2, transcript.size());
        assertEquals("数据库系统", transcript.get(0).courseName());
        assertEquals("教师01", transcript.get(0).teacherName());
        var classes = reports.classStatistics();
        assertEquals(12, classes.size());
        assertEquals(2, classes.get(0).enrolledCount());
        assertTrue(reports.transcript("UNKNOWN").isEmpty());
    }

    @Test
    void concurrentEnrollmentCannotOversellLastSeat() throws Exception {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            statement.executeUpdate("UPDATE teaching_classes SET capacity=3 WHERE class_id=1");
        }
        var start = new CountDownLatch(1);
        var pool = Executors.newFixedThreadPool(2);
        try {
            var first = pool.submit(() -> compete(start, 19));
            var second = pool.submit(() -> compete(start, 20));
            start.countDown();
            assertEquals(1, first.get(15, TimeUnit.SECONDS) + second.get(15, TimeUnit.SECONDS));
            assertEquals(3, scalar("SELECT enrolled_count FROM teaching_classes WHERE class_id=1"));
            assertEquals(3, scalar("SELECT count(*) FROM enrollments WHERE class_id=1"));
        } finally {
            pool.shutdownNow();
        }
    }

    private int compete(CountDownLatch start, long studentId) throws Exception {
        start.await();
        try {
            enrollment.enroll(studentId, 1);
            return 1;
        } catch (SQLException error) {
            assertEquals("23514", error.getSQLState());
            return 0;
        }
    }

    @Test
    void directCounterTamperingCannotCommit() throws Exception {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            connection.setAutoCommit(false);
            try {
                statement.executeUpdate("UPDATE teaching_classes SET enrolled_count=0 WHERE class_id=1");
                var error = assertThrows(SQLException.class, connection::commit);
                assertEquals("23514", error.getSQLState());
            } finally {
                connection.rollback();
            }
        }
    }

    @Test
    void capacityCannotBeLoweredBelowEnrollmentCount() throws Exception {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            var error = assertThrows(SQLException.class,
                    () -> statement.executeUpdate("UPDATE teaching_classes SET capacity=1 WHERE class_id=1"));
            assertEquals("23514", error.getSQLState());
        }
    }

    @Test
    void enrollmentIdentityCannotBeChangedInPlace() throws Exception {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            var error = assertThrows(SQLException.class, () -> statement.executeUpdate(
                    "UPDATE enrollments SET class_id=2 WHERE student_id=1 AND class_id=1"));
            assertEquals("23514", error.getSQLState());
        }
    }

    @Test
    void semesterYearsMustBeConsecutive() throws Exception {
        try (var connection = DBUtil.connect(); var statement = connection.createStatement()) {
            var error = assertThrows(SQLException.class,
                    () -> statement.executeUpdate("UPDATE teaching_classes SET semester='2026-2028-1' WHERE class_id=1"));
            assertEquals("23514", error.getSQLState());
        }
    }

    @Test
    void admissionYearBoundariesAreEnforced() throws Exception {
        students.add("T2000", "边界学生甲", 1, null, 2000);
        students.add("T2100", "边界学生乙", 1, null, 2100);
        var error = assertThrows(SQLException.class,
                () -> students.add("T1999", "越界学生", 1, null, 1999));
        assertEquals("23514", error.getSQLState());
    }

    @Test
    void multipleMissingEmailsAreAllowed() throws Exception {
        students.add("TNULL1", "无邮箱学生甲", 1, null, 2026);
        students.add("TNULL2", "无邮箱学生乙", 1, null, 2026);
        assertEquals(2, scalar("SELECT count(*) FROM students WHERE email IS NULL AND student_no LIKE 'TNULL%'"));
    }

    @Test
    void creditBoundaryIsEnforced() throws Exception {
        try (var connection = DBUtil.connect()) {
            connection.setAutoCommit(false);
            try (var statement = connection.createStatement()) {
                statement.executeUpdate("UPDATE courses SET credits=10.0 WHERE course_id=1");
            } finally {
                connection.rollback();
            }
        }
        for (String invalid : new String[]{"10.1", "0"}) {
            try (var connection = DBUtil.connect()) {
                connection.setAutoCommit(false);
                try (var statement = connection.createStatement()) {
                    assertEquals("23514", assertThrows(SQLException.class,
                            () -> statement.executeUpdate("UPDATE courses SET credits=" + invalid + " WHERE course_id=1"))
                            .getSQLState());
                } finally {
                    connection.rollback();
                }
            }
        }
    }

    @Test
    void sameCourseCanBeRetakenInAnotherClass() throws Exception {
        enrollment.enroll(1, 11);
        assertEquals(2, scalar("SELECT count(*) FROM enrollments e JOIN teaching_classes tc USING (class_id) " +
                "WHERE e.student_id=1 AND tc.course_id=1"));
        assertTrue(enrollment.withdraw(1, 11));
    }
}
