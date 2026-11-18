package cn.edu.coursework;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

class CliTest {
    @Test
    void redirectedConsoleOutputUsesUtf8() throws Exception {
        var process = new ProcessBuilder(
                Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-cp", Path.of("target/classes").toString(),
                "cn.edu.coursework.Main").redirectErrorStream(true).start();
        try (var input = process.getOutputStream()) {
            input.write("0\n".getBytes(StandardCharsets.UTF_8));
        }
        assertTrue(process.waitFor(10, TimeUnit.SECONDS));
        String output = new String(process.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        assertEquals(0, process.exitValue());
        assertTrue(output.contains("高校教学管理系统"), output);
        assertTrue(output.contains("添加学生"), output);
    }

    @Test
    void endOfInputExitsWithoutLooping() throws Exception {
        var process = new ProcessBuilder(
                Path.of(System.getProperty("java.home"), "bin", "java").toString(),
                "-cp", Path.of("target/classes").toString(),
                "cn.edu.coursework.Main").redirectErrorStream(true).start();
        process.getOutputStream().close();
        assertTrue(process.waitFor(10, TimeUnit.SECONDS));
        assertEquals(0, process.exitValue());
    }
}
