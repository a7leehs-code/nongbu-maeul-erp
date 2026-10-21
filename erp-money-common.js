// [AI 생성 초안 - 검토 전] 농부마을 경영·자금 「본다」 화면 공통 (통장·매출 보기 · 월 손익)
// 거래 분류함(erp-money-sort.html)과 같은 자료를 읽기만 합니다: 실습판은 같은 브라우저 서랍, 실사용은 같은 창고 표(bank_txns · money_categories).
// 대표·재무(money 허락)만 볼 수 있고, 금액 계산 규칙은 7회차 교보재(한빛산업)와 같습니다.
(function(){
  const CFG = window.ERP_CONFIG || {};
  const LIVE = Boolean(CFG.supabaseUrl && CFG.supabaseAnonKey) && !/[?&]practice=1(&|$)/.test(location.search);
  const SUPABASE_JS = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js";
  const M = window.MoneyCommon = { LIVE, txns: [], cats: [], me: null };

  const $ = id => document.getElementById(id);
  M.esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;" }[c]));
  M.won = n => Math.round(n || 0).toLocaleString("ko-KR");
  M.signed = n => (n < 0 ? "− " : n > 0 ? "+ " : "") + M.won(Math.abs(n));
  M.man = n => { const v = Math.round(Math.abs(n) / 10000); return v.toLocaleString("ko-KR") + "만"; };
  const localDate = d => new Date(d.getTime() - d.getTimezoneOffset()*60000).toISOString().slice(0,10);

  // ───────── 실습판: 거래 분류함과 같은 서랍·같은 가상 예시 ─────────
  const KEY_T = "nongbuErpBankTxns", KEY_C = "nongbuErpMoneyCats";
  const DEFAULT_CATS = [["계란 매출",true],["사람",true],["사료·약품",true],["자리·설비",true],["파는 데 드는 돈",true],["보증금",false],["카드정산",false],["대출 원금",false]];
  function practiceSeed(){
    const y = new Date().getFullYear(), m = String(new Date().getMonth() + 1).padStart(2, "0");
    const d = n => y + "-" + m + "-" + String(n).padStart(2, "0");
    const rows = [
      [1,"○○마트 계란 대금",3850000,0,"매출","계란 매출","AI"],
      [2,"△△사료",0,4620000,"원재료","사료·약품","AI"],
      [3,"○○빌딩 창고 보증금",0,10000000,"세금과공과","보증금","나","클로브는 「세금과공과」 — 돌려받을 돈"],
      [5,"신한카드정산",1280000,0,"매출","카드정산","나","클로브는 「매출」 — 지난달 판 것이 늦게 들어옴"],
      [6,"국민건강",0,612000,"복리후생비","사람","AI","무슨 달 것인지 확실하지 않아 귀속월 비움"],
      [8,"한국전력공사",0,1236000,"수도광열비","자리·설비","AI"],
      [9,"□□동물병원 백신",0,880000,"",null,null],
      [10,"◇◇포장 계란판",0,742000,"소모품비","파는 데 드는 돈","AI"],
      [12,"○○로컬푸드 계란",2140000,0,"매출","계란 매출","AI"],
      [15,"한길주유소",0,98000,"차량유지비","파는 데 드는 돈","AI"],
      [18,"농협 대출 원금상환",0,2000000,"",null,null],
      [20,"△△사료",0,4410000,"원재료","사료·약품","AI"],
      [25,"급여",0,9600000,"급여","사람","AI","",y + "-" + m],
      [27,"○○마트 계란 대금",4120000,0,"매출","계란 매출","AI"],
      [28,"택배 반품 환불",0,36000,"",null,null]
    ];
    return rows.map((r, i) => ({ id:"p" + i, date:d(r[0]), desc:r[1], inAmt:r[2], outAmt:r[3], clobe:r[4], cat:r[5], who:r[6], note:r[7] || "", belong:r[8] || "" }));
  }
  function loadPractice(){
    try{ M.txns = JSON.parse(localStorage.getItem(KEY_T)) || null; }catch(e){ M.txns = null; }
    if(!M.txns) M.txns = practiceSeed();
    try{ M.cats = JSON.parse(localStorage.getItem(KEY_C)) || null; }catch(e){ M.cats = null; }
    if(!M.cats) M.cats = DEFAULT_CATS.map(([name, pnl], i) => ({ id:"c" + i, name, pnl }));
  }

  // ───────── 실사용: 창고에서 읽기만 ─────────
  let sb = null, session = null, liveError = "", allowed = !LIVE;
  function loadScript(src){
    return new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = src; s.onload = resolve;
      s.onerror = () => reject(new Error("라이브러리를 불러오지 못했습니다. 인터넷 연결을 확인하세요."));
      document.head.appendChild(s);
    });
  }
  function friendly(msg){
    if(/Failed to fetch|NetworkError|Load failed/i.test(msg)) return "창고(서버)에 연결하지 못했습니다. 인터넷 연결을 확인하세요.";
    if(msg === "Invalid login credentials") return "이메일 또는 비밀번호가 틀렸습니다.";
    if(/Email not confirmed/i.test(msg)) return "메일함의 확인 링크를 먼저 눌러주세요.";
    if(/bank_txns.*does not exist|money_categories.*does not exist|Could not find the table/i.test(msg)) return "거래 분류함 표가 아직 없습니다. supabase/money_sort.sql 을 실행했는지 확인하세요.";
    return msg;
  }
  async function loadLiveData(){
    const c = await sb.from("money_categories").select("*").order("sort").order("id");
    if(c.error) throw new Error(c.error.message);
    M.cats = c.data.map(x => ({ id:String(x.id), name:x.name, pnl:x.pnl }));
    let all = [];
    for(let from = 0; ; from += 1000){
      const q = await sb.from("bank_txns").select("id,txn_date,description,note,amount_in,amount_out,clobe_category,my_category,who,belong_month").order("txn_date").order("id").range(from, from + 999);
      if(q.error) throw new Error(q.error.message);
      all = all.concat(q.data);
      if(q.data.length < 1000) break;
    }
    M.txns = all.map(r => ({ id:String(r.id), date:r.txn_date, desc:r.description, note:r.note, inAmt:Number(r.amount_in), outAmt:Number(r.amount_out),
      clobe:r.clobe_category, cat:r.my_category, who:r.who, belong:r.belong_month || "" }));
  }

  // ───────── 계산 규칙 ─────────
  // 판 것 = 이름에 「매출」이 들어간 내 분류 (들어온 돈 − 되돌려 준 돈)
  // 쓴 것 = 나머지 손익 분류 (나간 돈 − 취소·환불로 되돌아온 돈)
  // 손익 아님 = pnl=false 분류(보증금·카드정산·대출 원금) — 나갔거나 들어왔어도 손익에 넣지 않음
  // 미분류 = 아직 내 분류가 없는 거래 — 지우지 않고 따로 셈
  M.catOf = name => M.cats.find(c => c.name === name);
  M.isSales = c => !!c && c.pnl && /매출/.test(c.name);
  M.months = () => [...new Set(M.txns.map(t => t.date.slice(0,7)))].sort().reverse();
  M.monthLabel = m => m ? Number(m.slice(0,4)) + "년 " + Number(m.slice(5)) + "월" : "";
  M.stats = month => {
    const L = M.txns.filter(t => t.date.startsWith(month));
    const s = { list:L, count:L.length, inSum:0, outSum:0, sales:0, salesCount:0, cost:0, byCat:{}, nonIn:0, nonOut:0, nonInList:[], nonOutList:[], uncls:[], unclsNet:0, salesBy:{} };
    L.forEach(t => {
      s.inSum += t.inAmt; s.outSum += t.outAmt;
      const c = t.cat && M.catOf(t.cat);
      if(!c){ s.uncls.push(t); s.unclsNet += t.outAmt - t.inAmt; return; }
      if(!c.pnl){
        if(t.inAmt){ s.nonIn += t.inAmt; s.nonInList.push(t); }
        if(t.outAmt){ s.nonOut += t.outAmt; s.nonOutList.push(t); }
        const b = s.byCat[c.name] || (s.byCat[c.name] = { cat:c, kind:"손익 아님", count:0, amount:0, refund:0 });
        b.count++; b.amount += t.inAmt + t.outAmt;
        return;
      }
      if(M.isSales(c)){
        s.sales += t.inAmt - t.outAmt; s.salesCount++;
        const b = s.byCat[c.name] || (s.byCat[c.name] = { cat:c, kind:"판 것", count:0, amount:0, refund:0 });
        b.count++; b.amount += t.inAmt - t.outAmt;
        const who = t.desc.replace(/\s*(계란\s*)?(대금|입금)$/,"").trim() || t.desc;
        const g = s.salesBy[who] || (s.salesBy[who] = { name:who, count:0, amount:0 });
        g.count++; g.amount += t.inAmt - t.outAmt;
        return;
      }
      s.cost += t.outAmt - t.inAmt;
      const b = s.byCat[c.name] || (s.byCat[c.name] = { cat:c, kind:"쓴 것", count:0, amount:0, refund:0 });
      b.count++; b.amount += t.outAmt - t.inAmt; if(t.inAmt) b.refund += t.inAmt;
    });
    s.bankChange = s.inSum - s.outSum;
    s.profit = s.sales - s.cost;                    // 장부 규칙 (월 손익): 미분류는 따로
    s.viewSpent = s.cost + s.unclsNet;              // 통장·매출 보기: 미분류도 「쓴 것」에 넣어 셈
    s.viewResult = s.sales - s.viewSpent;
    s.unclsOut = s.uncls.reduce((a, t) => a + t.outAmt, 0);
    s.check = s.profit + s.nonIn - s.nonOut - s.unclsNet;   // = 통장 증감 이어야 맞음
    return s;
  };

  // ───────── 로그인 · 잠금 ─────────
  function renderModeNote(){
    const el = $("modeNote");
    if(LIVE){ el.className = "warn live"; el.innerHTML = "🔒 경영·자금 — 대표와 대표가 허락한 재무 담당만 볼 수 있는 화면입니다. 거래 분류함에서 정한 내 분류로 셉니다."; }
    else{ el.className = "warn"; el.innerHTML = "⚠ 실습판입니다. 거래 분류함 실습판과 같은 <b>가상 예시 거래</b>로 셉니다. 실제 숫자를 보려면 주소 끝의 <b>?practice=1</b>을 빼고 여세요."; }
  }
  function renderBar(){
    const bar = $("bar");
    if(!LIVE || !session){ bar.style.display = "none"; return; }
    bar.style.display = "";
    bar.innerHTML = `<span class="who">${M.me ? `👤 <b>${M.esc(M.me.name)}</b> (${M.esc(M.me.role)}) 로그인 중` : "로그인 중"}</span>
      <button class="btn btn-line" id="refreshBtn">새로고침</button><button class="btn btn-line" id="logoutBtn">로그아웃</button>`;
  }
  function renderGate(){
    renderModeNote(); renderBar();
    let gate = "";
    if(LIVE && liveError) gate = `<div class="card auth"><h3>연결에 문제가 있습니다</h3><p class="msg err" style="display:block">${M.esc(liveError)}</p></div>`;
    else if(LIVE && !sb) gate = `<div class="card auth" style="text-align:center;color:var(--muted)">창고(DB)에 연결하는 중…</div>`;
    else if(LIVE && !session) gate = `<div class="card auth">
        <label for="aEmail">이메일</label><input id="aEmail" type="email" autocomplete="email">
        <label for="aPw">비밀번호</label><input id="aPw" type="password" autocomplete="current-password">
        <div class="msg err" id="aErr" style="display:none"></div>
        <button class="btn btn-copper btn-block" id="authBtn">로그인</button>
        <p class="help" style="margin-top:10px">전자결재·산란 기록과 같은 계정입니다.</p></div>`;
    else if(LIVE && (!M.me || !M.me.active)) gate = `<div class="card auth"><h3>⏳ 대표 승인 대기 중</h3><p style="font-size:13.5px">대표가 「사용 허용」을 누르면 쓸 수 있습니다.</p></div>`;
    else if(LIVE && !allowed) gate = `<div class="card auth"><h3>🔒 대표·재무만 볼 수 있어요</h3><p style="font-size:13.5px">경영·자금 화면은 대표가 허락한 재무 담당만 볼 수 있습니다. 필요하면 대표에게 요청하세요.</p></div>`;
    $("auth").innerHTML = gate;
    $("app").style.display = gate ? "none" : "";
    if(LIVE && sb && !session && !liveError){
      $("authBtn").onclick = async () => {
        const err = $("aErr"); err.style.display = "none";
        const email = $("aEmail").value.trim(), password = $("aPw").value;
        if(!email.includes("@") || password.length < 6){ err.textContent = "이메일과 비밀번호(6자 이상)를 확인해주세요."; err.style.display = "block"; return; }
        $("authBtn").disabled = true;
        const { error } = await sb.auth.signInWithPassword({ email, password });
        $("authBtn").disabled = false;
        if(error){ err.textContent = friendly(error.message); err.style.display = "block"; }
      };
    }
    return !gate;
  }
  async function loadLive(){
    liveError = ""; M.me = null; allowed = false;
    if(session){
      try{
        const { data, error } = await sb.from("profiles").select("id,name,email,role,active").eq("id", session.user.id).maybeSingle();
        if(error) throw new Error(error.message);
        M.me = data ? { id:data.id, name:data.name || data.email, role:data.role, active:data.active } : null;
        if(M.me && M.me.active){
          const r = await sb.rpc("has_perm", { p:"money" });
          allowed = !r.error && r.data === true;
          if(allowed) await loadLiveData();
        }
      }catch(e){ liveError = friendly(e.message); }
    }
    if(!allowed){ M.txns = []; M.cats = []; }
    if(renderGate()) M.onReady();
  }

  // 화면이 M.onReady 를 정해 두고 M.start() 를 부르면 됩니다
  M.start = async () => {
    $("bar").addEventListener("click", async e => {
      if(e.target.id === "refreshBtn") await loadLive();
      else if(e.target.id === "logoutBtn") await sb.auth.signOut();
    });
    if(!LIVE){ loadPractice(); renderGate(); M.onReady(); return; }
    renderGate();
    try{
      if(!window.supabase) await loadScript(SUPABASE_JS);
      sb = window.supabase.createClient(CFG.supabaseUrl, CFG.supabaseAnonKey);
      sb.auth.onAuthStateChange((_e, s) => { session = s; setTimeout(loadLive, 0); });
    }catch(e){ liveError = e.message; renderGate(); }
  };
})();
