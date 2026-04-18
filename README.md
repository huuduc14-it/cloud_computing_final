# ☁️ TranVanHuy_HoHuuDuc_miniclouddemo

Hệ thống **MyMiniCloud** – 9 server mô phỏng Cloud Platform, chạy bằng Docker Compose trên Windows.

---

## 📁 Cấu trúc thư mục

```
TranVanHuy_HoHuuDuc_miniclouddemo/
├── docker-compose.yml
├── setup.ps1                          ← Chạy 1 lần là xong
├── test-commands.ps1                  ← Lệnh kiểm thử từng phần
│
├── api-gateway-proxy-server/
│   └── nginx.conf                     ← Round Robin 2 web server
│
├── application-backend-server/
│   ├── Dockerfile
│   ├── app.py                         ← Flask API
│   ├── students.json                  ← Dữ liệu 5 sinh viên
│   ├── templates/
│   │   ├── student.html               ← UI hiển thị sinh viên đơn
│   │   └── students_db.html           ← UI hiển thị danh sách DB
│   └── static/
│       ├── css/app-ui.css
│       └── js/student.js, students-db.js
│
├── relational-database-server/
│   └── init/001_init.sql              ← Auto-seed minicloud + studentdb
│
├── authentication-identity-server/    ← Keycloak (config via env)
│
├── object-storage-server/
│   └── data/                          ← Volume MinIO
│
├── internal-dns-server/
│   ├── named.conf
│   ├── named.conf.options
│   ├── named.conf.local
│   └── db.cloud.local                 ← Zone file cloud.local
│
├── web-frontend-server/               ← Nginx Server 1 (xanh dương)
│   ├── Dockerfile
│   ├── conf.default
│   └── html/
│       ├── index.html
│       ├── assets/ (css/, js/, images/)
│       └── blog/ (blog1.html, blog2.html, blog3.html)
│
├── web-frontend-server2/              ← Nginx Server 2 (đỏ – Round Robin)
│   └── (tương tự web-frontend-server)
│
├── monitoring-prometheus-server/
│   └── prometheus.yml
│
└── monitoring-grafana-dashboard-server/  ← Grafana (auto-managed)
```

---

## ⚡ Khởi động (Windows PowerShell)

```powershell
# Mở PowerShell, vào thư mục dự án:
cd TranVanHuy_HoHuuDuc_miniclouddemo

# Chạy script tự động (build + start + test toàn bộ):
.\setup.ps1

# Hoặc thủ công:
docker compose build --no-cache
docker compose up -d
docker compose ps
```
D:\TranVanHuy_HoHuuDuc_miniclouddemo\TranVanHuy_HoHuuDuc_miniclouddemo>docker exec object-storage-server sh -lc "my anonymous set none local/profile-pics"
Access permission for `local/profile-pics` is set to `private`
---

## 🌐 Bảng cổng dịch vụ

| # | Server | Công nghệ | Port | URL |
|---|--------|-----------|------|-----|
| 1a | Web Frontend 1 | Nginx | 8080 | http://localhost:8080 |
| 1b | Web Frontend 2 | Nginx | 8082 | http://localhost:8082 |
| 2 | App Backend | Flask | 8085 | http://localhost:8085/hello |
| 3 | Database | MariaDB | 3306 | docker exec ... |
| 4 | Auth | Keycloak | 8081 | http://localhost:8081 |
| 5 | Storage | MinIO | 9001 | http://localhost:9001 |
| 6 | DNS | Bind9 | 1053/UDP | docker exec nslookup |
| 7 | Monitoring | Prometheus | 9090 | http://localhost:9090 |
| 8 | Dashboard | Grafana | 3000 | http://localhost:3000 |
| 9 | Proxy/LB | Nginx | 80 | http://localhost |

---

## ✅ Kiểm thử nhanh

```powershell
# Web (Server 1 & 2)
Invoke-WebRequest http://localhost:8080/ -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8082/ -UseBasicParsing | Select-Object StatusCode

# App API
Invoke-WebRequest http://localhost:8085/hello -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:8085/student -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:8085/students-db -UseBasicParsing | Select-Object -ExpandProperty Content

# Database
docker exec relational-database-server mariadb -uroot -proot minicloud -e "SELECT * FROM notes;"
docker exec relational-database-server mariadb -uroot -proot studentdb -e "SELECT * FROM students;"
docker exec -it relational-database-server mariadb -u root -proot -e "USE minicloud; SHOW TABLES; SELECT * FROM notes;"
# DNS
docker exec internal-dns-server nslookup web-frontend-server.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup minio.cloud.local 127.0.0.1

# Load Balancer Round Robin
1..6 | ForEach-Object {
    $r = Invoke-WebRequest http://localhost/ -UseBasicParsing
    if ($r.Content -match "Server 2") { "Request $_ → Server 2 (Đỏ)" }
    else { "Request $_ → Server 1 (Xanh)" }
}
```

---

## 🚀 Phần mở rộng đã thực hiện

| # | Server | Yêu cầu | Kiểm tra |
|---|--------|---------|---------|
| 1 | Web | Blog 3 bài HTML | http://localhost:8080/blog/ |
| 2 | App | API /student (JSON + HTML view) | http://localhost:8085/student/view |
| 3 | DB | studentdb + bảng students (5 bản ghi) | mariadb studentdb |
| 4 | Keycloak | Tạo Realm + client | http://localhost:8081 |
| 5 | MinIO | Upload bucket | http://localhost:9001 |
| 6 | DNS | 6 bản ghi mở rộng | nslookup minio.cloud.local |
| 7 | Prometheus | Scrape web-frontend-server | http://localhost:9090/targets |
| 8 | Grafana | Dashboard 3 biểu đồ | http://localhost:3000 |
| 9 | Proxy | Route /student/ | http://localhost/student/ |
| 10 | Load Balancer | Round Robin 2 server | Request luân phiên Server 1↔2 |

---

## 🛠️ Lệnh hữu ích

```powershell
docker compose logs -f web-frontend-server     # Log realtime
docker compose restart api-gateway-proxy-server # Restart proxy
docker exec -it application-backend-server sh   # Shell vào app
docker compose down                             # Dừng (giữ data)
docker compose down -v                          # Dừng + xóa data
```

---

*© 2025 Tran Van Huy & Ho Huu Duc – MyMiniCloud*
