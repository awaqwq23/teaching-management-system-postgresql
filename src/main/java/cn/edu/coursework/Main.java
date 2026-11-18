package cn.edu.coursework;

import cn.edu.coursework.dao.ReportDAO;
import cn.edu.coursework.dao.StudentDAO;
import cn.edu.coursework.service.EnrollmentService;
import cn.edu.coursework.util.DBUtil;

import java.io.PrintStream;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.Scanner;

public final class Main {
    private Main() {
    }

    public static void main(String[] args) {
        System.setOut(new PrintStream(System.out, true, StandardCharsets.UTF_8));
        var students = new StudentDAO();
        var reports = new ReportDAO();
        var enrollments = new EnrollmentService();
        try (var input = new Scanner(System.in, StandardCharsets.UTF_8)) {
            while (true) {
                System.out.println("""
                        高校教学管理系统 / PostgreSQL
                        1 添加学生  2 查询学生  3 修改学生  4 删除学生
                        5 学生成绩单  6 教学班统计  7 选课  8 退课  9 录入成绩  0 退出
                        """);
                String operation = read(input, "选择");
                if (operation == null || operation.equals("0")) {
                    return;
                }
                try {
                    switch (operation) {
                        case "1" -> {
                            String number = required(input, "学号");
                            String name = required(input, "姓名");
                            long departmentId = Long.parseLong(required(input, "院系ID（1-10）"));
                            String email = required(input, "邮箱（留空表示未填写）");
                            int year = Integer.parseInt(required(input, "入学年份"));
                            System.out.println("添加成功，学生ID=" + students.add(number, name, departmentId,
                                    email.isBlank() ? null : email, year));
                        }
                        case "2" -> {
                            var student = students.find(required(input, "学号"));
                            System.out.println(student.map(Object::toString).orElse("未找到学生"));
                        }
                        case "3" -> {
                            long studentId = Long.parseLong(required(input, "学生ID"));
                            String name = required(input, "新姓名");
                            String email = required(input, "新邮箱（留空表示清除）");
                            System.out.println(students.update(studentId, name, email.isBlank() ? null : email)
                                    ? "修改成功" : "未找到学生");
                        }
                        case "4" -> System.out.println(students.delete(Long.parseLong(required(input, "学生ID")))
                                ? "删除成功" : "未找到学生");
                        case "5" -> {
                            var rows = reports.transcript(required(input, "学号"));
                            System.out.println("成绩单记录数=" + rows.size());
                            rows.forEach(System.out::println);
                        }
                        case "6" -> reports.classStatistics().forEach(System.out::println);
                        case "7" -> {
                            long studentId = Long.parseLong(required(input, "学生ID"));
                            long[] classIds = Arrays.stream(required(input, "教学班ID（多个用英文逗号分隔）").split(","))
                                    .map(String::trim).mapToLong(Long::parseLong).toArray();
                            enrollments.enroll(studentId, classIds);
                            System.out.println("选课成功，事务已提交");
                        }
                        case "8" -> System.out.println(enrollments.withdraw(
                                Long.parseLong(required(input, "学生ID")),
                                Long.parseLong(required(input, "教学班ID"))) ? "退课成功" : "未找到选课记录");
                        case "9" -> {
                            long studentId = Long.parseLong(required(input, "学生ID"));
                            long classId = Long.parseLong(required(input, "教学班ID"));
                            BigDecimal grade = new BigDecimal(required(input, "成绩（0-100）"));
                            System.out.println(enrollments.recordGrade(studentId, classId, grade)
                                    ? "成绩保存成功" : "未找到选课记录");
                        }
                        default -> System.out.println("请选择0到9");
                    }
                } catch (SQLException error) {
                    System.out.println(DBUtil.explain(error));
                } catch (IllegalArgumentException error) {
                    System.out.println("输入格式不正确：" + error.getMessage());
                } catch (IllegalStateException endOfInput) {
                    System.out.println("输入结束，程序退出");
                    return;
                }
            }
        }
    }

    private static String read(Scanner input, String prompt) {
        System.out.print(prompt + "> ");
        return input.hasNextLine() ? input.nextLine().trim() : null;
    }

    private static String required(Scanner input, String prompt) {
        String value = read(input, prompt);
        if (value == null) {
            throw new IllegalStateException("输入结束");
        }
        return value;
    }
}
