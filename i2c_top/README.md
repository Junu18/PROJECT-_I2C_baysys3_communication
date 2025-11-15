# I2C Multi-Slave Communication System

Basys3 FPGA를 위한 I2C Master-Slave 통신 프로젝트

## 🎯 프로젝트 개요

### 핵심 설계 철학: **"Multiple Slaves, Single Byte Protocol"**

복잡한 레지스터 맵 대신, **I2C의 핵심인 Multi-device Bus 개념**을 활용한 설계입니다.

```
┌──────────────┐
│  I2C Master  │  ← MicroBlaze + AXI IP
└──────┬───────┘
       │ I2C Bus (SDA/SCL)
   ────┼────────────┬────────────┬────────────
       │            │            │
   ┌───┴───┐   ┌───┴───┐   ┌───┴───┐
   │ 0x55  │   │ 0x56  │   │ 0x57  │
   │  LED  │   │  FND  │   │Switch │
   └───────┘   └───────┘   └───────┘
```

### 왜 이 방식인가?

#### ❌ 기존 방식 (Register-mapped):
```
1개 Slave + 레지스터 맵
→ [DEV_ADDR][REG_ADDR][DATA] (2바이트 필요)
→ Master가 멀티바이트 전송 구현 복잡
→ Controller FSM 또는 Master 수정 필요
```

#### ✅ 우리 방식 (Multi-slave):
```
3개 Slaves (각자 다른 주소)
→ [DEV_ADDR][DATA] (1바이트면 충분!)
→ Master 수정 불필요
→ I2C의 핵심 개념 완벽 시연
```

---

## 📋 시스템 사양

### I2C 파라미터
- **System Clock**: 100 MHz
- **SCL Frequency**: 100 kHz
- **Protocol**: I2C Standard (7-bit addressing)
- **Master Mode**: Single byte transfer
- **Slave Devices**: 3개 (LED, FND, Switch)

### Slave 주소 할당

| Device | Address | R/W | 기능 |
|--------|---------|-----|------|
| LED Slave | 0x55 | W | LED[7:0] 제어 |
| FND Slave | 0x56 | W | 7-segment 표시 (0-F) |
| Switch Slave | 0x57 | R | Switch[7:0] 읽기 |

---

## 📁 파일 구조

```
i2c_top/
├── rtl/                            # RTL 소스
│   ├── master/
│   │   └── i2c_master.sv           # I2C Master (from master_use/)
│   │
│   ├── slaves/
│   │   ├── i2c_led_slave.sv        # LED Slave (0x55)
│   │   ├── i2c_fnd_slave.sv        # FND Slave (0x56)
│   │   └── i2c_switch_slave.sv     # Switch Slave (0x57)
│   │
│   └── integration/
│       ├── i2c_system_top.sv       # 전체 통합 (Master + 3 Slaves)
│       ├── board_master_top.sv     # Master 보드용 Top
│       └── board_slaves_top.sv     # Slave 보드용 Top
│
├── tb/                             # Testbenches
│   ├── i2c_led_slave_tb.sv
│   ├── i2c_fnd_slave_tb.sv
│   ├── i2c_switch_slave_tb.sv
│   └── i2c_system_tb.sv            # 통합 시스템 테스트
│
├── constraints/
│   ├── basys3_master.xdc           # Master 보드용
│   ├── basys3_slaves.xdc           # Slave 보드용
│   └── basys3_integrated.xdc       # 단일 보드 데모용
│
├── firmware/                       # MicroBlaze 펌웨어 예제
│   ├── i2c_regs.h                  # AXI 레지스터 정의
│   ├── i2c_driver.h
│   ├── i2c_driver.c                # I2C 드라이버
│   ├── demo_led.c                  # LED 제어 예제
│   ├── demo_fnd.c                  # FND 제어 예제
│   ├── demo_switch.c               # Switch 읽기 예제
│   └── main.c                      # 통합 데모
│
├── sim/
│   ├── run_led_slave.sh
│   ├── run_fnd_slave.sh
│   ├── run_switch_slave.sh
│   └── run_system.sh               # 통합 시뮬레이션
│
└── docs/
    ├── README.md                   # 이 파일
    ├── PROTOCOL.md                 # I2C 프로토콜 상세
    ├── FIRMWARE_GUIDE.md           # 펌웨어 가이드
    └── VIVADO_IP.md                # Vivado IP 생성 가이드
```

---

## 🔌 I2C 통신 프로토콜

### LED 제어 (0x55)
```
Write: [START][0xAA][DATA][STOP]
              └ 0x55<<1|W

예: LED[7:0] = 0xFF
[START][0xAA][0xFF][STOP]
```

### FND 표시 (0x56)
```
Write: [START][0xAC][DIGIT][STOP]
              └ 0x56<<1|W

예: FND에 '5' 표시
[START][0xAC][0x05][STOP]
```

### Switch 읽기 (0x57)
```
Write: [START][0xAE][STOP]
              └ 0x57<<1|R
Read:  [START][0xAF][ACK][DATA][NACK][STOP]
              └ 0x57<<1|R

예: Switch 값 읽기
[START][0xAE][STOP]
[START][0xAF][ACK][SW_DATA][NACK][STOP]
```

---

## 🚀 시뮬레이션

### 개별 Slave 테스트
```bash
cd i2c_top/sim

# LED Slave 테스트
./run_led_slave.sh
# → LED 켜기/끄기 검증

# FND Slave 테스트
./run_fnd_slave.sh
# → 0-F 표시 검증

# Switch Slave 테스트
./run_switch_slave.sh
# → Switch 읽기 검증
```

### 통합 시스템 테스트
```bash
./run_system.sh
# → Master가 3개 Slave와 모두 통신
# → LED 제어, FND 표시, Switch 읽기 자동 검증
```

---

## 💻 펌웨어 예제

### 기본 사용법

```c
#include "i2c_driver.h"

// LED 제어
void demo_led(void) {
    i2c_write(0x55, 0xFF);  // LED 모두 켜기
    delay_ms(1000);
    i2c_write(0x55, 0x00);  // LED 모두 끄기
}

// FND 표시
void demo_fnd(void) {
    for (uint8_t i = 0; i < 16; i++) {
        i2c_write(0x56, i);  // 0-F 카운팅
        delay_ms(500);
    }
}

// Switch → LED 복사
void demo_switch(void) {
    uint8_t sw_value = i2c_read(0x57);  // Switch 읽기
    i2c_write(0x55, sw_value);          // LED에 표시
}
```

### 통합 데모

```c
int main(void) {
    i2c_init();

    while(1) {
        // 1. LED 점멸
        i2c_write(0x55, 0xFF);
        delay_ms(500);
        i2c_write(0x55, 0x00);
        delay_ms(500);

        // 2. FND 카운터
        static uint8_t counter = 0;
        i2c_write(0x56, counter++);
        if (counter > 0x0F) counter = 0;

        // 3. Switch → LED
        uint8_t sw = i2c_read(0x57);
        i2c_write(0x55, sw);

        delay_ms(100);
    }
}
```

---

## 🎓 교육적 가치

### I2C 핵심 개념 학습

1. **Multi-device Bus**
   - 한 버스에 여러 디바이스 연결
   - 주소로 선택적 통신
   - 최대 127개 디바이스 가능

2. **Address-based Selection**
   - 7-bit Device Address
   - R/W bit (8번째 비트)
   - 주소 충돌 방지

3. **Master-Slave 구조**
   - Master: 클럭 생성, 통신 주도
   - Slave: 주소 감지, 응답

4. **Protocol Simplicity**
   - 단일 바이트 전송
   - ACK/NACK 메커니즘
   - START/STOP 조건

### 실무 연계

실제 I2C 시스템 구성과 동일:
```
마이크로컨트롤러
    ↓
I2C Bus
    ├─ EEPROM (0x50)
    ├─ RTC (0x68)
    └─ Sensor (0x76)
```

우리 프로젝트:
```
MicroBlaze
    ↓
I2C Bus
    ├─ LED (0x55)
    ├─ FND (0x56)
    └─ Switch (0x57)
```

---

## 🔧 보드 구성

### Option 1: 단일 보드 데모 (학습/검증)
```
1개 Basys3:
├─ Master (MicroBlaze + I2C Master IP)
└─ 3 Slaves (LED + FND + Switch)

내부 I2C 버스 연결
펌웨어로 제어
```

### Option 2: 2보드 통신 (실전)
```
보드 #1 (Master):
└─ MicroBlaze + I2C Master IP

PMOD 케이블
↓

보드 #2 (Slaves):
├─ LED Slave (0x55)
├─ FND Slave (0x56)
└─ Switch Slave (0x57)
```

**연결:**
- PMOD JA1: SCL
- PMOD JA2: SDA
- GND: 공통 접지 필수!
- Pull-up: 4.7kΩ (SCL, SDA)

---

## 📊 설계 비교

| 항목 | Register-mapped | Multi-slave (우리) |
|------|----------------|-------------------|
| Slave 개수 | 1개 | 3개 |
| 프로토콜 | 2바이트 | 1바이트 |
| Master 복잡도 | 높음 (멀티바이트) | 낮음 (단순) |
| 펌웨어 복잡도 | 높음 (REG_ADDR 관리) | 낮음 (주소만) |
| I2C 개념 학습 | 약함 | 강함 ✅ |
| 확장성 | 레지스터 추가 | Slave 추가 |
| 교육적 가치 | 중간 | 높음 ✅ |

---

## 🎯 프로젝트 목표

1. ✅ I2C Master IP 개발 (Vivado용)
2. ✅ Multi-slave 시스템 구현
3. ✅ 펌웨어 드라이버 작성
4. ✅ 보드 간 통신 검증
5. 🔄 UVM Verification (향후)

---

## 📝 다음 단계

### 개발 단계:
1. ✅ RTL 설계 (Master + 3 Slaves)
2. ✅ 시뮬레이션 검증
3. ⏳ Vivado IP 생성
4. ⏳ 펌웨어 개발
5. ⏳ 보드 테스트

### 학습 단계:
1. I2C 프로토콜 이해
2. Multi-device 통신 체험
3. 펌웨어 개발 실습
4. 보드 간 통신 경험

---

## 🔗 참고 자료

- [I2C Specification](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)
- [Basys3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)
- [Vivado IP Packaging](https://www.xilinx.com/support/documentation/sw_manuals/xilinx2020_1/ug1118-vivado-creating-packaging-custom-ip.pdf)

---

## 💡 핵심 메시지

> **"복잡한 레지스터 맵 대신, I2C 본연의 Multi-device 특성을 활용한 심플하고 교육적인 설계"**

**Simple is Beautiful!** ✨
