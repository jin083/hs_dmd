# 새 bitstream 발열 검토 — 2026-10-23

## 결론과 확인 범위

사용자가 새 bitstream 구성 후 **PCB 전반의 열감이 증가했고, 특히 두 Virtex-5 메인 칩이 뜨거웠다**고 구체화했습니다. 보드 구성상 APPS FPGA(LX50)와 DLPC410으로 구성된 LX30에 해당하는 관찰입니다. **실제 온도·전류와 동일 조건의 이전 bitstream 비교값이 없어 정상 범위인지 또는 고장인지 판정할 수 없습니다.** 이전 합성·타이밍·JTAG 성공은 열 검증을 포함하지 않습니다.

현재 장비는 사용자에 의해 전원이 꺼진 상태입니다. 이번 검토는 소스, ISE 결과, TI/AMD 문서만 사용했습니다. USB/JTAG 접근, 재프로그래밍, FPGA RTL/IP 변경은 수행하지 않았습니다. 검사 대상은 D201 JTAG bitstream SHA-256 `d6e4b40456b90445aa84cf1a2360d2cdee895f4bbc3964dd9364387f5a534a39`입니다.

비교 기준은 두 가지입니다. TI 기본 설계와 이 저장소의 DDR2 확장 설계는 다릅니다. 저장소의 수정 전 커밋 `1f91eb4`에는 이미 메모리 PLL/MIG가 있었습니다. 따라서 DDR2 관련 추가 전력을 이번 버그 수정만의 영향으로 단정하지 않습니다. 사용자가 이전에 사용한 TI bitstream과 해당 소스의 정확한 대응도 아직 확인하지 못했습니다.

## 코드에서 확인한 사항

| 항목 | 확인한 사실 | 발열 해석 |
|---|---|---|
| DDR2 클럭·MIG | `memory_enable=0` 또는 재생 정지가 메모리 PLL/MIG를 끄지 않음. 75/150MHz와 200MHz 기준 클럭 연결 유지 | 업로드 직후에도 추가 소비전력이 생길 수 있음 |
| DDR2 CKE/refresh | MIG에서 초기 지연 이후 CKE 유지, calibration 완료 후 auto-refresh 수행. 현재 연결에 host 제어 self-refresh/power-down 없음 | 패턴 미전송 상태가 DDR2 저전력 모드는 아님 |
| DDR2 I/O | DQ/DM은 `SSTL18_II_DCI`, DQS는 `DIFF_SSTL18_II_DCI` | I/O·종단 회로도 전력 분석 대상. 실제 소모량은 미측정 |
| 시퀀스 BRAM | `index_q < 2543`이면 매 system clock마다 패턴/주기 테이블 읽기. 정지 시 `index_q=0`에도 읽기 조건 활성 | idle read-enable 개선 후보. 출력 데이터가 매번 바뀐다는 뜻은 아님 |
| 자동 패턴 재생 | 새 메모리 경로는 reset 시 `memory_enable=0`, `running=0`, `loaded=0`. DDR 사용자 read/write 명령은 요청 및 상태에 의해 제한 | 초기화 직후 새 패턴 시퀀스가 자동 무한 재생되는 경로는 확인되지 않음 |
| TI 기본 TPG | 기존 레지스터 기본값 `tpg_en=1`, `sw_en=1` 유지 | "호스트 명령 없음"도 DMD 전체가 정지한 상태라고 해석하면 안 됨 |
| DMD 클럭 | TI archive와 `PLL_400.vhd`의 차이는 공백뿐. 200MHz system/400MHz DMD 설정 유지 | 이번 수정으로 DMD PLL 배수를 높인 근거 없음 |
| 자동 과열 차단 | `OverTempPowerDown:Disable`, `JTAG_SysMon:Enable` | 과열 시 자동 차단을 보장하지 않음. 이전 저장소 설정을 계승 |

근거 소스:

- [클럭 연결](../APPSFPGA_MEM/src/rtl/appsfpga_io_400_a.vhd), [메모리 PLL](../APPSFPGA_MEM/src/rtl/PLL_mem_150.vhd)
- [MIG 연결](../APPSFPGA_MEM/src/rtl/MEM_IO_Verilog.v), [DDR 사용자 명령 조건](../APPSFPGA_MEM/src/rtl/ddr_pattern_engine.v)
- [시퀀스 reset 및 BRAM 읽기](../APPSFPGA_MEM/src/rtl/memory_playback.v)
- [MIG CKE 초기화](../APPSFPGA_MEM/ipcore_dir/mig_top/user_design/rtl/ddr2_phy_init.vhd), [refresh 제어](../APPSFPGA_MEM/ipcore_dir/mig_top/user_design/rtl/ddr2_ctrl.vhd)
- [DDR2 I/O 표준](../APPSFPGA_MEM/src/rtl/ddr2_sdram.ucf), [TI 기본 레지스터](../APPSFPGA_MEM/src/rtl/D4100_registers.vhd)
- [bitgen 옵션](../APPSFPGA_MEM/appsfpga.ut), [실제 JTAG bitgen 로그](../artifacts/dmd-20261023/reports/appsfpga_repaired_jtag.bgn)

## ISE 결과의 의미와 한계

[MAP 보고서](../artifacts/dmd-20261023/reports/appsfpga_map.mrp)의 사용량은 register 6,601/28,800, LUT 6,007/28,800, BRAM/FIFO 39/48, PLL 3/6, BUFG 12/32, IOB 378개입니다. 자원 사용률로 온도를 계산하거나 발열 정상 여부를 판정할 수는 없습니다. 입력 전압, toggle activity, 종단, 냉각 조건 등이 필요합니다.

같은 보고서의 `Initializing temperature to 85.000 Celsius`는 구현 도구의 기본 분석 조건입니다. **측정된 칩 온도 85°C라는 뜻이 아닙니다.** 실제 온도 로그, rail 전류 측정, 해당 동작 조건의 XPower 전력 분석은 아직 없습니다. 전력 추정에는 현실적인 activity와 환경 입력이 필요합니다([AMD UG440](https://www.xilinx.com/support/documents/sw_manuals/xilinx2022_1/ug440-xilinx-power-estimator.pdf)).

bitgen DRC의 active-net PULLDOWN 두 건은 TI archive에도 있는 GPIOA 출력 설정입니다. 이 경고만으로 외부 출력끼리 충돌하거나 큰 발열이 발생한다고 결론내릴 수 없습니다. 새로 LOC를 복구한 EXP1 세 출력과 연결된 외부 장비가 있다면 해당 장비의 출력 방향·전압도 확인해야 합니다. PCB의 실제 배선/전원/외부 연결 오류는 FPGA DRC만으로 배제할 수 없습니다.

## 부품별로 구분할 사항

### 두 Virtex-5 칩 발열 보고에 따른 추가 검토

TI 설명서 §2.1.1–2.1.2에서 APPS FPGA는 LX50, DLPC410은 TI 구성으로 동작하는 LX30임을 확인했습니다. [실제 프로그래밍 기록](../artifacts/dmd-program-20261023/programming_result.json)은 LX50만 구성했고 LX30/PROM은 재기록하지 않았음을 보여 줍니다. LX30의 열감 변화가 있다고 해서 그 칩의 bitstream이 바뀐 것은 아닙니다.

코드 비교 결과:

- 새 구성 후 reset 값은 `memory_enable=0`, `usb_tpg_en=1`, `usb_switch_en=1`입니다. 따라서 초기화가 끝나면 출력 mux는 기본 TPG 경로를 선택할 수 있습니다. 호스트가 이미지를 올리지 않았다는 사실만으로 두 FPGA의 데이터 전송이 없는 상태라고 판단하지 않습니다.
- DLP7000의 A/B 데이터 클럭은 계속 출력됩니다. `PLL_400.vhd`, `DMD_control.vhd`, LVDS/single-ended serializer 파일은 TI archive와 주석·공백을 제외하면 동일합니다. TPG 기본 활성값도 TI archive에 있습니다. 이 비교로 새 클럭 과속이나 새 TPG 동작을 발열 원인으로 확정할 수는 없습니다.
- `INIT_ACTIVE=1`인 동안에는 IO 블록이 training 패턴을 출력합니다. TI는 일반적인 초기화 소요 시간을 약 220ms로 설명합니다. 장시간 high 유지 또는 반복 reset 여부를 다음 실기에서 관찰해야 하며, 현재 그런 현상이 발생했다는 측정 증거는 없습니다([DLPC410 datasheet §8.3.6.1, §8.4.1](https://www.ti.com/lit/ds/symlink/dlpc410.pdf)).
- 현재 `stop()`은 D201 재생 제어 레지스터를 정지시키며 TPG 제어 레지스터 `0x24`를 변경하지 않습니다. 특히 구성 직후 아직 TI 경로가 선택된 상태에서는 `stop()`만으로 기본 TPG를 끌 수 없습니다. 완전한 idle 비교에는 TPG 상태와 memory 경로 선택 상태를 함께 확인해야 합니다.

원인 후보는 (1) LX50의 DDR2/MIG 추가 부하 및 보드를 통한 열 전달, (2) 두 FPGA 사이 데이터/TPG/초기화 상태가 이전 관찰과 다른 경우, (3) 보드 입력 전원·전원 레일·냉각 조건입니다. 이는 측정할 가설이며, 두 칩의 실제 소비전력이 모두 증가했다고 확인한 것은 아닙니다. DDR2만으로 두 칩의 발열을 설명하거나 두 칩이 뜨겁다는 이유만으로 단락을 단정하지 않습니다.

다음 비교 기록에는 **LX50 온도, LX30 온도, 주변/PCB 온도, 보드 입력 전류, 경과 시간, TPG 상태, `INIT_ACTIVE`, DDR2 calibration 상태**를 각각 포함합니다. 이전 TI 구성과 신규 구성에서 시작 온도·DIP·GUI/TPG 설정·냉각 조건을 맞춥니다. `INIT_ACTIVE` low는 초기화 절차 완료 표시이며 모든 전기적 동작의 정상 여부를 보장하지 않습니다.

TI 문서는 U11/U5 주변의 뜨거운 표면을 명시하며, 기본 EVM 설계에 DDR2 memory controller가 포함되지 않는다고 설명합니다. 따라서 기본 보드도 열이 날 수 있지만, 새 설계 후의 온도 증가가 정상이라고 보장하는 근거는 아닙니다([TI DLPU040, 현재 제공 PDF는 Rev. D, pp.4,10](https://www.ti.com/lit/ug/dlpu040c/dlpu040c.pdf)).

- LX50(APPS FPGA)이 뜨거운 경우: 추가 메모리 클럭/MIG/BRAM/I/O 전력을 우선 비교합니다.
- DDR2 모듈 또는 전원 레귤레이터인 경우: DDR2 초기화 상태, 모듈/전원 조건과 해당 rail 부하를 확인합니다.
- DLPC410/LX30 또는 DMD 쪽인 경우: 실제 출력 activity, TPG/초기화 상태와 부품 자체의 열 조건을 따로 확인합니다. 앞서 JTAG로 기록한 대상은 LX50뿐입니다.

## 온도 확인 방법

Virtex-5 System Monitor는 설계에 RTL instance가 없어도 JTAG에서 온도/VCCINT/VCCAUX를 읽을 수 있습니다. ChipScope Pro에는 센서 표시와 시간 기록 기능이 있습니다. 다만 보드에 필요한 analog 전원·reference 연결이 되어 있어야 합니다. 현재 보드에서 유효한 센서값이 읽히는지는 아직 확인하지 않았습니다([AMD UG192, pp.14–15,63–65](https://docs.amd.com/v/u/en-US/ug192)).

현재 옵션은 JTAG System Monitor 접근을 허용하지만 자동 과열 차단은 비활성입니다. UG192의 약 125°C OT 기능은 정상 운전 목표 온도가 아닙니다. DS202의 권장 접합온도 범위는 commercial 0~85°C, industrial -40~100°C이며 실제 부품 등급 확인이 필요합니다. 케이스 표면 온도와 die 접합온도도 구별합니다([AMD DS202, Tables 1–2](https://docs.amd.com/v/u/en-US/ds202)).

위 generic Virtex-5 등급 설명을 DLPC410의 한계값으로 그대로 적용하지 않습니다. DLPC410에는 TI가 별도 전기·열 조건을 지정하고 있으므로 해당 부품의 datasheet §7을 우선 확인합니다. 두 칩의 표면 온도를 같은 기준으로 합격/불합격 처리하지 않습니다([DLPC410 datasheet](https://www.ti.com/lit/ds/symlink/dlpc410.pdf)).

## 다음 실기 시험의 순서

1. 뜨거웠던 부품의 위치/표기, 패턴 전송 전후 여부, 시간 경과, DDR2/EXP 연결 상태를 기록합니다.
2. 동일한 냉각·주변 온도·DIP/TPG·연결 조건으로 TI 기본 bitstream과 신규 bitstream을 비교합니다. 매번 시작 온도와 경과 시간을 맞춥니다.
3. 우선 **신규 bitstream 구성만 하고 USB 패턴 전송을 하지 않은 상태**에서 온도 및 보드 입력 전류를 기록합니다. 여건이 되면 1.0V core 및 1.8V DDR rail도 계측합니다.
4. 온도 상승이 제한되고 정상 조건인지 확인한 뒤 패턴 업로드 → 단일 표시 → 저속 유한 반복 순서로 진행합니다. 발열 원인을 확인하기 전에는 고속 무한 반복 시험을 앞세우지 않습니다.
5. `Calibrated`, FPGA 오류 상태와 실제 온도를 별도로 남깁니다. calibrated가 완료되지 않았다면 이미지 테스트를 진행하기 전에 메모리 초기화 상태를 조사합니다.

소프트웨어 `stop`은 재생 정지이며 전원 차단이나 메모리 저전력 모드가 아닙니다. 온도가 계속 빠르게 오르거나 부품의 허용 범위에 접근하면 시험을 중단합니다. 손의 감각으로 허용 온도를 판단하지 않습니다.

개선 후보는 idle BRAM read-enable 제한, 적절한 온도 감시/경고·정지 정책, 필요할 경우 MIG가 지원하는 저전력 방식입니다. 메모리 클럭을 임의로 끄면 데이터 유지·refresh·calibration에 영향을 줄 수 있으므로, 기존 MIG와 주소 구조를 유지하며 별도 설계·시뮬레이션·ISE 타이밍·실기 검증을 거쳐야 합니다. 현재 검증 bitstream은 이 조사 과정에서 변경하지 않았습니다.
