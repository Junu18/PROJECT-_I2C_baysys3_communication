# Board-to-Board I2C Communication Test Guide

## 개요

이 테스트는 두 개의 Basys3 보드 간 I2C 통신을 **시뮬레이션**으로 검증합니다.

- **Master Board**: I2C Master만 탑재
- **Slave Board**: 3개의 I2C Slave (LED, FND, Switch) 탑재
- **연결**: PMOD 케이블로 SDA, SCL 연결 (4.7kΩ 풀업 포함)

## 파일 구조

```
i2c_top/
├── rtl/
│   ├── integration/
│   │   ├── i2c_master_board.sv    ← Master 보드 모듈 (새로 생성)
│   │   └── i2c_slave_board.sv     ← Slave 보드 모듈 (새로 생성)
│   ├── master/
│   │   └── i2c_master.sv
│   └── slaves/
│       ├── i2c_led_slave.sv
│       ├── i2c_fnd_slave.sv
│       └── i2c_switch_slave.sv
├── tb/
│   └── i2c_board2board_tb.sv      ← Board-to-Board 테스트벤치 (새로 생성)
└── sim/
    └── run_board2board.sh         ← 실행 스크립트 (새로 생성)
```

## 테스트 항목 (총 12개)

| # | 테스트 내용 | 검증 항목 |
|---|-----------|----------|
| 1 | LED 슬레이브 쓰기 | 0xFF → LED 출력 확인 |
| 2 | FND 슬레이브 쓰기 | 0x05 → 7-seg "5" 표시 |
| 3 | Switch 슬레이브 읽기 | SW=0xCD → Master 수신 확인 |
| 4 | 순차 동작 | LED 쓰기 → FND 쓰기 → Switch 읽기 |
| 5 | LED 패턴 변경 | 0xAA → 0x55 순차 쓰기 |
| 6 | FND 카운터 | 0~F 16개 숫자 표시 |
| 7 | Switch→LED 복사 | Switch 읽고 LED에 쓰기 |
| 8 | 잘못된 주소 | 0x99 → NACK 에러 검출 |
| 9 | **연속 읽기 (5회)** | 같은 슬레이브 반복 읽기 |
| 10 | **즉시 전환** | Write 직후 바로 Read |
| 11 | **비트 패턴 테스트** | 0x00, 0xFF, 0xAA, 0x55 |
| 12 | **동적 Switch 변경** | 읽기 중간에 SW 값 변경 |

**굵은 글씨**: 보드 간 통신 검증을 위한 추가 테스트

## 실행 방법

### 방법 1: Icarus Verilog (리눅스/WSL)

```bash
cd i2c_top/sim
./run_board2board.sh
```

### 방법 2: Vivado Simulator (GUI)

1. Vivado 프로젝트 생성
2. RTL 파일 추가:
   - `rtl/master/i2c_master.sv`
   - `rtl/slaves/*.sv` (3개)
   - `rtl/integration/i2c_master_board.sv`
   - `rtl/integration/i2c_slave_board.sv`
3. 테스트벤치 추가:
   - `tb/i2c_board2board_tb.sv`
4. Simulation Settings:
   - Top module: `i2c_board2board_tb`
   - Runtime: 50ms
5. Run Behavioral Simulation

### 방법 3: Vivado Simulator (TCL)

```tcl
# Vivado TCL Console에서 실행
cd i2c_top
source sim/run_board2board_vivado.tcl
```

## 예상 출력

시뮬레이션이 성공하면 다음과 같은 출력이 나옵니다:

```
================================================================================
          BOARD-TO-BOARD I2C COMMUNICATION TEST
          Master Board <--PMOD--> Slave Board
================================================================================

Test 1: Master writes 0xFF to LED Slave (0x55)
  ✓ PASS

Test 2: Master writes 0x05 to FND Slave (0x56)
  ✓ PASS

Test 3: Master reads from Switch Slave (0x57), SW=0xCD
  ✓ PASS

Test 4: Sequential - LED write → FND write → Switch read
  ✓ PASS

Test 5: LED Pattern - 0xAA → 0x55
  ✓ PASS

Test 6: FND Counter (0 → F)
  ✓ PASS

Test 7: Read Switch (0x3C) → Write to LED
  ✓ PASS

Test 8: Write to invalid address (0x99)
  ✓ PASS (ACK error detected)

Test 9: Continuous Read from Switch (5x)
  ✓ PASS (5 consecutive reads successful)

Test 10: Write LED → Immediate Read Switch
  ✓ PASS

Test 11: Bit Patterns (0x00, 0xFF, 0xAA, 0x55)
  ✓ PASS

Test 12: Switch changes during consecutive reads
  ✓ PASS (tracked SW changes correctly)

================================================================================
FINAL RESULTS:
  PASSED: 12/12
  FAILED: 0/12
================================================================================
✓ ALL TESTS PASSED!

Board-to-board communication verified successfully!
Ready for deployment on two separate Basys3 boards.
================================================================================
```

## 복사 방법

**터미널 출력을 복사하려면:**
1. 시뮬레이션 실행 후 전체 출력이 표시됨
2. 마우스로 드래그하여 전체 선택
3. Ctrl+C (또는 우클릭 → Copy)
4. 텍스트 파일 또는 이슈에 붙여넣기

**파일로 저장하려면:**
```bash
./run_board2board.sh | tee board2board_test_result.log
```

## 실제 하드웨어 배포

시뮬레이션이 통과하면 다음 단계:

### 1. Master Board 합성

**파일**: `rtl/integration/i2c_master_board.sv`
**제약**: `constraints/basys3_master.xdc`

```
PMOD JA 핀 배치:
- JA1 (pin K1): SCL
- JA2 (pin L2): SDA
```

### 2. Slave Board 합성

**파일**: `rtl/integration/i2c_slave_board.sv`
**제약**: `constraints/basys3_slaves.xdc`

```
PMOD JA 핀 배치:
- JA1 (pin K1): SCL
- JA2 (pin L2): SDA
```

### 3. 하드웨어 연결

```
Master Board (PMOD JA)  <---케이블--->  Slave Board (PMOD JA)
    JA1 (SCL) ----------------------------- JA1 (SCL)
    JA2 (SDA) ----------------------------- JA2 (SDA)
    GND ------------------------------- GND
```

**중요**: PMOD 케이블에 4.7kΩ 풀업 저항 필요 (SDA, SCL 각각 3.3V에 연결)

## 문제 해결

### Q: 컴파일 에러 발생
- SystemVerilog 지원 확인: `-g2012` 플래그 (iverilog) 또는 Vivado 2018.2+

### Q: 테스트가 TIMEOUT
- SCL 주파수 확인 (100kHz)
- 클록 생성 확인 (100MHz)

### Q: ACK 에러 발생
- 슬레이브 주소 확인 (0x55, 0x56, 0x57)
- 풀업 저항 확인 (tri1 타입)

### Q: rx_data가 'z'
- I2C 버스 풀업 확인
- Switch 슬레이브 TX_DATA 상태 확인

## 추가 정보

- **단일 보드 테스트**: `sim/run_system.sh` 사용
- **간단한 디버그**: `sim/run_simple_debug_tb.sh` 사용
- **파일 가이드**: `docs/FILE_USAGE_GUIDE.md` 참조
