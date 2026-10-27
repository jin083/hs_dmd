# ChipScope Pro로 Virtex-5 온도 읽기

대상은 DLPLCRC410EVM의 APPS FPGA `xc5vlx50`와 DLPC410 역할의 `xc5vlx30`입니다. Virtex-5의 System Monitor는 내부 접합온도와 VCCINT/VCCAUX 전압을 JTAG로 읽습니다. 외부 ADC나 photodiode 측정 장비는 필요하지 않습니다.

2026-10-23 확인 범위: 로컬 ISE 14.7 가상머신에 Analyzer 실행 파일이 있고, 새 LX50 bitstream의 `JTAG_SysMon:Enable` 설정을 확인했습니다. **사용자가 보드 전원을 내린 상태이므로 실제 센서 읽기는 수행하지 않았습니다. 두 칩의 센서 사용 가능 여부는 아직 미확인입니다.**

2026-10-26 추가 확인: 전원이 켜져 있을 때 iMPACT의 자동 System Monitor 조회에서 LX50/LX30 모두 `-273.00 C`, `VCCINT=0.000 V`, `VCCAUX=0.000 V`가 나왔습니다. 구성 전후 로그가 동일하며 **유효한 온도 측정값이 아닙니다.** 이 값과 Over-Temperature 비트 0으로 발열 안전성을 판단하지 않습니다. Analyzer에서의 별도 초기화·측정과 보드 센서 배선 확인은 남아 있습니다. 이후 사용자가 전원을 내렸으므로 추가 장비 접근은 하지 않았습니다. [원본 iMPACT 로그](../artifacts/dmd-program-20261026/impact_program.log)

## 사용 조건

- Virtex-5 System Monitor는 RTL에 인스턴스를 추가하지 않아도 JTAG에서 접근할 수 있습니다. 온도를 읽기 위한 재합성이나 ILA 삽입은 필요하지 않습니다.
- 보드의 AVDD/AVSS 및 VREFP/VREFN 등 센서 전원·기준전압 배선이 설명서 조건을 만족해야 합니다. 전용 전원과 입력을 접지해 기능을 비활성화한 보드에서는 소프트웨어 설정만으로 사용할 수 없습니다. 현재 보드 리비전의 이 배선은 확인하지 못했습니다.
- LX50의 bitgen 설정은 [appsfpga.ut](../APPSFPGA_MEM/appsfpga.ut)의 `JTAG_SysMon:Enable`입니다. LX30의 TI 구성에서도 센서 접근을 허용하는지는 실제 연결 시 별도로 확인합니다. LX30/PROM을 온도 측정 목적으로 다시 프로그램하지 않습니다.

근거: [AMD UG192, pp.14–17 및 63–65](https://docs.amd.com/v/u/en-US/ug192).

## 1. 연결 준비

보드 설명서의 전원·연결 순서를 따릅니다. 측정 시에는 보드에 전원이 공급되어야 합니다. 기존 FPGA 업로드에 사용한 Platform Cable USB를 보드 JTAG H1에 연결하고, VirtualBox의 **Devices → USB**에서 케이블을 ISE 가상머신에 연결합니다. 가상머신 이름은 `ISE_14.7_VIRTUAL_MACHINE`입니다.

JTAG 케이블과 D4100/FX2 패턴 전송 USB는 별개입니다. System Monitor 측정은 JTAG를 이용합니다. iMPACT 등 케이블을 사용하는 프로그램은 연결을 해제하거나 종료합니다.

## 2. Analyzer 실행

ISE 가상머신의 Linux 데스크톱에서 터미널을 열고 실행합니다. 아래 명령은 Windows PowerShell용 명령이 아닙니다.

```bash
source /opt/Xilinx/14.7/ISE_DS/settings64.sh
analyzer
```

설치된 실행 파일은 `/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64/analyzer`입니다.

## 3. 케이블과 FPGA 선택

1. **JTAG Chain → Xilinx Platform USB Cable**을 엽니다.
2. 연결된 케이블을 선택합니다. 이전 iMPACT 기록에서는 `USB21`이었으나 재연결 후 번호가 달라질 수 있습니다. 기본 3 MHz부터 사용할 수 있습니다.
3. 연결 후 장치 검색 결과에서 부품 이름을 확인합니다. `xc5vlx50`은 APPS FPGA, `xc5vlx30`은 TI DLPC410 구성의 FPGA입니다. iMPACT의 기존 체인 위치는 각각 1과 2였지만, 다른 프로그램의 표시 번호를 그대로 가정하지 않습니다.
4. 각 장치 아래 **System Monitor Console**을 우클릭하고 뷰어를 여는 항목을 선택합니다. 온도 확인에는 **Configure** 명령이나 bitstream 선택이 필요하지 않습니다.

케이블 설정과 자동 체인 검색은 [AMD UG029, pp.60–63](https://docs.amd.com/v/u/en-US/chipscope_pro_sw_cores_ug029)을 따릅니다.

## 4. 온도와 전압 확인

센서 목록에서 Temperature를 °C로 표시합니다. VCCINT와 VCCAUX도 함께 기록합니다. **JTAG Scan Rate**는 우선 `1 s`로 설정합니다. 수동 확인은 `Manual Scan`을 선택하고 **Sample Once (S!)**를 사용합니다.

현재값, 센서가 기록한 최댓값/최솟값, Analyzer가 수집한 값의 통계는 의미가 다릅니다. 비교 기록에는 현재값과 경과 시간을 사용하고 어떤 통계인지 남깁니다. `Invalid Data` 표시나 비정상적인 고정값을 유효한 온도로 기록하지 않습니다.

측정값은 칩 내부 접합온도이며 PCB·패키지 표면 온도와 다릅니다. UG192는 내장 온도 센서의 최대 오차를 ±4°C로 설명합니다. 장치별 허용 범위와 측정 오차를 고려해 해석합니다. [AMD UG192, pp.16–17](https://docs.amd.com/v/u/en-US/ug192)

## 5. CSV 기록

1. 해당 System Monitor 창을 선택합니다.
2. **System Monitor → Setup Logging**에서 저장 파일과 CSV 형식을 선택합니다.
3. **System Monitor → Enable Logging**을 켭니다.
4. 두 칩을 읽을 수 있다면 파일을 `lx50.csv`, `lx30.csv`처럼 구분합니다. 파일이 생성되고 새 행이 추가되는지 확인합니다.

Windows와 공유하려면 `/home/ise/C_DRIVE/Users/wlsgu/project/2026/DMD/DMD-FPGA-Test/runs/thermal/`처럼 실제로 생성해 둔 폴더를 선택할 수 있습니다. `runs/`는 Git에서 제외됩니다.

표시·주기·CSV 메뉴의 근거는 [AMD UG029, pp.79–81](https://docs.amd.com/v/u/en-US/chipscope_pro_sw_cores_ug029)입니다.

## 비교할 조건

TI 기본 bitstream과 새 bitstream에 대해 같은 시작 온도·주변 온도·냉각·DIP·TPG 조건을 맞추고, 구성 이후 경과 시간과 두 칩의 온도를 기록합니다. 가능하면 PCB 온도와 보드 입력 전류도 함께 남깁니다. 센서 전압 읽기는 전류나 소비전력 측정이 아닙니다.

우선 패턴을 업로드하지 않은 상태를 비교한 뒤, 발열 상태를 확인하고 단일 이미지와 저속 유한 반복으로 진행합니다. `stop`은 DDR2 클럭을 끄거나 기본 TPG를 비활성화하는 기능이 아니므로 전체 보드 idle로 간주하지 않습니다. 구체적인 비교 항목과 제한은 [발열 검토 기록](THERMAL_REVIEW_2026-10-23.md)을 따릅니다.

## 센서가 안 보이거나 값이 유효하지 않을 때

| 증상 | 확인할 사항 |
|---|---|
| 케이블을 찾지 못함 | VM USB 연결, 케이블 드라이버, iMPACT의 케이블 점유 |
| FPGA 체인을 찾지 못함 | 보드 전원, JTAG 연결·방향, 케이블 속도 |
| 체인은 보이지만 System Monitor를 사용할 수 없음 | 칩별 JTAG System Monitor 접근 설정 및 보드의 센서 전원·기준전압 배선 |
| `Invalid Data` 또는 비정상 고정값 | 측정값으로 채택하지 않고 센서 전원·기준전압·설정을 확인 |
| 한 칩만 읽힘 | 그 칩의 값만 기록하고 다른 칩은 미측정으로 표시. 필요하면 외부 표면 온도 측정을 별도로 기록 |

현재 Python `dmd_ctrl.memory.status()`는 FPGA D201 동작 상태를 반환하며 System Monitor 온도는 포함하지 않습니다. ChipScope CSV 기록은 별도 계측 경로입니다.

## 2026-10-27: VM GUI가 실행 직후 닫히는 경우

Windows에서 조회한 ISE VM은 `VMState="running"`, `SessionName="headless"`였습니다. 기존 합성/JTAG 작업은 `VBoxManage guestcontrol`로 실행했습니다. 백그라운드 VM이 실행 중인 상태에서도 GUI를 사용할 수 있으며, GUI가 즉시 종료되는 현상을 정상적인 headless 동작으로 설명할 수는 없습니다. 닫히는 창이 VirtualBox Manager인지 VM 콘솔인지, 보안 차단인지 프로그램 오류인지는 아직 확인하지 않았습니다. 사용자의 요청에 따라 상세 원인 조사나 보안 설정 변경은 하지 않았습니다. [Oracle의 GUI/CLI 구분](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/Introduction.html), [실행 중 VM에 GUI 연결](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/remotevm.html)

GUI가 복구되면 실행 중인 ISE VM을 선택해 **Show**로 열고, 앞 절차대로 ChipScope Analyzer의 System Monitor에서 LX50/LX30을 각각 확인합니다. 새 VM을 중복 실행하거나 FPGA를 다시 구성할 필요는 없습니다. 다만 현재 센서 사용 가능 여부는 확인되지 않았습니다. `-273°C/0V`는 유효한 온도가 아니며, GUI 복구만으로 측정 성공이 보장되지는 않습니다. 계속 같은 값이면 센서 전원·기준전압 배선과 설정 확인이 필요합니다. 외부 접촉 온도계/열화상 장비를 사용할 경우에는 **패키지 표면 온도**로 기록하고 내장 센서의 접합온도와 구분합니다.

보안팀에는 다음 내용을 전달할 수 있습니다.

> DMD FPGA 개발 장비의 온도를 Xilinx ISE 14.7 ChipScope Analyzer로 확인하려고 합니다. Windows에서 Oracle VirtualBox GUI를 실행하면 창이 즉시 종료됩니다. 기존 VM `ISE_14.7_VIRTUAL_MACHINE`은 headless 상태로 실행 중이고, `VBoxManage guestcontrol`을 통한 내부 ISE 명령 실행은 동작했습니다. 보안 정책 차단 여부를 확인하고, 차단된 경우 해당 설치본의 GUI 실행과 Xilinx Platform USB Cable 전달을 승인된 범위에서 허용해 주시기 바랍니다. 현재 보안 차단이 원인으로 확정된 상태는 아닙니다.

확인 대상 Windows 실행 파일은 `C:\Program Files\Oracle\VirtualBox\VirtualBox.exe`와 `VirtualBoxVM.exe`입니다. 센서 프로그램은 VM 내부 `/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64/analyzer`이며, Xilinx 케이블은 VM에, D4100 패턴 USB는 Windows에 연결합니다. 원격 데스크톱 포트 개방이나 보안 기능 전체 해제가 필요한 작업으로 요청하지 않습니다.
