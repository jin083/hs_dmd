# 문서 안내

이 저장소는 FPGA RTL·합성·bitstream을 관리합니다. Python 장치 API는 `../dlpc410`, 실험 명령과 harness는 `../DMD-FPGA-Test`에 있습니다.

| 목적 | 문서 |
|---|---|
| 시작, ISE 빌드·JTAG 명령 | [프로젝트 README](../README.md) |
| D202 슬롯 관리·CRC·재생 계약 | [D202_MANAGED_MEMORY.md](D202_MANAGED_MEMORY.md) |
| 레지스터 주소 | [REGISTER_MAP.md](REGISTER_MAP.md) |
| 테스트 구조·실행·증거 구분 | [TESTING.md](TESTING.md) |
| 이번 구현 결과와 그래프 | [D202 구현 기록](reports/D202_2026-10-27.md) |
| 온도 센서 사용 | [CHIPSCOPE_TEMPERATURE.md](CHIPSCOPE_TEMPERATURE.md) |
| 발열 검토 | [THERMAL_REVIEW_2026-10-23.md](THERMAL_REVIEW_2026-10-23.md) |
| 과거 변경 기록 | [10/23](UPDATES_2026-10-23.md), [10/26](UPDATES_2026-10-26.md), [10/27 D201 업로드](UPDATES_2026-10-27.md) |

과거 보고서는 당시 상태를 보존합니다. `ARCHITECTURE.md`와 오래된 설계 계획보다 현재 README, 레지스터 명세 및 D202 문서를 우선합니다. TI PDF와 기존 IP/참조 소스는 원래 위치에 보관합니다.

- [보존된 D201 README](history/README_D201_2026-10-27.md): 과거 독립 PS 명령·레지스터 요약·JTAG 오류 진단. 현재 실행 순서는 루트 README를 따릅니다.
