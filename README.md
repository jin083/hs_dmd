# DLP7000 DDR2 pattern playback

DLPLCRC410EVM의 Virtex-5 **xc5vlx50-1-ff1153**에서 DLP7000을 제어하는 FPGA 저장소입니다. 현재 개발 브랜치는 `feature/managed-pattern-memory`, 메모리 관리 ABI는 **D202**입니다. Python 제어 패키지는 별도 `../dlpc410`, 실험 CLI는 `../DMD-FPGA-Test`에서 관리합니다.

[문서 목차](docs/README.md) · [D202 명세](docs/D202_MANAGED_MEMORY.md) · [작업 기록·그래프](docs/reports/D202_2026-10-27.md) · [검증 구조](docs/TESTING.md)

**2026-10-28 추가 리뷰:** 오류 중 MCP/완료 신호, 부분 시퀀스 설정, arm 중 설정 변경, snapshot 통계에 경계 문제가 재현됐습니다. [리뷰 결과](docs/reports/D202_REVIEW_2026-10-28.md)를 확인합니다. 현재 D202 bitstream에는 아직 수정이 반영되지 않았습니다.

## 현재 기능과 검증 범위

D202는 DDR2의 **0..2542 고정 ID**에 개별 패턴을 저장·교체·삭제하고, 실제 DDR readback CRC32로 내용을 검증합니다. 재생 전 모든 참조 슬롯과 변경 generation을 검사합니다. 순서·패턴별 주기·유한/무한 반복·TTL 시작, 종료 패턴, snapshot 및 선택적 GPIO 동기화 출력을 지원합니다. CRC에 연결된 실험 JSON 저장·불러오기는 host API가 담당합니다.

검증 대상은 **1024×768, 1-bit, Global update**입니다. 전체 프레임은 98,304바이트입니다. Load2와 Single/Dual/Quad/Phased 메모리 재생은 지원하지 않습니다. TI IO/PLL/TPG, 생성된 MIG/IP 및 기존 DDR2 주소 배치를 보존했습니다. 활성 메모리 모듈은 `MEM_IO_Verilog.v`이며 `MEM_IO.vhd`는 사용하지 않습니다.

D202 합성 오류 0, 최종 타이밍 오류 0/Score 0, BitGen DRC 오류 0을 확인했습니다. [JTAG bitstream](artifacts/dmd-20261027-d202/appsfpga_repaired_jtag.bit)과 [검증 기록](artifacts/dmd-20261027-d202/validation.json)을 함께 보관합니다. **2026-10-28 사용자가 최신 bitstream에서 패턴 업로드 및 숫자 패턴 정상 표시를 확인했습니다.** 기본 업로드·표시 성공으로 기록하며, 오류 경계 조건·전체 관리 기능·전기 신호·광학 timing·온도 검사는 별도로 관리합니다. 이번 보고에는 파일 해시/ABI 읽기 로그가 없어 특정 SHA-256과 연결하지 않습니다. 이전 10장 업로드 응답은 [D201 실기 기록](docs/UPDATES_2026-10-27.md)에 보존합니다.

`D202`는 이 프로젝트의 **FPGA 명령/레지스터 규약 버전(ABI)**입니다. Python이 `0x3E`를 읽어 `0xD202`를 받으면 슬롯 관리·CRC 등 해당 규약을 사용합니다. TI 칩 모델, DLL의 32/64-bit 또는 bitstream 파일의 고유 해시와는 별개입니다.

## 저장소 구성

| 위치 | 역할 |
|---|---|
| `APPSFPGA_MEM/src/rtl/` | 합성 대상 RTL, D202 directory·playback·streamer |
| `APPSFPGA_MEM/src/sim/` | 시나리오, 공통 `harness/`, MIG user-port 모델 |
| `tools/` | ISE 빌드·시뮬레이션·JTAG 도구 |
| `tools/reports/` | 원본 로그 수집 및 PNG/SVG 그래프 생성 |
| `docs/` | 사용법·레지스터·검증·온도 측정, `history/`에 과거 기록 |
| `artifacts/dmd-20261027-d202/` | D202 산출물, 보고서·테스트·해시·그래프 |
| `runs/` | 개발·검증·사용자 실행 기록; Git에 커밋하여 보존 |

오래된 `src (copy)/`, 루트 `git_*.vhdl` 및 비활성 sequencer는 현재 구현 기준이 아닙니다. TI 참조 파일과 기존 bitstream은 보존합니다.

## bitstream 선택과 실행 순서

설치된 **ISE 14.7 VM, Xilinx JTAG 드라이버, Python 표준 라이브러리**를 사용합니다. 패턴 전송에는 Windows의 **TI D4100 USB DLL/드라이버**가 필요합니다. 추가 패키지 다운로드 없이 실행할 수 있지만 ISE와 장치 드라이버 자체는 필수입니다.

1. 보드 전원을 내린 상태에서 점퍼와 보드 쪽 H1 JTAG 연결을 확인합니다. Xilinx JTAG 케이블을 PC와 보드에 연결한 뒤 보드 전원을 인가합니다. D4100 패턴 USB는 별도이며 Windows에 연결합니다.
2. 기존 `ISE_14.7_VIRTUAL_MACHINE`이 실행 중인 상태에서 아래 `--check`로 파일을 확인하고 `--program`으로 **LX50만** 구성합니다. LX30/PROM에는 기록하지 않습니다.
3. 구성 완료 뒤 **SW2를 눌렀다 놓고**, `DMD-FPGA-Test`에서 status → DDR selftest → upload → show 순서로 확인합니다.

```powershell
# hs_dmd에서
python tools/ise_program.py --check
python tools/ise_program.py --program --bitstream "artifacts/dmd-20261027-d202/appsfpga_repaired_jtag.bit"
```

파일 인자를 생략하면 이 D202 JTAG 파일을 선택합니다. `--check`는 bitstream 목록·선택 파일·SHA-256·대상 FPGA·VM 메타데이터만 확인합니다. JTAG 통신 성공을 뜻하지 않습니다. 선택은 저장되지 않으므로 다른 파일을 확인했다면 `--program`에도 같은 `--bitstream` 경로를 지정합니다. `clock=JtagClk`인 파일을 사용하며 CCLK 파일은 JTAG 도구가 거부합니다. `$bit`는 선택 경로를 저장할 때 사용하는 선택적인 PowerShell 변수입니다.

SW2는 설계의 런타임 상태를 초기화하며 JTAG 구성 자체를 바꾸지 않습니다. **D202 슬롯 metadata도 초기화되므로 패턴을 다시 업로드**합니다. FPGA 전원이 꺼지면 휘발성 JTAG 구성은 사라지고 비휘발성 부팅 메모리에서 다시 구성되므로 D202를 다시 업로드해야 합니다. **10/28 실제 상태 읽기에서 Master SPI 모드를 확인했습니다.** TI 개정 회로도에서는 SPI Flash를 사용하며 J4는 구형 미실장 PROM에 연결됩니다. 구형 J4 revision 선택 절차를 그대로 적용하지 않습니다. [부팅 Flash·J4 확인 기록](docs/BOOT_FLASH_2026-10-28.md)을 참고합니다. Flash 기록의 최신 성공·실패 상태는 아래 실행 기록을 따릅니다.

SW4 위치나 케이블 LED만으로 FPGA 전원/JTAG 상태를 단정할 수 없습니다. 이전 연결 실패·복구 이력은 [D201 진단 기록](docs/history/README_D201_2026-10-27.md)에 보존했습니다. VM GUI 종료 원인은 조사하지 않았으며 도구는 보안 정책을 바꾸지 않습니다.

**10/28 Flash 기록 완료:** D202 전체 이미지 1,569,584바이트와 마지막 페이지 padding까지 읽기 비교를 통과했습니다. iMPACT 14.7의 짧은 page 쓰기 JTAG 전송을 padding해 앞선 실패를 해결했습니다. PC에서 BIT 데이터를 다시 보내지 않고 Flash에서 LX50을 재구성해 DONE/startup=1, CRC/ID 오류=0도 확인했습니다. 원본 4MiB 백업은 보존돼 있습니다. **물리 전원 재인가 시험은 남아 있고, 패턴 USB가 검출되지 않아 USB ABI/패턴 검증은 하지 못했습니다.** [SPI 이미지·백업·최종 기록](docs/PROM_PROGRAMMING_2026-10-28.md)을 참고합니다.

## Python API와 숫자 패턴 시험

[dlpc410](https://github.com/jin083/dlpc410/tree/feature/managed-pattern-memory)의 `dmd_ctrl.memory.PatternStore`와 [DMD-FPGA-Test](https://github.com/jin083/DMD-FPGA-Test/tree/feature/managed-pattern-memory)의 `dmd-test memory`를 사용합니다. 현재 로컬 작업본의 두 패키지는 0.4.0이며 pyproject metadata로 기존 Python에 설치합니다. 프로젝트 가상환경은 만들지 않습니다.

`dlpc410`의 기준 환경은 **64-bit Python + 64-bit `D4100_usb.dll`**입니다. 0.4.0의 기본 `Usb64Transport`는 재사용하는 64-bit Python worker에서 주 DLL을 직접 호출합니다. `PowerShellTransport`는 명시적으로 선택하는 32-bit 호환 옵션이며 자동 우회하지 않습니다. [전송 구현·검증 결과](../dlpc410/docs/USB64_TRANSPORT_2026-10-28.md)를 참고합니다. 이 전송 전환으로 FPGA bitstream/ABI가 바뀌지는 않습니다.

```powershell
# DMD-FPGA-Test에서
pip install --no-index --no-build-isolation --no-deps -e ..\dlpc410 -e .
dmd-test memory selftest --simulate  # 장치 없이 harness 확인

# D202 구성 및 SW2 후 실제 보드에서
dmd-test memory status
dmd-test memory selftest             # 빈 슬롯 2540..2542에서 DDR만 검사
dmd-test memory upload               # 숫자 10장 → ID 0..9
dmd-test memory show --id 0
dmd-test memory run --ids 0,1,2,3,4 --period-us 100000 --repeat 2
```

개별 교체·삭제·실험 JSON 및 TTL/무한 반복 예제는 [Test 사용법](https://github.com/jin083/DMD-FPGA-Test/blob/feature/managed-pattern-memory/docs/MANAGED_MEMORY.md)에 있습니다. 삭제/clear는 논리적 무효화이며 DMD 화면을 끄거나 DDR 전체를 0으로 덮지 않습니다. 기존 `tools/dmd_playback.ps1`은 **D201 전용**입니다.

## 빌드와 검증

```powershell
python tools/ise_test.py --build C:/Temp/dmd-tests-new
python tools/ise_build.py --stage implement --build C:/Temp/dmd-build-new
python -m unittest discover -s tools/tests -v
```

새 출력 폴더를 지정합니다. `--stage synth`는 합성만 수행하며 `.ngc`는 업로드 파일이 아닙니다. 구현 도구는 현재 UCF에 대해 `All constraints were met`를 확인한 뒤 BIT/BIN을 만듭니다. Windows에서는 기존 ISE VM의 임시 디스크에서 빌드하고 소스/IP 해시 및 보고서를 복사합니다. Linux에서는 ISE `settings64.sh`를 source한 뒤 같은 Python 도구를 사용할 수 있습니다.

테스트는 Xilinx FIFO 모델과 MIG user-port 모델을 사용합니다. 물리 DDR2·DMD 미러·온도 검증을 대체하지 않습니다. 합성 경고와 기존 제약의 검사 범위도 [작업 보고서](docs/reports/D202_2026-10-27.md)에 남깁니다. Matplotlib은 그래프 재생성에만 필요하며 제어·빌드 런타임에는 필요하지 않습니다.

## 타이밍과 온도

`period_us`는 MCP 명령 사이의 **최소 요청 간격**이며 하한은 20µs입니다. DDR 전송과 MCP 이후 12.5µs 안정 대기가 우선하므로 전체 XGA 패턴의 20µs 전환을 보장하지 않습니다. 최종 시뮬레이션 간격은 [결과 그래프](artifacts/dmd-20261027-d202/plots/tests_and_simulation.png)에 기록합니다. 실제 광학 switching 시간은 후속 측정 대상입니다.

사용자가 보고한 두 FPGA의 발열 증가에 대한 실측값은 아직 없습니다. [발열 검토](docs/THERMAL_REVIEW_2026-10-23.md)와 [ChipScope 내장 온도 측정](docs/CHIPSCOPE_TEMPERATURE.md)을 따릅니다. FPGA 자원 사용량이나 타이밍 통과는 온도·소비전력의 측정값이 아닙니다. Photodiode/ADC/오실로스코프 통합은 후속 단계입니다.
