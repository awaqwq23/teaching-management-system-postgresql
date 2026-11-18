package cn.edu.coursework.dao;

import cn.edu.coursework.util.DBUtil;

import java.math.BigDecimal;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public final class ReportDAO {
    public record Transcript(String studentNo, String studentName, String classCode,
                             String courseName, String teacherName, BigDecimal grade) {
    }

    public record ClassStatistics(String classCode, String courseName, String teacherName,
                                  int capacity, int enrolledCount, BigDecimal averageGrade) {
    }

    public List<Transcript> transcript(String studentNo) throws SQLException {
        String sql = """
                SELECT s.student_no, s.student_name, tc.class_code, c.course_name, t.teacher_name, e.grade
                FROM enrollments e JOIN students s USING (student_id)
                JOIN teaching_classes tc USING (class_id) JOIN courses c USING (course_id)
                JOIN teachers t USING (teacher_id)
                WHERE s.student_no=? ORDER BY tc.class_code
                """;
        var result = new ArrayList<Transcript>();
        try (var connection = DBUtil.connect(); var statement = connection.prepareStatement(sql)) {
            statement.setString(1, studentNo);
            try (var rows = statement.executeQuery()) {
                while (rows.next()) {
                    result.add(new Transcript(rows.getString(1), rows.getString(2), rows.getString(3),
                            rows.getString(4), rows.getString(5), rows.getBigDecimal(6)));
                }
            }
        }
        return result;
    }

    public List<ClassStatistics> classStatistics() throws SQLException {
        String sql = """
                SELECT tc.class_code, c.course_name, t.teacher_name, tc.capacity, tc.enrolled_count,
                       round(avg(e.grade), 2)
                FROM teaching_classes tc JOIN courses c USING (course_id)
                JOIN teachers t USING (teacher_id) LEFT JOIN enrollments e USING (class_id)
                GROUP BY tc.class_id, c.course_name, t.teacher_name ORDER BY tc.class_code
                """;
        var result = new ArrayList<ClassStatistics>();
        try (var connection = DBUtil.connect(); var statement = connection.prepareStatement(sql);
             var rows = statement.executeQuery()) {
            while (rows.next()) {
                result.add(new ClassStatistics(rows.getString(1), rows.getString(2), rows.getString(3),
                        rows.getInt(4), rows.getInt(5), rows.getBigDecimal(6)));
            }
        }
        return result;
    }
}
