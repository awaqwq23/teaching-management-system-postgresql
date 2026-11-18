package cn.edu.coursework;

import org.junit.jupiter.api.Test;

import java.sql.DriverManager;
import java.sql.SQLException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class DatabaseTest {
    private java.sql.Connection connect() throws SQLException {
        return DriverManager.getConnection(
                System.getenv("DB_URL"), System.getenv("DB_USER"), System.getenv("DB_PASSWORD"));
    }

    @Test
    void everyCoreTableHasAtLeastTenRows() throws Exception {
        try (var connection = connect(); var statement = connection.createStatement()) {
            for (String table : new String[]{"departments", "students", "teachers",
                    "courses", "teaching_classes", "enrollments"}) {
                try (var rows = statement.executeQuery("SELECT count(*) FROM " + table)) {
                    assertTrue(rows.next());
                    assertTrue(rows.getInt(1) >= 10, table);
                }
            }
        }
    }

    @Test
    void invalidGradeIsRejected() throws Exception {
        try (var connection = connect()) {
            connection.setAutoCommit(false);
            try (var statement = connection.createStatement()) {
                var error = assertThrows(SQLException.class,
                        () -> statement.executeUpdate("UPDATE enrollments SET grade = 101"));
                assertEquals("23514", error.getSQLState());
            } finally {
                connection.rollback();
            }
        }
    }
}
