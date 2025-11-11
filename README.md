# I2C Master-Slave Communication for Basys3

Basys3 FPGA 보드를 사용한 I2C 통신 프로젝트입니다.

## 프로젝트 개요

Basys3 FPGA 보드를 사용한 I2C 통신 프로젝트입니다. 두 가지 구성을 지원합니다:

### 1. 이중 보드 구성 (Two-Board Setup)
- **Master Board**: I2C 마스터로 동작, 데이터 전송 주도
- **Slave Board**: I2C 슬레이브로 동작, 주소 0x55로 응답
- PMOD 핀으로 두 보드 연결

### 2. 단일 보드 구성 (Single-Board Loopback)
- **하나의 보드**에서 Master와 Slave 모두 구현
- 내부 loopback 모드로 즉시 테스트 가능
- 외부 PMOD로 신호 모니터링 가능

## 주요 사양

- **System Clock**: 100 MHz
- **SCL Frequency**: 100 kHz (표준 모드)
- **Data Transfer**: 1 byte per transaction
- **Addressing**: 7-bit (0x55)
- **Bus Control**: Tri-state SDA, open-drain emulation

## 파일 구조

```
├── docs/                           # 문서
│   └── spec.md                    # 상세 스펙
├── rtl/                           # RTL 소스
│   ├── i2c_master.sv              # I2C Master (단일 파일)
│   ├── i2c_slave.sv               # I2C Slave (단일 파일)
│   └── i2c_single_board_top.sv    # 단일 보드 Top 모듈
├── tb/                            # 테스트벤치
│   ├── i2c_master_tb.sv           # Master TB
│   ├── i2c_system_tb.sv           # Master + Slave 통합 TB
│   └── i2c_single_board_tb.sv     # 단일 보드 TB
├── constraints/                   # XDC 제약 파일
│   ├── basys3_i2c_master.xdc      # Master 전용
│   ├── basys3_i2c_slave.xdc       # Slave 전용
│   └── basys3_i2c_single_board.xdc # 단일 보드 (Master+Slave)
└── hw/                            # Vivado 프로젝트
```

## 핀 배치

### 이중 보드 구성

**Master Board (JB PMOD)**
- **JB1 (A14)**: SCL
- **JB2 (A16)**: SDA
- **GND**: Common ground

**Slave Board (JA PMOD)**
- **JA1 (J1)**: SCL
- **JA2 (L2)**: SDA
- **GND**: Common ground

### 단일 보드 구성

**버튼 제어**
- **BTNC (U18)**: Reset
- **BTNU (T18)**: I2C Start
- **BTNL (W19)**: Display Mode Toggle (Master TX ↔ Slave RX)
- **BTNR (T17)**: Loopback Enable/Disable

**스위치 설정**
- **SW[7:0]**: Master TX 데이터
- **SW8**: Read/Write bit (0=Write, 1=Read)
- **SW[15:9]**: Slave 주소 (0이면 기본값 0x55 사용)

**LED 표시**
- **LED[7:0]**: 데이터 표시 (모드에 따라 Master TX 또는 Slave RX)
- **LED8**: Master Busy
- **LED9**: Master Done
- **LED10**: Master ACK
- **LED11**: Slave Address Match
- **LED12**: Slave Data Valid
- **LED13**: SCL 모니터
- **LED14**: SDA 모니터
- **LED15**: Loopback 상태

**External PMOD (Optional)**
- **JB1 (A14)**: SCL output (monitoring)
- **JB2 (A16)**: SDA output (monitoring)

## 시뮬레이션 실행

```bash
cd tb/

# 1. Master 단독 테스트
iverilog -g2012 -o i2c_master_tb.out \
    ../rtl/i2c_master.sv \
    i2c_master_tb.sv
vvp i2c_master_tb.out
gtkwave i2c_master_tb.vcd

# 2. Master + Slave 통합 테스트
iverilog -g2012 -o i2c_system_tb.out \
    ../rtl/i2c_master.sv \
    ../rtl/i2c_slave.sv \
    i2c_system_tb.sv
vvp i2c_system_tb.out
gtkwave i2c_system_tb.vcd

# 3. 단일 보드 (Top 모듈) 테스트
iverilog -g2012 -o i2c_single_board_tb.out \
    ../rtl/i2c_master.sv \
    ../rtl/i2c_slave.sv \
    ../rtl/i2c_single_board_top.sv \
    i2c_single_board_tb.sv
vvp i2c_single_board_tb.out
gtkwave i2c_single_board_tb.vcd
```

## 구현 상태

### RTL 모듈
- ✅ I2C Master 구현 완료 (단일 파일, 패키지 의존성 없음)
- ✅ I2C Slave 구현 완료 (단일 파일, 패키지 의존성 없음)
- ✅ 단일 보드 Top 모듈 완료 (Master + Slave 통합)

### 테스트벤치
- ✅ Master 단독 테스트벤치 완료
- ✅ Master + Slave 통합 테스트벤치 완료
- ✅ 단일 보드 Top 테스트벤치 완료

### 제약 파일
- ✅ Master 전용 제약 파일 (basys3_i2c_master.xdc)
- ✅ Slave 전용 제약 파일 (basys3_i2c_slave.xdc)
- ✅ 단일 보드 제약 파일 (basys3_i2c_single_board.xdc)

### 다음 단계
- 📋 Vivado 프로젝트 생성
- 📋 비트스트림 생성 및 다운로드
- 📋 하드웨어 검증 (단일/이중 보드)

## 참고 문서

- [상세 스펙](docs/spec.md)
- [I2C Protocol Standard](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)

## 라이선스

MIT License

## 작성자

2025-11-11