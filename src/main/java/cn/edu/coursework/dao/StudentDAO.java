package cn.edu.coursework.dao;

import cn.edu.coursework.util.DBUtil;

import java.sql.SQLException;
import java.sql.Types;
import java.util.Optional;

public final class StudentDAO {
    public record Student(long studentId, String studentNo, String studentName,
                          long departmentId, String email, int admissionYear) {
    }

    public long add(String studentNo, String studentName, long departmentId,
                    String email, int admissionYear) throws SQLException {
        String sql = """
                INSERT INTO students(student_no, student_name, department_id, email, admission_year)
                VALUES (?, ?, ?, ?, ?) RETURNING student_id
                """;
        try (var connection = DBUtil.connect(); var statement = connection.prepareStatement(sql)) {
            statement.setString(1, studentNo);
            statement.setString(2, studentName);
            statement.setLong(3, departmentId);
            statement.setObject(4, email, Types.VARCHAR);
            statement.setInt(5, admissionYear);
            try (var rows = statement.executeQuery()) {
                rows.next();
                return rows.getLong(1);
            }
        }
    }

    public Optional<Student> find(String studentNo) throws SQLException {
        try (var connection = DBUtil.connect();
             var statement = connection.prepareStatement("SELECT * FROM students WHERE student_no=?")) {
            statement.setString(1, studentNo);
            try (var rows = statement.executeQuery()) {
                if (!rows.next()) {
                    return Optional.empty();
                }
                return Optional.of(new Student(rows.getLong("student_id"), rows.getString("student_no"),
                        rows.getString("student_name"), rows.getLong("department_id"),
                        rows.getString("email"), rows.getInt("admission_year")));
            }
        }
    }

    public boolean update(long studentId, String studentName, String email) throws SQLException {
        try (var connection = DBUtil.connect();
             var statement = connection.prepareStatement("UPDATE students SET student_name=?, email=? WHERE student_id=?")) {
            statement.setString(1, studentName);
            statement.setObject(2, email, Types.VARCHAR);
            statement.setLong(3, studentId);
            return statement.executeUpdate() == 1;
        }
    }

    public boolean delete(long studentId) throws SQLException {
        try (var connection = DBUtil.connect();
             var statement = connection.prepareStatement("DELETE FROM students WHERE student_id=?")) {
            statement.setLong(1, studentId);
            return statement.executeUpdate() == 1;
        }
    }
}
