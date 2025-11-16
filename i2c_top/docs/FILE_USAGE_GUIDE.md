# 📁 파일 용도 정리 가이드

## 🎯 핵심 질문: i2c_master vs board_master_top 왜 분리?

### 간단 답변:
```
i2c_master.sv          → Vivado IP로 만들 순수한 I2C 엔진 (재사용 가능)
board_master_top.sv    → 개발/테스트용 완전한 보드 (버튼, 스위치 포함)
```

**비유:**
- `i2c_master.sv` = 자동차 엔진 (어디든 장착 가능)
- `board_master_top.sv` = 완성된 자동차 (엔진 + 핸들 + 브레이크)

---

## 📊 RTL 파일 용도 (SystemVerilog)

### 1️⃣ Core IP (재사용 가능한 순수 로직)

| 파일 | 어디에 쓰나? | 역할 | 입출력 |
|------|-------------|------|--------|
| **rtl/master/i2c_master.sv** | ✅ Vivado IP로 패키징<br>✅ 시뮬레이션<br>✅ 모든 top 모듈에 인스턴스 | 순수 I2C 프로토콜 엔진<br>- START/STOP 생성<br>- Address/Data 전송<br>- ACK/NACK 처리 | **입력:**<br>- clk, rst_n<br>- start (펄스)<br>- rw_bit (0=Write, 1=Read)<br>- slave_addr[6:0]<br>- tx_data[7:0]<br><br>**출력:**<br>- scl, sda (I2C 버스)<br>- rx_data[7:0]<br>- busy, done, ack_error<br>- debug signals |
| **rtl/slaves/i2c_led_slave.sv** | ✅ Board #2 (Slaves)<br>✅ 시뮬레이션 | LED 제어 Slave<br>주소: 0x55<br>Write-only | **입력:**<br>- clk, rst_n<br>- scl, sda (I2C)<br><br>**출력:**<br>- LED[7:0] |
| **rtl/slaves/i2c_fnd_slave.sv** | ✅ Board #2 (Slaves)<br>✅ 시뮬레이션 | 7-Segment 제어 Slave<br>주소: 0x56<br>Write-only | **입력:**<br>- clk, rst_n<br>- scl, sda (I2C)<br><br>**출력:**<br>- SEG[6:0]<br>- AN[3:0] |
| **rtl/slaves/i2c_switch_slave.sv** | ✅ Board #2 (Slaves)<br>✅ 시뮬레이션 | Switch 읽기 Slave<br>주소: 0x57<br>Read-only | **입력:**<br>- clk, rst_n<br>- scl, sda (I2C)<br>- SW[7:0]<br><br>**출력:**<br>- sda (데이터 전송) |

---

### 2️⃣ Integration Modules (보드 레벨 통합)

| 파일 | 어디에 쓰나? | 왜 필요한가? | 포함 내용 |
|------|-------------|-------------|----------|
| **rtl/integration/i2c_system_top.sv** | ✅ **단일 보드 데모**<br>(1개 보드에 Master+Slaves) | 개발/시연용<br>하나의 보드에서 모든 기능 테스트 | - i2c_master<br>- i2c_led_slave<br>- i2c_fnd_slave<br>- i2c_switch_slave<br>- 내부 I2C 버스 연결 |
| **rtl/integration/board_master_top.sv** | ✅ **Board #1 (Reference)**<br>실제로는 MicroBlaze 사용<br>⚠️ 테스트/개발 전용 | 버튼/스위치로 직접 제어<br>(MicroBlaze 없이 테스트) | - i2c_master<br>- BTNU 버튼 입력<br>- SW[15:0] 입력<br>- LED[15:0] 출력<br>- 버튼 debounce<br>- 스위치 → 파라미터 변환 |
| **rtl/integration/board_slaves_top.sv** | ✅ **Board #2 (실제 사용)**<br>Slave 보드용 | 보드간 통신 데모 | - i2c_led_slave<br>- i2c_fnd_slave<br>- i2c_switch_slave<br>- LED/FND/SW 연결 |

---

## 🔍 핵심 차이점: i2c_master vs board_master_top

### i2c_master.sv (순수 IP)

```systemverilog
module i2c_master (
    // 시스템
    input  logic        clk,
    input  logic        rst_n,

    // 제어 (AXI 레지스터에서 올 값)
    input  logic        start,        // ← AXI write
    input  logic        rw_bit,       // ← AXI 레지스터
    input  logic [6:0]  slave_addr,   // ← AXI 레지스터
    input  logic [7:0]  tx_data,      // ← AXI 레지스터
    output logic [7:0]  rx_data,      // → AXI 레지스터
    output logic        busy,         // → AXI 상태
    output logic        done,         // → AXI 인터럽트

    // I2C 버스
    inout  logic        sda,
    output logic        scl
);
```

**특징:**
- ✅ 순수한 I2C 프로토콜만
- ✅ 버튼/스위치 없음
- ✅ Vivado IP Packager로 패키징 가능
- ✅ 어떤 시스템에든 통합 가능
- ✅ MicroBlaze AXI 버스에 연결

**사용 예:**
1. Vivado Block Design에서 AXI IP로 추가
2. MicroBlaze AXI 버스에 연결
3. 펌웨어에서 레지스터 제어

---

### board_master_top.sv (보드 레벨)

```systemverilog
module board_master_top (
    input  logic       clk,
    input  logic       rst_n,

    // 보드 입력 (Basys3 하드웨어)
    input  logic       btn_start,    // ← BTNU 버튼 (Pin T18)
    input  logic [15:0] SW,          // ← 스위치 (Pin V17-R2)

    // 보드 출력 (Basys3 하드웨어)
    output logic [15:0] LED,         // → LED (Pin U16-L1)

    // I2C 버스 (PMOD)
    output logic       scl,          // → Pin J1
    inout  logic       sda           // ↔ Pin L2
);

    // 내부에서 i2c_master 인스턴스 생성
    i2c_master master (
        .clk(clk),
        .rst_n(rst_n),
        .start(btn_pulse),          // ← 버튼에서
        .slave_addr(SW[14:8]),      // ← 스위치에서
        .tx_data(SW[7:0]),          // ← 스위치에서
        .rx_data(rx_data),          // → LED로
        .sda(sda),
        .scl(scl)
    );

    // LED로 상태 표시
    assign LED[7:0] = rx_data;
    assign LED[8] = busy;
    assign LED[9] = done;
endmodule
```

**특징:**
- ✅ i2c_master를 포함
- ✅ Basys3 보드 I/O 연결
- ✅ 버튼 debounce 로직
- ✅ 스위치 → 파라미터 변환
- ✅ LED 상태 표시
- ✅ 펌웨어 없이 테스트 가능

**사용 예:**
1. 개발 중 빠른 테스트
2. I2C 프로토콜 검증
3. 하드웨어 동작 확인
4. 데모/발표용

---

## 📋 실제 사용 시나리오별 파일 조합

### 시나리오 A: 단일 보드 데모 (시뮬레이션/시연)

```
Vivado 프로젝트:
├─ Top Module: i2c_system_top.sv
├─ Constraints: basys3_integrated.xdc
└─ 사용 파일:
   ├─ rtl/master/i2c_master.sv
   ├─ rtl/slaves/i2c_led_slave.sv
   ├─ rtl/slaves/i2c_fnd_slave.sv
   ├─ rtl/slaves/i2c_switch_slave.sv
   └─ rtl/integration/i2c_system_top.sv

결과: 1개 보드에서 모든 기능 테스트
```

---

### 시나리오 B: Board-to-Board (개발 테스트)

#### Board #1 (Master - 간단 테스트)
```
Vivado 프로젝트:
├─ Top Module: board_master_top.sv
├─ Constraints: basys3_master.xdc
└─ 사용 파일:
   ├─ rtl/master/i2c_master.sv
   └─ rtl/integration/board_master_top.sv

조작: BTNU + 스위치로 직접 제어
```

#### Board #2 (Slaves)
```
Vivado 프로젝트:
├─ Top Module: board_slaves_top.sv
├─ Constraints: basys3_slaves.xdc
└─ 사용 파일:
   ├─ rtl/slaves/i2c_led_slave.sv
   ├─ rtl/slaves/i2c_fnd_slave.sv
   ├─ rtl/slaves/i2c_switch_slave.sv
   └─ rtl/integration/board_slaves_top.sv

결과: LED, FND, SW 동작
```

---

### 시나리오 C: 실전 시스템 (MicroBlaze + 펌웨어)

#### Board #1 (Master - 실제 구현)
```
Vivado Block Design:
├─ MicroBlaze 프로세서
├─ AXI Interconnect
├─ i2c_master.sv (AXI IP로 패키징)
├─ UART, Timer 등
└─ Constraints: Vivado가 자동 생성

사용 파일:
└─ rtl/master/i2c_master.sv만!
   (board_master_top.sv는 사용 안 함!)

Vitis 프로젝트 (펌웨어):
├─ firmware/i2c_driver.c
├─ firmware/i2c_driver.h
├─ firmware/i2c_regs.h
├─ firmware/main.c
├─ firmware/demo_led.c
├─ firmware/demo_fnd.c
└─ firmware/demo_switch.c

조작: 펌웨어 코드로 제어 (i2c_write/i2c_read)
```

#### Board #2 (Slaves - 동일)
```
(시나리오 B와 동일)
```

---

## 🎯 왜 이렇게 분리했나?

### 설계 철학:

```
┌──────────────────────────────────────────┐
│  설계 목표: 재사용 가능한 IP             │
└──────────────────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
    개발/테스트              실제 제품
        │                       │
        ▼                       ▼
board_master_top          MicroBlaze System
(버튼+스위치로 제어)      (펌웨어로 제어)
        │                       │
        └───────────┬───────────┘
                    │
                    ▼
              i2c_master.sv
           (순수한 I2C 엔진)
```

### 실전 예시:

**개발 초기:**
```
1. i2c_master.sv 작성
2. board_master_top.sv로 감싸기
3. Basys3에 프로그램
4. BTNU + 스위치로 직접 테스트
   ✓ 빠른 검증!
   ✓ 펌웨어 없어도 됨!
```

**제품 단계:**
```
1. i2c_master.sv만 가져오기
2. Vivado IP Packager로 AXI IP 생성
3. MicroBlaze 시스템에 추가
4. 펌웨어 개발
   ✓ 검증된 IP 재사용!
   ✓ board_master_top은 버림!
```

---

## 📝 Testbench 파일

| 파일 | 테스트 대상 | 용도 |
|------|------------|------|
| **tb/i2c_led_slave_tb.sv** | i2c_led_slave.sv | LED Slave 단독 검증<br>I2C master simulator 포함 |
| **tb/i2c_fnd_slave_tb.sv** | i2c_fnd_slave.sv | FND Slave 단독 검증 |
| **tb/i2c_switch_slave_tb.sv** | i2c_switch_slave.sv | Switch Slave 단독 검증 |
| **tb/i2c_system_tb.sv** | i2c_system_top.sv | Master + 3 Slaves 통합 검증<br>모든 시나리오 테스트 |

**실행:**
```bash
cd i2c_top/sim
./run_led_slave.sh      # LED 테스트
./run_fnd_slave.sh      # FND 테스트
./run_switch_slave.sh   # Switch 테스트
./run_system.sh         # 통합 테스트
./run_all_tests.sh      # 모두 실행
```

---

## 💻 Firmware 파일 (C 코드)

| 파일 | 역할 | 어디에 쓰나? |
|------|------|-------------|
| **firmware/i2c_regs.h** | AXI 레지스터 정의<br>매크로 | MicroBlaze 펌웨어<br>컴파일 타임 설정 |
| **firmware/i2c_driver.h** | 드라이버 API 선언<br>함수 프로토타입 | 모든 C 파일에서 include |
| **firmware/i2c_driver.c** | 드라이버 구현<br>i2c_write/read 함수 | MicroBlaze에서 실행 |
| **firmware/demo_led.c** | LED 제어 데모<br>- 깜빡임<br>- 패턴<br>- 카운터 | 데모/발표용<br>선택적 사용 |
| **firmware/demo_fnd.c** | FND 제어 데모<br>- 숫자 표시<br>- 카운팅 | 데모/발표용<br>선택적 사용 |
| **firmware/demo_switch.c** | Switch 읽기 데모<br>- SW→LED 복사<br>- 패턴 감지 | 데모/발표용<br>선택적 사용 |
| **firmware/main.c** | 메인 루프<br>모든 데모 실행 | MicroBlaze 진입점<br>필수! |

**컴파일 순서 (Vitis):**
```
1. i2c_regs.h, i2c_driver.h 준비
2. i2c_driver.c 컴파일
3. demo_*.c 컴파일 (선택)
4. main.c 컴파일
5. 링크 → .elf 생성
6. MicroBlaze에 다운로드
```

---

## 🗂️ Constraints 파일 (.xdc)

| 파일 | 어느 보드? | 어떤 Top Module? |
|------|-----------|-----------------|
| **constraints/basys3_integrated.xdc** | 1개 보드<br>(Master+Slaves 통합) | i2c_system_top.sv |
| **constraints/basys3_master.xdc** | Board #1<br>(Master 단독) | board_master_top.sv<br>(테스트용) |
| **constraints/basys3_slaves.xdc** | Board #2<br>(Slaves 3개) | board_slaves_top.sv |

---

## 🎓 교육적 가치 - 왜 이렇게 설계했나?

### 계층적 설계 (Hierarchical Design)

```
Level 3: Board Level
├─ board_master_top.sv    (테스트용 완성품)
├─ board_slaves_top.sv    (제품용 완성품)
└─ i2c_system_top.sv      (데모용 완성품)
        │
        ▼
Level 2: Protocol Level
├─ i2c_master.sv          (재사용 가능 IP)
├─ i2c_led_slave.sv       (재사용 가능 IP)
├─ i2c_fnd_slave.sv       (재사용 가능 IP)
└─ i2c_switch_slave.sv    (재사용 가능 IP)
        │
        ▼
Level 1: FSM & Logic
└─ (각 모듈 내부 구현)
```

### IP 재사용성 (IP Reusability)

```
i2c_master.sv는:
✓ Basys3 보드에서 동작
✓ Zynq SoC에서 동작
✓ Artix-7에서 동작
✓ 다른 FPGA에서 동작
✓ ASIC으로 변환 가능

왜? → 순수한 로직만 있고, 보드 특정 요소가 없기 때문!
```

### 개발 효율성

```
Phase 1: IP 개발
├─ i2c_master.sv 작성
├─ board_master_top.sv로 테스트
└─ 검증 완료 ✓

Phase 2: IP 재사용
├─ i2c_master.sv만 가져오기
├─ MicroBlaze 시스템에 통합
└─ 펌웨어 개발

시간 절약: 검증된 IP를 재사용하므로 버그 없음!
```

---

## 📊 최종 요약 표

| 목적 | 사용 파일 | 조작 방법 |
|------|----------|----------|
| **시뮬레이션** | i2c_master.sv<br>i2c_*_slave.sv<br>*_tb.sv | ./run_system.sh |
| **단일 보드 데모** | i2c_system_top.sv<br>basys3_integrated.xdc | SW + BTNU |
| **보드간 테스트** | board_master_top.sv<br>board_slaves_top.sv | Board #1: SW+BTNU<br>Board #2: SW 설정 |
| **실전 제품** | i2c_master.sv (IP)<br>board_slaves_top.sv<br>firmware/*.c | Board #1: 펌웨어<br>Board #2: 자동 응답 |

---

## 🎯 결론

### i2c_master vs board_master_top 차이:

| 특성 | i2c_master.sv | board_master_top.sv |
|------|--------------|-------------------|
| **성격** | 라이브러리 (IP) | 완제품 (보드) |
| **의존성** | 없음 (순수 로직) | Basys3 특정 |
| **재사용** | ✅ 어디든 가능 | ✗ Basys3만 |
| **펌웨어** | ✅ 필요 (MicroBlaze) | ✗ 불필요 (버튼) |
| **실제 제품** | ✅ 사용 | ✗ 테스트만 |
| **개발 속도** | 느림 (펌웨어 필요) | ✅ 빠름 (즉시) |

**비유:**
- **i2c_master.sv** = USB 컨트롤러 칩 (어디든 장착)
- **board_master_top.sv** = USB 테스터 장비 (개발용)

이제 이해되시나요? 🎓
