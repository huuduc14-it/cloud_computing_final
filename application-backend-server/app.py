from flask import Flask, jsonify, request, render_template
import time, requests, os, json
import pymysql

try:
    from jose import jwt
    HAS_JOSE = True
except ImportError:
    HAS_JOSE = False

# ── Config ───────────────────────────────────────────────────────────────
ISSUER   = os.getenv("OIDC_ISSUER",   "http://authentication-identity-server:8080/realms/master")
AUDIENCE = os.getenv("OIDC_AUDIENCE", "myapp")
JWKS_URL = f"{ISSUER}/protocol/openid-connect/certs"

DB_HOST = os.getenv("DB_HOST", "relational-database-server")
DB_USER = os.getenv("DB_USER", "root")
DB_PASS = os.getenv("DB_PASS", "root")

_JWKS = None
_TS   = 0

def get_jwks():
    global _JWKS, _TS
    now = time.time()
    if not _JWKS or now - _TS > 600:
        try:
            _JWKS = requests.get(JWKS_URL, timeout=5).json()
            _TS = now
        except Exception:
            pass
    return _JWKS

app = Flask(__name__, template_folder="templates", static_folder="static")

# ── Basic ─────────────────────────────────────────────────────────────────

@app.get("/hello")
def hello():
    return jsonify(message="Hello from App Server!", status="ok", server="application-backend-server")

@app.get("/health")
def health():
    return jsonify(status="healthy", server="application-backend-server")

@app.get("/secure")
def secure():
    if not HAS_JOSE:
        return jsonify(error="python-jose not installed"), 503
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return jsonify(error="Missing Bearer token"), 401
    token = auth.split(" ", 1)[1]
    try:
        jwks = get_jwks()
        if not jwks:
            return jsonify(error="JWKS not available"), 503
        payload = jwt.decode(token, jwks, algorithms=["RS256"], audience=AUDIENCE, issuer=ISSUER)
        return jsonify(message="Secure OK", preferred_username=payload.get("preferred_username"))
    except Exception as e:
        return jsonify(error=str(e)), 401

# ── Extended: /student – JSON file + HTML template ────────────────────────

@app.get("/student")
def student_json():
    """API trả JSON"""
    try:
        with open("students.json", encoding="utf-8") as f:
            data = json.load(f)
        return jsonify(data)
    except FileNotFoundError:
        return jsonify(error="students.json not found"), 404

@app.get("/student/view")
def student_view():
    """Hiển thị HTML template"""
    try:
        with open("students.json", encoding="utf-8") as f:
            data = json.load(f)
        return render_template("student.html", students=data)
    except Exception as e:
        return str(e), 500
@app.get("/student/view/<int:id>")
def student_view1(id):
    with open("students.json", encoding="utf-8") as f:
        data = json.load(f)

    student = next((s for s in data if s["id"] == id), None)

    return render_template("student2.html", student=student, students=data)
# ── Extended: /students-db – MariaDB + HTML template ──────────────────────

@app.get("/students-db")
def students_db_json():
    """API trả JSON từ DB"""
    try:
        conn = pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database="studentdb", charset="utf8mb4", connect_timeout=5
        )
        with conn.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute("SELECT * FROM students ORDER BY id")
            rows = cur.fetchall()
            for r in rows:
                if r.get("dob"): r["dob"] = str(r["dob"])
        conn.close()
        return jsonify(source="mariadb", data=rows)
    except Exception as e:
        return jsonify(error=str(e), hint="DB may still be initializing, retry in 30s"), 500

@app.get("/students-db/view")
def students_db_view():
    """Hiển thị HTML template từ DB"""
    try:
        conn = pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database="studentdb", charset="utf8mb4", connect_timeout=5
        )
        with conn.cursor(pymysql.cursors.DictCursor) as cur:
            cur.execute("SELECT * FROM students ORDER BY id")
            rows = cur.fetchall()
            for r in rows:
                if r.get("dob"): r["dob"] = str(r["dob"])
        conn.close()
        return render_template("students2_db.html", students=rows)
    except Exception as e:
        return render_template("students2_db.html", students=[], error=str(e))





# CRUD API ---------------------------------------------------------------------------------------------------------------------------------------------------------------

# @app.post("/students-db")
# def create_student():
#     data = request.json
#     try:
#         conn = pymysql.connect(
#             host=DB_HOST, user=DB_USER, password=DB_PASS,
#             database="studentdb", charset="utf8mb4"
#         )
#         with conn.cursor() as cur:
#             cur.execute("""
#                 INSERT INTO students (student_id, fullname, dob, major)
#                 VALUES (%s, %s, %s, %s)
#             """, (data["student_id"], data["fullname"], data["dob"], data["major"]))
#             conn.commit()
#         conn.close()
#         return jsonify(message="Created"), 201
#     except Exception as e:
#         return jsonify(error=str(e)), 500
@app.post("/students-db")
def create_student():
    data = request.json
    try:
        conn = pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database="studentdb", charset="utf8mb4"
        )
        with conn.cursor() as cur:
            # CHECK TRÙNG
            cur.execute("SELECT * FROM students WHERE student_id=%s", (data["student_id"],))
            if cur.fetchone():
                return jsonify(error="Student ID already exists"), 400

            cur.execute("""
                INSERT INTO students (student_id, fullname, dob, major)
                VALUES (%s, %s, %s, %s)
            """, (data["student_id"], data["fullname"], data["dob"], data["major"]))
            conn.commit()

        conn.close()
        return jsonify(message="Created"), 201

    except Exception as e:
        return jsonify(error=str(e)), 500


@app.put("/students-db/<int:id>")
def update_student(id):
    data = request.json
    try:
        conn = pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database="studentdb", charset="utf8mb4"
        )
        with conn.cursor() as cur:
            cur.execute("""
                UPDATE students
                SET student_id=%s, fullname=%s, dob=%s, major=%s
                WHERE id=%s
            """, (data["student_id"], data["fullname"], data["dob"], data["major"], id))
            conn.commit()
        conn.close()
        return jsonify(message="Updated")
    except Exception as e:
        return jsonify(error=str(e)), 500


@app.delete("/students-db/<int:id>")
def delete_student(id):
    try:
        conn = pymysql.connect(
            host=DB_HOST, user=DB_USER, password=DB_PASS,
            database="studentdb", charset="utf8mb4"
        )
        with conn.cursor() as cur:
            cur.execute("DELETE FROM students WHERE id=%s", (id,))
            conn.commit()
        conn.close()
        return jsonify(message="Deleted")
    except Exception as e:
        return jsonify(error=str(e)), 500
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081, debug=True)