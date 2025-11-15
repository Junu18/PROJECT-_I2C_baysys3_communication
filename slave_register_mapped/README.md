# I2C Slave Register-Mapped Implementation

Basys3 FPGA용 레지스터 맵 기반 I2C Slave 구현

## 📁 파일 구조

```
slave_register_mapped/
├── i2c_slave_protocol.sv      # I2C 프로토콜 엔진
├── slave_register_map.sv      # 레지스터 맵 (LED/FND 제어)
├── i2c_slave_top.sv           # Top 통합 모듈
├── i2c_slave_top_tb.sv        # Testbench
├── basys3_i2c_slave.xdc       # Constraint 파일
└── README.md                  # 이 파일
```

## 🎯 특징

### I2C 프로토콜
- **Device Address**: 0x55 (7-bit)
- **SCL Frequency**: 100 kHz
- **Protocol**: START → DEV_ADDR → REG_ADDR → DATA → STOP
- **Repeated START** 지원 (Read 시)

### 레지스터 맵

| 주소 | 이름 | R/W | 설명 |
|------|------|-----|------|
| 0x00 | SW_DATA | R | Switch 입력 [7:0] |
| 0x01 | LED_LOW | R/W | LED[7:0] 제어 |
| 0x02 | LED_HIGH | R/W | LED[15:8] 제어 |
| 0x03 | FND_DATA | R/W | 7-segment 표시 (0-F) |

## 📡 통신 프로토콜

### Write 시나리오
```
Master → Slave
[START] [0xAA] [ACK] [REG_ADDR] [ACK] [DATA] [ACK] [STOP]
         └─ 0x55<<1 | W

예: LED[7:0]을 0xFF로 설정
[START] [0xAA] [ACK] [0x01] [ACK] [0xFF] [ACK] [STOP]
```

### Read 시나리오
```
Master → Slave
[START] [0xAA] [ACK] [REG_ADDR] [ACK]
[R_START] [0xAB] [ACK] [DATA] [NACK] [STOP]
           └─ 0x55<<1 | R

예: SW 값 읽기
[START] [0xAA] [ACK] [0x00] [ACK]
[R_START] [0xAB] [ACK] [SW_DATA] [NACK] [STOP]
```

## 🔌 핀 배치 (PMOD JA)

| 핀 | 신호 | 방향 | 설명 |
|----|------|------|------|
| JA1 | SCL | Input | I2C 클럭 (from Master) |
| JA2 | SDA | Bidir | I2C 데이터 |
| GND | GND | - | 공통 접지 필수! |

## 🚀 시뮬레이션 실행

```bash
# 컴파일
iverilog -g2012 -o i2c_slave_top_tb \
    i2c_slave_protocol.sv \
    slave_register_map.sv \
    i2c_slave_top.sv \
    i2c_slave_top_tb.sv

# 실행
vvp i2c_slave_top_tb

# 파형 확인
gtkwave i2c_slave_top_tb.vcd
```

## 📝 Vivado 프로젝트 설정

1. **RTL 추가:**
   - i2c_slave_protocol.sv
   - slave_register_map.sv
   - i2c_slave_top.sv (Top module)

2. **Constraint 추가:**
   - basys3_i2c_slave.xdc

3. **Synthesis & Implementation**

4. **Generate Bitstream**

## 🎮 사용 예시 (Master 펌웨어)

```c
// LED 제어
void set_led(uint16_t value) {
    // LED_LOW 쓰기
    i2c_write(0x55, 0x01, value & 0xFF);

    // LED_HIGH 쓰기
    i2c_write(0x55, 0x02, value >> 8);
}

// FND 표시
void set_fnd(uint8_t digit) {
    i2c_write(0x55, 0x03, digit);
}

// Switch 읽기
uint8_t read_switch(void) {
    return i2c_read(0x55, 0x00);
}
```

## 🔧 디버깅

- `debug_addr_match`: Device address 매칭 시 HIGH
- `debug_state[3:0]`: 현재 FSM 상태
  - 0: IDLE
  - 2: RX_DEV_ADDR
  - 4: RX_REG_ADDR
  - 6: RX_DATA
  - 8: TX_DATA

## ⚠️ 주의사항

1. **Pull-up 저항**: SCL, SDA에 4.7kΩ 필요 (보드 내부 pull-up만으로는 부족할 수 있음)
2. **공통 접지**: Master와 Slave 보드의 GND 연결 필수
3. **케이블 길이**: 100 kHz 기준 최대 1m 권장
4. **7-segment**: Common Anode 기준 (필요시 SEG 극성 변경)

## 📊 타이밍

- **System Clock**: 100 MHz
- **I2C SCL**: 100 kHz (10us period)
- **Setup/Hold Time**: I2C Standard 준수
- **ACK Timing**: SCL HIGH 중간에 샘플링

## 🔄 확장 가능성

레지스터 추가 시 `slave_register_map.sv`만 수정:

```systemverilog
// 새 레지스터 추가 예시
localparam ADDR_NEW_REG = 8'h04;

logic [7:0] new_reg;

// Write
if (reg_wen && reg_addr == ADDR_NEW_REG)
    new_reg <= reg_wdata;

// Read
if (reg_addr == ADDR_NEW_REG)
    reg_rdata = new_reg;
```
