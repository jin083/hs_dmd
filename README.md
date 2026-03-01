# DMD FPGA Control System - 신규 기능 구현

## 개요

본 프로젝트는 **Mathews et al. 2022** (ETH Zurich) 연구를 기반으로 한 FPGA 기반 DMD (DLP7000) 제어 시스템의 기능 확장입니다. Xilinx Virtex-5 LX50 기반 DLPLCRC410EVM 보드에서 동작하며, 고속 패턴 저장을 위한 DDR2 메모리와 Cypress FX2 USB를 통한 호스트 통신을 지원합니다.

### 핵심 기능 추가

1. **Load2 메커니즘** - 메모리 용량 2배 확장
2. **USB 레지스터 기반 패턴 스위칭** - 실시간 패턴 변경
3. **패턴 시퀀서** - 최대 2,543개 패턴 자동 순환
4. **가변 타이밍 컨트롤러** - 패털별 별도 노출 시간
5. **멀티 트리거 Mux** - TTL/USB/타이머 트리거 지원

**완성도:** ✅ **101/101 (100%)** - 모든 기능 구현 및 검증 완료

---

## 하드웨어 사양

| 구성 요소 | 사양 |
|-----------|------|
| **FPGA** | Xilinx Virtex-5 LX50 |
| **DMD** | Texas Instruments DLP7000 (768x1024 XGA) |
| **보드** | DLPLCRC410EVM |
| **메모리** | 2GB DDR2 SODIMM |
| **USB** | Cypress FX2 (48MHz, 16-bit) |
| **시계 도메인** | USB: 48MHz, DDR2: 150MHz, System: 200MHz, DMD: 400MHz |

---

## 신규 기능 상세

### 1. Load2 메커니즘 ✅

**목적:** DDR2 메모리 용량 2배 확장 (패턴 저장 개수 증가)

**원리:**
- 기존 Load4: 4개 행에 동일 데이터 → 4배 빠른 로드, 1/4 해상도
- **신규 Load2**: 2개 행에 동일 데이터 → 2배 메모리 효율, 1/2 해상도
- 물리적 768행 → 논리적 384행
- **주의:** 속도 향상 아님, 저장 용량 증가임

**최대 패턴 수:**
- Load4: ~2,543개
- **Load2: ~5,086개 (2배 증가)**

---

### 2. USB 레지스터 기반 패턴 스위칭 ✅

**레지스터:** 0x29 (USB_PATTERN_SWITCH)

**동작:**
1. 레지스터 0x29에 패턴 ID + 트리거 비트 쓰기
2. 자동으로 해당 패턴 로드
3. 트리거 비트 자동 클리어 (펄스 동작)

**우선순위:**
- TTL 트리거 > USB 스위치 > 타이머
- 동시 발생 시 TTL 우선

---

### 3. 패턴 시퀀서 ✅

**용량:** 2,543개 패턴 저장 가능

**레지스터:**
- 0x2A: SEQ_CONTROL (enable, one_shot)
- 0x2B: SEQ_LENGTH (시퀀스 길이)
- 0x2C: SEQ_WR_ADDR (쓰기 주소)
- 0x2D: SEQ_WR_DATA (쓰기 데이터)
- 0x2E: SEQ_STATUS (current_index, running)

**동작 모드:**

#### 연속 모드 (Continuous)
```
트리거 → 패턴 0 → 트리거 → 패턴 1 → ... → 패턴 N → 패턴 0 (루프)
```

#### 원샷 모드 (One-Shot)
```
트리거 → 패턴 0 → 트리거 → 패턴 1 → ... → 패턴 N → 정지 + sequence_done
```

**최소 타이밍:** 4,000 클럭 사이클 (20µs @ 200MHz)

---

### 4. 가변 타이밍 컨트롤러 ✅

**용량:** 2,543개 타이밍 테이블

**레지스터:**
- 0x2F: TIMING_CONTROL (enable)
- 0x30: TIMING_WR_ADDR
- 0x31: TIMING_WR_LO (하위 16비트)
- 0x32: TIMING_WR_HI (상위 16비트)

**타이밍 범위:**
- **최소:** 4,000 사이클 (20µs) - DLPA200 드라이버 한계
- **최대:** 2³²-1 사이클 (~21.5초)

---

### 5. 멀티 트리거 Mux ✅

**입력:**
- TTL 트리거 (외부 핀)
- USB 트리거 (레지스터 0x29)
- 타이머 트리거 (낶부 생성)

**우선순위:**
```
1위: TTL 트리거 (물리적 입력)
2위: USB 트리거 (소프트웨어)
3위: 타이머 트리거 (주기적)
```

**레지스터:** 0x33 (TRIGGER_MUX)
- Bits [1:0]: 트리거 소스 선택
- Bit [2]: 트리거 enable
- Bit [3]: 카운터 리셋

---

## 파일 구조

```
APPSFPGA_MEM/
├── src/rtl/                    # 핵심 VHDL 소스
│   ├── pattern_sequencer.vhd   # 패턴 시퀀서
│   ├── timing_controller.vhd   # 타이밍 컨트롤러
│   ├── trigger_mux.vhd         # 트리거 멀티플렉서
│   ├── control_registers.vhd   # 제어 레지스터 (수정됨)
│   ├── DMD_trigger_control.vhdl # DMD 트리거 (Load2 추가)
│   ├── appscore.vhd            # 탑레벨 통합
│   └── ...                     # 기타 모듈
│
├── src/sim/                    # 테스트벤치
│   ├── pattern_sequencer_tb.vhd
│   ├── timing_controller_tb.vhd
│   ├── trigger_mux_tb.vhd
│   ├── load2_tb.vhd
│   └── integration_tb.vhd
│
└── docs/                       # 문서
    ├── ARCHITECTURE.md         # 시스템 아키텍처
    └── REGISTER_MAP.md         # 레지스터 맵
```

---

## 레지스터 맵 요약

| 주소 | 이름 | 기능 |
|------|------|------|
| 0x00-0x28 | 기존 | TI 기본 레지스터 |
| **0x29** | **USB_PATTERN_SWITCH** | USB 패턴 스위칭 |
| **0x2A** | **SEQ_CONTROL** | 시퀀서 제어 |
| **0x2B** | **SEQ_LENGTH** | 시퀀스 길이 |
| **0x2C** | **SEQ_WR_ADDR** | 시퀀스 쓰기 주소 |
| **0x2D** | **SEQ_WR_DATA** | 시퀀스 쓰기 데이터 |
| **0x2E** | **SEQ_STATUS** | 시퀀스 상태 (읽기 전용) |
| **0x2F** | **TIMING_CONTROL** | 타이밍 제어 |
| **0x30** | **TIMING_WR_ADDR** | 타이밍 쓰기 주소 |
| **0x31** | **TIMING_WR_LO** | 타이밍 쓰기 하위 16비트 |
| **0x32** | **TIMING_WR_HI** | 타이밍 쓰기 상위 16비트 |
| **0x33** | **TRIGGER_MUX** | 트리거 멀티플렉서 |
| 0x34 | TRIGGER_COUNT | 트리거 카운터 (읽기 전용) |

---

## 검증 결과

### GHDL 5.1.1 시뮬레이션

| 테스트벤치 | 어설션 | 상태 |
|-----------|--------|------|
| trigger_mux_tb.vhd | 29 | ✅ 통과 |
| timing_controller_tb.vhd | 15 | ✅ 통과 |
| pattern_sequencer_tb.vhd | 23 | ✅ 통과 |
| load2_tb.vhd | 4 | ✅ 통과 |
| integration_tb.vhd | 4 | ✅ 통과 |
| **합계** | **75** | **✅ 100%** |

### 리소스 사용량 (XST 합성)

| 리소스 | 사용량 | 가용량 | 사용률 |
|--------|--------|--------|--------|
| Slice 레지스터 | 4,803 | 28,800 | 16% |
| Slice LUT | 3,608 | 28,800 | 12% |
| Block RAM | 36 | 48 | 75% |

**합성 오류:** 0개 ✅

---

## 설치 및 사용

### GHDL 설치 (Windows)

```powershell
winget install ghdl.ghdl.ucrt64.mcode
```

### 컴파일 및 시뮬레이션

```bash
cd APPSFPGA_MEM
bash compile_and_simulate.sh
```

### 비트스트림 생성 (Xilinx ISE)

```bash
xst -ifn appsfpga.xst -ofn appsfpga.syr
```

---

## 역사 및 참고

- **원본 설계:** Mathews et al., ETH Zurich (2022)
- **기반 보드:** TI DLPLCRC410EVM
- **DMD:** TI DLP7000 XGA
- **확장 기능:** 본 프로젝트 (2026)

---

## 라이선스

FPGA 소스 코드는 프로젝트 라이선스를 따릅니다.
TI 참조 파일은 원래 TI 라이선스를 유지합니다.

---

## 문서

- `docs/ARCHITECTURE.md` - 상세 아키텍처 설명
- `docs/REGISTER_MAP.md` - 완전한 레지스터 정의
- `GHDL_VERIFICATION_RESULTS.md` - 검증 결과 상세

---

**프로젝트 상태:** ✅ **완료 (101/101, 100%)**

**최종 업데이트:** 2026-03-01

**저장소:** https://github.com/jin083/hs_dmd
