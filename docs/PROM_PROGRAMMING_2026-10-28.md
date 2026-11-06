# APPS SPI Flash 기록 작업 — 2026-10-28

**최종 결과(18:38 KST): APPS SPI Flash에 D202 기록과 전체 이미지 읽기 비교가 성공했다.** 이미지 1,569,584바이트와 마지막 페이지 `0xFF` padding 208바이트까지 총 1,569,792바이트가 일치했다. 이후 LX50에 JPROGRAM만 전달하고 PC에서 BIT 데이터를 보내지 않은 상태에서 Flash 재구성이 성공했다. DONE/configured/startup=1, CRC/ID/readback CRC 오류=0이다. 기록·구간별 검증은 약 20분 44초였다. [최종 결과](../artifacts/dmd-spi-20261028/prom-finalize-20261028T085433Z/summary.json) · [Flash 재구성 결과](../artifacts/dmd-spi-20261028/prom-finalize-20261028T085433Z/flash_boot_result.json) · [최신 상태](../artifacts/dmd-spi-20261028/latest_result.json).

**실제 전원을 차단했다 재인가하는 cold boot는 아직 시험하지 않았다.** Flash 재구성 이후 `dmd-test memory status --usb-timeout 20`은 `D4100 USB device unavailable`로 끝났으므로 USB ABI/DDR/패턴 동작도 미검증이다. 원본 4MiB 백업은 보존돼 있으며 LX30/DLPC Flash는 기록하지 않았다. 실패를 해소한 JTAG 전송 길이 보정은 아래 “전송 길이 진단과 최종 기록”에 설명한다.

## 이전 상태와 복구 이력

**17:50 KST 전원 재인가 후 재복구:** 사용자가 전원을 껐다 켠 뒤 LX50의 DONE/configured/startup=0을 실제 확인했다. 같은 D202 JTAG 파일을 SRAM에 다시 구성해 13초에 성공했고 DONE/configured/startup=1, CRC/ID/readback CRC 오류=0을 확인했다. Flash에는 추가 기록하지 않았다. 이어 실행한 `dmd-test memory status --usb-timeout 20`은 `D4100 USB device unavailable`로 끝나 USB ABI·DDR 준비 상태는 확인하지 못했다. [재복구 결과](../artifacts/dmd-spi-20261028/powercycle-restore-20261028T085029Z/powercycle_result.json)에 전후 상태를 보관한다. 패턴 USB를 Windows에 연결하고 status를 확인한 뒤 패턴을 다시 업로드해야 한다.

**이전 상태(08:43 UTC / 17:43 KST): D202를 FPGA SRAM에 다시 구성했고 DONE/startup=1, CRC/ID 오류=0을 확인했다. 당시 APPS Flash는 전체 4MiB가 `0xFF`로 읽혀 비어 있었다.** 앞선 삭제·쓰기 작업은 verify가 주소 0에서 실패했고, 실제 데이터도 저장되지 않았다. 당시 32-bit iMPACT 재시도는 케이블 연결 전에 지원 환경 검사에서 중단됐다. 이후 아래 최종 보정 작업으로 D202 Flash 기록을 완료했다. 두 번 전체 읽기로 검증한 원본 백업은 보존했고 원본 이미지를 Flash에 다시 쓰지는 않았다.

최초 시도에서는 전체 readback의 장치 비교가 `0x38FD00`에서 실패했고 이후 JTAG 체인이 검출되지 않아 Flash 삭제·기록을 하지 않았다. 당시 [첫 결과 JSON](../artifacts/dmd-spi-20261028/result.json)은 역사 기록으로 보존한다. 사용자의 추가 재확인 요청 뒤 연결이 복구되어 아래 후속 작업을 진행했다.

## 대상과 이미지

- APPS FPGA: JTAG 위치 1, `xc5vlx50`. 위치 2 `xc5vlx30`은 기록 대상이 아니다.
- Flash: S25FL032P, 4MiB. 초기 iMPACT signature `0x15` 검사 후 최종 조사에서 JEDEC 제조사/제품 ID `01 02 15`도 직접 읽어 확인했다.
- ABI: D202, 기존 `artifacts/dmd-20261027-d202/`의 동일한 배치·배선 결과를 사용한다. RTL 기능 변경이나 R1–R4 수정은 포함하지 않는다.
- SPI 부팅용 BIT: `appsfpga_repaired.bit`, StartupClk=CCLK, ConfigRate=2.
- BIT SHA-256: `10f12f6ce7ee6209c143dddec9c4ce81b40770d146618dd1145a742f69395d37`.
- 생성 MCS SHA-256: `249fd0e9ccbc4f8dc12139fa2e11a22a9a3a87f2119ad81952e6e26f56c23938`.
- MCS 주소: `0x000000`부터 1,569,584바이트. Intel HEX 레코드 checksum, EOF, 주소 중복·용량, 원본 BIN payload와의 바이트 일치를 검사했다.

생성 명령은 ISE 환경에서 다음과 같다. `-spi`는 SPI Flash에 필요한 byte 내 bit 순서를 유지한다. JTAG 전용 BIT를 입력하지 않는다.

```bash
promgen -w -spi -p mcs -s 4096 -u 0 d202_spi_boot.bit -o d202_spi_boot
```

## 연결 및 백업 이력

원본 로그 폴더: `runs/prom-program-20261028T062757Z/`.

1. 6MHz JTAG에서 LX50 → LX30 식별에 성공했다.
2. `readIdcode -target`은 이 SPI 접근 방식에 맞지 않아 거부됐고 `readCFI`도 이 장치에서 지원되지 않았다. 이 두 명령으로 Flash 식별에 성공했다고 기록하지 않는다.
3. `readbackToFile -p 1 -spi S25FL032P`가 LX50에 임시 SPI 접근 코어를 구성하고 Flash ID 검사를 통과했다.
4. 최초 전체 읽기는 작업자가 설정한 55초 제한으로 중단됐다. 생성된 파일에는 유효 데이터 309,776바이트만 있고 EOF가 없어 **복원용 전체 백업으로 사용할 수 없다**.
5. 그 뒤 케이블 통신과 guest 명령이 멈췄다. VM 재시작 및 사용자의 PC 쪽 JTAG USB 재연결 뒤 다시 JTAG가 연결됐다. 이 시간 순서만으로 최초 읽기 중단과 USB 장애의 인과관계를 단정하지 않는다.
6. 재연결 후 6MHz 식별이 한 차례 실패했다. 포트 `usb21`, TCK 1.5MHz에서는 체인 및 FPGA status 읽기가 성공했다. 실제 속도는 로그로 확인했다. `-p auto`는 baud 설정을 기본 6MHz로 바꾸므로 사용하지 않는다.
7. 1.5MHz로 전체 읽기를 다시 시작했다. 이번 출력은 Linux guest 로컬 `/tmp/dmd_flash_slow.*`에 쓰고, 완료 후 Windows 로그 폴더로 복사한다. 충분한 작업 시간을 부여하고 진행률을 확인한다.

8. 전체 읽기는 927초 만에 성공했다. `0x000000..0x3FFFFF`의 4,194,304바이트를 빠짐없이 읽었으며 EOF와 모든 Intel HEX 레코드 checksum이 유효하다.
9. 별도 `Verify -p 1 -spionly`는 825초 뒤 주소 3,734,784 (`0x38FD00`)에서 `Verification Terminated`로 실패했다. 이 파일을 검증 완료한 복원용 백업이라고 취급하지 않는다.
10. 해당 구간을 다시 읽으려 했으나 FPGA IDCODE가 기대값 대신 `0x0FFFFFFF`로 읽혀 부분 읽기가 실행되지 않았다. 새 `Identify`도 장치를 찾지 못했다.
11. 사용자에게 실제 FPGA 전원을 차단하는 컨트롤 보드 재부팅과 PC 쪽 JTAG USB 재연결을 요청했고 완료 답변을 받았다. 그 뒤 750kHz, 1.5MHz, 6MHz 모두에서 빈 체인으로 끝났다. 초기 SPI bridge가 재부팅 뒤에도 남았다고 단정하지 않으며, 최종 FPGA 구성을 JTAG로 확인하지 못한 상태로 기록한다.

전체 readback 후보와 준비된 부팅 이미지, 성공·실패 로그는 [artifacts/dmd-spi-20261028](../artifacts/dmd-spi-20261028/)에 보관했다. 파일 hash는 파일의 동일성을 확인하며 장치 검증 실패를 대체하지 않는다.

| 파일 | SHA-256 |
|---|---|
| `original_apps_full.mcs` | `17ba24929d9cc51c57ea6595a3bb28d42a7d1601cdb626cac0dba45974ee538b` |
| `original_apps_full.bin` | `7ec0b170de54be4b6b99c8df3fce0f8a713a18230de54478ed0e315f88de660f` |

최초 시도에서는 Flash 기록을 보류했다. 루트 산출물 폴더의 `program_flash.cmd`와 `restore_original_flash.cmd`는 최초 시도에 준비만 했던 명령이다. 실제 후속 기록 명령과 실행 결과는 `recheck_071935/`에 별도로 보관한다. 원본 복원 명령은 실행하지 않았다.

원본 readback에서 Xilinx sync word는 `0x30`에 한 번 나왔고, 64KiB sector 기준 nonblank 영역은 `0x000000..0x17FFFF`에 있었다. 실패 주소가 이 범위 밖이라는 사실만으로 실패를 무시하지 않는다. Flash 불량, 보드 전원 이상, 접점/신호 문제 중 무엇이 원인인지 이번 로그로 확정하지 못했다.

## 후속 재확인 및 기록

로그: `runs/prom-recheck-20261028T071935Z/`. 보존 파일: [recheck_071935](../artifacts/dmd-spi-20261028/recheck_071935/).

1. 1.5MHz에서 LX50 → LX30 체인을 다시 식별했다. LX50의 DONE/startup=1, CRC/ID 오류=0과 Master SPI 모드를 읽었다.
2. 실패 구간의 부분 읽기를 요청했으나 이 SPI 경로에서는 `-partial`이 적용되지 않고 주소 0부터 4MiB 전체가 읽혔다. 첫 레코드와 실제 데이터 범위로 이를 확인했으며, 작업을 중단하지 않고 전체 비교에 사용했다.
3. 두 번째 전체 읽기는 943초에 성공했다. **4,194,304바이트 전체가 첫 백업과 일치하고 두 MCS 파일의 SHA-256도 동일하다.** [전체 비교 결과](../artifacts/dmd-spi-20261028/recheck_071935/backup_comparison.json)에 기록했다. 첫 iMPACT Verify가 성공한 것으로 바꾸지 않으며, 독립적으로 다시 읽은 전체 데이터의 일치로 백업을 검증했다.
4. MCS/BIT 해시 및 CCLK용 이미지, 예상 체인과 백업 비교 완료를 확인한 뒤 `Program -p 1 -spionly -e -v -loadfpga`를 실행했다. iMPACT는 sector erase, non-volatile quad-enable bit 해제, Flash programming 단계로 진행했다. LX30 또는 DLPC 쪽 Flash는 기록 대상으로 지정하지 않았다.
5. 삭제·쓰기 이후 verify가 주소 0에서 실패했고 `Flash was not programmed successfully`로 끝났다. 작업 시간은 268초였다. 이 시점에는 JTAG 체인 식별이 다시 성공했다.
6. `ReadStatusRegister -p 1 -flash -spionly`는 `0x0000`과 보호 비트 0을 보고했다. 이후 도구가 자동으로 Flash에서 FPGA를 재구성하려다 멈춰 45초 제한에 종료됐고, 케이블 USB 통신 오류가 뒤따랐다. 단순 상태 읽기 명령에도 재구성 동작이 포함된 사실을 기록한다.
7. 보드 전원을 유지하고 PC 쪽 JTAG USB만 재연결하도록 요청했다. 정상 FPGA 동작과 Flash 내용을 복구하는 작업이 아직 남아 있다. 원본 Flash 복원은 아직 실행하지 않았다.
8. guest 명령도 응답하지 않아, 이미 종료된 Flash 쓰기와 별개로 작업용 VM을 재시작했다. guest 응답은 복구됐으나 Windows `Get-PnpDevice -PresentOnly`, VirtualBox USB 목록 및 guest `lsusb`에 Xilinx 케이블이 없었다. 모든 iMPACT 작업은 끝난 상태이며 JTAG USB 연결을 기다린다. 재연결 후 FPGA SRAM의 정상 설계를 우선 복구하고 Flash의 실제 기록 내용과 원본 복원을 확인해야 한다.

## 재연결 후 복구 조사

로그: `runs/prom-recovery-20261028T082528Z/`. 보존 파일: [복구 로그](../artifacts/dmd-spi-20261028/prom-recovery-20261028T082528Z/).

1. 사용자 재연결 후 1.5MHz에서 LX50 → LX30 체인이 다시 식별됐다.
2. 검증된 JTAG D202 파일을 LX50 SRAM에 구성했다. 13초에 성공했고 DONE/configured/startup=1, CRC/ID/readback CRC 오류=0을 확인했다. 이 단계는 Flash를 기록하지 않는다.
3. 실제 Flash 내용을 파악하기 위해 `readbackToFile` 전체 읽기를 실행했다. 앞선 부분 읽기 제한을 반영하여 1,800초 제한을 부여했다. 947초에 성공했고 Intel HEX checksum/EOF/주소 연속성 및 전체 길이를 확인했다. **4,194,304바이트가 모두 `0xFF`**다. raw BIN SHA-256은 `cd3517473707d59c3d915b52a3e16213cadce80d9ffb2b4371958fb7acb51a08`이다. 이 파일은 실패 후 상태 증거이며 원본 복원용 백업이 아니다.
4. 하드웨어 쓰기와 분리하여 로컬 iMPACT의 명령 도움말과 SPI 데이터 폭 설정을 확인했다. ISE 14.7의 32-bit 실행 파일도 로컬에 존재하며 하드웨어 없는 도움말 실행에 성공했다. 실제 Flash 삭제·쓰기를 실행했던 도구는 64-bit iMPACT였다.
5. 같은 입력 MCS로 생성한 오프라인 SVF를 비교했다. 64-bit 기본 옵션, 64-bit `-dataWidth 1`, 32-bit `-dataWidth 1`의 주석 제외 명령이 모두 동일했다. 각 파일에는 page program 6,132회가 있으며, 명령 SHA-256은 `ac395f6af33c1adca47f28413bba3a3142966bd0ccd778a3c26582026b3ec067`이다. 기본 데이터 폭이 잘못됐다고 결론내리지 않는다. 이 비교는 파일 생성만 수행한 것이며 실제 Flash 프로그래밍 성공이 아니다.
6. 전체가 비어 있음을 확인한 뒤, 삭제를 생략하고 verify를 유지한 `Program -p 1 -dataWidth 1 -spionly -v -loadfpga`를 32-bit iMPACT로 실행하려 했다. 도구가 `Cable operation is not supported when running the 32-bit version of the application on a 64-bit platform`으로 케이블 연결 전에 중단했다. **이 시도는 Flash 쓰기에 진입하지 않았다.** 종료 코드만으로 성공을 판단하면 안 된다.
7. 64-bit iMPACT를 사용해 검증된 D202 JTAG 파일을 LX50 SRAM에 다시 구성했다. 14초에 성공했고 08:43 UTC에 DONE/configured/startup=1, CRC/ID/readback CRC 오류=0을 확인했다. LX30은 구성하지 않았다. 이번 작업에서는 USB ABI·DDR·광학 표시를 재시험하지 않았다.

도구 호환성 참고: [TI DLPC910 EVM 가이드 §5.3](https://www.ti.com/lit/ug/dlpu124/dlpu124.pdf)는 다른 보드의 S25FL032P 프로그래밍에 ISE 14.1 32-bit를 시험했고, 다른 버전에서 오기록 사례가 있었다고 명시한다. [Aldec Virtex-5 SPI FAQ §8](https://www.aldec.com/files/products/FAQ.pdf)는 자사 Virtex-5 보드의 ISE 14.x SPI 문제와 13.4 사용을 안내한다. 두 문서는 **현재 보드에서 실패 원인이 도구 버전이라고 확정하는 증거는 아니다.**

당시 다음 소프트웨어 시험 후보는 별도 ISE 14.1 Lab Tools였다. [AMD 공식 다운로드](https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/legacy-ise/v14_1.html)의 `Lab Tools – 14.1 / All Platforms` 파일은 `Xilinx_LabTools_14.1_P.15xf.0.1.tar`(표기 약 1GB)이며, 계정 세션 오류로 받지 못해 사용자에게 로컬 설치 파일 경로를 요청했다. **이후 기존 64-bit ISE 14.7에서 전송 길이를 보정해 성공했으므로 이번 작업을 위해 14.1을 확보할 필요는 없어졌다.** 기존 14.7 설치·드라이버·보안 설정은 변경하지 않았다.

## 시간 측정과 이후 작업

전체 readback은 각각 **927초, 943초, 947초**, 최초 실패한 전체 verify는 **825초**였다. 첫 D202 삭제·쓰기·실패한 verify까지의 시간은 **268초**다. 최종 padding 방식의 성공한 기록·구간별 읽기 비교 실측은 **1,243.907초(약 20분 44초)**다. 초기 10~20분 안내는 실측 전 추정이었으며, 이 성공 시간에는 원본 백업·실패 조사·Flash 재구성이 포함되지 않는다.

JTAG 식별이 다시 불안정해지면 보드 전원을 내린 상태에서 H1 연결·접점을 확인하고, 필요하면 해당 보드 revision의 FPGA 전원 및 JTAG target reference 전압을 실측한다. SW4 위치나 LED만으로 FPGA 전원 상태를 판단하지 않는다. 기록 중에는 전원이나 연결을 변경하지 않는다.

## 아직 완료하지 못한 항목

- 실제 전원 재인가 부팅 및 D202 ABI 확인. 소프트웨어 재구성만으로 cold boot 검증을 완료했다고 표시하지 않는다.
- DDR2 패턴은 별도로 다시 업로드한다. 부팅 Flash에 FPGA 구성을 저장해도 DDR2 패턴 데이터가 비휘발성으로 바뀌지 않는다.

기존 J4 관련 제한은 [부팅 Flash 조사 기록](BOOT_FLASH_2026-10-28.md)을 따른다. J4로 원본과 사용자 이미지를 선택할 수 있다고 가정하지 않는다.


## 전송 길이 진단과 최종 기록

실행 폴더는 `runs/prom-finalize-20261028T085433Z/`이며, [보존 증거](../artifacts/dmd-spi-20261028/prom-finalize-20261028T085433Z/)에 원본 명령과 응답을 남긴다.

| 검사 | 실제 관측 |
|---|---|
| JEDEC 제조사/제품 ID | `01 02 15`, S25FL032P와 일치 |
| WREN 전 / 후 / WRDI 후 status | `0x00` / `0x02` / `0x00` |
| 보호 비트 | BP2:BP0=0, SRWD=0 |
| 원래 page program 후 | status=`0x02`, 데이터는 `0xFF` |
| JTAG 전송을 padding한 page program 후 | status=`0x00`, 별도 읽기 256바이트가 D202와 일치 |

Status 해석은 [S25FL032P datasheet §9.9–9.11](https://www.infineon.com/assets/row/public/documents/10/49/infineon-s25fl032p-32-mbit-3.0-v-flash-memory-datasheet-en.pdf)을 따른다. WEL은 정상 쓰기 완료 후 해제된다. 원래 전송에서는 쓰기 허용 자체는 됐지만 정상 쓰기 완료가 관측되지 않았다.

ISE 생성 SVF의 page write `SDR 2160`을 **`SDR 8560`으로 zero-padding**하고 대응하는 RUNTEST를 늘렸다. SPI header의 2,080비트 명령 길이(명령 1 + 주소 3 + 데이터 256바이트), 주소와 데이터는 그대로 유지했다. 앞선 긴 대기만 추가한 시험은 실패했고, padding 뒤에는 첫 페이지의 별도 읽기가 성공했다. 이 결과는 현재 ISE 14.7/Virtex-5 간접 SPI 경로의 짧은 쓰기 전송 문제를 가리킨다. 내부 bridge/케이블의 정확한 결함을 파형으로 규명한 것은 아니다.

전체 6,132페이지의 주소·데이터·verify mask를 D202 BIN과 미리 대조했다. 추가 erase와 보호 레지스터 변경 없이 512페이지씩 기록하고, 매 페이지 status 및 각 구간의 실제 읽은 데이터를 확인했다. 이미 검증한 첫 페이지는 다시 쓰지 않았다. 모든 구간이 끝나야 성공 결과 JSON이 생성된다.

최종 검증 범위는 D202 이미지 1,569,584바이트와 마지막 페이지 `0xFF` padding 208바이트다. 전체 이미지를 포함한 구간을 검증하며 Flash의 나머지 영역을 이번 단계에서 다시 읽었다고 주장하지 않는다. 실제 읽은 이미지의 SHA-256은 `ea90d7e62c49b016e2c9f755ebebb6b1d42174383be13dc0cf8c05cbf8f6999c`여야 한다.

재구성 검증은 [UG191의 JPROGRAM 정의](https://docs.amd.com/api/khub/documents/cTuOiEFk3dqCqgyb4BUTog/content)에 따라 LX50에 JPROGRAM → BYPASS만 보내 수행한다. CFG_IN이나 BIT 데이터 전송은 없다. 물리적으로 전원을 껐다 켜는 cold boot와는 별도 검사다. LX30/DLPC Flash는 기록 대상이 아니다.

초기 진단의 `play -cont_on_fail`은 mismatch가 있어도 마지막에 succeeded를 표시할 수 있다. 최종 전체 기록은 이 옵션 없이 실행하며, 모든 오류 문구를 거부하고 JTAG TDO를 별도 디코딩해 실제 바이트를 비교한다. `chunk_evidence.zip`에는 구간별 SVF·명령·로그·읽은 BIN·결과 JSON이, `offline_default.svf.gz`에는 변환 전 ISE 생성 원본이 들어 있다. 당일 복구용 스크립트는 당시 `runs/` 경로와 임시 SPI 코어 상태에 의존하므로 일반 사용자용 단독 업로드 CLI가 아니다.

32-bit iMPACT의 연결 문제는 `linux32`와 임시 디렉터리의 32-bit libusb로 해결했지만 동일한 page 쓰기 실패가 재현됐다. 따라서 32/64-bit 전환 자체가 해결책은 아니다. 최종 padding 경로는 **기존 64-bit ISE 14.7**을 사용하므로 추가 libusb에 의존하지 않는다. 진단용 CentOS 공식 RPM은 서명 검증 후 임시 폴더에만 풀었으며 OS 드라이버·보안 설정은 변경하지 않았다.

`tools/ise_program.py --program`은 계속 휘발성 JTAG 구성 명령이다. 이번 Flash 기록과 명령의 역할을 구분한다. 실제 전원 재인가 뒤 `dmd-test memory status`로 ABI/DDR 준비를 확인하고 패턴을 다시 업로드한다. DDR2의 패턴 데이터는 부팅 Flash에 포함되지 않는다.
