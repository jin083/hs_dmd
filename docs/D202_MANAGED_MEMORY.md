# D202: 고정 슬롯 메모리 관리와 실험 재생

새 구현은 `feature/managed-pattern-memory`에 있습니다. `hs_dmd`가 RTL과 bitstream을, `../dlpc410`의 `PatternStore`가 API를, `../DMD-FPGA-Test`의 `dmd-test memory`가 실행·검증을 담당합니다. D201 산출물은 보존합니다. Detector/ADC/오실로스코프 드라이버는 이번 범위에 포함하지 않습니다.

## 메모리 계약

- 슬롯 ID는 **0–2542**로 고정합니다. 삭제해도 다른 ID는 이동하지 않습니다. 프레임은 1024×768, 1-bit, 98,304 byte이며 기존 DDR2 `{pattern_id, offset, 2'b00}` 주소 배치를 유지합니다.
- 모든 슬롯은 리셋 후 empty입니다. 초기화 스캔이 끝나기 전 관리 명령과 재생을 허용하지 않습니다.
- 단일 슬롯 쓰기는 해당 슬롯을 writing으로 바꾸고 다른 슬롯을 보존합니다. USB 전송 뒤 **실제 DDR2 읽기 경로와 기존 비동기 FIFO를 통해** 전체 프레임을 다시 읽습니다. FPGA가 USB의 bit/byte 변환을 되돌린 packed-file 바이트에 IEEE/zlib CRC32를 계산하고 호스트 예상값과 비교합니다.
- CRC가 일치한 슬롯만 valid/verified가 됩니다. 실패·취소된 슬롯은 error이고 재사용할 수 있습니다. 교체 실패 시 그 슬롯의 이전 이미지를 복구하는 이중 버퍼 방식은 아닙니다. 다른 슬롯은 유지합니다.
- 여러 슬롯 쓰기는 슬롯마다 완료됩니다. 전체 묶음의 원자적 교체는 지원하지 않습니다. 호스트는 모든 파일의 크기·SHA-256·CRC를 검사한 뒤 첫 전송을 시작합니다.
- delete/clear는 **논리적 무효화**입니다. DDR2의 물리 데이터를 지우거나, 현재 DMD에 남아 있는 이미지를 바꾸지 않습니다.
- 쓰기 중 전송이 끊기면 명시적 abort 또는 약 10초의 FPGA 업로드 제한 시간이 동작합니다. 이미 제출 중인 MIG write burst를 마친 뒤 취소합니다. DDR 읽기 자체가 응답하지 않는 하드웨어 고장은 host timeout으로 보고하며 리셋/연결 진단이 필요합니다.
- 관리·조회·설정은 재생 정지 및 TTL disarm 상태에서 수행합니다. status/타이밍 snapshot은 재생 중에도 읽을 수 있습니다. 자동으로 실행 중인 실험을 중단하고 데이터를 교체하지 않습니다.

D202의 기존 `0x31 bit1` 일괄 업로드 명령은 거부합니다. `DLPC410.upload()`는 D202를 인식하면 CRC 검증을 포함하는 슬롯 업로드를 사용합니다. D201에서도 기존 API를 계속 사용할 수 있습니다. ABI가 다르면 예전 도구가 관리 명령을 잘못 적용하지 않도록 명시적으로 거부합니다.

이 펌웨어 저장소의 standalone `tools/dmd_playback.ps1`은 D201 진단용으로 보존합니다. D202에는 `dlpc410` 0.3.0 API 또는 `dmd-test memory`를 사용합니다.

## 추가 레지스터

`0x3E = 0xD202`. 기존 재생 주소는 유지하되 `0x39`는 현재 valid 슬롯 개수입니다. `0x30`의 연속 패턴 개수로 접근 가능 ID를 판단하지 않습니다. 새 영역은 다음과 같습니다.

| 주소 | 의미 |
|---|---|
| 0x40 | 대상 슬롯 ID |
| 0x41 write | 1=query, 2=write+DDR verify, 3=reverify, 4=delete, 5=clear all, 6=abort write |
| 0x41 read | bit0 busy, bit1 done, bit2 operation error, bit3 USB payload 입력 준비, bit4 directory 초기화 완료 |
| 0x42 | 마지막 조회 슬롯: bits1:0 empty=0/writing=1/valid=2/error=3, bit2 CRC verified |
| 0x43–44 | 호스트 예상 CRC32 low/high |
| 0x45–46 | 검증 직후 실제 DDR CRC32; query 후에는 저장된 슬롯 CRC32 |
| 0x47 / 0x48 | valid 슬롯 개수 / 용량 2543 |
| 0x49 | 오류: 1=busy/armed, 2=ID/명령, 3=invalid slot, 4=CRC, 5=upload timeout, 6=abort, 7=memory/USB, 8=not ready |
| 0x4A–4B | directory generation, 변경 시작·삭제·clear·검증 실패 시 증가 |
| 0x4C–4D | 호스트가 설정하는 session cookie. valid 슬롯이 없고 idle일 때만 쓰기 허용; FPGA 리셋 시 0 |
| 0x4E / 0x4F | 기능 비트 0x000F / 구현 버전 0x0201. 전체 bitstream SHA-256 값은 아님 |
| 0x50 / 0x51 | query 결과의 슬롯 ID / CRC 검사 word 인덱스 |
| 0x60 write/read | bit0 write로 통계 snapshot / snapshot 번호 |
| 0x61 / 0x62 | 정상 종료 패턴 enable / 종료 슬롯 ID |
| 0x63 | bit0 GPIO 동기화 출력 enable, 기본 0 |
| 0x64–65 | snapshot: 현재/최근 실행의 MCP 명령 개수; 종료 패턴 포함 |
| 0x66–67 / 0x68–69 / 0x6A–6B | snapshot: 마지막/최소/최대 MCP 간격, 5ns tick |
| 0x6C–6D | snapshot: 리셋 이후 거부한 시작 요청 수(USB 및 TTL), 포화 카운터 |
| 0x6E | snapshot: none=0/completed=1/stopped=2/error=3 |
| 0x70–71 / 0x72–73 | snapshot: generation / session |

32-bit 값을 개별 low/high 레지스터로 읽습니다. 실행 중 타이밍 통계는 반드시 먼저 snapshot을 요청하고 읽습니다. 단일 프레임 실행에는 MCP 간격 표본이 없으므로 0입니다. 타이밍 카운터의 폭은 32-bit이며 통계는 FPGA 내부 사건을 나타냅니다. 간격은 약 21.47초에서 wrap하므로 그보다 긴 실제 간격을 이 통계로 판별하지 않습니다.

## 재생·실험 계약

실행 시작 시 시퀀스와 종료 패턴의 모든 슬롯을 먼저 검사합니다. 삭제·오류·미검증 ID가 하나라도 있으면 DMD 프레임을 출력하지 않습니다. 슬롯 변경 후에는 이전 시퀀스의 generation이 달라지므로 다시 configure해야 합니다.

기존 임의 순서·패턴별 최소 요청 주기·유한/무한 반복·TTL 시작을 유지합니다. TTL 하나에 전체 목록이 시작하며 재생 중 요청은 대기열에 넣지 않고 거부/계수합니다. TTL arm을 유지하면 유한 완료 후 다음 에지를 기다립니다. preflight 검사 시간은 목록 길이에 비례하므로 trigger-to-first-frame 지연에 포함됩니다.

정상 완료 시 마지막 이미지를 유지하거나 지정한 valid 슬롯을 한 번 더 출력할 수 있습니다. 종료 패턴은 반복 횟수에 추가되지 않습니다. 사용자 stop은 진행 중 프레임을 마무리하고 마지막 이미지를 유지합니다. 오류 시 다른 슬롯을 자동으로 출력하지 않습니다. OFF 이미지 표시는 광원 전원을 끄는 동작과 다릅니다.

GPIO 동기화 출력은 명시적으로 켠 경우에만 기존 GPIO 출력 대신 연결됩니다.

| 출력 | 사건 | 기존 UCF 핀 |
|---|---|---|
| GPIOA_o[0] | preflight 후 첫 프레임 DDR 읽기 시작 | AG17 |
| GPIOA_o[1] | FPGA의 Global MCP 명령 사건 | AG16 |
| GPIOA_o[2] | 정상 시퀀스 및 종료 패턴 완료 | AH12 |

출력은 200MHz 도메인의 100클럭(500ns) 펄스이며 레지스터 파이프라인 지연이 있습니다. 기존 UCF의 LVCMOS25를 유지합니다. 실제 커넥터 배선은 보드 리비전과 회로도를 확인한 뒤 연결합니다. 이 신호나 snapshot을 실제 미러 안정/광학 전환 시간 측정값으로 간주하지 않습니다. 최소 요청 주기 20µs와 기존 전송·안정 시간 제약을 유지합니다.

PC에서 저장하는 실험 JSON은 순서·주기·반복·종료 패턴·동기화 설정과 참조 슬롯 CRC를 포함합니다. 다른 내용이 같은 ID에 저장되어 있으면 configure를 거부합니다. 전원을 다시 켠 뒤 원본 패턴을 재업로드하면 CRC 일치 확인 후 같은 설정을 적용할 수 있습니다. API는 필요하면 예상 session/generation도 검사합니다.

## 검증과 실행

`memory_playback_tb`는 기존 데이터·행·시퀀스·TTL·타이밍·정지 회귀 검사, `pattern_store_tb`는 슬롯 교체·보존·실제 MIG 모델 데이터 손상·CRC·삭제·취소·재사용·preflight·종료 패턴·리셋을 검사합니다. `usb_memory_tb`는 실제 Xilinx FIFO 모델로 USB 변환을 검사합니다. MIG 모델은 물리 DDR2 전기 신호를 검증하지 않습니다.

API와 Test 명령은 [dlpc410 관리 API](https://github.com/jin083/dlpc410/blob/feature/managed-pattern-memory/docs/MANAGED_MEMORY.md) 및 [Test 실행 안내](https://github.com/jin083/DMD-FPGA-Test/blob/feature/managed-pattern-memory/docs/MANAGED_MEMORY.md)를 참고합니다. 새 bitstream의 실제 업로드·DDR2·광학 결과는 시뮬레이션 결과와 별도로 기록해야 합니다.

테스트 파일 구조는 [TESTING](TESTING.md), 빌드 결과와 그래프는 [이번 구현 기록](reports/D202_2026-10-27.md)을 참고합니다.
