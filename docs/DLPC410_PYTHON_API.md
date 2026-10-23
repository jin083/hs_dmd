# DLPC410 / DLP7000 Python 제어 패키지

브랜치: `feature/dlpc410-python-api`. 패키지 배포명은 `hs-dlpc410`, import 이름은 `dlpc410`입니다. 검증된 FPGA ABI D201 위에 BMP 변환·DDR2 저장·개별 이미지 표시·시퀀스 재생 함수를 추가합니다. 이 브랜치의 변경으로 FPGA RTL이나 bitstream을 다시 생성할 필요는 없습니다.

2026-10-23 사용자가 DMD 전원을 내렸다고 알려주었습니다. 이번 패키지는 **오프라인 테스트만 수행**했으며 실제 USB 업로드/광학 결과는 확인하지 않았습니다. 이전 iMPACT 성공 기록은 당시의 FPGA 구성 결과입니다. 다음 실기 시험에는 전원 인가 후 D201 bitstream 재구성과 DDR2 패턴 업로드가 필요합니다.

## 설치와 의존성

Python 3.10 이상. Python 런타임 의존 패키지는 없습니다. BMP 처리는 표준 라이브러리를 사용합니다. 실제 장치 제어에는 Windows, 기존 32-bit TI `D4100_usb.dll`과 USB 드라이버가 필요합니다. Python 자체는 64-bit여도 됩니다. 패키지가 32-bit Windows PowerShell을 통해 DLL을 호출합니다.

```powershell
# pip/setuptools가 이미 있는 환경에서 네트워크 없이 설치
python -m pip install --no-index --no-deps --no-build-isolation -e .
python -m unittest discover -s tests -v
```

패키지의 `dlpc410/dmd_playback.ps1`이 USB 제어 원본입니다. 기존 `tools/dmd_playback.ps1` 경로는 호환용 진입점으로 유지합니다. 장치 제어 함수는 FPGA 프로그래밍을 수행하지 않습니다.

## API

| 함수 | 동작 |
|---|---|
| `PatternLibrary.create(bmps, output, ...)` | BMP 변환, packed 파일·SHA-256 목록 생성. 기존 출력 폴더 덮어쓰기 금지 |
| `PatternLibrary.load(manifest)` | 각 packed 이미지 크기와 해시 확인 |
| `DLPC410(library, transport=...)` | 이미지 목록 및 전송 방식 연결. 생성만으로 USB 접근하지 않음 |
| `upload()` | 전체 라이브러리를 DDR2에 저장하고 정지 상태 유지 |
| `show(pattern_id)` | 저장된 이미지 한 장 표시, 완료 대기. 마지막 이미지는 유지 |
| `configure(PlaybackPlan(...))` | DDR2 재전송 없이 순서·주기·반복 횟수 설정 |
| `play(plan, trigger=False)` | 설정 후 즉시 시작, 또는 TTL 시작 대기 |
| `wait_done(timeout_s)` | 유한 반복 완료 대기. 외부 트리거 대기도 timeout에 포함 |
| `stop()` | 재생 중 프레임을 마무리하고 정지 확인. 화면 blank 명령은 아님 |
| `status()` | 연결, ABI, 업로드 개수, 실행/완료/오류, 트리거 및 반복 상태 |

```python
from dlpc410 import DLPC410, PatternLibrary, PlaybackPlan, MockTransport

library = PatternLibrary.load("patterns/numbers/packed/library.json")
dmd = DLPC410(library, MockTransport())  # 현재 전원 OFF: 모의 실행
dmd.upload()
dmd.show(2)  # API는 0부터 시작: 숫자 3에 해당
try:
    dmd.play(PlaybackPlan((0, 2, 4, 6, 9), (100000,), repeat_count=2))
    print(dmd.wait_done(timeout_s=30))
finally:
    dmd.stop()
```

실제 연결은 `PowerShellTransport(device=0, dll_path=...)`로 교체합니다. DLL이 이미 검색 경로에 있으면 `dll_path`는 생략합니다. 소스·DLL 경로는 shell 문자열로 이어붙이지 않고 인자 목록으로 전달합니다. USB 장치 인덱스는 JTAG 체인 위치와 별개입니다.

## 이미지와 타이밍 계약

- DLP7000 full XGA 1024×768, Global update만 지원합니다.
- 일반 Windows BMP의 비압축 1/24/32-bit만 지원합니다. 24/32-bit는 기본 밝기 threshold=128로 이진화하며 alpha는 사용하지 않습니다. 압축 BMP와 다른 해상도는 거부합니다.
- BMP 헤더/팔레트/상하 행 방향을 해석한 뒤 위→아래, 왼쪽→오른쪽, MSB-first, white=1 형식의 98,304바이트를 생성합니다. USB byte swap 및 AB lane 변환은 기존 FPGA 경로에서 처리합니다.
- `invert`, `flip_x`, `flip_y`, `threshold`를 변환 단계에서 선택할 수 있습니다. 실제 광학계에서의 방향·ON/OFF 극성은 숫자와 방향 마커로 확인해야 합니다.
- `sequence`는 0부터 시작하는 라이브러리 인덱스, 최대 2543개 항목입니다. 반복 번호는 0=무한, 1..65535=전체 리스트 반복 횟수입니다.
- `period_us`는 1개 공통값 또는 시퀀스 항목별 값입니다. 20µs 이상이며 FPGA의 5ns tick으로 올림 처리됩니다. `PlaybackPlan.at_rate(..., rate_hz=10)`은 패턴별 100ms를 요청합니다.
- 20µs는 허용 요청 하한이며 50kHz 실제 표시를 보장하지 않습니다. 기존 RTL 시뮬레이션에서 짧은 요청의 MCP 간격은 약 64.515–65.935µs였습니다. 물리적 전환 속도는 미측정입니다.
- `trigger=True`는 GPIOA[0] 상승 에지로 전체 시퀀스를 시작합니다. 재생 중 트리거는 무시되고 missed 상태가 기록됩니다. Python이 µs 간격으로 패턴을 바꾸지 않습니다.
- `play()` 후에는 호출자가 `try/finally: stop()`을 사용합니다. 무한 반복은 `wait_done()`으로 완료되지 않습니다. 테스트 CLI는 Ctrl+C/시간 제한/실패 시 정지를 요청합니다.

DDR2의 실제 콘텐츠 readback API는 없습니다. 업로드 성공은 DLL 반환값·FPGA 상태·프레임 개수로 확인하며, 동일 개수의 다른 라이브러리를 구별하는 FPGA 해시 검증은 지원하지 않습니다. 라이브러리를 바꾸거나 전원을 다시 켰으면 반드시 `upload()`부터 실행해야 합니다.

## 검증 범위

BMP 행 순서·팔레트 극성·좌우/상하 반전·24/32-bit threshold·잘못된 파일 거부, 업로드/표시/유한·무한·TTL 명령 흐름, 잘못된 설정의 사전 차단, 통신 실패 시 정지 요청을 단위 테스트로 확인합니다. `MockTransport`는 명령 순서 fixture이며 DDR2나 광학 타이밍 모델이 아닙니다. 모의 TTL 에지는 즉시 발생한 것으로 처리합니다.

실행용 CLI, 숫자 BMP 10장, PC 미리보기와 후속 detector 계획은 [DMD-FPGA-Test 브랜치](https://github.com/jin083/DMD-FPGA-Test/tree/feature/dlp7000-memory-tests)에 있습니다.

2026-10-23 실행 결과: 패키지 단위 테스트 **10개 통과**, PowerShell 구문 검사 통과, 네트워크 없는 editable 설치 및 wheel 빌드 성공, wheel 내부 USB 스크립트 포함 확인. 기존 bitstream·검증 보고서의 SHA-256과 FPGA 빌드 입력 79개의 해시가 그대로 유지됨을 확인했습니다.
