---
name: baobab-html-design
description: 바오밥의 모든 HTML 산출물(수업계획서·안내문·아카이브·카드·랜딩·복사용 문서)에 적용하는 디자인 표준 스킬. HTML 페이지를 만들거나 다듬을 때 반드시 사용한다. 바오밥 디자인 시스템(NAVY·COPPER·CREAM·TEAL, 맑은 고딕)과 표준 컴포넌트(헤더 그라데이션·카드·스텝·인용·복사박스·표·콜아웃)를 일관되게 적용한다. "수업계획서", "안내문", "html 만들어", "페이지", "카드뉴스 html", "랜딩", "복사용 문서"를 만들 때 트리거. baobab-html-open(브라우저 열기)과 짝으로 운영한다.
---

# 바오밥 HTML 디자인 표준

바오밥의 HTML 산출물은 전부 아래 하나의 시스템을 따른다. 매번 CSS를 새로 짜지 말고 이 보일러플레이트를 복사해 내용만 채운다. 그래야 수업계획서·안내문·아카이브가 한 눈에 "바오밥 것"으로 보인다.

## 절대 원칙 (5가지)

1. **자기완결(self-contained)** — CSS·JS·폰트 전부 파일 안에 인라인. 외부 CDN·링크·이미지 host 금지. 통째로 복사·배포해도 그대로 뜬다.
2. **.html로 낸다** — 대표님께 보여줄 열 수 있는 산출물은 `.md`가 아니라 `.html`. (세션 루트 밖 `.md`는 자동으로 안 열림 — 이건 확인된 사실)
3. **첫 줄 워터마크** — AI 생성물은 첫 줄에 `<!-- [AI 생성 초안 - 검토 전] ... -->`, 화면 하단 푸터에도 `[AI 생성 초안 - 검토 전]`.
4. **모바일 우선** — 대표·학생 상당수가 폰으로 연다. 상대단위·max-width·표는 가로 스크롤 처리.
5. **만든 직후 baobab-html-open으로 브라우저 자동 열기** — 대표는 폴더 탐색을 Labor로 본다.

## 색 시스템 (고정)

| 이름 | 값 | 용도 |
|---|---|---|
| NAVY | #2B3A4E | 제목·헤더·표 헤더·본문 강조 |
| COPPER | #C67B3C | 강조·버튼·포인트(핵심 단어에만) |
| CREAM | #F7F3EE | 배경 |
| TEAL | #3A8FB7 | 보조 강조·인용 좌측선·링크·날짜 |
| 보조 | ink #243140 / line #e3dccf / muted #6b7785 / red #b3503a / green #3f7a52 | 본문·경계·흐린글·경고·성공 |

- 폰트: 한글 "맑은 고딕"("Malgun Gothic"). 본문 15~16.5px, 제목 볼드.
- 강조색(COPPER)은 **핵심 단어·숫자에만.** 문장 전체를 물들이지 않는다.

## 표준 컴포넌트 (이 이름·구조를 재사용)

- `header` — NAVY→COPPER 그라데이션, 라운드 하단, `.k`(코퍼 칩 라벨) + `h1` + `.sub`(설명) + `.meta`(정보 칩들) + `.flow`(단계 칩들)
- `.quote` — 흰 배경 + TEAL 좌측선. 핵심 메시지·프레임. 빨강 좌측선(`border-left-color:var(--red)`)은 경고성 프레임.
- `.step` — NAVY 바. 섹션/STEP 헤더. `<span>`으로 시간·부제.
- `.card` — 흰 카드(라운드·옅은 그림자). 본문 담는 기본 그릇. `.card h3`로 소제목.
- `.copybox` + `.copybtn` — NAVY 배경 코드박스 + 코퍼 "복사" 버튼. 프롬프트·복사용 텍스트. (JS `cp()` 포함)
- `table` — NAVY 헤더(흰 글씨) + cream 줄무늬(`tr:nth-child(even)`). 비교·정리는 무조건 표.
- 콜아웃 3종 — `.out`(코퍼, 결론·통과선) / `.safe`(틸, 안내·팁) / `.warn`(빨강, 경고·리스크)
- `.sub-h` — 크림 배경 인라인 소제목 라벨
- `.foot` — 중앙정렬 흐린 푸터(출처·워터마크)

## 복사용 문서(카톡 안내문 등) 변형

전문을 그대로 복사하게 하는 문서는: 상단 헤더에 "복사" 버튼 하나 + 본문을 `.box`(흰 카드, `white-space:pre-wrap`) 하나에 담고, 버튼이 `.box` 전체를 클립보드로 복사. (카톡 문구·프롬프트 전달용)

## 보일러플레이트 (복사해서 시작)

```html
<!-- [AI 생성 초안 - 검토 전] {제목} -->
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{제목}</title>
<style>
  :root{--navy:#2B3A4E;--copper:#C67B3C;--cream:#F7F3EE;--teal:#3A8FB7;--ink:#243140;--line:#e3dccf;--muted:#6b7785;--red:#b3503a;--green:#3f7a52;}
  *{box-sizing:border-box;margin:0;padding:0;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
  body{background:var(--cream);color:var(--ink);font-family:"맑은 고딕","Malgun Gothic",sans-serif;line-height:1.7;font-size:16.5px;}
  .wrap{max-width:920px;margin:0 auto;padding:0 20px 90px;}
  header{background:linear-gradient(135deg,#2B3A4E,#1a2636 58%,#C67B3C 210%);color:#fff;border-radius:0 0 24px 24px;padding:38px 26px 30px;margin:0 -20px 24px;}
  header .k{display:inline-block;background:rgba(198,123,60,.28);border:1px solid rgba(198,123,60,.5);color:#f0c89a;font-size:13px;font-weight:700;border-radius:20px;padding:5px 14px;margin-bottom:12px;}
  header h1{font-size:24px;line-height:1.45;}
  header .sub{color:#d7dee6;font-size:15px;margin-top:10px;max-width:660px;}
  .meta{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px;}
  .meta span{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.22);border-radius:8px;padding:6px 12px;font-size:13px;font-weight:700;}
  .flow{display:flex;flex-wrap:wrap;gap:6px;margin-top:14px;}
  .flow span{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.22);border-radius:8px;padding:6px 11px;font-size:12.5px;font-weight:700;color:#fff;}
  .quote{background:#fff;border-left:4px solid var(--teal);border-radius:10px;padding:15px 18px;font-size:15px;color:var(--navy);margin-bottom:18px;}
  .quote b{color:var(--copper);}
  .step{background:var(--navy);color:#fff;border-radius:12px;padding:12px 18px;margin:26px 0 14px;font-weight:800;font-size:18px;}
  .step span{color:#f0c89a;font-size:13.5px;font-weight:700;}
  .card{background:#fff;border:1px solid var(--line);border-radius:14px;padding:20px;margin-bottom:16px;box-shadow:0 3px 12px rgba(0,0,0,.05);}
  .card h3{font-size:16.5px;color:var(--navy);margin-bottom:10px;}
  p{font-size:15px;margin:6px 0;}
  .muted{color:var(--muted);font-size:13.5px;}
  ol,ul{padding-left:22px;} li{margin:6px 0;font-size:15px;}
  table{width:100%;border-collapse:collapse;margin-top:8px;font-size:14px;}
  th,td{padding:9px 11px;border-bottom:1px solid var(--line);text-align:left;vertical-align:top;}
  th{background:var(--navy);color:#fff;font-weight:600;font-size:13.5px;}
  tr:nth-child(even) td{background:#faf7f1;}
  .out{background:#fff8f0;border-left:4px solid var(--copper);border-radius:8px;padding:12px 15px;font-size:14px;color:#7a5a30;margin-top:10px;}
  .safe{background:#eef4f7;border-left:4px solid var(--teal);border-radius:8px;padding:12px 15px;font-size:14px;margin-top:10px;}
  .warn{background:#fbeee9;border-left:4px solid var(--red);border-radius:8px;padding:12px 15px;font-size:14px;color:#8a3a2a;margin-top:10px;}
  .copybox{position:relative;background:#2b3a4e;border-radius:10px;padding:16px 15px;margin:10px 0;}
  .copybox pre{white-space:pre-wrap;word-break:break-word;color:#e8eef4;font-family:"맑은 고딕",monospace;font-size:13.2px;line-height:1.65;margin:0;}
  .copybtn{position:absolute;top:9px;right:9px;background:var(--copper);color:#fff;border:none;border-radius:7px;padding:6px 12px;font-size:12.3px;font-weight:700;cursor:pointer;font-family:inherit;}
  .sub-h{font-size:13px;font-weight:800;color:var(--navy);background:var(--cream);border-radius:7px;padding:5px 10px;display:inline-block;margin:14px 0 8px;}
  .foot{text-align:center;color:var(--muted);font-size:12.5px;margin-top:30px;line-height:1.7;}
  a.lnk{color:var(--teal);font-weight:700;text-decoration:none;word-break:break-all;}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="k">{라벨}</div>
    <h1>{제목}</h1>
    <div class="sub">{한 줄 설명}</div>
    <div class="meta"><span>{정보1}</span><span>{정보2}</span></div>
    <div class="flow"><span>① {단계}</span><span>② {단계}</span></div>
  </header>

  <div class="quote">🎯 <b>핵심 메시지</b></div>

  <div class="step">STEP 1 · {제목} <span>— {시간}</span></div>
  <div class="card">
    <h3>{소제목}</h3>
    <p>{본문}</p>
    <div class="copybox"><button class="copybtn" onclick="cp(this)">복사</button><pre>{프롬프트}</pre></div>
    <div class="out">✅ {통과선/결론}</div>
  </div>

  <div class="foot">바오밥 · {과정명} · {버전} · {날짜}<br>[AI 생성 초안 - 검토 전]</div>
</div>
<script>
function cp(b){var p=b.parentElement.querySelector('pre');navigator.clipboard.writeText(p.innerText).then(function(){var o=b.textContent;b.textContent='복사됨 ✓';setTimeout(function(){b.textContent=o;},1500);});}
</script>
</body>
</html>
```

## 품질 체크 (내보내기 전)

- 색·폰트가 위 시스템과 일치하는가 (임의 색 추가 금지)
- 표는 NAVY 헤더 + cream 줄무늬인가
- 복사 버튼이 실제 작동하는가(`cp()` 포함)
- `<div>` 여닫음 균형 — `grep -o '<div' | wc -l` = `grep -o '</div>' | wc -l`
- 첫 줄·푸터에 워터마크
- 모바일에서 가로 스크롤 안 생기는가(넓은 표는 스크롤 컨테이너)
- 외부 링크·CDN 0개 (자기완결)

## 관련 스킬

- **baobab-html-open** — 만든 직후 브라우저 자동 열기(짝).
- **instagram-image-sizing** — 인스타 카드뉴스 이미지 규격(별도).
- **baobab-excel-design** — 엑셀 산출물 디자인(별도, 표 안전성).
