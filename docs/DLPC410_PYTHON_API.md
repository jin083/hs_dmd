# DLPC410 Python API 위치 변경

Python 제어 패키지는 별도 [`jin083/dlpc410`](https://github.com/jin083/dlpc410/tree/feature/ddr2-memory-api) 저장소에서 관리합니다. 이 `hs_dmd` 저장소는 FPGA RTL, 합성 도구, bitstream과 검증 자료를 담당합니다.

2026-10-23 초기 구현은 이 저장소의 `feature/dlpc410-python-api`에 `hs-dlpc410`이라는 패키지로 잘못 배치되어 있었습니다. 사용자 지적에 따라 실제 Python 제어 저장소로 이동했습니다.

| 항목 | 현재 위치 |
|---|---|
| 패키지 저장소 / 브랜치 | `jin083/dlpc410` / `feature/ddr2-memory-api` |
| 배포명 / 버전 | `dlpc410` / `0.2.0` |
| D201 API import | `from dmd_ctrl.memory import DLPC410, PatternLibrary, PlaybackPlan` |
| 기존 TI 제어 클래스 | `dmd_ctrl.dlpc7000_class.DDC4100Controller` 유지 |
| API 설명 | [dlpc410/docs/MEMORY_API.md](https://github.com/jin083/dlpc410/blob/feature/ddr2-memory-api/docs/MEMORY_API.md) |
| 숫자 BMP·테스트 CLI | [DMD-FPGA-Test](https://github.com/jin083/DMD-FPGA-Test/tree/feature/dlp7000-memory-tests) |

`DMD-FPGA-Test` 폴더에서 기존 Python에 두 로컬 패키지를 설치합니다. 가상환경은 사용하지 않습니다.

```powershell
python -m pip install --no-index --no-build-isolation -e ..\dlpc410 -e .
python -m dmd_test show --number 7 --simulate
```

이 저장소의 `tools/dmd_playback.ps1`은 Python 패키지 설치 없이 실행할 수 있는 독립 FPGA 진단 도구로 유지합니다. Python API는 새 저장소의 `dmd_ctrl/memory/dmd_playback.ps1`을 사용합니다. 이번 위치 변경은 FPGA RTL·IP·bitstream 변경을 포함하지 않습니다. 실제 장치 접근 없이 오프라인에서 확인했습니다.
