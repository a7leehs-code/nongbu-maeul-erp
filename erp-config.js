// 농부마을 ERP 연결 설정
// Supabase 대시보드 → Project Settings → API 에서 두 값을 복사해 넣으면 전자결재가 실사용 모드로 바뀝니다.
// 비워두면 이 브라우저에만 저장되는 실습판으로 동작합니다.
//
// supabaseAnonKey 에는 「anon · public」 키를 넣으세요 — 공개돼도 되는 키입니다(권한은 DB 규칙이 지킵니다).
// 「service_role」 키는 절대 넣지 마세요. 그 키는 모든 권한을 가진 열쇠입니다.
window.ERP_CONFIG = {
  supabaseUrl: "https://ehdsvtrlnuzpbaszygoj.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVoZHN2dHJsbnV6cGJhc3p5Z29qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA3ODg4MDEsImV4cCI6MjEwNjM2NDgwMX0.CsO6lRDmfspJ5EXNJaYyXQt4Dfv5eVkY4e_uH84xkUw"
};
