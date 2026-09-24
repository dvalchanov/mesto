/* Mesto explainer, "from dark to clear" cut.
 *
 * Problem: a neighbourhood in shadow, full of unanswered questions.
 * Solution: the buyer checks the address in Mesto, the property lights up and
 * the light spreads through the neighbourhood, turning every question into a
 * sourced answer, then into a clear report.
 *
 * Same deterministic engine as composition.js. Open story.html to preview
 * (space: play/pause, ←/→: scrub, ?lang=en, ?t=12.5 to freeze).
 */
(() => {
  const params = new URLSearchParams(location.search);
  const LANG = params.get("lang") === "en" ? "en" : "bg";
  const DURATION = 29;
  document.documentElement.lang = LANG;

  // ---------------------------------------------------------------- copy
  const COPY_BG = {
    cap1_title: "Купуваш имот,\nно не знаеш\n*нищо* за него?",
    cap1_sub: "Сградата, кварталът, документите: всичко е на тъмно.",
    cap2_eyebrow: "Решението",
    cap2_title: "Провери го\nв Mesto.",
    cap2_sub: "Въвеждаш адреса. Без регистрация.",
    cap3_eyebrow: "Яснота",
    cap3_title: "Mesto осветява\nимота и квартала.",
    cap3_sub: "Данни от 12+ публични източника, всяко с ясен произход.",
    cap5_eyebrow: "Отчет",
    cap5_title: "Решаваш\nспокойно.",
    cap5_sub: "Факти с източник и какво още да провериш.",
    tags: [
      { q: "Какво ще се строи тук?", a: "Разрешение за строеж", src: "НАГ" },
      { q: "Какво показва кадастърът?", a: "Ап. 12 · 78 m²", src: "АГКК", hot: true },
      { q: "Какво предвижда планът?", a: "Жилищна зона", src: "Софияплан" },
      { q: "Колко е до метрото?", a: "Метро · 450 m", src: "Софияплан" },
      { q: "Има ли училище наблизо?", a: "3 училища · парк", src: "Софияплан" }
    ],
    disclaimer: "Примерни данни",
    panel_eyebrow: "Започни оттук",
    panel_title: "Провери конкретен имот",
    tab_addr: "По адрес",
    tab_id: "По идентификатор",
    addr_label: "Адрес на сградата",
    address: "ул. Проф. Крикор Азарян 25",
    suggestions: [["ул. Проф. Крикор Азарян 25", "Лозенец, София · 1 сграда"], ["ул. Проф. Крикор Азарян 25А", "Лозенец, София"], ["ул. Проф. Крикор Азарян 27", "Лозенец, София"]],
    button: "Провери имота",
    selected: "Избрана е точна сграда",
    report_id: "68134.4356.27.1.12",
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
    end_trust: ["Безплатен преглед", "Без регистрация"]
  };
  const COPY_EN = {
    cap1_title: "Buying a place\nyou know\n*nothing* about?",
    cap1_sub: "The building, the neighbourhood, the paperwork: all in the dark.",
    cap2_eyebrow: "The answer",
    cap2_title: "Check it\nin Mesto.",
    cap2_sub: "Enter the address. No registration.",
    cap3_eyebrow: "Clarity",
    cap3_title: "Mesto lights up the home and the neighbourhood.",
    cap3_sub: "Data from 12+ public sources, each with a clear origin.",
    cap5_eyebrow: "Report",
    cap5_title: "Decide\nwith clarity.",
    cap5_sub: "Sourced facts, plus what's left to check.",
    tags: [
      { q: "What will be built here?", a: "Building permit", src: "NAG" },
      { q: "What does the cadastre say?", a: "Apt 12 · 78 m²", src: "AGCC", hot: true },
      { q: "What does the plan allow?", a: "Residential zone", src: "SofiaPlan" },
      { q: "How far is the metro?", a: "Metro · 450 m", src: "SofiaPlan" },
      { q: "Any schools nearby?", a: "3 schools · park", src: "SofiaPlan" }
    ],
    disclaimer: "Illustrative data",
    panel_eyebrow: "Start here",
    panel_title: "Check a specific property",
    tab_addr: "By address",
    tab_id: "By identifier",
    addr_label: "Building address",
    address: "ул. Проф. Крикор Азарян 25",
    suggestions: [["ул. Проф. Крикор Азарян 25", "Lozenets, Sofia · 1 building"], ["ул. Проф. Крикор Азарян 25А", "Lozenets, Sofia"], ["ул. Проф. Крикор Азарян 27", "Lozenets, Sofia"]],
    button: "Check the property",
    selected: "Exact building selected",
    report_id: "68134.4356.27.1.12",
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
    end_trust: ["Free preview", "No registration"]
  };
  const COPY = LANG === "en" ? COPY_EN : COPY_BG;

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

  $("#brand-night").innerHTML = wordmark({ primary: "#f4f0e8", accent: "#cf7a57" });
  $("#brand").innerHTML = wordmark({ primary: "#173f34", accent: "#b95f3f" });
  $("#end-logo").innerHTML = wordmark({ primary: "#f4f0e8", accent: "#cf7a57", animated: true });

  const topoPaths = $(".topo").innerHTML;
  $("#night svg").innerHTML = topoPaths;
  $("#end-bg").innerHTML = `<svg viewBox="0 0 760 640">${topoPaths}</svg>`;

  // Captions
  function buildCap(id, eyebrow, titleKey, subKey) {
    const cap = $(id);
    cap.innerHTML = `${eyebrow ? `<div class="cap__eyebrow cap__eyebrow--plain"><i></i><span>${eyebrow}</span></div>` : ""}<h2></h2><p></p>`;
    setWords($("h2", cap), COPY[titleKey]);
    setWords($("p", cap), COPY[subKey]);
    return cap;
  }
  buildCap("#cap1", null, "cap1_title", "cap1_sub");
  buildCap("#cap2", COPY.cap2_eyebrow, "cap2_title", "cap2_sub");
  buildCap("#cap3", COPY.cap3_eyebrow, "cap3_title", "cap3_sub");
  buildCap("#cap5", COPY.cap5_eyebrow, "cap5_title", "cap5_sub");

  COPY.suggestions.forEach(([title, sub]) => {
    $("#suggestions").appendChild(h("div", { class: "sugg" }, `<b class="sugg__hl"></b><span class="sugg__icon"><svg viewBox="0 0 24 24"><path d="M5 21V6.5L12 3l7 3.5V21M3 21h18"/></svg></span><div><strong>${title}</strong><span>${sub}</span></div>`));
  });
  COPY.findings.forEach(([icon, title, text, source, kind]) => {
    const warn = kind === "warn";
    $("#findings").appendChild(h("li", { class: `finding${warn ? " finding--warn" : ""}` },
      `<span class="finding__icon"><svg viewBox="0 0 24 24">${ICONS[icon]}</svg></span><div><strong>${title}${warn ? "" : ICON_CHECK}</strong><p>${text}</p></div><em>${source}</em>`));
  });
  COPY.asks.forEach((q) => $("#asks ol").appendChild(h("li", {}, `<i>${ICON_CHECK}</i><span>${q}</span>`)));
  COPY.end_trust.forEach((label) => $(".end__trust").appendChild(h("span", {}, `${ICON_CHECK}${label}`)));
  for (let i = 0; i < 16 * 9; i++) $("#wipe").appendChild(h("i"));

  // ------------------------------------------------------ build: the map
  const L = 460;
  const OURS_C = [260, 215]; // centre of the checked building
  const STATION = [368, 301]; // midpoint of the metro curve's second segment
  const FH = 26;
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
  const BUILDINGS = [
    { x: 195, y: 170, w: 130, d: 90, floors: 6, ours: true },
    { x: 168, y: 28, w: 112, d: 58, floors: 4 },
    { x: 328, y: 24, w: 104, d: 52, floors: 5, wire: true },
    { x: 384, y: 140, w: 56, d: 130, floors: 3 },
    { x: 18, y: 18, w: 72, d: 54, floors: 3 },
    { x: 22, y: 118, w: 66, d: 62, floors: 2 },
    { x: 18, y: 232, w: 78, d: 52, floors: 4 },
    { x: 20, y: 352, w: 70, d: 42, floors: 2 },
    { x: 164, y: 356, w: 92, d: 62, floors: 3 }
  ];

  function mapSVG(p, id) {
    const solid = BUILDINGS.filter((b) => !b.wire && !b.ours);
    return `
      <defs>
        <clipPath id="${id}-clip"><rect width="460" height="460" rx="18"/></clipPath>
        <filter id="${id}-blur" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
      </defs>
      <g clip-path="url(#${id}-clip)">
        <rect width="460" height="460" fill="${p.bg}"/>
        <path d="M0 318H460M128 0V460" stroke="${p.road}" stroke-width="30"/>
        <path d="M0 318H460M128 0V460" stroke="${p.dash}" stroke-width="1.5" stroke-dasharray="8 10"/>
        <g fill="none" stroke="${p.parcel}" stroke-width="1.4">${PARCELS.map((q) => `<polygon points="${pts(q)}"/>`).join("")}</g>
        <polygon points="${pts(OURS)}" fill="${p.oursFill}" stroke="${p.oursStroke}" stroke-width="2.4"/>
        ${p.shadow ? BUILDINGS.filter((b) => !b.wire).map((b) => `<rect x="${b.x + 12}" y="${b.y + 16}" width="${b.w}" height="${b.d}" fill="${p.shadow}" filter="url(#${id}-blur)"/>`).join("") : ""}
        ${solid.map((b) => `<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.d}" rx="2" fill="${p.fp}" stroke="${p.fpStroke}"/>`).join("")}
        <rect x="195" y="170" width="130" height="90" rx="2" fill="${p.foot}"/>
      </g>
      <rect width="460" height="460" rx="18" fill="none" stroke="${p.border}" stroke-width="1.5"/>`;
  }
  $("#map-day").innerHTML = mapSVG({
    bg: "#fbfaf7", road: "#ece5d9", dash: "#fbfaf7", parcel: "rgba(23,63,52,.42)", oursFill: "rgba(216,194,162,.42)", oursStroke: "#173f34",
    fp: "#e9e1d4", fpStroke: "rgba(23,63,52,.22)", foot: "#173f34", border: "#d9d1c4", shadow: "rgba(14,44,37,.2)"
  }, "day");
  $("#map-night").innerHTML = mapSVG({
    bg: "#14241f", road: "#1a2c26", dash: "rgba(244,240,232,.06)", parcel: "rgba(244,240,232,.12)", oursFill: "rgba(244,240,232,.03)", oursStroke: "rgba(244,240,232,.2)",
    fp: "#182a24", fpStroke: "rgba(244,240,232,.06)", foot: "#0f1c18", border: "rgba(244,240,232,.1)"
  }, "night");

  const PERMITS = [[396, 56], [58, 158], [214, 396]];
  const SCHOOL = '<rect x="-17" y="-17" width="34" height="34" rx="8" fill="#fff" stroke="#173f34" stroke-width="2.5"/><path d="M-8 -3 0 -8l8 5-8 5-8-5Zm3 3v5c3 3 7 3 10 0V0" fill="none" stroke="#173f34" stroke-width="2" stroke-linejoin="round"/>';
  $("#map-answers").innerHTML = `
    <defs><clipPath id="answers-clip"><rect width="460" height="460" rx="18"/></clipPath></defs>
    <g clip-path="url(#answers-clip)">
      <g class="zones" stroke="rgba(23,63,52,.45)" stroke-width="1.4" stroke-dasharray="6 5">
        <path d="M146 3H457V300H146Z" fill="rgba(143,168,128,.2)"/>
        <path d="M3 3H110V300H3Z" fill="rgba(227,185,165,.26)"/>
        <path d="M3 336H110V457H3Z" fill="rgba(216,194,162,.34)"/>
        <path d="M293 336H457V457H283Z" fill="rgba(111,128,96,.3)"/>
      </g>
      <rect x="328" y="24" width="104" height="52" rx="2" fill="rgba(185,95,63,.08)" stroke="#b95f3f" stroke-width="2" stroke-dasharray="6 5"/>
      <circle class="radius" cx="${OURS_C[0]}" cy="${OURS_C[1]}" r="176" fill="none" stroke="#b95f3f" stroke-width="2" stroke-dasharray="3 8" stroke-linecap="round"/>
      <g class="park"><circle cx="330" cy="380" r="9" fill="#6f8060"/><circle cx="360" cy="420" r="11" fill="#6f8060"/><circle cx="400" cy="372" r="8" fill="#6f8060"/><circle cx="430" cy="420" r="10" fill="#6f8060"/><circle cx="318" cy="430" r="7" fill="#6f8060"/></g>
      <path class="metro" d="M-10 372C90 364 160 318 250 318S400 296 470 250" fill="none" stroke="#173f34" stroke-width="7" stroke-linecap="round" pathLength="1"/>
      <g class="station" transform="translate(${STATION[0]} ${STATION[1]})"><circle r="15" fill="#fff" stroke="#173f34" stroke-width="5"/><text y="5.5" text-anchor="middle" font-family="Manrope" font-weight="800" font-size="15" fill="#173f34">M</text></g>
      ${PERMITS.map(([x, y]) => `<g class="permit" data-x="${x}" data-y="${y}" transform="translate(${x} ${y})"><circle r="22" fill="rgba(185,95,63,.16)"/><circle r="12" fill="#b95f3f"/><rect x="-3.5" y="-4.5" width="7" height="9" rx="1" fill="#fff"/></g>`).join("")}
      <g class="school" data-x="102" data-y="400" transform="translate(102 400)">${SCHOOL}</g>
      <g class="school" data-x="100" data-y="30" transform="translate(100 30)">${SCHOOL}</g>
    </g>`;

  // --- 3D buildings. Colours are CSS variables mixed between dusk and day.
  const NIGHT = { fl: "#22332e", fr: "#192923", rf: "#2a3d37", rs: "rgba(244,240,232,.05)", wn: "#111e1a", ww: "#e9c07c", wg: "rgba(233,192,124,.55)", wire: "rgba(244,240,232,.22)", wf: "rgba(244,240,232,0)" };
  const DAY = { fl: "#efe8dc", fr: "#dcd1bf", rf: "#fbfaf7", rs: "rgba(23,63,52,.16)", wn: "#b9c6bc", ww: "#b9c6bc", wg: "rgba(233,192,124,0)", wire: "#b95f3f", wf: "rgba(185,95,63,.06)" };
  const DAY_OURS = { ...DAY, fl: "#2c5a4c", fr: "#1b4539", rf: "#3d6d5e", rs: "rgba(244,240,232,.18)", wn: "#f4f0e8", ww: "#f4f0e8" };
  const rgba = (c) => {
    if (c.startsWith("#")) { const n = parseInt(c.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 1]; }
    const m = c.match(/[\d.]+/g).map(Number);
    return [m[0], m[1], m[2], m[3] ?? 1];
  };
  const parsePalette = (p) => Object.fromEntries(Object.entries(p).map(([k, v]) => [k, rgba(v)]));
  const P_NIGHT = parsePalette(NIGHT), P_DAY = parsePalette(DAY), P_DAY_OURS = parsePalette(DAY_OURS);
  const mix = (a, b, t) => { const c = a.map((v, i) => v + (b[i] - v) * t); return `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${c[3].toFixed(3)})`; };

  let seed = 7;
  const rand = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  const warmWindows = [];
  let TARGET = null;
  BUILDINGS.forEach((b) => {
    const box = h("div", { class: `box${b.wire ? " box--wire" : ""}` });
    for (let f = 0; f < b.floors; f++) {
      const floor = h("div", { class: "floor" });
      floor.style.transform = `translateZ(${f * FH}px)`;
      const left = h("div", { class: "face face--left" });
      Object.assign(left.style, { left: `${b.x}px`, top: `${b.y}px`, width: `${FH}px`, height: `${b.d}px`, transform: "rotateY(-90deg)" });
      const right = h("div", { class: "face face--right" });
      Object.assign(right.style, { left: `${b.x}px`, top: `${b.y + b.d}px`, width: `${b.w}px`, height: `${FH}px`, transform: "rotateX(90deg)" });
      if (!b.wire) {
        const lc = Math.max(1, Math.round(b.d / 28));
        const rc = b.ours ? 6 : Math.max(1, Math.round(b.w / 22));
        for (let c = 0; c < lc; c++) {
          const w = h("i", { class: "win" });
          const pitch = b.d / lc;
          Object.assign(w.style, { left: "7px", top: `${c * pitch + pitch * 0.2}px`, width: "13px", height: `${pitch * 0.6}px` });
          left.appendChild(w);
          if (rand() < 0.16) warmWindows.push({ el: w, on: 0.3 + rand() * 6 });
        }
        for (let c = 0; c < rc; c++) {
          const w = h("i", { class: "win" });
          const pitch = b.w / rc;
          Object.assign(w.style, { left: `${c * pitch + pitch * 0.2}px`, top: "7px", width: `${pitch * 0.6}px`, height: "13px" });
          right.appendChild(w);
          if (b.ours && f === 3 && c === 4) TARGET = w;
          else if (rand() < 0.16) warmWindows.push({ el: w, on: 0.3 + rand() * 6 });
        }
      }
      floor.append(left, right);
      if (f === b.floors - 1) {
        const roof = h("div", { class: "face roof" });
        Object.assign(roof.style, { left: `${b.x}px`, top: `${b.y}px`, width: `${b.w}px`, height: `${b.d}px`, transform: `translateZ(${FH}px)` });
        floor.appendChild(roof);
      }
      box.appendChild(floor);
    }
    $("#buildings").appendChild(box);
    b.el = box;
    b.dist = Math.hypot(b.x + b.w / 2 - OURS_C[0], b.y + b.d / 2 - OURS_C[1]);
  });
  TARGET.appendChild(h("b", { class: "hot" }));

  // Question tags anchored to places in the neighbourhood (layer coords + height).
  const ANCHORS = [[380, 50, 5 * FH], [OURS_C[0], OURS_C[1], 6 * FH], [55, 149, 2 * FH], [...STATION, 0], [55, 373, 2 * FH]];
  const LINE_H = [58, 64, 50, 80, 70];
  const TAG_DX = [0, 0, 0, 120, 0]; // keeps the metro label clear of the lit apartment
  const tagEls = COPY.tags.map((tag, i) => {
    const q = h("div", { class: "tag tag--q", style: `--lh: ${LINE_H[i]}px` }, `<span class="tag__dot"></span><i class="tag__line"></i><div class="tag__pill"><b>?</b>${tag.q}</div>`);
    const a = h("div", { class: `tag tag--a${tag.hot ? " tag--hot" : ""}`, style: `--lh: ${LINE_H[i]}px` }, `<span class="tag__dot"></span><i class="tag__line"></i><div class="tag__pill"><i>${ICON_CHECK}</i>${tag.a}<em>${tag.src}</em></div>`);
    $("#tags").append(q, a);
    $(".tag__pill", q).style.transform = `translateX(calc(-50% + ${TAG_DX[i]}px))`;
    return { q, a };
  });

  // ------------------------------------------------------ camera + project
  const cam = { cx: 0, cy: 0, s: 1, rx: 55, rz: -45, k: 1, R: 0, Rb: 0 };
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
      document.fonts.load('600 80px "Literata"', "Купуваш имот Buying"),
      document.fonts.load('italic 500 80px "Literata"', "нищо дом"),
      document.fonts.load('800 20px "Manrope"', "Провери имот"),
      document.fonts.load('600 20px "Manrope"', "Провери имот"),
      document.fonts.load('700 20px "Manrope"', "Провери имот"),
      document.fonts.load('500 18px "JetBrains Mono"', "68134")
    ]);

    const slot = $(".report__map-slot");
    const report = $("#report");
    let sx = slot.offsetLeft, sy = slot.offsetTop, node = slot.offsetParent;
    while (node && node !== report) { sx += node.offsetLeft; sy += node.offsetTop; node = node.offsetParent; }
    const MAP = { cx: report.offsetLeft + sx + slot.offsetWidth / 2, cy: report.offsetTop + sy + slot.offsetHeight / 2, s: slot.offsetWidth / L };

    const T_LIGHT = 10.95; // the moment Mesto's light lands on the building
    const lightAt = (t) => clamp01((t - T_LIGHT - 0.2) / 0.9);

    // --- background + chrome
    A(".topo", { x: [[0, 0], [DURATION, -90, "linear"]], y: [[0, 0], [DURATION, 30, "linear"]] });
    A("#night svg", { x: [[0, 0], [T_LIGHT + 2, -60, "linear"]] });
    A("#brand-night", { o: [[0.1, 0], [0.8, 1, "soft"], [T_LIGHT + 0.4, 1], [T_LIGHT + 1.1, 0, "soft"]] });
    A("#brand", { o: [[T_LIGHT + 0.4, 0], [T_LIGHT + 1.1, 1, "soft"], [24.3, 1], [24.7, 0, "in"]] });
    A("#domain", { o: [[0.1, 0], [0.8, 1, "soft"], [24.3, 1], [24.7, 0, "in"]] });
    hooks.push((t) => { $("#domain").style.color = mix([244, 240, 232, 0.75], [23, 63, 52, 1], lightAt(t)); });
    A("#disclaimer", { o: [[12.4, 0], [13, 1, "soft"], [24.3, 1], [24.7, 0, "in"]] });

    // --- camera
    A(cam, {
      cx: [[0, 1250], [T_LIGHT, 1225, "linear"], [12.3, 1200, "cam"], [16.9, 1190, "linear"], [18.1, MAP.cx, "cam"]],
      cy: [[0, 640], [T_LIGHT, 625, "linear"], [12.3, 610, "cam"], [16.9, 615, "linear"], [18.1, MAP.cy, "cam"]],
      s: [[0, 1.06], [T_LIGHT, 1.2, "linear"], [12.3, 1.32, "cam"], [16.9, 1.38, "linear"], [18.1, MAP.s, "cam"]],
      rx: [[16.9, 55], [18.1, 0, "cam"]],
      rz: [[0, -35], [T_LIGHT, -42, "linear"], [12.3, -45, "cam"], [16.9, -45], [18.1, 0, "cam"]],
      k: [[16.75, 1], [17.45, 0.002, "in"]],
      R: [[T_LIGHT, 0], [12.9, 560, "soft"]],
      Rb: [[T_LIGHT, 0], [13.6, 2300, "soft"]]
    }, (obj, v) => Object.assign(obj, v));

    const stack = $("#stack");
    const buildings = $("#buildings");
    const nightMap = $("#map-night");
    const night = $("#night");
    hooks.unshift((t) => {
      stack.style.transform = `translate(${(cam.cx - L / 2).toFixed(2)}px, ${(cam.cy - L / 2).toFixed(2)}px) scale(${cam.s.toFixed(4)}) rotateX(${cam.rx.toFixed(3)}deg) rotateZ(${cam.rz.toFixed(3)}deg)`;
      buildings.style.transform = `scale3d(1, 1, ${cam.k.toFixed(4)})`;
      buildings.style.visibility = cam.k < 0.01 ? "hidden" : "visible";

      // Light spreads outwards from the checked building.
      const R = cam.R;
      const mapMask = `radial-gradient(circle at ${OURS_C[0]}px ${OURS_C[1]}px, transparent ${(R - 150).toFixed(1)}px, #000 ${R.toFixed(1)}px)`;
      nightMap.style.maskImage = mapMask;
      nightMap.style.webkitMaskImage = mapMask;
      nightMap.style.visibility = R > 540 ? "hidden" : "visible";
      const [gx, gy] = project(OURS_C[0], OURS_C[1], 0);
      const r = cam.Rb;
      const nightMask = `radial-gradient(circle at ${gx.toFixed(1)}px ${gy.toFixed(1)}px, transparent ${(r - 420).toFixed(1)}px, #000 ${r.toFixed(1)}px)`;
      night.style.maskImage = nightMask;
      night.style.webkitMaskImage = nightMask;
      night.style.visibility = r > 2250 ? "hidden" : "visible";

      BUILDINGS.forEach((b) => {
        const lit = clamp01((R - b.dist) / 170);
        const day = b.ours ? P_DAY_OURS : P_DAY;
        for (const k in P_NIGHT) b.el.style.setProperty(`--${k}`, mix(P_NIGHT[k], day[k], lit));
      });
      for (const w of warmWindows) w.el.classList.toggle("is-warm", t >= w.on);
    });
    A("#stack-wrap", { o: [[25.4, 1], [25.5, 0]] });

    // --- act 1: in the dark ------------------------------------------------
    wordsIn($("#cap1 h2"), 0.3, { stagger: 0.09, dur: 1.0 });
    wordsIn($("#cap1 p"), 1.5, { stagger: 0.04, dur: 0.8 });
    fadeOut("#cap1", 6.15, { dy: -40, dur: 0.5 });

    tagEls.forEach(({ q, a }, i) => {
      const t0 = 1.9 + i * 0.42;
      const t1 = 11.35 + (Math.hypot(ANCHORS[i][0] - OURS_C[0], ANCHORS[i][1] - OURS_C[1]) / 260) * 0.8; // answered as the light arrives
      A($(".tag__dot", q), { s: [[t0, 0], [t0 + 0.4, 1, "back"]] });
      A($(".tag__line", q), { sy: [[t0 + 0.1, 0], [t0 + 0.55, 1, "out"]] });
      A($(".tag__pill", q), { o: [[t0 + 0.25, 0], [t0 + 0.55, 1, "soft"], [t1, 1], [t1 + 0.3, 0, "in"]] });
      A(q, { o: [[t1, 1], [t1 + 0.35, 0, "in"]] }, (el, v, t) => {
        const [px, py] = project(...ANCHORS[i]);
        el.style.transform = `translate(${px.toFixed(2)}px, ${(py + Math.sin(t * 1.3 + i * 2) * 3).toFixed(2)}px)`;
        el.style.opacity = v.o.toFixed(3);
        el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
      });
      A($(".tag__line", a), { sy: [[t1, 0], [t1 + 0.4, 1, "out"]] });
      A($(".tag__pill", a), { o: [[t1 + 0.1, 0], [t1 + 0.35, 1, "soft"]], s: [[t1 + 0.1, 0.7], [t1 + 0.6, 1, "back"]] }, (el, v) => {
        el.style.opacity = v.o.toFixed(3);
        el.style.transform = `translateX(calc(-50% + ${TAG_DX[i]}px)) scale(${v.s.toFixed(3)})`;
      });
      A(a, { o: [[t1, 0], [t1 + 0.05, 1], [16.55 + i * 0.04, 1], [16.9 + i * 0.04, 0, "in"]] }, (el, v) => {
        const [px, py] = project(...ANCHORS[i]);
        el.style.transform = `translate(${px.toFixed(2)}px, ${py.toFixed(2)}px)`;
        el.style.opacity = v.o.toFixed(3);
        el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
      });
    });

    // --- act 2: check it in Mesto ---------------------------------------------
    A("#dim", { o: [[6.2, 0], [6.8, 1, "soft"], [10.35, 1], [10.9, 0, "soft"]] });
    capIn("#cap2", 6.5);
    fadeOut("#cap2", 10.3, { dy: -40, dur: 0.5 });
    A("#panel", {
      o: [[6.45, 0], [6.95, 1, "soft"], [10.25, 1], [10.75, 0, "in"]],
      y: [[6.45, 70], [7.35, 0, "out"], [10.25, 0], [10.75, -20, "in"]],
      s: [[6.45, 0.95], [7.35, 1, "out"], [10.25, 1], [10.75, 0.92, "in"]],
      blur: [[10.25, 0], [10.75, 8, "in"]]
    });
    A(".panel__field", { "--fr": [[7.1, 0], [7.45, 6, "out"]] });
    hooks.push((t) => $(".panel__field").style.setProperty("--fb", t >= 7.1 ? "var(--clay)" : "var(--line)"));
    const typed = $("#typed");
    const TYPE_A = 7.3, TYPE_B = 8.5;
    hooks.push((t) => {
      const n = Math.round(clamp01((t - TYPE_A) / (TYPE_B - TYPE_A)) * COPY.address.length);
      typed.textContent = COPY.address.slice(0, n);
      const typing = t >= TYPE_A && t <= TYPE_B + 0.1;
      $("#caret").style.opacity = t < 7.1 || t > 9.6 ? 0 : typing ? 1 : (Math.floor((t - TYPE_B) * 2.6) % 2 ? 0 : 1);
    });
    A("#suggestions", {
      o: [[8.6, 0], [8.8, 1, "soft"], [9.5, 1], [9.75, 0, "in"]],
      sy: [[8.6, 0.92], [8.95, 1, "out"], [9.5, 1], [9.75, 0.96, "in"]],
      y: [[8.6, -8], [8.95, 0, "out"]]
    });
    $$(".sugg").forEach((s, i) => fadeUp(s, 8.68 + i * 0.07, { dy: 12, dur: 0.5 }));
    A($(".sugg__hl"), { o: [[9.15, 0], [9.27, 1, "soft"]] });
    $$(".sugg__hl").slice(1).forEach((el) => A(el, { o: 0 }));
    A("#selected-chip", { o: [[9.65, 0], [9.85, 1, "soft"]], s: [[9.65, 0.7], [10.05, 1, "back"]] });
    const btn = $("#find-button");
    const panel = $("#panel");
    const BTN = [btn.offsetWidth / 2, btn.offsetHeight / 2];
    for (let n = btn; n && n !== $("#stage"); n = n.offsetParent) { BTN[0] += n.offsetLeft; BTN[1] += n.offsetTop; }
    A(btn, { s: [[9.95, 1], [10.05, 0.95, "out"], [10.25, 1, "back"]] });
    A("#cursor", {
      o: [[8.6, 0], [8.8, 1, "soft"], [10.2, 1], [10.45, 0, "in"]],
      x: [[8.6, 1560], [9.2, 1080, "cam"], [9.5, 1080], [9.85, BTN[0] - 8, "cam"]],
      y: [[8.6, 900], [9.2, 650, "cam"], [9.5, 650], [9.85, BTN[1] - 5, "cam"]],
      s: [[9.3, 1], [9.36, 0.82, "out"], [9.48, 1, "out"], [9.95, 1], [10.01, 0.82, "out"], [10.13, 1, "out"]]
    });

    // The clay cell: the "your place" square from the wordmark carries the check
    // from the button into the building.
    A("#spark", { p: [[10.1, 0], [T_LIGHT, 1, "inOut"]], o: [[10.08, 0], [10.12, 1], [T_LIGHT - 0.05, 1], [T_LIGHT + 0.05, 0]] }, (el, v) => {
      const [ex, ey] = project(OURS_C[0], OURS_C[1], 6 * FH);
      const x = BTN[0] + (ex - BTN[0]) * v.p;
      const y = BTN[1] + (ey - BTN[1]) * v.p - Math.sin(Math.PI * v.p) * 180;
      el.style.transform = `translate(${x.toFixed(2)}px, ${y.toFixed(2)}px) rotate(${(v.p * 180).toFixed(1)}deg) scale(${(1 - v.p * 0.35).toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
      el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
    });

    // --- act 3: Mesto lights it up --------------------------------------------
    const atBuilding = (el, v) => {
      const [px, py] = project(OURS_C[0], OURS_C[1], 6 * FH);
      el.style.transform = `translate(${px.toFixed(2)}px, ${py.toFixed(2)}px) scale(${v.s.toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
      el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
    };
    A("#glow", { o: [[T_LIGHT - 0.05, 0], [T_LIGHT + 0.12, 1, "out"], [12.9, 0, "soft"]], s: [[T_LIGHT, 0.2], [12.6, 1.6, "out"]] }, atBuilding);
    A("#burst", { o: [[T_LIGHT, 0], [T_LIGHT + 0.05, 1], [12.0, 0, "soft"]], s: [[T_LIGHT, 0.2], [12.0, 6, "out"]] }, atBuilding);

    capIn("#cap3", 11.55);
    fadeOut("#cap3", 16.7, { dy: -40, dur: 0.5 });

    A($(".hot", TARGET), { o: [[11.9, 0], [12.1, 1, "soft"]] });
    const targetPos = [195 + 4 * (130 / 6) + 130 / 12, 260, 3 * FH + 13.5];
    A("#focus-ring", {
      o: [[12.0, 0], [12.05, 1], [12.9, 0, "soft"], [12.95, 0], [13.0, 1], [13.85, 0, "soft"]],
      s: [[12.0, 0.3], [12.9, 1.6, "out"], [12.95, 0.3], [13.85, 1.6, "out"]]
    }, (el, v) => {
      const [px, py] = project(...targetPos);
      el.style.transform = `translate(${px.toFixed(2)}px, ${py.toFixed(2)}px) scale(${v.s.toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
    });

    // Answers on the map: they sit under the dusk layer and are revealed by the
    // light; the pops make them feel discovered rather than already there.
    $$("#map-answers .permit").forEach((p, i) => {
      const { x, y } = p.dataset;
      A(p, { s: [[12.2 + i * 0.15, 0], [12.7 + i * 0.15, 1, "back"]] }, (el, v) => el.setAttribute("transform", `translate(${x} ${y}) scale(${v.s.toFixed(3)})`));
    });
    $$("#map-answers .school").forEach((s, i) => {
      const { x, y } = s.dataset;
      A(s, { s: [[12.6 + i * 0.15, 0], [13.1 + i * 0.15, 1, "back"]] }, (el, v) => el.setAttribute("transform", `translate(${x} ${y}) scale(${v.s.toFixed(3)})`));
    });
    A("#map-answers .metro", { d: [[11.6, 1], [12.8, 0, "out"]] }, (el, v) => { el.style.strokeDasharray = "1 1"; el.style.strokeDashoffset = v.d.toFixed(4); });
    A("#map-answers .station", { s: [[12.3, 0], [12.8, 1, "back"]] }, (el, v) => el.setAttribute("transform", `translate(${STATION[0]} ${STATION[1]}) scale(${v.s.toFixed(3)})`));
    A("#map-answers .zones", { o: [[11.6, 0], [12.6, 1, "soft"]] });
    A("#map-answers .radius", { o: [[12.4, 0], [13.2, 1, "soft"]] });

    // --- act 4: the report -------------------------------------------------------
    capIn("#cap5", 17.45);
    A("#cap5", { o: [[24.3, 1], [24.7, 0, "in"]] });
    A("#report", {
      o: [[17.35, 0], [17.9, 1, "soft"], [25.4, 1], [25.5, 0]],
      y: [[17.35, 50], [18.2, 0, "out"]],
      s: [[17.35, 0.96], [18.2, 1, "out"]]
    });
    fadeUp(".report__header > div", 17.8, { dy: 16 });
    A(".report__badge", { o: [[18.25, 0], [18.45, 1, "soft"]], s: [[18.25, 0.7], [18.7, 1, "back"]] });
    $$(".finding").forEach((row, i) => {
      const t0 = 18.35 + i * 0.3 + (i === 4 ? 0.15 : 0);
      A(row, { o: [[t0, 0], [t0 + 0.35, 1, "soft"]], x: [[t0, -28], [t0 + 0.7, 0, "out"]] });
      A($("em", row), { o: [[t0 + 0.2, 0], [t0 + 0.4, 1, "soft"]], s: [[t0 + 0.2, 0.7], [t0 + 0.65, 1, "back"]] });
      const check = $("strong svg", row);
      if (check) A(check, { s: [[t0 + 0.3, 0], [t0 + 0.7, 1, "back"]] });
    });
    A($(".finding--warn"), { s: [[21.4, 1], [21.65, 1.025, "out"], [22.05, 1, "inOut"]] });
    A("#map-pin", { o: [[19.0, 0], [19.15, 1, "soft"], [25.4, 1], [25.5, 0]], y: [[19.0, -60], [19.5, 0, "back"]], s: [[19.0, 1.3], [19.5, 1, "out"]] }, (el, v) => {
      const [px, py] = project(OURS_C[0], OURS_C[1], 0);
      el.style.transform = `translate(${px.toFixed(2)}px, ${(py + v.y).toFixed(2)}px) scale(${v.s.toFixed(3)})`;
      el.style.opacity = v.o.toFixed(3);
      el.style.visibility = v.o < 0.002 ? "hidden" : "visible";
    });
    fadeUp("#asks", 19.85, { dy: 24 });
    $$("#asks li").forEach((li, i) => {
      const t0 = 20.2 + i * 0.35;
      A(li, { o: [[t0, 0], [t0 + 0.3, 1, "soft"]], x: [[t0, -14], [t0 + 0.6, 0, "out"]] });
      A($("i", li), { s: [[t0 + 0.1, 0], [t0 + 0.55, 1, "back"]] });
    });
    A("#s5", { o: [[25.4, 1], [25.5, 0]] });

    // --- act 5: end card -------------------------------------------------------
    $$("#wipe i").forEach((cell, i) => {
      const col = i % 16, row = Math.floor(i / 16);
      const d = Math.hypot(col * 120 + 60 - MAP.cx, row * 120 + 60 - MAP.cy);
      const t0 = 24.55 + (d / 1700) * 0.55;
      A(cell, { s: [[t0, 0], [t0 + 0.42, 1, "inOut"]], r: [[t0, 45], [t0 + 0.42, 0, "inOut"]] });
    });
    A("#end-bg", { o: [[25.3, 0], [25.4, 1]] });
    A("#end-bg svg", { x: [[25.3, 0], [DURATION, 40, "linear"]] });
    $$("#end-logo .cell").forEach((cell, i) => {
      const t0 = 25.55 + i * 0.016;
      A(cell, { o: [[t0, 0], [t0 + 0.25, 1, "soft"]], y: [[t0, 6], [t0 + 0.5, 0, "snap"]], s: [[t0, 0.55], [t0 + 0.5, 1, "snap"]] });
    });
    A("#end-logo .accent-hot", { o: [[26.85, 0], [27.15, 1, "soft"]], s: [[26.85, 0.6], [27.35, 1, "back"]] });
    wordsIn($("#s6 h2"), 26.25, { stagger: 0.06, dur: 1.0 });
    $$(".end__trust span").forEach((s, i) => fadeUp(s, 27.15 + i * 0.12, { dy: 16 }));
  }

  function capIn(id, t0) {
    const cap = $(id);
    A($(".cap__eyebrow i", cap), { sx: [[t0 + 0.05, 0], [t0 + 0.65, 1, "out"]] });
    A($(".cap__eyebrow span", cap), { o: [[t0 + 0.15, 0], [t0 + 0.55, 1, "soft"]], x: [[t0 + 0.15, -10], [t0 + 0.75, 0]] });
    wordsIn($("h2", cap), t0 + 0.1, { stagger: 0.08, dur: 0.95 });
    wordsIn($("p", cap), t0 + 0.55, { stagger: 0.03, dur: 0.8 });
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
