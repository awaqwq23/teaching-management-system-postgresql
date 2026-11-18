package cn.edu.coursework.service;

import cn.edu.coursework.util.DBUtil;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.Arrays;

public final class EnrollmentService {
    public void enroll(long studentId, long... classIds) throws SQLException {
        if (classIds.length == 0) {
            throw new IllegalArgumentException("至少指定一个教学班");
        }
        long[] orderedClassIds = classIds.clone();
        Arrays.sort(orderedClassIds);
        try (var connection = DBUtil.connect()) {
            connection.setAutoCommit(false);
            try (var statement = connection.prepareStatement(
                    "INSERT INTO enrollments(student_id, class_id) VALUES (?, ?)")) {
                for (long classId : orderedClassIds) {
                    statement.setLong(1, studentId);
                    statement.setLong(2, classId);
                    statement.executeUpdate();
                }
                connection.commit();
            } catch (SQLException error) {
                try {
                    connection.rollback();
                } catch (SQLException rollbackError) {
                    error.addSuppressed(rollbackError);
                }
                throw error;
            }
        }
    }

    public boolean withdraw(long studentId, long classId) throws SQLException {
        try (var connection = DBUtil.connect();
             var statement = connection.prepareStatement("DELETE FROM enrollments WHERE student_id=? AND class_id=?")) {
            statement.setLong(1, studentId);
            statement.setLong(2, classId);
            return statement.executeUpdate() == 1;
        }
    }

    public boolean recordGrade(long studentId, long classId, BigDecimal grade) throws SQLException {
        try (var connection = DBUtil.connect();
             var statement = connection.prepareStatement("UPDATE enrollments SET grade=? WHERE student_id=? AND class_id=?")) {
            statement.setBigDecimal(1, grade);
            statement.setLong(2, studentId);
            statement.setLong(3, classId);
            return statement.executeUpdate() == 1;
        }
    }
}
