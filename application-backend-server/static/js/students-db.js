console.log("students-db.js loaded – DB list view");
const API = "/students-db";

const form = document.getElementById("studentForm");
const statusBox = document.getElementById("formStatus");

// ==============================
// UI helper
// ==============================
function showStatus(msg, success = true) {
  statusBox.innerText = msg;
  statusBox.style.color = success ? "green" : "red";
}

// ==============================
// SUBMIT (CREATE / UPDATE)
// ==============================
if (form) {
  form.onsubmit = async (e) => {
    e.preventDefault();

    const id = document.getElementById("id").value;

    const data = {
      student_id: document.getElementById("student_id").value.trim(),
      fullname: document.getElementById("fullname").value.trim(),
      dob: document.getElementById("dob").value,
      major: document.getElementById("major").value.trim(),
    };

    try {
      let res;

      if (id) {
        // UPDATE
        res = await fetch(`${API}/${id}`, {
          method: "PUT",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        });

        showStatus("✅ Cập nhật thành công!");
      } else {
        // CREATE
        res = await fetch(API, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(data),
        });

        const result = await res.json();

        if (!res.ok) {
          showStatus("❌ " + result.error, false);
          return;
        }

        showStatus("✅ Thêm sinh viên thành công!");
      }

      form.reset();
      document.getElementById("id").value = "";

      setTimeout(() => location.reload(), 800);
    } catch (err) {
      showStatus("❌ Lỗi hệ thống!", false);
    }
  };
}

// ==============================
// DELETE
// ==============================
async function deleteStudent(id) {
  if (!confirm("Bạn có chắc muốn xóa?")) return;

  try {
    await fetch(`${API}/${id}`, { method: "DELETE" });

    showStatus("🗑️ Đã xóa!");
    setTimeout(() => location.reload(), 500);
  } catch (err) {
    showStatus("❌ Xóa thất bại!", false);
  }
}

// ==============================
// EDIT
// ==============================
function handleEdit(btn) {
  const id = btn.dataset.id;
  const student_id = btn.dataset.student_id;
  const fullname = btn.dataset.fullname;
  const dob = btn.dataset.dob;
  const major = btn.dataset.major;

  document.getElementById("id").value = id;
  document.getElementById("student_id").value = student_id;
  document.getElementById("fullname").value = fullname;
  document.getElementById("dob").value = dob ? dob.split(" ")[0] : "";
  document.getElementById("major").value = major;

  showStatus("✏️ Đang chỉnh sửa sinh viên...");
  window.scrollTo({ top: 0, behavior: "smooth" });
}
