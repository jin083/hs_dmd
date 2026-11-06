## 전송 길이 진단과 최종 기록

실행 폴더는 `runs/prom-finalize-20261028T085433Z/`이며, [보존 증거](./)에 원본 명령과 응답을 남긴다.

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
