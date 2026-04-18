-- ═══════════════════════════════════════
-- Database 1: minicloud (yêu cầu cơ bản)
-- ═══════════════════════════════════════
CREATE DATABASE IF NOT EXISTS minicloud CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE minicloud;

CREATE TABLE IF NOT EXISTS notes (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  title      VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO notes (title) VALUES
  ('Hello from MariaDB!'),
  ('MyMiniCloud is running'),
  ('Docker Compose rocks!');

-- ═══════════════════════════════════════════════════════
-- Database 2: studentdb (yêu cầu mở rộng 3 - CRUD SV)
-- ═══════════════════════════════════════════════════════
CREATE DATABASE IF NOT EXISTS studentdb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE studentdb;

CREATE TABLE IF NOT EXISTS students (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(10)  NOT NULL UNIQUE,
  fullname   VARCHAR(100) NOT NULL,
  dob        DATE,
  major      VARCHAR(50)
);

INSERT INTO students (student_id, fullname, dob, major) VALUES
  ('SV001', 'Nguyen Van An',   '2002-05-15', 'Cong Nghe Thong Tin'),
  ('SV002', 'Tran Thi Binh',  '2002-08-20', 'Ky Thuat Phan Mem'),
  ('SV003', 'Le Van Cuong',   '2001-12-01', 'Khoa Hoc May Tinh'),
  ('SV004', 'Pham Thi Dung',  '2002-03-18', 'An Toan Thong Tin'),
  ('SV005', 'Hoang Van Em',   '2001-09-30', 'Cong Nghe Thong Tin');

-- ═══════════════════════════════════
-- Ví dụ CRUD (comment, dùng để demo)
-- ═══════════════════════════════════
-- SELECT * FROM students;
-- UPDATE students SET gpa=3.9 WHERE student_id='SV001';
-- DELETE FROM students WHERE student_id='SV005';
