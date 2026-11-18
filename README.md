# 高校教学管理系统

数据库系统课程大作业。使用 PostgreSQL 16 和 Java JDBC 实现院系、学生、教师、课程、教学班及选课成绩管理，提供命令行演示程序。数据均为虚构测试数据。

## 环境

| 组件 | 版本 |
| --- | --- |
| 数据库 | PostgreSQL 16 |
| Java | JDK 17 或以上，编译目标 17 |
| 驱动 | org.postgresql:postgresql:42.7.11 |
| 构建工具 | Maven 3.9 或以上 |
| 测试 | JUnit Jupiter 5.11.4，连接真实 PostgreSQL |

本地验证使用 PostgreSQL 16.16、Java 27（`--release 17`）与 Maven 3.9.9；GitHub Actions 使用 Java 17 和 PostgreSQL 16。2026-11-18 首次推送的 CI 已通过（提交 `f217b82`），后续提交状态以仓库页面为准。

## 创建数据库

先安装 PostgreSQL 16 并启动服务，将 `psql` 加入 PATH。以下为 PowerShell 操作，密码在本机安全输入，不写入源码。默认端口 5432；若使用本次创建的独立本地实例，则使用 55432。

```powershell
$env:PGHOST = '127.0.0.1'
$env:PGPORT = '5432'
$env:PGUSER = 'postgres'
$securePassword = Read-Host '数据库密码' -AsSecureString
$env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $securePassword).Password
psql -X -v ON_ERROR_STOP=1 -d postgres -f sql/create_database.sql
psql -X -v ON_ERROR_STOP=1 -d course_management -f sql/create_tables.sql
psql -X -v ON_ERROR_STOP=1 -d course_management -f sql/insert_data.sql
psql -X -v ON_ERROR_STOP=1 -d course_management -f sql/verify.sql
psql -X -v ON_ERROR_STOP=1 -d course_management -f sql/query.sql
```

`create_database.sql` 只在数据库不存在时创建。建表和初始化脚本仅对空数据库运行一次；重复运行会明确失败，不删除原有数据。不要对已有业务数据库执行测试重置语句。

也可将 `database/course_management.sql` 恢复到一个新建空数据库：

```powershell
psql -X -v ON_ERROR_STOP=1 -d course_management -f database/course_management.sql
```

备份和分离的建表、初始化脚本二选一。备份来自实际本地数据库，已排除所有者及权限设置。

## 运行命令行程序

```powershell
$env:DB_URL = "jdbc:postgresql://$($env:PGHOST):$($env:PGPORT)/course_management"
$env:DB_USER = $env:PGUSER
$env:DB_PASSWORD = $env:PGPASSWORD
mvn -B -ntp -DskipTests package
mvn -q exec:java
```

也可执行 `scripts/run.ps1`，或在 IntelliJ IDEA/Eclipse 导入 `pom.xml`，设置上述三个环境变量，运行 `cn.edu.coursework.Main`。

菜单支持学生添加、按学号查询、姓名邮箱修改、删除，学生成绩单、教学班统计，以及选课、退课、成绩录入。初始学生学号为 `S2026001` 至 `S2026020`；学生 ID 为 1 至 20，院系 ID 为 1 至 10，教学班 ID 为 1 至 12。

演示建议：菜单 5 查询 `S2026001`，得到数据库系统 71 分、大学语文 91 分；菜单 7 让学生 20 选择教学班 1，可成功；教学班 12 初始已满，选择 `1,12` 可以观察整体回滚。操作前后用菜单 6 核对人数。

学生、教师、教务员为需求中的业务角色。本程序由可信操作员统一演示，未实现账号登录与按角色授权；请勿用于多用户生产部署。

## 运行测试

测试只接受名为 `course_management_test` 的独立数据库。测试会清空该测试库中的六张表并重建测试数据，不接触演示库。

```powershell
psql -X -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE course_management_test ENCODING 'UTF8' TEMPLATE template0"
psql -X -v ON_ERROR_STOP=1 -d course_management_test -f sql/create_tables.sql -f sql/insert_data.sql
$env:DB_URL = "jdbc:postgresql://$($env:PGHOST):$($env:PGPORT)/course_management_test"
mvn -B -ntp verify
```

如果测试库已经存在，跳过创建数据库；如果表已经存在，也跳过建表与初始化。测试报告位于 `target/surefire-reports/`。测试包括学生 CRUD、唯一性、外键、非法成绩、SQL 注入输入、选课退课、批量回滚、并发争抢最后名额、计数篡改与学期规则。

## 设计与提交材料

| 目录 | 内容 |
| --- | --- |
| `docs/` | 需求、概念设计、规范化、物理设计、测试报告、AI使用与总结 |
| `submission/` | 按任务书整理的完整 PDF 与 ER 图 |
| `sql/` | 数据库创建、六表建模、初始化、8 条分类查询和一致性检查 |
| `src/main/java/` | DBUtil、DAO、Service 与 Main |
| `src/test/java/` | 真实数据库集成测试 |
| `evidence/` | 实际 SQL、CLI 和测试输出及截图 |
| `database/` | 实际数据库的可恢复 SQL 备份 |
| `.github/workflows/` | PostgreSQL 16 与 Java 17 持续集成 |

学生与教学班通过选课表实现多对多，成绩属于选课联系。数据库以原子更新维护已选人数，并在事务提交时核对真实选课数，避免超选及直接篡改计数。批量选课按教学班 ID 排序；任何一步失败均回滚。发生序列化失败或死锁时提示重试，不自动悄悄重复提交。

本地运行凭据、数据库文件、下载的运行环境、Maven 构建目录均不上传。课程原始课件也不上传。正式提交前，实际小组需补充真实成员分工，亲自审核、理解设计与操作结果；当前记录不冒充学生人工复核。
