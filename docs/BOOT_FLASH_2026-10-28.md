# 부팅 Flash와 J4 확인 기록 — 2026-10-28

> 이 문서는 초기 조사 시점의 기록이다. 이후 실제 Flash 접근과 전체 백업에 성공한 후속 작업은 [PROM 기록 작업](PROM_PROGRAMMING_2026-10-28.md)을 따른다.

실제 보드의 두 FPGA에서 **Master SPI 부팅 모드**를 읽었다. 구형 설명서의 XCF16P PROM/J4 revision 선택 절차를 현재 보드에 그대로 적용하면 안 된다. TI 공식 개정 회로도에서는 SPI Flash를 추가하고 기존 PROM을 미실장 처리했다. 정확한 PCB revision과 실장 Flash의 JEDEC ID는 아직 확인하지 못했다.

이번 작업에서는 FPGA 재구성, Flash erase/program, 보호 비트 변경을 수행하지 않았다. Flash 백업도 아직 생성되지 않았다. 기존 `tools/ise_program.py --program`은 계속 LX50의 휘발성 구성만 담당한다.

## 직접 읽은 결과

재연결 직후 `runs/prom-probe-20261028T050157Z`에서 JTAG 식별과 상태 읽기에 성공했다. 이후 Flash 식별 준비 중 케이블 USB 통신이 실패했다. 성공 당시 상태와 마지막 연결 상태를 구분한다.

| 항목 | 확인 결과 |
|---|---|
| JTAG CDF 위치 1 / 2 | `xc5vlx50` / `xc5vlx30` |
| XCF16P JTAG 장치 | 검출되지 않음 |
| 두 FPGA의 DONE / startup 완료 | 각각 1 / 1 |
| 두 FPGA의 CRC / ID 오류 | 각각 0 / 0 |
| 두 FPGA의 M2:M1:M0 | `001`, Master SPI |
| 두 FPGA의 SPI type bits | `101`, 일반 SPI read 명령 `0x03` 선택 |
| 실제 Flash JEDEC ID | 미확인 — 위 type bits는 제조사/제품 ID가 아님 |
| 실장 PCB revision | 미확인 — SPI 부팅과 PROM 없는 체인이 개정 회로도에 부합함 |

부팅 모드 해석은 [AMD Virtex-5 Configuration Guide UG191](https://docs.amd.com/v/u/en-US/ug191)의 Table 2-1 및 Master SPI 설명을 따른다. 상태 읽기의 `-273°C`, `0.000V` 출력은 유효한 온도·전압 측정값으로 취급하지 않는다. 이번 확인은 D202 ABI 및 DDR2/광학 재생 시험을 포함하지 않는다.

## 공식 회로도에서 찾은 부품과 연결

근거는 [TI DLPLCRC410EVM Rev C 공식 설계 파일](https://dr-download-cdn.ti.com/design-tools-simulation/design-tool/MD-DDe5Hraon8/1.0/DLPLCRC410EVM_RevC_Design_Files.zip)의 `DLPLCRC410EVM_RevC_SCH.pdf`이다. 도면명은 DLP010 Rev C, 도면 날짜는 2023-06-01이다.

| 도면 위치 | 내용 |
|---|---|
| Sheet 1, revision history | Rev B에서 APPS/DLPC SPI Flash U27/U24 및 JTAG bypass 저항 추가. Rev C에서 level shifter 추가, 구형 PROM U10/U8 미실장(DNI) 지정 |
| Sheet 5 | APPS FPGA용 U27: **S25FL032P0XMFA010**, 32Mbit = **4MiB** |
| Sheet 5 | U30/U31 level shifter, 외부 SPI 프로그래머용 J20과 관련 J21/J22 연결 |
| Sheet 7 | 구형 U10 XCF16P는 DNI, R737로 JTAG 우회 |
| Sheet 7 | **J4는 U10의 REV_SEL0에 연결**, U27 SPI Flash의 이미지 선택에는 연결되지 않음 |

따라서 이전의 “J4 0–1은 원본, 1–2는 새 이미지” 설명은 구형 XCF16P 구성에 한정한다. 이 개정 도면에서는 J4로 SPI Flash의 두 이미지를 선택할 수 없다. 단순히 새 이미지를 다른 주소에 기록해도 J4 선택 기능이 생기지 않는다. 실제 보드가 정확히 Rev C라고 확정한 것은 아니다. 사용자가 관찰한 J4 변경 전후 동작 차이는 보존하며, 그 원인은 아직 확인하지 않았다.

도면과 다운로드 파일은 로컬 `runs/prom-probe-20261028T050157Z/reference/` 및 상위 폴더에 보관했다. ZIP SHA-256은 `06a280048c2d9e158627bc01406fbc261c54567716f489eadb06269646822275`, schematic PDF SHA-256은 `177da0306492a7b353bc94ee320ee4ad9073228c82d6d7e1aca82e5caeceb308`이다.

## 로컬 ISE에서 확인한 지원 범위

설치된 ISE 14.7에는 Virtex-5 JTAG 간접 SPI 구성 코어 `virtex5/data/xc5vlx50_spi.cor`와 S25FL032P 지원이 있다. 하드웨어를 사용하지 않는 iMPACT 세션에서 `attachFlash -p 1 -spi S25FL032P`가 받아들여지는 것도 확인했다. 이는 **도구가 해당 부품을 지원한다는 증거이며 실물 Flash ID를 읽었다는 뜻은 아니다.**

설치 문서 `ISE/doc/usenglish/isehelp/`의 `pim_r_supported_spi_bpi_proms.htm`, `pim_p_configure_spi_bpi_through_fpga.htm`, `pim_p_readbacks.htm`에서 간접 SPI 구성과 PROM MCS readback 기능을 확인했다. 간접 접근은 LX50에 임시 통신 코어를 구성하므로 현재 FPGA 설계가 교체된다. 실제 접근 후에는 검증된 D202 JTAG 파일로 복구하고 SW2/패턴 재업로드 절차를 수행해야 한다. 이번에는 초기 케이블 연결부터 실패해 임시 코어도 구성하지 않았다.

영구 기록 전 남은 순서는 다음과 같다.

1. Xilinx 케이블의 실제 guest USB 연결과 LX50 → LX30 JTAG 체인을 다시 확인한다.
2. APPS 쪽 Flash의 실제 ID와 용량을 읽어 도면의 후보 부품과 비교한다.
3. 기존 Flash를 전체 readback하고 파일 범위·크기·해시 및 반복 읽기 일치를 확인해 복원용 백업을 확보한다. Readback 지원 여부도 실물에서 검증한다.
4. 확인된 부품과 부팅 방식에 맞춰 CCLK/SPI용 이미지와 MCS를 만들고 기록 주소·용량을 검증한다. 현재 JTAG용 BIT를 그대로 영구 부팅용이라고 간주하지 않는다.
5. APPS Flash만 기록·검증한 뒤 전원 재인가 부팅, ABI 및 패턴 동작을 확인한다. LX30/DLPC 쪽 Flash는 대상이 아니다.

현재는 1단계에서 막혀 있다. 원본 유지와 사용자 이미지 선택을 동시에 원한다면 실제 Flash 배치에 맞는 multiboot 설계가 별도로 필요하며 J4의 기존 기능으로 해결된다고 가정하지 않는다.

## 마지막 연결 상태와 복구 시도

- iMPACT: `control tranfer failed`, `write cmdbuffer failed 20000020`, `Loopback test failed` 후 종료. FPGA 체인 스캔에 도달하지 못했다.
- Windows: Xilinx `VID_03FD&PID_0008`이 **문제 코드 28 (`CM_PROB_FAILED_INSTALL`)**, 선택된 driver INF/service 없음. [Microsoft의 코드 28 설명](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/cm-prob-failed-install)에 해당한다. 이것만으로 앞선 모든 연결 실패의 원인을 확정하지는 않는다.
- VirtualBox: 케이블 attach 요청을 `busy with a previous request`로 거부. `Captured` 표시가 실제 guest 연결을 보장하지 않았다.
- Linux guest: `lsusb`에 root hub 두 개만 있고 Xilinx 장치는 없음.
- 패턴 전송용 TI D4100 USB는 Windows에서 정상 표시됨. Xilinx JTAG USB와 별개이다.

소프트웨어 detach/attach, guest 정상 종료 후 headless 재시작, VirtualBox 서비스 재시작을 수행했다. 케이블이 잠시 `Available`로 나타났지만 다시 attach 오류가 발생했다. 최종 VM 상태는 running/headless이며, 드라이버 설치·제거 및 보안 정책 변경은 하지 않았다. 물리 재연결로 복구되는지 또는 호스트 드라이버 조치가 필요한지는 아직 확인하지 못했다.

검토 가능한 원본 증거는 [artifacts/dmd-boot-probe-20261028](../artifacts/dmd-boot-probe-20261028/)에 보관했다. 성공 당시 `read_status.log`/`chain.cdf`, 이후 `identify_usb_failure.log`, 마지막 Windows/guest 상태 및 `session_result.json`을 함께 읽는다. 각 파일의 SHA-256은 `sha256.json`에 있다. 최신 USB 오류를 근거로 FPGA 무전원이나 Flash 고장을 단정하지 않는다.
