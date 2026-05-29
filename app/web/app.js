const $ = (sel) => document.querySelector(sel);

const api = async (method, path, body) => {
  const opts = { method, headers: {} };
  if (body !== undefined) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(path, opts);
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`${res.status}: ${err}`);
  }
  if (res.status === 204) return null;
  return res.json();
};

const toast = (msg) => {
  const el = $("#toast");
  el.textContent = msg;
  el.classList.add("show");
  clearTimeout(toast._t);
  toast._t = setTimeout(() => el.classList.remove("show"), 2200);
};

// ---------- 펫 등록 / 목록 ----------
async function loadPets() {
  const pets = await api("GET", "/pets");
  const list = $("#pet-list");
  const sels = [$("#guide-pet"), $("#cal-pet")];
  list.innerHTML = "";
  sels.forEach((s) => (s.innerHTML = '<option value="">— 펫 선택 —</option>'));

  pets.forEach((p) => {
    const li = document.createElement("li");
    li.innerHTML = `
      <div>
        <strong>${p.name}</strong>
        <span class="age">${p.species === "dog" ? "🐶" : "🐱"} ${p.breed || "품종미상"} · ${p.age_months}개월</span>
      </div>
      <button class="del" data-id="${p.id}">삭제</button>`;
    list.appendChild(li);
    sels.forEach((s) => {
      const o = document.createElement("option");
      o.value = p.id;
      o.textContent = `${p.name} (${p.species === "dog" ? "강아지" : "고양이"}, ${p.age_months}개월)`;
      s.appendChild(o);
    });
  });

  list.querySelectorAll(".del").forEach((b) =>
    b.addEventListener("click", async () => {
      if (!confirm("정말 삭제할까요? 가이드/이벤트도 함께 삭제됩니다.")) return;
      await api("DELETE", `/pets/${b.dataset.id}`);
      toast("삭제됨");
      loadPets();
    })
  );
}

$("#pet-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const fd = new FormData(e.target);
  const payload = Object.fromEntries(fd.entries());
  payload.neutered = payload.neutered === "true";
  payload.weight_kg = payload.weight_kg ? parseFloat(payload.weight_kg) : null;
  if (!payload.breed) delete payload.breed;
  try {
    await api("POST", "/pets", payload);
    e.target.reset();
    toast("등록 완료");
    loadPets();
  } catch (err) {
    toast(`등록 실패: ${err.message}`);
  }
});

// ---------- 가이드 ----------
$("#gen-guide").addEventListener("click", async () => {
  const petId = $("#guide-pet").value;
  if (!petId) return toast("먼저 펫을 선택하세요.");
  const out = $("#guide-out");
  out.innerHTML = "<em>생성 중… (수 초 소요)</em>";
  try {
    const g = await api("POST", "/guides", { pet_id: parseInt(petId, 10) });
    renderGuide(g);
  } catch (err) {
    out.textContent = `오류: ${err.message}`;
  }
});

function renderGuide(g) {
  const citIndex = {};
  (g.citations || []).forEach((c) => (citIndex[c.doc_id] = c));

  const sectionsHtml = (g.sections || [])
    .map((s) => {
      const cits = (s.citations || [])
        .map((id) => {
          const c = citIndex[id];
          if (!c) return `<span class="cit">${id}</span>`;
          const label = c.source
            ? `${c.source}${c.year ? " " + c.year : ""}${c.page ? " p." + c.page : ""}`
            : c.title || id;
          const cls = c.doc_type === "guideline" ? "cit guideline" : "cit";
          return `<span class="${cls}" title="${id}">${label}</span>`;
        })
        .join("");
      return `<h3>${s.topic}</h3>
              <div class="advice">${s.advice || ""}</div>
              <div class="cits">${cits}</div>`;
    })
    .join("");

  $("#guide-out").innerHTML = `
    <div class="summary">📌 ${g.summary}</div>
    ${sectionsHtml}
  `;
}

// ---------- 캘린더 ----------
$("#rebuild").addEventListener("click", async () => {
  const petId = $("#cal-pet").value;
  if (!petId) return toast("먼저 펫을 선택하세요.");
  try {
    await api("POST", `/calendar/${petId}/rebuild`);
    toast("일정이 새로 생성되었습니다.");
    loadEvents();
  } catch (err) {
    toast(`실패: ${err.message}`);
  }
});

$("#load-events").addEventListener("click", loadEvents);

async function loadEvents() {
  const petId = $("#cal-pet").value;
  const days = $("#days").value || 90;
  if (!petId) return;
  const events = await api("GET", `/calendar/${petId}/upcoming?days=${days}`);
  const list = $("#events");
  if (!events.length) {
    list.innerHTML = `<li class="muted" style="grid-template-columns:1fr">예정된 일정이 없습니다. "메타 기반 일정 생성"을 먼저 눌러보세요.</li>`;
    return;
  }
  list.innerHTML = events
    .map((e) => `
      <li data-id="${e.id}">
        <span class="date">${e.due_date}</span>
        <div>
          <div><span class="cat">${e.category}</span>${e.title}${e.recurring ? ` · 매 ${e.interval_days}일` : ""}</div>
          <div class="meta">출처: ${e.source_doc_id}</div>
        </div>
        <button class="done-btn">완료</button>
      </li>`)
    .join("");
  list.querySelectorAll(".done-btn").forEach((b) =>
    b.addEventListener("click", async () => {
      const id = b.parentElement.dataset.id;
      await api("PATCH", `/calendar/event/${id}`, { done: true });
      toast("완료 처리됨");
      loadEvents();
    })
  );
}

// ---------- init ----------
loadPets();
