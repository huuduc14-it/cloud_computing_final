# ============================================================
#  MyMiniCloud – Lenh kiem thu nhanh (copy-paste tung lenh)
#  Tran Van Huy  & Ho Huu Duc
# ============================================================

# ── 0. Khoi dong ──────────────────────────────────────────────────────────
docker compose build --no-cache
docker compose up -d
docker compose ps

# ── 1. Web Frontend Server 1 (port 8080) ──────────────────────────────────
Invoke-WebRequest http://localhost:8080/ -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8080/blog/ -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8080/blog/blog1.html -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8080/blog/blog2.html -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8080/blog/blog3.html -UseBasicParsing | Select-Object StatusCode

# ── 1b. Web Frontend Server 2 (port 8082 – Round Robin) ───────────────────
Invoke-WebRequest http://localhost:8082/ -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost:8082/blog/ -UseBasicParsing | Select-Object StatusCode

# ── 2. App Backend (port 8085) ────────────────────────────────────────────
Invoke-WebRequest http://localhost:8085/hello -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:8085/student -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:8085/students-db -UseBasicParsing | Select-Object -ExpandProperty Content
Start-Process "http://localhost:8085/student/view"
Start-Process "http://localhost:8085/students-db/view"

# ── 3. Database MariaDB ────────────────────────────────────────────────────
docker exec relational-database-server mariadb -uroot -proot minicloud -e "SHOW TABLES; SELECT * FROM notes;"
docker exec relational-database-server mariadb -uroot -proot studentdb -e "SELECT * FROM students;"
# CRUD demo:
docker exec relational-database-server mariadb -uroot -proot studentdb -e "UPDATE students SET major='AI' WHERE student_id='SV001';"
docker exec relational-database-server mariadb -uroot -proot studentdb -e "SELECT * FROM students WHERE student_id='SV001';"

# ── 4. Keycloak Auth ──────────────────────────────────────────────────────
Start-Process "http://localhost:8081"
# Dang nhap: admin / admin

# ── 5. MinIO Storage ──────────────────────────────────────────────────────
Start-Process "http://localhost:9001"
# Dang nhap: minioadmin / minioadmin

# ── 6. DNS Server (Bind9) ─────────────────────────────────────────────────
docker exec internal-dns-server nslookup web-frontend-server.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup web-frontend-server2.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup minio.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup keycloak.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup app-backend.cloud.local 127.0.0.1
docker exec internal-dns-server nslookup grafana.cloud.local 127.0.0.1

# ── 7. Prometheus ─────────────────────────────────────────────────────────
Start-Process "http://localhost:9090/targets"
# Kiem tra: job 'node' va 'web' phai UP

# ── 8. Grafana ────────────────────────────────────────────────────────────
Start-Process "http://localhost:3000"
# Dang nhap: admin / admin
# Add Datasource: Prometheus → http://monitoring-prometheus-server:9090
# Import Dashboard ID: 1860

# ── 9. Reverse Proxy (port 80) ────────────────────────────────────────────
Invoke-WebRequest http://localhost/ -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest http://localhost/api/hello -UseBasicParsing | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost/student/ -UseBasicParsing | Select-Object -ExpandProperty Content

# ── 10. Load Balancer Round Robin test ────────────────────────────────────
# Gui 10 request, quan sat luot phien giua Server 1 (xanh) va Server 2 (do)
1..10 | ForEach-Object {
    $r = Invoke-WebRequest http://localhost/ -UseBasicParsing -TimeoutSec 5
    $server = if ($r.Content -match "Server 2") { "→ SERVER 2 (Do)" } else { "→ SERVER 1 (Xanh)" }
    Write-Host "Request $_ $server"
}

# ── Ping mang noi bo (tu container proxy) ─────────────────────────────────
docker exec api-gateway-proxy-server ping -c 3 web-frontend-server
docker exec api-gateway-proxy-server ping -c 3 web-frontend-server2
docker exec api-gateway-proxy-server ping -c 3 application-backend-server
docker exec api-gateway-proxy-server ping -c 3 relational-database-server
docker exec api-gateway-proxy-server ping -c 3 authentication-identity-server
docker exec api-gateway-proxy-server ping -c 3 object-storage-server
docker exec api-gateway-proxy-server ping -c 3 monitoring-prometheus-server
docker exec api-gateway-proxy-server ping -c 3 monitoring-grafana-dashboard-server
docker exec api-gateway-proxy-server ping -c 3 internal-dns-server

# ── Mo tat ca dashboard ───────────────────────────────────────────────────
Start-Process "http://localhost:8080"
Start-Process "http://localhost:8082"
Start-Process "http://localhost:8081"
Start-Process "http://localhost:9001"
Start-Process "http://localhost:9090/targets"
Start-Process "http://localhost:3000"

# ── Don dep ───────────────────────────────────────────────────────────────
# docker compose down        # Dung (giu data volume)
# docker compose down -v     # Dung va xoa het data
