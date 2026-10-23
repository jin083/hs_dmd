# DMD FPGA Register Map — ABI D201

2026-10-23 구현 기준입니다. 주소는 8-bit, 데이터는 16-bit입니다. 먼저 `0x3E == 0xD201`인지 확인합니다. 이전 실험용 `control_registers.vhd`의 Load2 및 sequence 정의는 이 ABI에 적용되지 않습니다.

기존 TI 레지스터 `0x00–0x28`은 [D4100_registers.vhd](../APPSFPGA_MEM/src/rtl/D4100_registers.vhd)가 처리합니다. `0x10 == 1`이 DLP7000 XGA이며, `0x28 == 0`이 Global 모드입니다. `0x16`의 bit7은 Load4 enable이고 bit8 Load2는 이 경로에 없습니다. 메모리 경로를 선택하면 Load4 출력은 비활성화됩니다.

확장 레지스터는 [memory_playback.v](../APPSFPGA_MEM/src/rtl/memory_playback.v)가 처리합니다. 모든 sequence/timing 엔트리는 정지 상태에서 초기화한 후 사용합니다.

| 주소 | 의미 |
|---|---|
| 0x29 | 직접 패턴 선택: `(pattern_id << 1) | 1` |
| 0x2A | bit0 enable, bit1 one-shot, bit2 index/status clear, bit3 USB start, bit4 TTL arm, bit5 stop |
| 0x2B | sequence 길이 1–2543 |
| 0x2C / 0x2D | sequence write 주소 / 패턴 ID |
| 0x2E | bit15 running, bit14 done, bits13:0 현재 인덱스 |
| 0x2F | bit0 per-entry timing enable; 비활성 시 최소 시간 |
| 0x30 | 업로드할 패턴 **개수** 1–2543 (마지막 ID가 아님) |
| 0x31 write | bit1: 새 업로드 시작. 정지/DDR 준비 상태에서만 허용 |
| 0x31 read | 아래 상태 비트 |
| 0x32 | bit0 메모리 출력 경로 선택; 기본 0 = TI 경로 |
| 0x33 | bit2 TTL arm 별칭; 새로운 host 도구는 0x2A 사용 |
| 0x34 | 수락한 시작 트리거 수 |
| 0x35 / 0x36 / 0x37 | timing write 주소 / low16 / high16(write commit), 단위 5ns |
| 0x38 | 전체 sequence 반복 횟수, 0 = 무한, 1–65535 = 유한 |
| 0x39 | 업로드 완료 프레임 수 |
| 0x3A | 완료한 전체 sequence 수 (65535에서 포화) |
| 0x3B | 현재 패턴 ID |
| 0x3C / 0x3D | MCP 간격 타이머 low16 / high16 (개별 read, 원자적 snapshot 아님) |
| 0x3E | 읽기 전용 ABI 식별자 `0xD201` |

0x31 상태: bit0 DDR calibration 완료, bit1 업로드 중, bit2 preload 완료, bit3 sequence running, bit4 프레임 처리 중, bit5 sequence 완료, bit6 오류, bit7 시작 트리거 무시됨, bit8 새 업로드 가능, bit9 메모리 경로 선택됨.

업로드 및 5개 패턴 반복/TTL 시작 예는 [README](../README.md)를 참고합니다. `0x30`의 값은 마지막 ID가 아닌 **패턴 개수**이며, 데이터 업로드는 1024×768 1-bit 프레임당 98,304 byte입니다.
