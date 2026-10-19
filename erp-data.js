// 농부마을 ERP 지도 데이터 — erp-map.html(지도)과 erp-console.html(작업대)이 함께 씁니다.
// 칸의 상태(status: done / inprogress / todo)를 바꾸면 두 화면의 숫자가 같이 바뀝니다.
window.ERP_CATEGORIES = [
  {
    code: "전사", anchor: "cat-all", name: "⭐ 전사 공통",
    sub: "대표·직원 전원이 매일 보는 항목.",
    items: [
      { icon:"📅", name: "회사 일정판 (첫 칸)", where: "구글 캘린더", often: "상시", urgency: "상",
        order: "2회차", status: "done", file: "erp-schedule.html" },
      { icon:"📝", name: "전자결재", where: "기안 → 대표 · 승인되면 근태·연차 집계에 반영 (실습판 · 이 브라우저에 저장)", often: "수시", urgency: "중",
        order: "4회차", status: "inprogress", file: "erp-approvals.html" },
      { icon:"💬", name: "마을톡 (사내메신저)", where: "1:1·단톡·전체방 · 대화는 회사 기록으로 남음 (실습판 · Supabase 연결 전)", often: "매일", urgency: "중",
        order: "4회차", status: "inprogress", file: "erp-talk.html" },
      { icon:"👥", name: "고객관리", where: "홈페이지 문의 → DB 저장 → 직원이 확인·응대 (로그인 필요)", often: "매일", urgency: "중",
        order: "3회차", status: "inprogress", proposed:true, file: "erp-customers.html" }
    ]
  },
  {
    code: "돈", anchor: "cat-money", name: "① 돈",
    sub: "돈이 새는 지점을 보는 묶음. 7·8회차(회계·재무)에서 채운다.",
    items: [
      { icon:"🥚", name: "계란 출하량/매출 집계", where: "엑셀 일부 + 정리 안 함", often: "정산 때마다", urgency: "상", order: 1, status: "todo" },
      { icon:"💰", name: "거래처별 판매 단가", where: "엑셀/기억", often: "수시", urgency: "중", order: null, status: "todo" },
      { icon:"🧾", name: "거래처 정산서 작성", where: "수기/엑셀, 매번 번거로움", often: "월 1회", urgency: "중", order: null, status: "todo" },
      { icon:"💳", name: "미수금 현황", where: "해당 없음 (즉시결제)", often: "-", urgency: "하", order: null, status: "todo" },
      { icon:"🌾", name: "사료 등 매입 대금", where: "즉시 현금/이체, 별도 기록 없음", often: "발주 때마다", urgency: "하", order: null, status: "todo" },
      { icon:"💵", name: "급여 지급 내역", where: "전원 월급 고정", often: "월 1회", urgency: "하", order: null, status: "todo" },
      { icon:"📄", name: "세금계산서 발행", where: "대표/직원 직접 처리", often: "월/분기", urgency: "중", order: null, status: "todo", proposed:true },
      { icon:"📊", name: "자금(현금흐름) 현황", where: "미논의", often: "수시", urgency: "중", order: null, status: "todo", proposed:true }
    ]
  },
  {
    code: "일", anchor: "cat-work", name: "② 일",
    sub: "매일 반복되는 현장 업무 기록. 수업에서 다루지 않아 혼자 붙이는 칸 — 오늘 순서를 전부 정했다.",
    items: [
      { icon:"🐔", name: "산란율/폐사율 기록", where: "동별 계란·폐사 입력 → 산란율·폐사율 자동 계산 (실습판 · 이 브라우저에 저장)", often: "매일", urgency: "상", order: 3, status: "inprogress", file: "erp-eggs.html" },
      { icon:"📇", name: "거래처 목록/연락처", where: "지도에서 등록·수정 (이 컴퓨터에 저장)", often: "수시", urgency: "중", order: 6, status: "inprogress", file: "erp-clients-map.html" },
      { icon:"🧴", name: "방역 소독 스케줄 체크", where: "수기/기억, 매번 번거로움", often: "정기", urgency: "중", order: 7, status: "todo" },
      { icon:"🔍", name: "폐사 원인 기록", where: "숫자만 기록, 원인 분석 없음", often: "발생 시", urgency: "중", order: 8, status: "todo", proposed:true },
      { icon:"🚚", name: "판매처별 배송/납품 일정", where: "미논의", often: "수시", urgency: "중", order: 9, status: "todo", proposed:true }
    ]
  },
  {
    code: "물건", anchor: "cat-goods", name: "③ 물건",
    sub: "사료·계란·시설의 흐름. 이것도 혼자 붙이는 칸 — 오늘 순서를 전부 정했다.",
    items: [
      { icon:"🌽", name: "사료 재고량", where: "담당 직원 눈대중 확인 → 구두 보고", often: "발주 필요시 수시", urgency: "상", order: 4, status: "todo" },
      { icon:"📦", name: "사료 발주", where: "대표 보고받고 결정", often: "정기", urgency: "상", order: 5, status: "todo" },
      { icon:"🥚", name: "계란 등급별(왕란/특란/대란) 재고", where: "세분화는 하나 방식 불명", often: "매일", urgency: "중", order: 10, status: "todo" },
      { icon:"🔧", name: "장비/설비 점검·수리 이력", where: "미논의", often: "수시", urgency: "중", order: 11, status: "todo", proposed:true },
      { icon:"🏚️", name: "계사(농장) 시설 현황", where: "계사 4동 (1~4동)", often: "수시", urgency: "하", order: 12, status: "todo" }
    ]
  },
  {
    code: "사람", anchor: "cat-people", name: "④ 사람",
    sub: "근태·급여·채용. 6회차(채용·노무)에서 채운다.",
    items: [
      { icon:"⏰", name: "직원 근태(출퇴근/휴가)", where: "구두로 파악, 기록 없음", often: "매일", urgency: "중", order: null, status: "todo" },
      { icon:"💵", name: "급여 정산", where: "전원 월급 고정", often: "월 1회", urgency: "하", order: null, status: "todo" },
      { icon:"🧑‍💼", name: "직원별 담당 업무/권한", where: "미논의", often: "수시", urgency: "중", order: null, status: "todo", proposed:true },
      { icon:"📋", name: "채용/인력 계획", where: "미논의", often: "수시", urgency: "하", order: null, status: "todo", proposed:true }
    ]
  },
  {
    code: "기한", anchor: "cat-deadline", name: "⑤ 기한",
    sub: "놓치면 과태료로 이어지는 날짜들. 9회차(정부지원사업)와 연결된다.",
    items: [
      { icon:"💉", name: "방역 접종 일정", where: "수기 장부/메모, 놓친 경험 있음", often: "접종 주기마다", urgency: "상", order: 2, status: "todo" },
      { icon:"📜", name: "가축사육업 허가·등록 갱신", where: "미논의", often: "수시", urgency: "중", order: null, status: "todo", proposed:true },
      { icon:"🧮", name: "부가세 등 세금 신고 마감", where: "직접 처리, 관리 방식 불명", often: "분기/반기", urgency: "중", order: null, status: "todo", proposed:true },
      { icon:"🛡️", name: "가축재해보험 등 갱신", where: "미논의", often: "수시", urgency: "중", order: null, status: "todo", proposed:true }
    ]
  },
  {
    code: "알리기", anchor: "cat-promo", name: "⑥ 알리기",
    sub: "밖에 어떻게 보이는지. 3·5회차(홈페이지·홍보)에서 채운다.",
    items: [
      { icon:"🛒", name: "온라인 판매 채널 관리", where: "미논의 (직배 판매 중)", often: "-", urgency: "중", order: null, status: "todo", proposed:true },
      { icon:"📱", name: "홈페이지/SNS 운영", where: "GitHub Pages로 배포 완료", often: "수시", urgency: "하", order: "3회차", status: "done", proposed:true, file: "https://a7leehs-code.github.io/nongbu-maeul-erp/" },
      { icon:"📸", name: "상품 소개/원산지 콘텐츠", where: "미논의", often: "수시", urgency: "하", order: null, status: "todo", proposed:true }
    ]
  }
];
