# 🎮 실전 데모 시나리오 - 핀 번호 포함 상세 가이드

## 📦 하드웨어 구성

### Board #1: Master 보드
- **역할**: I2C Master (명령 전송)
- **입력**: 버튼(BTNU), 스위치(SW[15:0])
- **출력**: LED[15:0], I2C 신호(SCL, SDA)

### Board #2: Slaves 보드
- **역할**: 3개의 I2C Slaves
- **입력**: I2C 신호(SCL, SDA), 스위치(SW[7:0])
- **출력**: LED[15:0], 7-Segment Display

---

## 🔌 물리적 연결 (PMOD JA)

```
Board #1 (Master)          4.7kΩ         Board #2 (Slaves)
                          ┌──────┐
PMOD JA Pin 1 (J1) ──────┤ SCL  ├────── PMOD JA Pin 1 (J1)
                          └──┬───┘
                             │ Pull-up to 3.3V

                          ┌──────┐
PMOD JA Pin 2 (L2) ──────┤ SDA  ├────── PMOD JA Pin 2 (L2)
                          └──┬───┘
                             │ Pull-up to 3.3V

GND ─────────────────────────┴────────── GND
```

**필수:** SCL과 SDA 라인 각각에 4.7kΩ 저항으로 3.3V로 pull-up!

---

## 🎬 시나리오 1: LED 제어 (가장 간단)

### 목표: Board #2의 LED를 켜기

### 📍 Board #1 (Master) - 사용자 조작

#### 1단계: 스위치 설정
```
┌─────────────────────────────────────────────────┐
│ Board #1 Master - 스위치 설정                    │
├─────────────────────────────────────────────────┤
│ SW15 (Pin R2)  = DOWN (0)  ← Write 모드          │
│ SW14 (Pin T1)  = DOWN (0)  ┐                    │
│ SW13 (Pin U1)  = UP   (1)  ├ Slave Addr = 0x55  │
│ SW12 (Pin W2)  = DOWN (0)  │  (LED Slave)       │
│ SW11 (Pin R3)  = UP   (1)  │                    │
│ SW10 (Pin T2)  = DOWN (0)  │                    │
│ SW9  (Pin T3)  = UP   (1)  ┘                    │
│ SW8  (Pin V2)  = DOWN (0)  ┐                    │
│                             │                    │
│ SW7  (Pin W13) = UP   (1)  ┐                    │
│ SW6  (Pin W14) = UP   (1)  │                    │
│ SW5  (Pin V15) = UP   (1)  │                    │
│ SW4  (Pin W15) = UP   (1)  ├ Data = 0xFF        │
│ SW3  (Pin W17) = UP   (1)  │  (모든 LED ON)     │
│ SW2  (Pin W16) = UP   (1)  │                    │
│ SW1  (Pin V16) = UP   (1)  │                    │
│ SW0  (Pin V17) = UP   (1)  ┘                    │
└─────────────────────────────────────────────────┘
```

#### 2단계: 버튼 누르기
```
┌─────────────────────────────────────────────────┐
│ BTNU (Pin T18) 누름!                             │
│                                                  │
│ [사용자 손가락] → BTNU 버튼 → Pin T18           │
└─────────────────────────────────────────────────┘
```

### ⚡ 내부 하드웨어 동작

#### 3단계: Board #1 내부 (i2c_master)
```
[Pin T18] BTNU 감지
    ↓
btn_sync[2:0] 동기화 (3 클럭)
    ↓
btn_pulse = 1 (1 클럭 펄스)
    ↓
start = 1
    ↓
[i2c_master FSM]
    IDLE → START_1 → START_2 → START_3
    ↓
    SCL 생성 시작 (Pin J1 출력)
    SDA 제어 (Pin L2 출력/입력)
```

#### 4단계: I2C 버스 (물리적 전송)
```
Board #1 Pin J1 (SCL)  ────[4.7kΩ]────→  Board #2 Pin J1 (SCL)
Board #1 Pin L2 (SDA)  ────[4.7kΩ]────→  Board #2 Pin L2 (SDA)

타이밍:
t=0ns    : START 조건
           SCL = 1 (Pin J1 = HIGH)
           SDA = 1→0 (Pin L2 = HIGH→LOW)

t=1000ns : Address 전송 시작
           SCL = 0→1→0→1... (100kHz 클럭)

           Bit 7: 1 (0x55 = 01010101)
           Bit 6: 0
           Bit 5: 1
           Bit 4: 0
           Bit 3: 1
           Bit 2: 0
           Bit 1: 1
           Bit 0: 0 (Write bit)

t=81us   : Address ACK
           SDA 릴리즈 (Master)

t=82us   : Data 전송 (0xFF)
           Bit 7-0: 11111111

t=163us  : Data ACK

t=164us  : STOP 조건
           SCL = 1
           SDA = 0→1
```

### 📍 Board #2 (Slaves) - 자동 응답

#### 5단계: Board #2 내부 (i2c_led_slave)
```
[Pin J1] SCL 입력 감지
[Pin L2] SDA 입력 감지
    ↓
scl_sync[2:0] 동기화
sda_sync[2:0] 동기화
    ↓
START 조건 감지:
    sda_prev = 1, sda_in = 0, scl_high = 1
    ↓
[i2c_led_slave FSM]
    IDLE → START → RX_DEV_ADDR
    ↓
Address 수신: 0xAA (0x55<<1 | 0)
    ↓
Address 매칭 체크:
    0xAA >> 1 = 0x55 ✓ 일치!
    ↓
debug_addr_match = 1
    ↓
ACK 전송:
    [Pin L2] SDA = 0 (ACK)
    ↓
Data 수신: 0xFF
    ↓
led_reg[7:0] = 0xFF
    ↓
[실제 LED 핀으로 출력]
    Pin U16 (LED0) = 1
    Pin E19 (LED1) = 1
    Pin U19 (LED2) = 1
    Pin V19 (LED3) = 1
    Pin W18 (LED4) = 1
    Pin U15 (LED5) = 1
    Pin U14 (LED6) = 1
    Pin V14 (LED7) = 1
```

### 🔍 물리적으로 보이는 결과

#### Board #1 (Master):
```
LED9  (Pin V3)  = 깜빡 (done 펄스)
LED12 (Pin P3)  = 깜빡깜빡 (SCL 클럭)
LED11 (Pin U3)  = 깜빡 (ACK 수신)
```

#### Board #2 (Slaves):
```
LED0 (Pin U16) = 켜짐 ✨
LED1 (Pin E19) = 켜짐 ✨
LED2 (Pin U19) = 켜짐 ✨
LED3 (Pin V19) = 켜짐 ✨
LED4 (Pin W18) = 켜짐 ✨
LED5 (Pin U15) = 켜짐 ✨
LED6 (Pin U14) = 켜짐 ✨
LED7 (Pin V14) = 켜짐 ✨
LED8 (Pin V13) = 켜짐 (LED Slave 선택됨)
```

---

## 🎬 시나리오 2: FND 제어 (7-Segment 표시)

### 목표: Board #2의 7-Segment에 '5' 표시

### 📍 Board #1 (Master) - 사용자 조작

#### 1단계: 스위치 설정
```
┌─────────────────────────────────────────────────┐
│ Board #1 Master - 스위치 설정                    │
├─────────────────────────────────────────────────┤
│ SW15 (Pin R2)  = DOWN (0)  ← Write              │
│ SW14 (Pin T1)  = DOWN (0)  ┐                    │
│ SW13 (Pin U1)  = UP   (1)  ├ Slave Addr = 0x56  │
│ SW12 (Pin W2)  = DOWN (0)  │  (FND Slave)       │
│ SW11 (Pin R3)  = UP   (1)  │                    │
│ SW10 (Pin T2)  = UP   (1)  │                    │
│ SW9  (Pin T3)  = DOWN (0)  ┘                    │
│ SW8  (Pin V2)  = DOWN (0)                       │
│                                                  │
│ SW7  (Pin W13) = DOWN (0)                       │
│ SW6  (Pin W14) = DOWN (0)                       │
│ SW5  (Pin V15) = DOWN (0)                       │
│ SW4  (Pin W15) = DOWN (0)  ← Data = 0x05 (5)    │
│ SW3  (Pin W17) = UP   (1)                       │
│ SW2  (Pin W16) = DOWN (0)                       │
│ SW1  (Pin V16) = UP   (1)                       │
│ SW0  (Pin V17) = UP   (1)                       │
└─────────────────────────────────────────────────┘
```

#### 2단계: BTNU (Pin T18) 누름!

### ⚡ I2C 버스 전송
```
Board #1 Pin J1 (SCL) → Board #2 Pin J1 (SCL)
Board #1 Pin L2 (SDA) → Board #2 Pin L2 (SDA)

전송:
[START][0xAC][ACK][0x05][ACK][STOP]
       └0x56<<1|0
```

### 📍 Board #2 (Slaves) - FND Slave 응답

```
[i2c_fnd_slave]
    Address 0x56 매칭 ✓
    ↓
    Data 수신: 0x05
    ↓
    digit_reg[3:0] = 0x05
    ↓
    7-Segment Decoder:
        case(0x05):
            seg_pattern = 7'b0010010
    ↓
    [실제 7-Segment 핀 출력]
    Pin W7 (SEG[0]) = 0  ─┐
    Pin W6 (SEG[1]) = 1   │
    Pin U8 (SEG[2]) = 0   ├─ '5' 모양
    Pin V8 (SEG[3]) = 0   │
    Pin U5 (SEG[4]) = 1   │
    Pin V5 (SEG[5]) = 0   │
    Pin U7 (SEG[6]) = 1  ─┘

    Pin U2 (AN[0])  = 0 (활성)
    Pin U4 (AN[1])  = 1 (비활성)
    Pin V4 (AN[2])  = 1 (비활성)
    Pin W4 (AN[3])  = 1 (비활성)
```

### 🔍 물리적으로 보이는 결과

#### Board #2:
```
7-Segment Display (맨 오른쪽 자리):
 ━━━
┃   ┃
 ━━━
    ┃
 ━━━

'5' 표시됨! ✨

LED9 (Pin V3) = 켜짐 (FND Slave 선택됨)
```

---

## 🎬 시나리오 3: Switch 읽기 (가장 복잡)

### 목표: Board #2의 스위치 값을 Board #1 LED로 표시

### 📍 Board #2 (Slaves) - 사용자 조작

#### 1단계: Board #2 스위치 설정
```
┌─────────────────────────────────────────────────┐
│ Board #2 Slaves - 스위치 설정                    │
├─────────────────────────────────────────────────┤
│ SW7 (Pin W13) = UP   (1)                        │
│ SW6 (Pin W14) = DOWN (0)                        │
│ SW5 (Pin V15) = UP   (1)                        │
│ SW4 (Pin W15) = UP   (1)   ← 0xCD (11001101)    │
│ SW3 (Pin W17) = DOWN (0)                        │
│ SW2 (Pin W16) = DOWN (0)                        │
│ SW1 (Pin V16) = UP   (1)                        │
│ SW0 (Pin V17) = UP   (1)                        │
└─────────────────────────────────────────────────┘
```

### 📍 Board #1 (Master) - 사용자 조작

#### 2단계: 스위치 설정 (Read 모드)
```
┌─────────────────────────────────────────────────┐
│ Board #1 Master - 스위치 설정                    │
├─────────────────────────────────────────────────┤
│ SW15 (Pin R2)  = UP   (1)  ← READ 모드!         │
│ SW14 (Pin T1)  = DOWN (0)  ┐                    │
│ SW13 (Pin U1)  = UP   (1)  ├ Slave Addr = 0x57  │
│ SW12 (Pin W2)  = DOWN (0)  │  (Switch Slave)    │
│ SW11 (Pin R3)  = UP   (1)  │                    │
│ SW10 (Pin T2)  = UP   (1)  │                    │
│ SW9  (Pin T3)  = UP   (1)  ┘                    │
│ SW8  (Pin V2)  = UP   (1)                       │
│                                                  │
│ SW[7:0] = Don't care (Read이므로)               │
└─────────────────────────────────────────────────┘
```

#### 3단계: BTNU (Pin T18) 누름!

### ⚡ I2C 버스 전송
```
Board #1 Pin J1 (SCL) → Board #2 Pin J1 (SCL)
Board #1 Pin L2 (SDA) ↔ Board #2 Pin L2 (SDA)

전송:
[START][0xAF][ACK]
       └0x57<<1|1 (Read!)

응답:
[DATA=0xCD][NACK][STOP]
 ↑ Slave가 전송
```

### 📍 Board #2 (Slaves) - Switch Slave 응답

```
[i2c_switch_slave]
    Address 0x57 + Read bit 매칭 ✓
    ↓
    ACK 전송
    ↓
    [스위치 핀 읽기]
    Pin V17 (SW0) = 1  ─┐
    Pin V16 (SW1) = 1   │
    Pin W16 (SW2) = 0   │
    Pin W17 (SW3) = 0   ├─ 0xCD 읽기
    Pin W15 (SW4) = 1   │
    Pin V15 (SW5) = 1   │
    Pin W14 (SW6) = 0   │
    Pin W13 (SW7) = 1  ─┘
    ↓
    tx_shift[7:0] = 0xCD
    ↓
    [Pin L2] SDA로 0xCD 전송
    Bit 7: 1
    Bit 6: 1
    Bit 5: 0
    Bit 4: 0
    Bit 3: 1
    Bit 2: 1
    Bit 1: 0
    Bit 0: 1
```

### 📍 Board #1 (Master) - 데이터 수신

```
[i2c_master]
    [Pin L2] SDA에서 데이터 샘플링
    ↓
    rx_shift[7:0] = 0xCD
    ↓
    rx_data = 0xCD
    ↓
    [LED 핀 출력]
    Pin U16 (LED0) = 1  ─┐
    Pin E19 (LED1) = 0   │
    Pin U19 (LED2) = 1   │
    Pin V19 (LED3) = 1   ├─ 0xCD 표시
    Pin W18 (LED4) = 0   │
    Pin U15 (LED5) = 0   │
    Pin U14 (LED6) = 1   │
    Pin V14 (LED7) = 1  ─┘
```

### 🔍 물리적으로 보이는 결과

#### Board #1 (Master):
```
LED0 (Pin U16) = 켜짐  ─┐
LED1 (Pin E19) = 꺼짐   │
LED2 (Pin U19) = 켜짐   │
LED3 (Pin V19) = 켜짐   ├─ 0xCD (Board #2 스위치 값)
LED4 (Pin W18) = 꺼짐   │
LED5 (Pin U15) = 꺼짐   │
LED6 (Pin U14) = 켜짐   │
LED7 (Pin V14) = 켜짐  ─┘
```

#### Board #2 (Slaves):
```
LED10 (Pin W3) = 켜짐 (Switch Slave 선택됨)
```

---

## 🎯 핵심 포인트 정리

### Board #1 (Master) 역할
```
입력:
- BTNU (Pin T18): 트랜잭션 시작 트리거
- SW[15]: Read(1) / Write(0) 선택
- SW[14:8]: 대상 Slave 주소 (0x55/0x56/0x57)
- SW[7:0]: 전송할 데이터 (Write 시)

출력:
- Pin J1 (SCL): I2C 클럭 (100kHz)
- Pin L2 (SDA): I2C 데이터 (양방향)
- LED[7:0]: 수신 데이터 표시 (Read 시)
- LED[9]: Done 표시
- LED[12]: SCL 모니터
```

### Board #2 (Slaves) 역할
```
입력:
- Pin J1 (SCL): I2C 클럭 입력
- Pin L2 (SDA): I2C 데이터 입력
- SW[7:0]: Switch Slave가 읽을 데이터

출력:
- LED[7:0]: LED Slave 출력
- LED[8]: LED Slave 선택 표시
- LED[9]: FND Slave 선택 표시
- LED[10]: Switch Slave 선택 표시
- SEG[6:0]: 7-Segment 표시
- AN[3:0]: 7-Segment digit 선택
```

---

## 🔧 실전 데모 순서

1. **전원 연결**: 두 보드 모두 USB 연결
2. **PMOD 연결**: JA1(SCL), JA2(SDA), GND
3. **Pull-up 확인**: SCL, SDA에 4.7kΩ 저항
4. **Board #2 프로그램**: Slaves bitstream
5. **Board #1 프로그램**: Master bitstream
6. **Board #2 스위치 설정**: 원하는 값
7. **Board #1 스위치 설정**: 주소 + 데이터
8. **Board #1 BTNU 누름**: 전송!
9. **결과 확인**: Board #2 LED/FND 확인

---

이제 정확히 어디서 어떤 버튼을 누르고, 어떤 핀을 통해 신호가 전달되는지 완벽하게 이해되셨을 겁니다! 🎉
