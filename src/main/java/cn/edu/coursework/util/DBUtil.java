package cn.edu.coursework.util;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public final class DBUtil {
    private DBUtil() {
    }

    public static Connection connect() throws SQLException {
        String url = System.getenv().getOrDefault("DB_URL", "jdbc:postgresql://127.0.0.1:5432/course_management");
        String user = System.getenv().getOrDefault("DB_USER", "postgres");
        String password = System.getenv("DB_PASSWORD");
        if (password == null || password.isBlank()) {
            throw new SQLException("请设置环境变量 DB_PASSWORD", "08001");
        }
        return DriverManager.getConnection(url, user, password);
    }

    public static String explain(SQLException error) {
        String state = error.getSQLState() == null ? "" : error.getSQLState();
        return switch (state) {
            case "23505" -> "编号或选课记录重复";
            case "23503" -> "关联记录不存在，或该记录仍被其他数据引用";
            case "23514" -> "数据不符合业务规则，请检查成绩、名额、学期及必填内容";
            case "23502" -> "必填数据不能为空";
            case "22001" -> "输入内容超过字段长度";
            case "40001", "40P01" -> "发生并发冲突，事务已回滚，请重试";
            default -> state.startsWith("08") || state.equals("28P01")
                    ? "数据库连接失败，请检查服务和环境变量"
                    : "数据库操作失败，SQLState=" + state;
        };
    }
}
