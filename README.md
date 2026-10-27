# DLP7000 DDR2 pattern playback

이 저장소는 DLPLCRC410EVM의 Virtex-5 **xc5vlx50-1-ff1153**에서 DLP7000을 제어합니다. TI 기본 USB/TPG 경로에 DDR2 패턴 저장 및 시퀀스 재생 경로를 추가합니다.

수정 배경, 검증 범위, 실제 업로드 결과와 남은 작업은 [2026-10-23 작업 보고서](docs/UPDATES_2026-10-23.md)에 정리했습니다.

Python 제어 패키지는 별도 [dlpc410 저장소의 `feature/ddr2-memory-api`](https://github.com/jin083/dlpc410/tree/feature/ddr2-memory-api)에서 관리합니다. `dmd_ctrl.memory`가 BMP 변환, DDR2 업로드, 개별 이미지 표시, 순서·속도·횟수·TTL 시퀀스 API를 제공합니다. 이 저장소에 만들었던 Python 패키지는 [실제 패키지 저장소로 이동](docs/DLPC410_PYTHON_API.md)했습니다. 숫자 1~10 BMP와 실행 CLI는 [DMD-FPGA-Test 브랜치](https://github.com/jin083/DMD-FPGA-Test/tree/feature/dlp7000-memory-tests)에 있으며, 가상환경 없이 `pyproject.toml`로 설치합니다. Detector 측정은 후속 계획입니다.

## 현재 상태 (2026-10-27)

**10월 26일 수정 bitstream을 LX50에 JTAG 업로드했습니다.** 직접 iMPACT 명령과 `python tools/ise_program.py --program` 두 방식 모두 LX50→LX30 체인을 확인한 뒤 위치 1만 기록했으며, DONE=1, startup 완료=1, CRC/ID 오류=0을 확인했습니다. LX30과 PROM은 기록하지 않았습니다. [10월 27일 기록](docs/UPDATES_2026-10-27.md)과 [원본 결과](artifacts/dmd-program-20261027/programming_result.json)를 보관했습니다. 직접 업로드 후 D4100 패턴 USB 조회는 장치 0개였으므로 **수정 bitstream의 D201 응답·DDR2 업로드·광학 재검증은 남아 있습니다.**

앞선 10월 26일에는 10월 23일 bitstream에서 SW2 후 D201/calibration, 숫자 10장 업로드와 단일 프레임 완료를 확인했지만, 사용자가 고정된 깨진 영상/좌표 이상을 확인했습니다. 이후 신규 DDR2 경로가 TI USB FIFO burst의 마지막 워드를 잘못 저장하던 오류를 재현·수정하고 USB 및 메모리 재생 회귀 테스트를 통과했습니다. 이번에 기록한 파일은 이 수정이 포함된 버전입니다. 완료 플래그는 콘텐츠 무결성을 보장하지 않으며, 원인과 빌드 검증 범위는 [2026-10-26 보고서](docs/UPDATES_2026-10-26.md)를 참고합니다.

## 이전 검증 기록 (2026-10-23)

사용자가 새 bitstream 구성 후 발열 증가를 보고했습니다. [발열 검토 기록](docs/THERMAL_REVIEW_2026-10-23.md)에 상시 DDR2 동작, idle BRAM 읽기, 과열 차단 설정 및 온도 비교 절차를 정리했습니다. 실제 온도·소비전력은 미측정이며 합성/타이밍 통과가 열 검증을 의미하지 않습니다. 내장 센서 연결·표시·CSV 기록은 [ChipScope 온도 측정 안내](docs/CHIPSCOPE_TEMPERATURE.md)를 참고합니다.

- 저장소에 원래 있던 `.bit` 파일은 2021–2022년 빌드입니다. 새 RTL 기능이 들어 있는 파일로 간주하면 안 됩니다.
- 기존 소스는 top-level component 포트 불일치로 XST 합성이 실패했습니다. 수정 후 로컬 ISE 14.7에서 전체 합성 **오류 0건**을 확인했습니다.
- 수정 경로의 자체 검사 시뮬레이션을 통과했습니다(임의 순서·유한/무한 반복·TTL·단일 패턴·직접 선택·조기 정지·잘못된 ID 거부·재업로드·USB 경계). 테스트는 실제 Xilinx FIFO 모델과 지연/역압력을 넣은 MIG user-port 모델을 사용합니다. 물리 DDR2 신호, 실제 DMD 미러, USB 펌웨어 자체를 검증하는 테스트는 아닙니다.
- 테스트 출력 3개의 누락된 핀 제약을 기존 EXP1 배치(B32/A33/B33)로 복원했습니다. [TI 보드 매뉴얼, J16 핀 표](https://www.ti.com/lit/ug/dlpu040c/dlpu040c.pdf)
- 배치·배선 후 현재 UCF 제약에 대해 **타이밍 오류 0건, Score 0**을 확인했습니다. 200MHz 시스템 클럭 setup 여유는 0.033ns, 150MHz 메모리 클럭은 0.170ns입니다. `ise_build.py`는 타이밍 통과 문구가 없으면 bitgen을 실행하지 않습니다.
- **JTAG 및 USB/SelectMAP용 `.bit/.bin`을 생성했습니다.** 두 파일 모두 bitgen DRC 오류 0건입니다. 경고 26건은 미사용/최적화된 신호 24건과 기존 GPIOA 출력의 pull-down 설정 2건이며, 관련 TI 핀 설정은 유지했습니다. 합성 경고도 남아 있으므로 "경고 0건"인 빌드는 아닙니다.
- **실제 LX50에 JTAG 업로드도 성공했습니다.** iMPACT의 `Programmed successfully`, DONE=1, startup 완료=1, CRC/ID 오류=0을 확인했습니다. 현재 체인은 iMPACT 위치 1=LX50, 위치 2=LX30이며 LX50만 기록했습니다. [업로드 결과](artifacts/dmd-program-20261023/programming_result.json)와 [원본 로그](artifacts/dmd-program-20261023/impact_program.log)를 보관했습니다. 휘발성 FPGA 구성이므로 전원을 끄면 새 bitstream을 다시 업로드해야 합니다.
- Windows에 ISE VM과 TI `D4100_usb.dll`이 설치되어 있습니다. 패턴 전송용 D4100 USB 장치는 업로드 후에도 **0개**였습니다. 따라서 DDR2 패턴 업로드/광학 동작은 아직 확인하지 못했습니다. 빌드 폴더의 `validation.json`은 업로드 전 시점의 검증 기록이며, 실제 업로드 상태는 위 `programming_result.json`을 참조합니다.
- 이전 README의 “100% 구현 및 검증 완료” 주장은 철회합니다. 이전 `run_all_tests.tcl`은 테스트를 실행하지 않고 PASS를 출력하던 스크립트였으며, 새 회귀 검사 도구로 교체했습니다.

## 기존 경로와 달라진 점

아래 비교는 저장소의 수정 전 RTL 및 TI 기준 경로를 대상으로 합니다. 기존 `.bit`와 소스의 정확한 대응을 입증하는 빌드 기록은 없으므로, 바이너리만 보고 기존 파일별 지원 기능을 확정하지 않습니다.

| 항목 | 수정 전 문제 | 현재 구현 |
|---|---|---|
| DDR2 주소 선택 | USB/시퀀스 패턴 번호가 DDR2 주소에 전달되지 않음 | 선택한 ID를 CDC handshake를 거쳐 실제 MIG 주소에 적용 |
| DDR2 쓰기/읽기 | 경계에서 여분 burst/word, FIFO stall에 취약 | 1프레임 = 6,144개의 128-bit word = 3,072 BL4 명령, 데이터 보존 |
| USB 입력 | 행/패킷 경계 데이터를 임의로 생략 | DDR 업로드는 연속 데이터 스트림, overflow 상태 표시 |
| DMD 행 출력 | FIFO 응답 공백이 행 중간에 들어갈 가능성 | 두 행 버퍼를 사용해 1행의 8개 word를 연속 출력 |
| 시퀀스 | 전송 완료와 무관한 트리거 전달, 길이 1 one-shot 누락 | 임의 ID 목록, 유한/무한 반복, 완료 확인, 단일 패턴 지원 |
| 외부 트리거 | 목록 전체 재생 시작과 연결되지 않음 | GPIOA[0] 상승 에지로 목록 재생 시작, 재생 중 트리거는 무시하고 상태 기록 |
| 타이밍 | 타이머/트리거 경로 불완전 | 패턴별 MCP 간격, 20µs 하한, 전송 및 미러 안정 시간 우선 |
| 상태 읽기 | 확장 레지스터 readback 미연결 | USB에서 업로드 수, 현재 ID, 완료 횟수, 오류 및 busy 조회 |
| 재현 가능한 빌드 | 실제 source list와 문서 불일치, 절대 경로 | 모든 `.prj`를 상대 경로로 통일, ISE VM 자동 실행 도구 |

TI IO/PLL/TPG/DMD_control 및 생성된 MIG/IP 코어는 변경하지 않았습니다. `MEM_IO.vhd`도 변경하지 않았습니다. 실제 프로젝트가 사용하는 `MEM_IO_Verilog.v`의 MIG user-port 제어를 수정했으며, 기존 `{pattern_id, offset, 2'b00}` 주소 배치는 유지합니다. 리셋 직후 메모리 경로는 꺼져 있고 TI 경로가 선택됩니다.

검증 대상은 **1024×768, 1-bit, Global update**입니다. Load2, Float, Single/Dual/Quad/Phased 메모리 재생은 이 새 경로에서 지원하지 않습니다. 이전 Load2의 “용량 2배/5,086장” 주장은 현재 구현의 보장 사항이 아닙니다. 잘못된 모드로 재생을 요청하면 시작을 거부합니다. 기존 실험용 `pattern_sequencer.vhd`, `timing_controller.vhd`, `trigger_mux.vhd`, `DMD_trigger_control.vhdl`은 보관되어 있지만 새 메모리 경로에는 인스턴스화되지 않습니다.

## 타이밍 의미

`period_us`는 현재 패턴의 MCP에서 다음 패턴의 MCP까지의 **최소 요청 간격**입니다. 20µs를 지정하면 이 구현에서 안전하게 가능한 가장 빠른 재생을 요청합니다. DDR 전송이 늦으면 간격이 늘어나며 패턴을 건너뛰지 않습니다.

전체 XGA 프레임은 데이터 전송만으로도 400 MHz에서 30.72µs가 필요합니다. 같은 블록 재기록 전에는 MCP 이후 12.5µs의 reset/settling 시간을 고려해야 합니다. 따라서 전체 프레임 Global 모드에서 20µs 전환을 보장할 수 없습니다. 이 구현은 MCP 명령 종료 뒤 12.5µs 이상 기다리고, MCP 사이에는 최소 20µs를 강제합니다. [TI DLPC410 데이터시트](https://www.ti.com/lit/gpn/DLPC410)

역압력을 넣은 시뮬레이션에서는 짧은 요청 간격이 약 **64.5–65.9µs**, 100µs 요청이 **100.015µs**로 관찰되었습니다. 이는 해당 테스트 조건의 결과이며 보드 실측치나 하드웨어의 절대 최대 속도가 아닙니다. TTL은 DDR 읽기/재생을 시작하므로 첫 MCP까지 프레임 로딩 지연이 있습니다. TTL 입력은 GPIOA[0]이며 충분한 펄스 폭(예: 50ns 이상)을 사용합니다.

## 실행 도구

추가 다운로드나 Python 패키지 설치 없이, 설치된 **ISE 14.7 + Python 표준 라이브러리 + Windows PowerShell/TI DLL**을 사용합니다. Xilinx ISE 및 USB/JTAG 드라이버 자체는 필수 의존성입니다. 오픈소스 도구만으로 이 Virtex-5 bitstream을 생성하는 경로는 제공하지 않습니다.

Windows PowerShell에서 VM 화면 없이 JTAG 구성하려면 아래 명령을 사용합니다. 업로드 시 기존 ISE VM이 실행 중이어야 합니다. `--check`는 bitstream 목록과 현재 선택 파일을 표시하고, 선택 파일의 해시·대상 FPGA 및 VM 메타데이터를 확인합니다. 장비에 접근하지 않습니다. `--program`은 보드 전원과 Xilinx JTAG 연결을 준비한 뒤 실행합니다.

```powershell
Set-Location 'C:\Users\wlsgu\project\2026\DMD\hs_dmd'
python tools/ise_program.py --check
python tools/ise_program.py --program

# 파일을 직접 선택: --check로 확인한 경로를 --program에도 동일하게 지정
python tools/ise_program.py --check --bitstream "artifacts/dmd-20261026/appsfpga_repaired_jtag.bit"
python tools/ise_program.py --program --bitstream "artifacts/dmd-20261026/appsfpga_repaired_jtag.bit"
```

옵션 생략 시 2026-10-26 수정 후보를 선택합니다. `--check`의 목록은 `artifacts/*/*.bit`와 `APPSFPGA_MEM/*.bit`를 포함하며 `*`로 현재 선택 파일을 표시합니다. `clock=JtagClk/Cclk/unknown`은 BitGen 보고서 기준이고, `hash-reference=recorded/missing`은 비교할 해시 기록 유무입니다. 목록의 모든 파일을 검증했다는 뜻은 아닙니다. VM 조회에 실패해도 파일 목록은 먼저 출력합니다. `--check`의 선택은 저장되지 않으므로 `--program`에도 같은 `--bitstream` 인자를 사용합니다.

다른 release의 JTAG BIT도 선택할 수 있으며 같은 폴더의 `artifact_hashes.json`에서 예상 해시를 읽습니다. 파일을 별도 위치로 복사했다면 `--sha256 <기록된 SHA-256>`을 함께 지정할 수 있습니다. 대상이 LX50 FF1153이 아니거나 해시가 다르면 업로드 전에 중단합니다. BitGen 보고서에 CCLK로 기록된 USB/SelectMAP용 파일은 거부합니다. 보고서가 없는 외부 파일의 startup clock은 자동 확인되지 않으므로 JTAG용 파일을 지정해야 합니다. 2026-10-23 후보는 앞선 실기에서 영상 깨짐이 관찰된 버전입니다.

이 도구는 Xilinx 케이블을 VM에 연결한 뒤 실제 체인이 LX50→LX30인지 검사합니다. LX50만 구성하고 DONE/startup/CRC/ID 상태를 확인합니다. D4100 패턴 USB는 Windows에 유지합니다. 로그에는 선택 파일 경로와 SHA-256을 기록하며 출력된 Windows 임시 폴더에 보존합니다. D201 구성 완료 후 SW2를 눌렀다 놓고 `DMD-FPGA-Test`에서 `dmd-test status` → `upload` → `show --number 1` 순서로 확인합니다. 실제 `--check` 실행과 `python -m unittest discover -s tools/tests -v` 오프라인 테스트를 검증했습니다. 10월 27일에는 이 wrapper를 이용한 실제 장비 업로드도 성공했습니다. [Python 실행 결과](artifacts/dmd-program-20261027/python/result.json)

GUI가 실행 즉시 종료되는 원인은 확인되지 않았습니다. 이 도구는 보안 정책이나 VM 설정을 변경하지 않습니다. 온도 측정과 GUI 허용 요청 내용은 [ChipScope 안내](docs/CHIPSCOPE_TEMPERATURE.md)를 참고합니다.

2026-10-27 실기 시도에서는 `Identifying JTAG chain` 단계의 `identify.log`에 `control tranfer failed`, `Loopback test failed`, `Cable autodetection failed`가 기록됐습니다. VM과 iMPACT는 실행됐지만 케이블 통신에서 실패하여 FPGA 기록 단계에 도달하지 않았습니다. VM의 `Xilinx cable attached ... True`는 연결 메타데이터이며 통신 성공 판정이 아닙니다. 스크립트는 이제 실패한 iMPACT 단계·원인·로그 경로를 출력합니다. 다음 시도에는 PC 쪽 **Xilinx JTAG USB 케이블**을 재연결하고 보드 전원을 켠 상태에서 같은 명령을 실행합니다. D4100 패턴 USB와 구분합니다. 사용자가 이후 전원을 내렸으므로 이 오류 처리 수정 중에는 장비 재시도를 하지 않았습니다.

같은 날 후속 시도에서는 `Cable connection established` 뒤에 `A problem may exist in the hardware configuration` 오류가 나고, 장치가 없는 빈 `chain.cdf`가 저장됐습니다. PC↔Xilinx USB 케이블 통신은 성공했으나 보드 FPGA 체인 인식이 실패하여 이번 bitstream은 기록되지 않았습니다. 사용자는 SW4 OFF 상태에서도 FPGA에 전원이 들어오며 이전 업로드가 성공했다고 설명했습니다. 10월 23일과 26일의 저장된 로그에서도 실제 업로드 성공과 DONE=1, CRC 오류=0을 확인할 수 있지만, 당시 SW4 위치는 기록되어 있지 않습니다. **이번 실패를 SW4 OFF 때문이라고 단정한 이전 안내를 철회합니다. 현재 오류 로그만으로 FPGA 전원 상태나 실패 원인을 확정할 수 없습니다.**

전원 회로는 [TI의 DLPLCRC410 Rev C 설계 파일](https://dr-download.ti.com/design-tools-simulation/design-tool/MD-DDe5Hraon8/1.0/DLPLCRC410EVM_RevC_Design_Files.zip)의 `DLPLCRC410EVM_RevC_SCH.pdf`를 확인했습니다. 3쪽의 SW4는 주 5V 입력을 직접 차단하지 않고 `POWER_STANDBY#`를 제어합니다. 이 신호는 19쪽 U17의 SS_ENA에 연결되고, U17은 7·11쪽의 두 FPGA에 연결된 1.0V 코어 전원을 공급합니다. 18쪽의 3.3V·12V 전원 회로는 별도 경로이므로 일부 전원이 남는 것과 FPGA 코어 전원의 정상 동작은 구분해야 합니다. 따라서 이 회로도를 근거로 SW4를 DMD 전원만의 스위치라고 설명할 수도 없습니다. 이는 공개된 **Rev C 회로도에서 확인한 연결**이며, 실제 보드의 리비전·실장 상태·전압과 일치하는지는 아직 확인하지 않았습니다. [TPS54310의 SS/ENA 기능](https://www.ti.com/lit/ds/symlink/tps54310.pdf#page=3)

다음 진단은 실제 보드의 FPGA 전원 및 H1 기준전압, H1 연결·방향, JTAG 체인 읽기 결과를 기준으로 합니다. 스위치 위치나 케이블 연결 메시지만으로 판단하지 않습니다. 헤더 연결을 바꿀 때는 보드 전원을 차단합니다. 이번 수정 중에는 장비에 접근하거나 전원·VM 설정을 변경하지 않았습니다.

iMPACT는 위 오류 후에도 종료 코드 0을 반환하므로 도구는 로그의 ERROR/FATAL도 검사하여 FPGA 기록 전에 중단합니다. 오류 처리 수정은 저장된 로그와 모의 호출로만 검증했습니다.

위 실패 기록 이후 10월 27일 재연결 시 직접 iMPACT 업로드가 성공했고, 이어 같은 파일로 Python wrapper의 실제 업로드도 성공했습니다. 두 방식은 같은 VM/iMPACT와 JTAG 명령을 사용합니다. 연결 복구 원인과 패턴 USB 분리 필요 여부는 확정하지 않았습니다. [성공 기록 및 방식 비교](docs/UPDATES_2026-10-27.md)

VM `ISE_14.7_VIRTUAL_MACHINE`을 실행한 뒤 저장소 루트에서:

```powershell
# 실제 자체 검사: PASS 마커와 assertion/timeout 결과 확인
python tools/ise_test.py --build C:/Temp/dmd-tests

# 합성만
python tools/ise_build.py --stage synth --build C:/Temp/dmd-build

# 합성 -> NGDBuild -> MAP -> PAR -> TRCE -> 타이밍 통과 시 BIT/BIN
python tools/ise_build.py --stage implement --build C:/Temp/dmd-build
```

빌드는 별도 폴더에서 수행하므로 원래 `.bit`를 덮어쓰지 않습니다. `.xise`에서도 소스가 등록되어 있습니다. Windows 도구는 로컬 ISE VM의 `/opt/Xilinx/14.7/ISE_DS/settings64.sh`와 `C_DRIVE` 공유 폴더를 사용합니다. 실제 컴파일은 VM 임시 디스크에서 수행하며 보고서를 지정한 폴더로 복사합니다. Linux에서는 ISE 환경을 먼저 source한 뒤 같은 Python 도구를 사용할 수 있습니다.

`source_hashes.json`은 사용한 소스/IP 해시입니다. 생성된 bitstream은 동일 빌드의 PAR/TRCE 보고서와 함께 관리해야 합니다. 합성만 통과한 `.ngc`는 업로드 파일이 아닙니다.

이번 검증 산출물은 `artifacts/dmd-20261023/`, 실제 업로드 기록은 `artifacts/dmd-program-20261023/`에 모아 Git에 포함했습니다. 그 외 임시 빌드 산출물은 계속 제외합니다.

- [ISE/iMPACT JTAG용 bitstream](artifacts/dmd-20261023/appsfpga_repaired_jtag.bit)
- [USB/SelectMAP용 bitstream](artifacts/dmd-20261023/appsfpga_repaired.bit) 및 [BIN](artifacts/dmd-20261023/appsfpga_repaired.bin)
- [검증 결과와 대상 디바이스](artifacts/dmd-20261023/validation.json), [최종 타이밍 보고서](artifacts/dmd-20261023/reports/appsfpga.twr), [산출물 SHA-256](artifacts/dmd-20261023/artifact_hashes.json)
- [바로 사용할 수 있는 5개 테스트 패턴 계획](artifacts/dmd-20261023/patterns/plan.json)

최종 제약 보완 시에는 RTL/IP/합성 옵션 해시가 동일함을 확인하고 합성 결과를 재사용한 뒤 NGDBuild부터 다시 실행했습니다. 이 기록은 `build_provenance.json`에 있습니다. 원래 bitstream 7개는 기준 커밋 `1f91eb4`와 바이트 단위로 동일합니다. 새 빌드를 할 때는 이전 산출물이 없는 폴더를 지정합니다. 도구는 이미 생성된 bitstream이 있는 폴더의 보고서와 소스 기록을 덮어쓰지 않습니다.

## 패턴 업로드 및 5개 패턴 재생

호스트 도구는 설치된 32-bit TI DLL을 호출하도록 32-bit PowerShell로 자동 전환합니다. FPGA를 재프로그램하지 않으며, `Upload`는 DDR2에 **패턴 데이터만** 씁니다. 새 bitstream을 먼저 ISE/iMPACT로 LX50에 구성하고 **SW2를 눌렀다 놓은 뒤 D201/Calibrated 상태를 확인**합니다. 전원을 다시 끄면 JTAG 구성이 사라집니다. 최신 후보 파일은 [2026-10-26 보고서](docs/UPDATES_2026-10-26.md)에 있습니다.

```powershell
# 읽기 전용 연결/ABI 조회
powershell -NoProfile -File tools/dmd_playback.ps1 -Action Status

# 검정, 흰색, 세로줄, 가로줄, 체크보드 생성
python tools/make_test_patterns.py C:/Temp/dmd-patterns

# DDR2 저장 및 시퀀스 설정; 자동 재생하지 않음
powershell -NoProfile -File tools/dmd_playback.ps1 -Action Upload -Plan C:/Temp/dmd-patterns/plan.json

# USB 명령으로 시작
powershell -NoProfile -File tools/dmd_playback.ps1 -Action Start

# 또는, GPIOA[0] 상승 에지마다 전체 목록을 시작하도록 arm
powershell -NoProfile -File tools/dmd_playback.ps1 -Action Arm

# 현재 전송 중인 프레임까지 완료한 뒤 정지
powershell -NoProfile -File tools/dmd_playback.ps1 -Action Stop
```

`plan.json` 예:

```json
{
  "patterns": ["p0.bin", "p1.bin", "p2.bin", "p3.bin", "p4.bin"],
  "sequence": [4, 1, 3, 0, 2],
  "repeat_count": 3,
  "period_us": [20, 20, 100, 20, 20]
}
```

- 파일 하나는 기존 TI/XGA packed-row 형식의 **98,304바이트**, 768행 × 128바이트입니다. 파일 헤더는 포함하지 않습니다. 픽셀 방향은 보드에서 줄무늬 패턴으로 확인해야 합니다.
- ID는 `patterns` 배열의 0부터 시작하는 인덱스입니다. 순서 변경 및 같은 ID 중복 재생이 가능합니다.
- `repeat_count=3`: 전체 목록을 3번 재생합니다. `0`: 무한 반복, `1`: 한 번입니다.
- `Arm` + `repeat_count=1`: 트리거 한 번에 5개 패턴을 한 번씩 재생하고 다음 트리거를 기다립니다. 재생 중 들어온 트리거는 대기열에 넣지 않습니다.
- `period_us` 하나는 모든 엔트리에 적용됩니다. 배열이면 sequence 길이와 같아야 합니다.
- `Configure`는 같은 업로드 데이터를 두고 목록/반복/시간만 변경합니다. 동작 중 설정 변경은 거부하므로 도구는 먼저 정지시킵니다.
- 업로드는 48행(6,144바이트)씩 전송합니다. TI `LoadData`의 512바이트 패딩을 피하는 크기입니다. 이전의 1행 + 47행 전송 방식을 그대로 사용하면 새 raw DDR 업로드에 맞지 않습니다.
- 불완전한 업로드/전송 오류가 발생하면 오류 상태를 확인하고 FPGA를 재초기화한 뒤 재시도합니다. 전송 도중 강제로 MIG/FIFO를 리셋하는 기능은 제공하지 않습니다.

## 확장 레지스터 ABI D201

기존 TI 0x00–0x28 레지스터는 그대로 유지합니다. 주소 0x3E를 읽어 `0xD201`인지 확인한 뒤 확장 명령을 사용합니다. 재생/업로드 중 테이블과 설정을 변경하지 않습니다.

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

## 실제 보드 검증이 필요한 부분

1. ISE/iMPACT에서 JTAG chain을 확인합니다. 이번에는 위치 1=LX50, 위치 2=LX30으로 확인했습니다. 자동 검색 로그의 발견 순서와 iMPACT 위치는 다를 수 있으므로 저장한 CDF와 장치명을 확인합니다. 연결 문제는 VM의 USB 2.0(EHCI) 활성화, 정상 재시작, PC 쪽 케이블 재연결로 해결했습니다. 설치된 VirtualBox 7.2는 EHCI를 기본 제공하므로 Extension Pack 추가 설치는 필요하지 않았습니다([Oracle 릴리스 노트](https://docs.oracle.com/en/virtualization/virtualbox/7.0/relnotes/ChangeLog.html)).
2. 타이밍 검증이 완료된 `appsfpga_repaired_jtag.bit`를 LX50에 지정해 구성합니다. 이번 실제 업로드와 DONE/CRC 검사는 성공했습니다. 이 파일은 JTAG startup clock을 사용합니다. `appsfpga_repaired.bit/.bin`은 기존 USB/SelectMAP용 CCLK 설정입니다. 기존 `.bit`는 보관되어 있습니다.
3. TI FX2 USB도 PC에 연결하고 `Status`에서 장치 및 ABI를 확인합니다. JTAG 케이블만 연결해서는 패턴 업로드용 USB 장치가 나타나지 않습니다.
4. 1개 검정/흰색 패턴부터 DDR 저장 수와 표시를 확인한 뒤, 5개 목록의 유한 반복, TTL, 무한 반복/정지를 차례로 확인합니다.
5. 오실로스코프로 MCP/RST_ACTIVE, 트리거 및 광학 출력을 측정해 간격과 실제 안정 시간을 확인합니다. 전기적 DDR2 calibration/신호 무결성 및 광학 픽셀 방향은 RTL 시뮬레이션 통과만으로 보장되지 않습니다.
