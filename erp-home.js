// 농부마을 앱 공통 — 모든 화면에 「🏠 홈」 버튼을 달고, 어느 화면에서 「홈 화면에 추가」를 눌러도 같은 앱 하나로 설치되게 합니다.
// 화면마다 <script src="erp-home.js"></script> 한 줄만 넣으면 됩니다.
(function(){
  // 앱 설치 정보 (아이콘·이름·시작 화면 = app.html)
  if(!document.querySelector('link[rel="manifest"]')){
    var m = document.createElement("link"); m.rel = "manifest"; m.href = "manifest.webmanifest";
    document.head.appendChild(m);
    var a = document.createElement("link"); a.rel = "apple-touch-icon"; a.href = "erp-icon.png";
    document.head.appendChild(a);
  }

  // ERP 콘솔(왼쪽 메뉴) 안에 들어가 있을 때는 홈 버튼을 달지 않음
  if(window.top !== window.self) return;
  if(/(^|\/)app\.html$/.test(location.pathname)) return;

  function addButton(){
    var b = document.createElement("a");
    b.href = "app.html";
    b.textContent = "🏠 홈";
    b.setAttribute("aria-label", "농부마을 앱 홈으로");
    b.style.cssText = "position:fixed;top:10px;right:10px;z-index:9999;background:rgba(43,58,78,.92);color:#fff;" +
      "font:700 13px 'Malgun Gothic','맑은 고딕',sans-serif;padding:7px 12px;border-radius:18px;text-decoration:none;" +
      "box-shadow:0 2px 8px rgba(0,0,0,.18);";
    document.body.appendChild(b);
  }
  if(document.body) addButton(); else document.addEventListener("DOMContentLoaded", addButton);
})();
