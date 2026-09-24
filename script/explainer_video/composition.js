/* Mesto explainer: a deterministic, seekable motion composition.
 *
 * Every visual property is a pure function of time, so the renderer can
 * capture identical frames at any frame rate. Open the HTML file directly to
 * preview (space: play/pause, ←/→: scrub, ?lang=en, ?t=12.5 to freeze).
 */
(() => {
  const params = new URLSearchParams(location.search);
  const LANG = params.get("lang") === "en" ? "en" : "bg";
  const DURATION = 28;
  document.documentElement.lang = LANG;

  // ---------------------------------------------------------------- copy
  const COPY = {
    bg: {
      s1_title: "Хареса\nапартамент?",
      s1_sub: "Преди капарото идват въпросите.",
      listing_tag: "Нова обява",
      listing_title: "3-стаен апартамент",
      listing_place: "Лозенец, София",
      listing_price: "€ 245 000",
      listing_meta: "78 m² · етаж 4",
      questions: ["Какво се строи наоколо?", "Има ли разрешение за строеж?", "Какво показва кадастърът?", "Колко е до метрото?", "Какво да питам продавача?"],
      steps: ["Адрес", "Точен имот", "Източници", "Отчет"],
      disclaimer: "Примерни данни",
      s2_title: "Започни\nс адрес.",
      s2_sub: "Не ти трябва кадастрален номер.",
      panel_eyebrow: "Започни оттук",
      panel_title: "Провери конкретен имот",
      tab_addr: "По адрес",
      tab_id: "По идентификатор",
      addr_label: "Адрес на сградата",
      address: "ул. Проф. Крикор Азарян 25",
      suggestions: [["ул. Проф. Крикор Азарян 25", "Лозенец, София · 1 сграда"], ["ул. Проф. Крикор Азарян 25А", "Лозенец, София"], ["ул. Проф. Крикор Азарян 27", "Лозенец, София"]],
      button: "Намери апартамента",
      selected: "Избрана е точна сграда",
      s3_title: "Посочи точния\nапартамент.",
      s3_sub: "По вход, етаж, номер или площ.",
      chips: ["Вход Б", "Етаж 4", "Ап. 12", "78 m²"],
      callout_title: "Ап. 12 · 78 m²",
      callout_label: "Самостоятелен обект",
      report_id: "68134.4356.27.1.12",
      s4_title: "Свързваме\n*12+* публични\nизточника.",
      s4_sub: "На едно място, всяко с ясен произход.",
      layers: [["АГКК", "Кадастър"], ["Софияплан", "Устройство и зони"], ["НАГ", "Разрешения и актове"], ["Софияплан", "Метро, училища, паркове"]],
      s5_title: "Получаваш\nясен отчет.",
      s5_sub: "Факти с източник и какво още да провериш.",
      report_eyebrow: "Отчет за имота",
      report_title: "ул. Проф. Крикор Азарян 25, ап. 12",
      report_badge: "Анализът е готов",
      findings: [
        ["building", "Идентичност", "Апартамент · 78 m² · етаж 4", "АГКК"],
        ["layers", "Устройство", "Жилищна зона · регулация", "Софияплан"],
        ["doc", "Строителство наоколо", "3 разрешения в радиус 500 m", "НАГ"],
        ["tree", "Среда", "Метро 450 m · 3 училища · парк 8 мин", "Софияплан"],
        ["alert", "Още за проверка", "Собственост и тежести", "Имотен регистър", "warn"]
      ],
      asks_title: "Въпроси към продавача",
      asks: ["Има ли ипотека или тежести?", "Има ли Акт 16 за сградата?", "Какво се строи в съседство?"],
      end_title: "Опознай мястото,\nпреди да го наречеш *дом.*",
      end_cta: "Започни проверка",
      end_trust: ["Безплатен преглед", "Без регистрация"]
    },
    en: {
      s1_title: "Found a place\nyou love?",
      s1_sub: "Before the deposit come the questions.",
      listing_tag: "New listing",
      listing_title: "2-bedroom apartment",
      listing_place: "Lozenets, Sofia",
      listing_price: "€ 245,000",
      listing_meta: "78 m² · floor 4",
      questions: ["What's being built nearby?", "Is there a building permit?", "What does the cadastre say?", "How far is the metro?", "What should I ask the seller?"],
      steps: ["Address", "Exact home", "Sources", "Report"],
      disclaimer: "Illustrative data",
      s2_title: "Start with\nan address.",
      s2_sub: "No cadastral number needed.",
      panel_eyebrow: "Start here",
      panel_title: "Check a specific property",
      tab_addr: "By address",
      tab_id: "By identifier",
      addr_label: "Building address",
      address: "ул. Проф. Крикор Азарян 25",
      suggestions: [["ул. Проф. Крикор Азарян 25", "Lozenets, Sofia · 1 building"], ["ул. Проф. Крикор Азарян 25А", "Lozenets, Sofia"], ["ул. Проф. Крикор Азарян 27", "Lozenets, Sofia"]],
      button: "Find the apartment",
      selected: "Exact building selected",
      s3_title: "Pinpoint\nthe exact home.",
      s3_sub: "By entrance, floor, number or area.",
      chips: ["Entrance B", "Floor 4", "Apt 12", "78 m²"],
      callout_title: "Apt 12 · 78 m²",
      callout_label: "Individual unit",
      report_id: "68134.4356.27.1.12",
      s4_title: "We connect\n*12+* public\nsources.",
      s4_sub: "In one place, each with a clear origin.",
      layers: [["AGCC", "Cadastre"], ["SofiaPlan", "Planning and zoning"], ["NAG", "Permits and acts"], ["SofiaPlan", "Metro, schools, parks"]],
      s5_title: "Get a clear\nreport.",
      s5_sub: "Sourced facts, plus what's left to check.",
      report_eyebrow: "Property report",
      report_title: "ул. Проф. Крикор Азарян 25, apt 12",
      report_badge: "Analysis ready",
      findings: [
        ["building", "Identity", "Apartment · 78 m² · floor 4", "AGCC"],
        ["layers", "Planning", "Residential zone · regulation", "SofiaPlan"],
        ["doc", "Construction nearby", "3 permits within 500 m", "NAG"],
        ["tree", "Surroundings", "Metro 450 m · 3 schools · park 8 min", "SofiaPlan"],
        ["alert", "Still to verify", "Ownership and encumbrances", "Property Register", "warn"]
      ],
      asks_title: "Questions for the seller",
      asks: ["Any mortgage or encumbrances?", "Does the building have Act 16?", "What's being built next door?"],
      end_title: "Know the place\nbefore you call it *home.*",
      end_cta: "Start a check",
      end_trust: ["Free preview", "No registration"]
    }
  }[LANG];

  // -------------------------------------------------------------- engine
  function bezier(x1, y1, x2, y2) {
    const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx;
    const cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
    const sx = (t) => ((ax * t + bx) * t + cx) * t;
    const sy = (t) => ((ay * t + by) * t + cy) * t;
    const dx = (t) => (3 * ax * t + 2 * bx) * t + cx;
    return (x) => {
      if (x <= 0) return 0;
      if (x >= 1) return 1;
      let t = x;
      for (let i = 0; i < 8; i++) {
        const err = sx(t) - x;
        if (Math.abs(err) < 1e-6) break;
        const d = dx(t);
        if (Math.abs(d) < 1e-6) break;
        t -= err / d;
      }
      let lo = 0, hi = 1;
      for (let i = 0; i < 30 && Math.abs(sx(t) - x) > 1e-6; i++) {
        if (sx(t) < x) lo = t; else hi = t;
        t = (lo + hi) / 2;
      }
      return sy(t);
    };
  }
  const EASE = {
    linear: (t) => t,
    out: bezier(0.16, 1, 0.3, 1),
    soft: bezier(0.33, 1, 0.68, 1),
    in: bezier(0.7, 0, 0.84, 0),
    inOut: bezier(0.65, 0, 0.35, 1),
    cam: bezier(0.76, 0, 0.24, 1),
    back: bezier(0.34, 1.56, 0.64, 1),
    snap: bezier(0.2, 0.75, 0.25, 1)
  };

  const records = new Map();
  const hooks = [];

  // A(target, { prop: [[time, value, ease], ...] }, apply?)
  // Keyframes for the same prop are merged, so entrances and exits can be
  // declared independently.
  function A(target, props, apply) {
    const el = typeof target === "string" ? document.querySelector(target) : target;
    if (!el) throw new Error(`Missing element ${target}`);
    let rec = records.get(el);
    if (!rec) { rec = { el, props: {}, apply: apply || applyDefault }; records.set(el, rec); }
    if (apply) rec.apply = apply;
    for (const [k, kf] of Object.entries(props)) {
      const list = typeof kf === "number" ? [[0, kf]] : kf;
      rec.props[k] = (rec.props[k] || []).concat(list).sort((a, b) => a[0] - b[0]);
    }
    return el;
  }

  function value(kf, t) {
    if (t <= kf[0][0]) return kf[0][1];
    for (let i = 1; i < kf.length; i++) {
      const [t1, v1, e] = kf[i];
      if (t <= t1) {
        const [t0, v0] = kf[i - 1];
        const p = t1 === t0 ? 1 : (t - t0) / (t1 - t0);
        return v0 + (v1 - v0) * EASE[e || "out"](p);
      }
    }
    return kf[kf.length - 1][1];
  }

  function applyDefault(el, v) {
    let tr = "";
    if ("x" in v || "y" in v) tr += `translate(${(v.x || 0).toFixed(2)}px, ${(v.y || 0).toFixed(2)}px) `;
    if ("r" in v) tr += `rotate(${v.r.toFixed(3)}deg) `;
    if ("s" in v || "sx" in v || "sy" in v) {
      const s = "s" in v ? v.s : 1;
      tr += `scale(${(s * ("sx" in v ? v.sx : 1)).toFixed(4)}, ${(s * ("sy" in v ? v.sy : 1)).toFixed(4)})`;
    }
    if (tr) el.style.transform = tr;
    if ("o" in v) {
      const o = Math.max(0, Math.min(1, v.o));
      el.style.opacity = o.toFixed(3);
      el.style.visibility = o < 0.002 ? "hidden" : "visible";
    }
    if ("blur" in v) el.style.filter = v.blur > 0.05 ? `blur(${v.blur.toFixed(2)}px)` : "none";
    for (const k in v) if (k.startsWith("--")) el.style.setProperty(k, v[k].toFixed(4));
  }

  function seek(t) {
    for (const rec of records.values()) {
      const v = {};
      for (const k in rec.props) v[k] = value(rec.props[k], t);
      rec.apply(rec.el, v, t);
    }
    for (const hook of hooks) hook(t);
  }

  // ------------------------------------------------------------- helpers
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const h = (tag, attrs = {}, html = "") => {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) el.setAttribute(k, v);
    el.innerHTML = html;
    return el;
  };
  const clamp01 = (x) => Math.max(0, Math.min(1, x));
  const ICON_CHECK = '<svg viewBox="0 0 24 24"><path d="m5 12.5 4.2 4L19 7"/></svg>';
  const ICONS = {
    building: '<path d="M5 21V6.5L12 3l7 3.5V21M3 21h18M9 9.5h.01M15 9.5h.01M9 13.5h.01M15 13.5h.01M10 21v-4h4v4"/>',
    layers: '<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="m3 12.5 9 5 9-5M3 16.5l9 5 9-5"/>',
    doc: '<path d="M7 3h7l4 4v14H7V3Z"/><path d="M14 3v4h4M10 12h5M10 16h5"/>',
    tree: '<path d="M12 3a5 5 0 0 1 5 5c0 3.2-2.2 4.5-5 4.5S7 11.2 7 8a5 5 0 0 1 5-5ZM12 12.5V21M8 21h8"/>',
    alert: '<path d="M12 3.5 2.5 20h19L12 3.5Z"/><path d="M12 10v4.2M12 17.2v.3"/>'
  };

  // "Line one\nline *two*" -> masked word spans; *text* becomes <em>.
  function setWords(el, text) {
    el.innerHTML = "";
    text.split("\n").forEach((line, li) => {
      if (li) el.appendChild(document.createElement("br"));
      let italic = false;
      line.split(" ").forEach((word, wi) => {
        if (wi) el.appendChild(document.createTextNode(" "));
        let w = word;
        const starts = w.startsWith("*");
        if (starts) { italic = true; w = w.slice(1); }
        const ends = w.endsWith("*");
        if (ends) w = w.slice(0, -1);
        const outer = h("span", { class: "w" });
        const inner = h("span", { class: "wi" });
        if (italic) inner.appendChild(h("em", {}, w)); else inner.textContent = w;
        outer.appendChild(inner);
        el.appendChild(outer);
        if (ends) italic = false;
      });
    });
    return $$(".wi", el);
  }

  function wordsIn(el, t0, { stagger = 0.07, dur = 0.9 } = {}) {
    $$(".wi", el).forEach((w, i) => {
      const hgt = w.offsetHeight * 1.1;
      A(w, { y: [[t0 + i * stagger, hgt], [t0 + i * stagger + dur, 0, "out"]] });
    });
  }

  function fadeUp(el, t0, { dy = 24, dur = 0.7, s } = {}) {
    const props = { o: [[t0, 0], [t0 + dur * 0.7, 1, "soft"]], y: [[t0, dy], [t0 + dur, 0, "out"]] };
    if (s !== undefined) props.s = [[t0, s], [t0 + dur, 1, "out"]];
    return A(el, props);
  }

  function fadeOut(el, t0, { dy = -30, dur = 0.5 } = {}) {
    return A(el, { o: [[t0, 1], [t0 + dur, 0, "in"]], y: [[t0, 0], [t0 + dur, dy, "in"]] });
  }

  // --------------------------------------------------------- build: copy
  $$("[data-k]").forEach((el) => { el.textContent = COPY[el.dataset.k]; });
  $$("[data-words]").forEach((el) => setWords(el, COPY[el.dataset.words]));

  // Wordmark from the canonical MestoLogoHelper letterforms.
  const LETTERFORMS = {
    M: ["10001", "11011", "10101", "10001", "10001"],
    E: ["1111", "1000", "1110", "1000", "1111"],
    S: ["1111", "1000", "1111", "0001", "1111"],
    T: ["11111", "00100", "00100", "00100", "00100"],
    O: ["01110", "10001", "10001", "10001", "01110"]
  };
  function wordmark({ primary, accent, animated }) {
    const cells = [];
    let offset = 0;
    for (const [letter, rows] of Object.entries(LETTERFORMS)) {
      rows.forEach((row, r) => [...row].forEach((v, c) => {
        if (v === "1") cells.push({ key: `${letter}:${r}:${c}`, x: (offset + c) * 12, y: r * 12 });
      }));
      offset += rows[0].length + 1;
    }
    const width = (offset - 2) * 12 + 10;
    const rects = cells.map((cell, i) => {
      const isAccent = cell.key === "M:2:2";
      const fill = isAccent && !animated ? accent : primary;
      const hot = isAccent && animated ? `<rect class="accent-hot" x="${cell.x}" y="${cell.y}" width="10" height="10" rx=".7" fill="${accent}" style="transform-box: fill-box; transform-origin: center"/>` : "";
      return `<rect class="cell" data-i="${i}" x="${cell.x}" y="${cell.y}" width="10" height="10" rx=".7" fill="${fill}" style="transform-box: fill-box; transform-origin: center"/>${hot}`;
    });
    return `<svg viewBox="0 0 ${width} 58" xmlns="http://www.w3.org/2000/svg">${rects.join("")}</svg>`;
  }
  $("#brand").innerHTML = wordmark({ primary: "#173f34", accent: "#b95f3f" });
  $("#end-logo").innerHTML = wordmark({ primary: "#f4f0e8", accent: "#cf7a57", animated: true });

  // Progress
  COPY.steps.forEach((label, i) => {
    $("#progress").appendChild(h("div", { class: "step" }, `<div class="step__track"><div class="step__fill"></div></div><div class="step__label"><b>0${i + 1}</b>${label}</div>`));
  });

  // Captions
  function buildCap(id, n, titleKey, subKey) {
    const cap = $(id);
    cap.innerHTML = `<div class="cap__eyebrow"><b>0${n}</b><i></i><span>${COPY.steps[n - 1]}</span></div><h2></h2><p></p>`;
    setWords($("h2", cap), COPY[titleKey]);
    setWords($("p", cap), COPY[subKey]);
    return cap;
  }
  buildCap("#cap2", 1, "s2_title", "s2_sub");
  buildCap("#cap3", 2, "s3_title", "s3_sub");
  buildCap("#cap4", 3, "s4_title", "s4_sub");
  buildCap("#cap5", 4, "s5_title", "s5_sub");

  // Listing illustration: the same building language as the 3D model.
  (() => {
    const cols = 5, rows = 6;
    let wins = "";
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const x = 170 + c * 34, y = 84 + r * 30;
      const hot = r === 2 && c === 3;
      wins += `<rect x="${x}" y="${y}" width="18" height="18" rx="1.5" fill="${hot ? "#cf7a57" : "#f4f0e8"}" opacity="${hot ? 1 : 0.92}"/>`;
    }
    $("#listing-art").innerHTML = `
      <defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e6ece2"/><stop offset="1" stop-color="#f6f8f4"/></linearGradient></defs>
      <rect width="480" height="300" fill="url(#sky)"/>
      <circle cx="398" cy="78" r="40" fill="#e8d6bb"/>
      <rect x="30" y="170" width="120" height="110" fill="#d8c2a2"/>
      <rect x="44" y="186" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/><rect x="72" y="186" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/><rect x="100" y="186" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/>
      <rect x="44" y="216" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/><rect x="72" y="216" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/><rect x="100" y="216" width="16" height="16" rx="1.5" fill="#f4f0e8" opacity=".8"/>
      <rect x="340" y="130" width="110" height="150" fill="#6f8060" opacity=".55"/>
      <rect x="152" y="62" width="186" height="218" fill="#173f34"/>
      <rect x="146" y="56" width="198" height="10" rx="2" fill="#0e2c25"/>
      ${wins}
      <rect x="228" y="258" width="34" height="22" fill="#0e2c25"/>
      <rect x="0" y="278" width="480" height="22" fill="#e9e1d4"/>
      <circle cx="380" cy="244" r="30" fill="#6f8060"/><circle cx="404" cy="230" r="24" fill="#7f9170"/><rect x="386" y="252" width="5" height="28" fill="#4f5e44"/>
      <circle cx="120" cy="252" r="20" fill="#7f9170"/><rect x="118" y="260" width="4" height="20" fill="#4f5e44"/>`;
  })();

  // Heart burst particles
  (() => {
    const heart = $(".listing__heart");
    for (let i = 0; i < 8; i++) {
      const p = h("i", { class: "burst" });
      Object.assign(p.style, { position: "absolute", left: "50%", top: "50%", width: "8px", height: "8px", margin: "-4px", borderRadius: "1.5px", background: i % 2 ? "#cf7a57" : "#b95f3f" });
      heart.appendChild(p);
    }
  })();

  // Question chips
  const QPOS = [[930, 196], [1330, 150], [905, 520], [1480, 430], [1170, 760]];
  COPY.questions.forEach((q, i) => {
    const wrap = h("div", { class: "qwrap" });
    Object.assign(wrap.style, { position: "absolute", left: `${QPOS[i][0]}px`, top: `${QPOS[i][1]}px` });
    wrap.appendChild(h("div", { class: `q${i === 4 ? " q--dark" : ""}`, style: "position: relative" }, `<i>?</i>${q}`));
    $("#questions").appendChild(wrap);
  });

  // Suggestions
  COPY.suggestions.forEach(([title, sub]) => {
    $("#suggestions").appendChild(h("div", { class: "sugg" }, `<b class="sugg__hl"></b><span class="sugg__icon"><svg viewBox="0 0 24 24"><path d="M5 21V6.5L12 3l7 3.5V21M3 21h18"/></svg></span><div><strong>${title}</strong><span>${sub}</span></div>`));
  });

  // Filter chips
  COPY.chips.forEach((chip, i) => {
    $("#chips").appendChild(h("div", { class: `chip${i === 2 ? " is-hot" : ""}` }, `<i>${ICON_CHECK}</i>${chip}`));
  });

  // Findings + asks
  COPY.findings.forEach(([icon, title, text, source, kind]) => {
    const warn = kind === "warn";
    $("#findings").appendChild(h("li", { class: `finding${warn ? " finding--warn" : ""}` },
      `<span class="finding__icon"><svg viewBox="0 0 24 24">${ICONS[icon]}</svg></span><div><strong>${title}${warn ? "" : ICON_CHECK}</strong><p>${text}</p></div><em>${source}</em>`));
  });
  COPY.asks.forEach((q) => $("#asks ol").appendChild(h("li", {}, `<i>${ICON_CHECK}</i><span>${q}</span>`)));

  // End card trust line
  COPY.end_trust.forEach((label) => $(".end__trust").appendChild(h("span", {}, `${ICON_CHECK}${label}`)));

  // End background: the hero topography, inverted onto pine.
  const topo = $(".topo").innerHTML;
  $("#end-bg").innerHTML = `<svg viewBox="0 0 760 640">${topo}</svg>`;

  // Wipe cells
  for (let i = 0; i < 16 * 9; i++) $("#wipe").appendChild(h("i"));

  // Layer labels
  COPY.layers.forEach(([tag, text], i) => {
    $("#layer-labels").appendChild(h("div", { class: "layer-label", "data-i": i }, `<i></i><div><em></em><b>${tag}</b><span>${text}</span></div>`));
  });

  // ------------------------------------------------------ build: the map
  const L = 460;
  const BX = 195, BY = 170, BW = 130, BD = 90; // building footprint (layer coords)
  const FH = 26, FLOORS = 6;
  const pts = (arr) => arr.map((p) => p.join(",")).join(" ");
  const PARCELS = [
    [[143, 0], [305, 0], [300, 113], [143, 123]],
    [[305, 0], [460, 0], [460, 100], [300, 113]],
    [[143, 123], [178, 121], [170, 303], [143, 303]],
    [[352, 108], [460, 100], [460, 303], [360, 303]],
    [[0, 0], [113, 0], [113, 90], [0, 105]],
    [[0, 105], [113, 90], [113, 200], [0, 215]],
    [[0, 215], [113, 200], [113, 303], [0, 303]],
    [[0, 333], [113, 333], [113, 460], [0, 460]],
    [[143, 333], [290, 333], [280, 460], [143, 460]],
    [[290, 333], [460, 333], [460, 460], [280, 460]]
  ];
  const OURS = [[178, 121], [352, 108], [360, 303], [170, 303]];
  const FOOTPRINTS = [[168, 28, 112, 58], [328, 24, 104, 52], [384, 140, 56, 130], [18, 18, 72, 54], [22, 118, 66, 62], [18, 232, 78, 52], [20, 352, 70, 42], [164, 356, 92, 62]];

  $("#map-base").innerHTML = `
    <defs>
      <clipPath id="map-clip"><rect width="460" height="460" rx="18"/></clipPath>
      <filter id="shadow-blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>
    </defs>
    <g clip-path="url(#map-clip)">
      <rect width="460" height="460" fill="#fbfaf7"/>
      <path d="M0 318H460M128 0V460" stroke="#ece5d9" stroke-width="30"/>
      <path d="M0 318H460M128 0V460" stroke="#fbfaf7" stroke-width="1.5" stroke-dasharray="8 10"/>
      <g class="parcels" fill="none" stroke="rgba(23,63,52,.42)" stroke-width="1.4">
        ${PARCELS.map((p) => `<polygon points="${pts(p)}" pathLength="1"/>`).join("")}
      </g>
      <g class="footprints">${FOOTPRINTS.map(([x, y, w, hh]) => `<rect x="${x}" y="${y}" width="${w}" height="${hh}" rx="2" fill="#e9e1d4" stroke="rgba(23,63,52,.22)"/>`).join("")}</g>
      <polygon class="ours" points="${pts(OURS)}" fill="rgba(216,194,162,.42)" stroke="#173f34" stroke-width="2.4" pathLength="1"/>
      <rect class="bshadow" x="${BX + 16}" y="${BY + 20}" width="${BW}" height="${BD}" fill="rgba(14,44,37,.28)" filter="url(#shadow-blur)"/>
      <rect class="bfoot" x="${BX}" y="${BY}" width="${BW}" height="${BD}" rx="2" fill="#173f34"/>
    </g>
    <rect width="460" height="460" rx="18" fill="none" stroke="#d9d1c4" stroke-width="1.5"/>`;

  const SHEET = '<rect class="sheet" x="1" y="1" width="458" height="458" rx="18" fill="rgba(255,254,251,.22)" stroke="rgba(23,63,52,.3)" stroke-width="1.4" stroke-dasharray="5 6"/>';
  $("#map-planning").innerHTML = SHEET + `
    <g stroke="rgba(23,63,52,.55)" stroke-width="1.6" stroke-dasharray="6 5">
      <path class="zone" d="M146 3H457V300H146Z" fill="rgba(143,168,128,.32)"/>
      <path class="zone" d="M3 3H110V300H3Z" fill="rgba(227,185,165,.42)"/>
      <path class="zone" d="M3 336H110V457H3Z" fill="rgba(216,194,162,.5)"/>
      <path class="zone" d="M146 336H287L283 457H146Z" fill="rgba(143,168,128,.22)"/>
      <path class="zone" d="M293 336H457V457H283Z" fill="rgba(111,128,96,.34)"/>
    </g>`;

  const PERMITS = [[396, 56], [58, 158], [214, 396]];
  $("#map-permits").innerHTML = SHEET + PERMITS.map(([x, y]) => `
    <g class="permit" transform="translate(${x} ${y})">
      <circle class="permit__pulse" r="12" fill="none" stroke="#b95f3f" stroke-width="2.5"/>
      <g class="permit__dot"><circle r="22" fill="rgba(185,95,63,.16)"/><circle r="12" fill="#b95f3f"/><rect x="-3.5" y="-4.5" width="7" height="9" rx="1" fill="#fff"/></g>
    </g>`).join("");

  $("#map-around").innerHTML = SHEET + `
    <defs><clipPath id="around-clip"><rect width="460" height="460" rx="18"/></clipPath></defs>
    <g clip-path="url(#around-clip)">
    <circle class="radius" cx="${BX + BW / 2}" cy="${BY + BD / 2}" r="176" fill="rgba(185,95,63,.045)" stroke="#b95f3f" stroke-width="2" stroke-dasharray="3 8" stroke-linecap="round"/>
    <g class="park">
      <circle cx="330" cy="380" r="9" fill="#6f8060"/><circle cx="360" cy="420" r="11" fill="#6f8060"/><circle cx="400" cy="372" r="8" fill="#6f8060"/><circle cx="430" cy="420" r="10" fill="#6f8060"/><circle cx="318" cy="430" r="7" fill="#6f8060"/>
    </g>
    <path class="metro" d="M-10 372C90 364 160 318 250 318S400 296 470 250" fill="none" stroke="#173f34" stroke-width="7" stroke-linecap="round" pathLength="1"/>
    <g class="station" transform="translate(250 318)"><circle r="15" fill="#fff" stroke="#173f34" stroke-width="5"/><text y="5.5" text-anchor="middle" font-family="Manrope" font-weight="800" font-size="15" fill="#173f34">M</text></g>
    </g>
    <g class="school" transform="translate(56 390)"><rect x="-17" y="-17" width="34" height="34" rx="8" fill="#fff" stroke="#173f34" stroke-width="2.5"/><path d="M-8 -3 0 -8l8 5-8 5-8-5Zm3 3v5c3 3 7 3 10 0V0" fill="none" stroke="#173f34" stroke-width="2" stroke-linejoin="round"/></g>
    <g class="school" transform="translate(58 52)"><rect x="-17" y="-17" width="34" height="34" rx="8" fill="#fff" stroke="#173f34" stroke-width="2.5"/><path d="M-8 -3 0 -8l8 5-8 5-8-5Zm3 3v5c3 3 7 3 10 0V0" fill="none" stroke="#173f34" stroke-width="2" stroke-linejoin="round"/></g>`;

  // The 3D building: one CSS box per floor so floors can assemble like the
  // wordmark cells. Faces are +y (long, right on screen) and -x (left).
  const RIGHT_COLS = 6, LEFT_COLS = 3;
  const windows = []; // {el, face, floor, col}
  for (let f = 0; f < FLOORS; f++) {
    const floor = h("div", { class: "floor" });
    const left = h("div", { class: "face face--left" });
    Object.assign(left.style, { left: `${BX}px`, top: `${BY}px`, width: `${FH}px`, height: `${BD}px`, transform: "rotateY(-90deg)" });
    const right = h("div", { class: "face face--right" });
    Object.assign(right.style, { left: `${BX}px`, top: `${BY + BD}px`, width: `${BW}px`, height: `${FH}px`, transform: "rotateX(90deg)" });
    for (let c = 0; c < LEFT_COLS; c++) {
      const w = h("i", { class: "win" });
      Object.assign(w.style, { left: "7px", top: `${c * (BD / LEFT_COLS) + 8}px`, width: "13px", height: `${BD / LEFT_COLS - 16}px` });
      left.appendChild(w);
      windows.push({ el: w, face: "left", floor: f, col: c });
    }
    for (let c = 0; c < RIGHT_COLS; c++) {
      const w = h("i", { class: "win" });
      const pitch = BW / RIGHT_COLS;
      Object.assign(w.style, { left: `${c * pitch + 4.5}px`, top: "7px", width: `${pitch - 9}px`, height: "13px" });
      right.appendChild(w);
      windows.push({ el: w, face: "right", floor: f, col: c });
    }
    floor.append(left, right);
    if (f === FLOORS - 1) {
      const roof = h("div", { class: "roof" });
      Object.assign(roof.style, { left: `${BX}px`, top: `${BY}px`, width: `${BW}px`, height: `${BD}px`, transform: `translateZ(${FH}px)` });
      floor.appendChild(roof);
    }
    $("#building").appendChild(floor);
  }
  const TARGET = windows.find((w) => w.face === "right" && w.floor === 3 && w.col === 4);
  TARGET.el.appendChild(h("b", { class: "hot" }));

  // ------------------------------------------------------ camera + project
  const cam = { cx: 0, cy: 0, s: 1, rx: 55, rz: -45, gap: 0, k: 1 };
  const deg = Math.PI / 180;
  function project(x, y, z) {
    const px = x - L / 2, py = y - L / 2;
    const cz = Math.cos(cam.rz * deg), sz = Math.sin(cam.rz * deg);
    const x1 = px * cz - py * sz, y1 = px * sz + py * cz;
    const cx = Math.cos(cam.rx * deg), sx = Math.sin(cam.rx * deg);
    const y2 = y1 * cx - z * sx;
    return [cam.cx + cam.s * x1, cam.cy + cam.s * y2];
  }

  // =================================================== timeline (seconds)
  async function build() {
    await document.fonts.ready;
    await Promise.all([
      document.fonts.load('600 80px "Literata"', "Хареса апартамент"),
      document.fonts.load('italic 500 80px "Literata"', "дом home"),
      document.fonts.load('800 20px "Manrope"', "Провери имот"),
      document.fonts.load('600 20px "Manrope"', "Провери имот"),
      document.fonts.load('700 20px "Manrope"', "Провери имот"),
      document.fonts.load('500 18px "JetBrains Mono"', "68134")
    ]);

    // Map slot for the report (measured in stage coordinates)
    const slot = $(".report__map-slot");
    const report = $("#report");
    let sx = slot.offsetLeft, sy = slot.offsetTop, node = slot.offsetParent;
    while (node && node !== report) { sx += node.offsetLeft; sy += node.offsetTop; node = node.offsetParent; }
    const MAP = { cx: report.offsetLeft + sx + slot.offsetWidth / 2, cy: report.offsetTop + sy + slot.offsetHeight / 2, s: slot.offsetWidth / L };

    // --- background life
    A(".topo", { x: [[0, 0], [DURATION, -90, "linear"]], y: [[0, 0], [DURATION, 30, "linear"]] });

    // --- chrome
    A("#brand", { o: [[0.1, 0], [0.8, 1, "soft"], [23.5, 1], [23.9, 0, "in"]] });
    A("#domain", { o: [[0.1, 0], [0.8, 1, "soft"], [23.5, 1], [23.9, 0, "in"]] });
    A("#disclaimer", { o: [[9.4, 0], [10, 1, "soft"], [23.4, 1], [23.8, 0, "in"]] });
    A("#progress", { o: [[4.4, 0], [5.0, 1, "soft"], [23.4, 1], [23.8, 0, "in"]], y: [[4.4, 24], [5.1, 0], [23.4, 0], [23.9, 20, "in"]] });
    const STEP_T = [[4.4, 8.8], [8.8, 13.0], [13.0, 17.0], [17.0, 23.4]];
    $$(".step").forEach((step, i) => {
      A($(".step__fill", step), { "--p": [[STEP_T[i][0], 0], [STEP_T[i][1], 1, "linear"]] });
    });
    hooks.push((t) => $$(".step").forEach((step, i) => step.classList.toggle("is-on", t >= STEP_T[i][0])));

    const cap3 = $("#cap3");
    $("#chips").style.top = `${cap3.offsetTop + cap3.offsetHeight + 44}px`;

    // --- scene 1: the questions ------------------------------------------
    const hero = $(".cap--hero");
    wordsIn($("h1", hero), 0.15, { stagger: 0.13, dur: 1.0 });
    wordsIn($("p", hero), 2.3, { stagger: 0.045, dur: 0.8 });
    fadeOut(hero, 3.95, { dy: -50, dur: 0.5 });

    A("#listing", {
      o: [[0.45, 0], [0.95, 1, "soft"], [3.9, 1], [4.4, 0, "in"]],
      y: [[0.45, 140], [1.4, 0, "out"], [3.9, 0], [4.4, 60, "in"]],
      r: [[0.45, 7], [1.5, -2.2, "out"], [3.9, -1.2, "linear"], [4.4, -4, "in"]],
      s: [[0.45, 0.9], [1.4, 1, "out"], [3.9, 1.02, "linear"], [4.4, 0.86, "in"]],
      blur: [[3.9, 0], [4.4, 10, "in"]]
    });
    A(".listing__heart", { s: [[1.45, 1], [1.58, 1.3, "out"], [1.9, 1, "back"]] });
    hooks.push((t) => $(".listing__heart").style.setProperty("--hf", t >= 1.5 ? "var(--clay)" : "transparent"));
    $$(".burst").forEach((p, i) => {
      const a = (i / 8) * Math.PI * 2 + 0.3;
      A(p, {
        x: [[1.5, 0], [2.05, Math.cos(a) * 42, "out"]],
        y: [[1.5, 0], [2.05, Math.sin(a) * 42, "out"]],
        r: [[1.5, 0], [2.05, 120, "out"]],
        o: [[1.49, 0], [1.5, 1], [1.8, 1], [2.1, 0, "in"]],
        s: [[1.5, 1.2], [2.05, 0.4]]
      });
    });

    const CENTER = [1380, 470];
    const FIELD = [1330, 540];
    $$(".qwrap").forEach((wrap, i) => {
      const t0 = 1.8 + i * 0.27;
      const [qx, qy] = QPOS[i];
      const w = wrap.offsetWidth, hh = wrap.offsetHeight;
      const dx = (CENTER[0] - (qx + w / 2)) * 0.35, dy = (CENTER[1] - (qy + hh / 2)) * 0.35;
      const t1 = 3.9 + i * 0.05;
      const ex = FIELD[0] - (qx + w / 2), ey = FIELD[1] - (qy + hh / 2);
      A(wrap, {
        o: [[t0, 0], [t0 + 0.25, 1, "soft"], [t1, 1], [t1 + 0.45, 0, "in"]],
        x: [[t0, dx], [t0 + 0.8, 0, "out"], [t1, 0], [t1 + 0.5, ex, "in"]],
        y: [[t0, dy], [t0 + 0.8, 0, "out"], [t1, 0], [t1 + 0.5, ey, "in"]],
        s: [[t0, 0.55], [t0 + 0.7, 1, "back"], [t1, 1], [t1 + 0.5, 0.25, "in"]]
      });
      const q = $(".q", wrap);
      hooks.push((t) => { q.style.transform = `translateY(${(Math.sin(t * 1.7 + i * 1.9) * 6).toFixed(2)}px)`; });
    });

    // --- scene 2: address ------------------------------------------------
    capIn("#cap2", 4.45);
    capOut("#cap2", 8.55);
    A("#panel", {
      o: [[4.3, 0], [4.8, 1, "soft"], [8.5, 1], [9.0, 0, "in"]],
      y: [[4.3, 70], [5.2, 0, "out"], [8.5, 0], [9.0, -20, "in"]],
      s: [[4.3, 0.95], [5.2, 1, "out"], [8.5, 1], [9.0, 0.9, "in"]],
      blur: [[8.5, 0], [9.0, 8, "in"]]
    });
    A(".panel__field", { "--fr": [[4.95, 0], [5.3, 6, "out"]] });
    hooks.push((t) => $(".panel__field").style.setProperty("--fb", t >= 4.95 ? "var(--clay)" : "var(--line)"));
    const typed = $("#typed");
    const addr = COPY.address;
    const TYPE_A = 5.15, TYPE_B = 6.55;
    hooks.push((t) => {
      const n = Math.round(clamp01((t - TYPE_A) / (TYPE_B - TYPE_A)) * addr.length);
      typed.textContent = addr.slice(0, n);
      const typing = t >= TYPE_A && t <= TYPE_B + 0.1;
      $("#caret").style.opacity = t < 4.95 || t > 7.7 ? 0 : typing ? 1 : (Math.floor((t - TYPE_B) * 2.6) % 2 ? 0 : 1);
    });
    A("#suggestions", {
      o: [[6.7, 0], [6.9, 1, "soft"], [7.75, 1], [8.0, 0, "in"]],
      sy: [[6.7, 0.92], [7.05, 1, "out"], [7.75, 1], [8.0, 0.96, "in"]],
      y: [[6.7, -8], [7.05, 0, "out"]]
    });
    $$(".sugg").forEach((s, i) => fadeUp(s, 6.78 + i * 0.07, { dy: 12, dur: 0.5 }));
    A($(".sugg__hl"), { o: [[7.3, 0], [7.42, 1, "soft"]] });
    $$(".sugg__hl").slice(1).forEach((el) => A(el, { o: 0 }));
    A("#selected-chip", { o: [[7.95, 0], [8.15, 1, "soft"]], s: [[7.95, 0.7], [8.35, 1, "back"]] });
    A("#find-button", { s: [[8.2, 1], [8.3, 0.95, "out"], [8.5, 1, "back"]] });
    A("#cursor", {
      o: [[6.75, 0], [6.95, 1, "soft"], [8.45, 1], [8.7, 0, "in"]],
      x: [[6.75, 1560], [7.45, 1080, "cam"], [7.85, 1080], [8.2, 1150, "cam"]],
      y: [[6.75, 900], [7.45, 650, "cam"], [7.85, 650], [8.2, 660, "cam"]],
      s: [[7.5, 1], [7.56, 0.82, "out"], [7.68, 1, "out"], [8.22, 1], [8.28, 0.82, "out"], [8.4, 1, "out"]]
    });

    // --- scene 3-5: the property stack -----------------------------------
    A(cam, {
      cx: [[8.7, 1215], [13.0, 1200, "linear"], [13.9, 1030, "cam"], [16.9, 1030], [18.0, MAP.cx, "cam"]],
      cy: [[8.7, 690], [13.0, 650, "linear"], [13.9, 660, "cam"], [16.9, 650, "linear"], [18.0, MAP.cy, "cam"]],
      s: [[8.7, 1.18], [10.0, 1.36, "out"], [13.0, 1.45, "linear"], [13.9, 0.88, "cam"], [16.9, 0.91, "linear"], [18.0, MAP.s, "cam"]],
      rx: [[16.9, 55], [18.0, 0, "cam"]],
      rz: [[16.9, -45], [18.0, 0, "cam"]],
      gap: [[13.6, 0], [14.7, 112, "out"], [16.1, 124, "linear"], [16.8, 0, "inOut"]],
      k: [[13.05, 1], [13.75, 0.002, "in"]]
    }, (obj, v) => Object.assign(obj, v));

    const stack = $("#stack");
    const layers = $$(".layer");
    const building = $("#building");
    const drops = [0, 0, 0, 0];
    const LAYER_T = [8.75, 13.95, 14.6, 15.25];
    [1, 2, 3].forEach((i) => {
      A({ id: `drop${i}` }, { d: [[LAYER_T[i], 300], [LAYER_T[i] + 0.8, 0, "out"]] }, (_, v) => { drops[i] = v.d; });
      A(layers[i], { o: [[LAYER_T[i], 0], [LAYER_T[i] + 0.4, 1, "soft"]] });
    });
    hooks.unshift(() => {
      stack.style.transform = `translate(${(cam.cx - L / 2).toFixed(2)}px, ${(cam.cy - L / 2).toFixed(2)}px) scale(${cam.s.toFixed(4)}) rotateX(${cam.rx.toFixed(3)}deg) rotateZ(${cam.rz.toFixed(3)}deg)`;
      layers.forEach((layer, i) => { layer.style.transform = `translateZ(${(i * cam.gap + drops[i]).toFixed(2)}px)`; });
      building.style.transform = `scale3d(1, 1, ${cam.k.toFixed(4)})`;
      building.style.visibility = cam.k < 0.01 ? "hidden" : "visible";
    });
    A("#stack-wrap", { o: [[24.4, 1], [24.5, 0]] });

    // base map
    A("#map-base", { o: [[8.7, 0], [9.2, 1, "soft"]] });
    $$("#map-base .parcels polygon").forEach((p, i) => {
      A(p, { "--d": [[8.8 + i * 0.03, 1], [9.9 + i * 0.03, 0, "out"]] }, (el, v) => { el.style.strokeDasharray = "1 1"; el.style.strokeDashoffset = v["--d"]; });
    });
    A("#map-base .ours", { "--d": [[9.0, 1], [10.0, 0, "out"]] }, (el, v) => { el.style.strokeDasharray = "1 1"; el.style.strokeDashoffset = v["--d"]; });
    $$("#map-base .footprints rect").forEach((r, i) => A(r, { o: [[9.0 + i * 0.04, 0], [9.4 + i * 0.04, 1, "soft"]] }));
    A("#map-base .bshadow", { o: [[9.2, 0], [10.2, 1, "soft"], [13.1, 1], [13.7, 0]] });

    // floors assemble bottom-up, like the wordmark cells
    $$(".floor").forEach((floor, f) => {
      const t0 = 9.0 + f * 0.13;
      A({ id: `floor${f}` }, { z: [[t0, 70], [t0 + 0.65, 0, "out"]], o: [[t0, 0], [t0 + 0.3, 1, "soft"]] }, (_, v) => {
        floor.style.transform = `translateZ(${(f * FH + v.z).toFixed(2)}px)`;
        $$(".face, .roof", floor).forEach((face) => { face.style.opacity = v.o.toFixed(3); });
      });
    });

    // narrowing down: entrance -> floor -> apartment
    const DIM = 0.26;
    const T_ENT = 10.35, T_FLOOR = 10.95, T_APT = 11.55;
    windows.forEach((w) => {
      let off = null;
      if (w.face === "left" || w.col < 3) off = T_ENT;
      else if (w.floor !== 3) off = T_FLOOR;
      else if (w !== TARGET) off = T_APT;
      if (off) A(w.el, { o: [[off, 1], [off + 0.35, DIM, "soft"]] });
    });
    A($(".hot", TARGET.el), { o: [[T_APT, 0], [T_APT + 0.2, 1, "soft"]] });

    capIn("#cap3", 8.95);
    capOut("#cap3", 12.75);
    $$(".chip").forEach((chip, i) => {
      const t0 = [T_ENT - 0.1, T_FLOOR - 0.1, T_APT - 0.1, T_APT + 0.35][i];
      A(chip, {
        o: [[t0, 0], [t0 + 0.25, 1, "soft"], [12.7 + i * 0.04, 1], [13.1 + i * 0.04, 0, "in"]],
        s: [[t0, 0.6], [t0 + 0.55, 1, "back"]],
        y: [[12.7 + i * 0.04, 0], [13.1 + i * 0.04, -24, "in"]]
      });
    });

    const ring = $("#focus-ring");
    const callout = $("#callout");
    const target3d = [BX + 4 * (BW / RIGHT_COLS) + BW / RIGHT_COLS / 2, BY + BD, 3 * FH + 13.5];
    A(ring, {
      o: [[T_APT, 0], [T_APT + 0.05, 1], [T_APT + 0.9, 0, "soft"], [T_APT + 0.95, 0], [T_APT + 1.0, 1], [T_APT + 1.85, 0, "soft"]],
      s: [[T_APT, 0.3], [T_APT + 0.9, 1.6, "out"], [T_APT + 0.95, 0.3], [T_APT + 1.85, 1.6, "out"]]
    }, (el, v) => {
      const [px, py] = project(...target3d);
      el.style.transform = `translate(${px.toFixed(2)}px, ${py.toFixed(2)}px) scale(${v.s.toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
    });
    const calloutH = callout.offsetHeight;
    A(callout, {
      o: [[T_APT + 0.3, 0], [T_APT + 0.6, 1, "soft"], [12.8, 1], [13.15, 0, "in"]],
      x: [[T_APT + 0.3, -16], [T_APT + 0.9, 0, "out"]]
    }, (el, v) => {
      const [px, py] = project(...target3d);
      el.style.transform = `translate(${(px + 14 + v.x).toFixed(2)}px, ${(py - calloutH / 2).toFixed(2)}px)`;
      el.style.opacity = v.o.toFixed(3);
      el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
    });
    A("#callout > i", { sx: [[T_APT + 0.3, 0], [T_APT + 0.8, 1, "out"]] });

    // --- scene 4: data layers ---------------------------------------------
    capIn("#cap4", 13.35);
    capOut("#cap4", 16.65);
    $$("#map-planning .zone").forEach((z, i) => A(z, { o: [[14.1 + i * 0.08, 0], [14.5 + i * 0.08, 1, "soft"]] }));
    $$("#map-permits .permit").forEach((p, i) => {
      const t0 = 14.75 + i * 0.12;
      A($(".permit__dot", p), { s: [[t0, 0], [t0 + 0.5, 1, "back"]] }, (el, v) => { el.setAttribute("transform", `scale(${v.s.toFixed(3)})`); });
      A($(".permit__pulse", p), { r: [[t0 + 0.3, 12], [t0 + 1.3, 34, "out"], [t0 + 1.31, 12], [t0 + 2.3, 34, "out"]], o: [[t0 + 0.3, 0.8], [t0 + 1.3, 0, "soft"], [t0 + 1.31, 0.8], [t0 + 2.3, 0, "soft"]] },
        (el, v) => { el.setAttribute("r", v.r.toFixed(2)); el.style.opacity = v.o.toFixed(3); });
    });
    A("#map-around .metro", { d: [[15.4, 1], [16.3, 0, "out"]] }, (el, v) => { el.style.strokeDasharray = "1 1"; el.style.strokeDashoffset = v.d.toFixed(4); });
    A("#map-around .station", { s: [[15.85, 0], [16.3, 1, "back"]] }, (el, v) => el.setAttribute("transform", `translate(250 318) scale(${v.s.toFixed(3)})`));
    $$("#map-around .school").forEach((s, i) => {
      const [tx, ty] = s.getAttribute("transform").match(/[\d.]+/g);
      A(s, { s: [[15.6 + i * 0.1, 0], [16.05 + i * 0.1, 1, "back"]] }, (el, v) => el.setAttribute("transform", `translate(${tx} ${ty}) scale(${v.s.toFixed(3)})`));
    });
    $$("#map-around .park circle").forEach((c, i) => A(c, { o: [[15.5 + i * 0.05, 0], [15.8 + i * 0.05, 1, "soft"]] }));
    A("#map-around .radius", { o: [[15.4, 0], [15.9, 1, "soft"]] });

    $$(".sheet").forEach((sheet) => A(sheet, { o: [[16.3, 1], [16.8, 0, "inOut"]] }));

    const labels = $$(".layer-label");
    const LABEL_T = [13.75, 14.15, 14.8, 15.45];
    labels.forEach((label, i) => {
      const t0 = LABEL_T[i];
      const lh = label.offsetHeight;
      A(label, {
        o: [[t0, 0], [t0 + 0.3, 1, "soft"], [16.2 + i * 0.03, 1], [16.5 + i * 0.03, 0, "in"]],
        x: [[t0, 24], [t0 + 0.7, 0, "out"]]
      }, (el, v) => {
        const [px, py] = project(L, L, i * cam.gap + drops[i]);
        el.style.transform = `translate(${(px + 10 + v.x).toFixed(2)}px, ${(py - lh / 2).toFixed(2)}px)`;
        el.style.opacity = v.o.toFixed(3);
        el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
      });
      const line = $("i", label);
      line.style.width = "44px";
      A(line, { sx: [[t0, 0], [t0 + 0.5, 1, "out"]] });
    });

    // --- scene 5: report ----------------------------------------------------
    capIn("#cap5", 17.35);
    A("#cap5", { o: [[23.35, 1], [23.7, 0, "in"]] });
    A("#report", {
      o: [[17.25, 0], [17.8, 1, "soft"], [24.4, 1], [24.5, 0]],
      y: [[17.25, 50], [18.1, 0, "out"]],
      s: [[17.25, 0.96], [18.1, 1, "out"]]
    });
    fadeUp(".report__header > div", 17.7, { dy: 16 });
    A(".report__badge", { o: [[18.15, 0], [18.35, 1, "soft"]], s: [[18.15, 0.7], [18.6, 1, "back"]] });
    $$(".finding").forEach((row, i) => {
      const t0 = 18.25 + i * 0.3 + (i === 4 ? 0.15 : 0);
      A(row, { o: [[t0, 0], [t0 + 0.35, 1, "soft"]], x: [[t0, -28], [t0 + 0.7, 0, "out"]] });
      A($("em", row), { o: [[t0 + 0.2, 0], [t0 + 0.4, 1, "soft"]], s: [[t0 + 0.2, 0.7], [t0 + 0.65, 1, "back"]] });
      const check = $("strong svg", row);
      if (check) A(check, { s: [[t0 + 0.3, 0], [t0 + 0.7, 1, "back"]] });
    });
    const warn = $(".finding--warn");
    A(warn, { s: [[21.3, 1], [21.55, 1.025, "out"], [21.95, 1, "inOut"]] });

    A("#map-pin", { o: [[18.9, 0], [19.05, 1, "soft"], [24.4, 1], [24.5, 0]], y: [[18.9, -60], [19.4, 0, "back"]], s: [[18.9, 1.3], [19.4, 1, "out"]] }, (el, v) => {
      const [px, py] = project(BX + BW / 2, BY + BD / 2, 0);
      el.style.transform = `translate(${px.toFixed(2)}px, ${(py + v.y).toFixed(2)}px) scale(${v.s.toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
      el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
    });

    fadeUp("#asks", 19.75, { dy: 24 });
    $$("#asks li").forEach((li, i) => {
      const t0 = 20.1 + i * 0.35;
      A(li, { o: [[t0, 0], [t0 + 0.3, 1, "soft"]], x: [[t0, -14], [t0 + 0.6, 0, "out"]] });
      A($("i", li), { s: [[t0 + 0.1, 0], [t0 + 0.55, 1, "back"]] });
    });
    A("#s5", { o: [[24.4, 1], [24.5, 0]] });

    // --- scene 6: end card --------------------------------------------------
    const WIPE_ORIGIN = [MAP.cx, MAP.cy];
    $$("#wipe i").forEach((cell, i) => {
      const col = i % 16, row = Math.floor(i / 16);
      const d = Math.hypot(col * 120 + 60 - WIPE_ORIGIN[0], row * 120 + 60 - WIPE_ORIGIN[1]);
      const t0 = 23.55 + (d / 1700) * 0.55;
      A(cell, { s: [[t0, 0], [t0 + 0.42, 1, "inOut"]], r: [[t0, 45], [t0 + 0.42, 0, "inOut"]] });
    });
    A("#end-bg", { o: [[24.3, 0], [24.4, 1]] });
    A("#end-bg svg", { x: [[24.3, 0], [DURATION, 40, "linear"]] });
    const cells = $$("#end-logo .cell");
    cells.forEach((cell, i) => {
      const t0 = 24.55 + i * 0.016;
      A(cell, { o: [[t0, 0], [t0 + 0.25, 1, "soft"]], y: [[t0, 6], [t0 + 0.5, 0, "snap"]], s: [[t0, 0.55], [t0 + 0.5, 1, "snap"]] });
    });
    A("#end-logo .accent-hot", { o: [[25.85, 0], [26.15, 1, "soft"]], s: [[25.85, 0.6], [26.35, 1, "back"]] });
    wordsIn($("#s6 h2"), 25.25, { stagger: 0.06, dur: 1.0 });
    fadeUp(".end__cta", 26.15, { dy: 24, s: 0.96 });
    $$(".end__trust span").forEach((s, i) => fadeUp(s, 26.4 + i * 0.12, { dy: 16 }));
  }

  function capIn(id, t0) {
    const cap = $(id);
    A($(".cap__eyebrow b", cap), { o: [[t0, 0], [t0 + 0.4, 1, "soft"]], y: [[t0, 14], [t0 + 0.6, 0]] });
    A($(".cap__eyebrow i", cap), { sx: [[t0 + 0.05, 0], [t0 + 0.65, 1, "out"]] });
    A($(".cap__eyebrow span", cap), { o: [[t0 + 0.15, 0], [t0 + 0.55, 1, "soft"]], x: [[t0 + 0.15, -10], [t0 + 0.75, 0]] });
    wordsIn($("h2", cap), t0 + 0.1, { stagger: 0.08, dur: 0.95 });
    wordsIn($("p", cap), t0 + 0.55, { stagger: 0.03, dur: 0.8 });
  }
  function capOut(id, t0) {
    A(id, { o: [[t0, 1], [t0 + 0.45, 0, "in"]], y: [[t0, 0], [t0 + 0.5, -40, "in"]] });
  }

  // --------------------------------------------------------------- runtime
  const stage = $("#stage");
  const render = params.has("render");
  if (render) document.body.classList.add("render");
  function fit() {
    if (render) return;
    const s = Math.min(innerWidth / 1920, innerHeight / 1080);
    stage.style.transform = `scale(${s})`;
  }
  addEventListener("resize", fit);
  fit();

  window.__duration = DURATION;
  window.__seek = seek;
  window.__ready = build().then(() => {
    seek(0);
    if (render) return;
    let playing = !params.has("t");
    let t = params.has("t") ? parseFloat(params.get("t")) : 0;
    let last = performance.now();
    seek(t);
    addEventListener("keydown", (e) => {
      if (e.code === "Space") playing = !playing;
      if (e.code === "ArrowRight") t = Math.min(DURATION, t + (e.shiftKey ? 2 : 0.25));
      if (e.code === "ArrowLeft") t = Math.max(0, t - (e.shiftKey ? 2 : 0.25));
      seek(t);
    });
    const tick = (now) => {
      if (playing) { t += (now - last) / 1000; if (t > DURATION) t = 0; seek(t); }
      last = now;
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  });
})();
