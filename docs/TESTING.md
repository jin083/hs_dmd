# 테스트와 산출물 구조

```text
APPSFPGA_MEM/src/rtl/                합성 대상 RTL
APPSFPGA_MEM/src/sim/
  harness/playback_harness.vh        공통 클럭·FIFO/MIG 연결·프레임 scoreboard
  mig_user_model.v                   지연/역압력이 있는 MIG user-port 모델
  memory_playback_tb.v               순서·반복·TTL·타이밍·STOP 회귀 시나리오
  pattern_store_tb.v                 슬롯·CRC·교체·삭제·abort·snapshot 시나리오
  usb_memory_tb.vhd                  실제 FIFO 모델을 통한 USB 경계 검사
tools/
  ise_build.py                      소스 복사·해시·합성·타이밍 gate·bitgen
  ise_test.py                       자체 검사 ISim 실행 및 로그 수집
  ise_program.py                    파일 검사 및 명시적 JTAG 구성
  reports/plot_validation.py         저장된 증거에서 PNG/SVG 그래프 생성
  reports/collect_validation.py      원본 로그에서 수치·CSV·출처 해시 추출
  tests/                            JTAG 도구의 오프라인 로그 판정 테스트
docs/reports/                       결과 해석과 한계
artifacts/                          선택한 빌드·로그·해시·그래프
runs/                               사용자의 실행 기록; 정리 시 자동 삭제하지 않음
```

두 Verilog 테스트는 공통 harness를 include하고 각자 시나리오만 정의합니다. `ise_test.py`는 `.vh`를 테스트 폴더에 복사하지만 독립 컴파일 단위로 등록하지 않습니다. RTL 파일뿐 아니라 harness와 모델의 SHA-256도 저장합니다.

```powershell
python tools/ise_test.py --build C:/Temp/dmd-d202-tests-final
python tools/ise_build.py --stage implement --build C:/Temp/dmd-d202-build-final
python -m unittest discover -s tools/tests -v
```

새 출력 폴더를 사용합니다. 빌드 도구는 `All constraints were met` 확인 전에는 bitgen을 실행하지 않습니다. `pattern_store_tb`는 DDR 모델의 저장값을 직접 손상시켜 CRC 검출을 확인하며, 마지막 ID 2542의 물리 주소도 검사합니다.

검증 층은 서로 대체되지 않습니다.

| 층 | 확인 범위 | 확인하지 않는 것 |
|---|---|---|
| API mock | 입력 검증, 명령 순서, 상태/실험 계약 | DLL·USB·RTL 실행 |
| PowerShell register fixture | 실제 PS 명령 본문의 레지스터·CRC 처리 | TI DLL·실제 장치 |
| ISim | RTL, 실제 Xilinx FIFO 모델, 모델 DDR 데이터 | DDR2 전기 신호, 광학·온도 |
| ISE 구현 | 선택 UCF에 대한 배치·배선 타이밍 및 bitgen DRC | 실기 정상 동작 |
| 보드 시험 | USB, DDR readback CRC, 실제 재생 | photodiode 검증 전 광학 전환 시간 |

Detector/ADC/오실로스코프 연동은 후속 단계입니다. 현재 snapshot과 GPIO는 FPGA 명령 사건을 나타냅니다.
