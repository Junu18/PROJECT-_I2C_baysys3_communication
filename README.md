# I2C Master-Slave Communication for Basys3

Basys3 FPGA 보드를 사용한 I2C 통신 프로젝트입니다.

## 프로젝트 개요

Basys3 FPGA 보드를 사용한 I2C 통신 프로젝트입니다. 두 가지 아키텍처를 지원합니다:

### A. Standalone Hardware 구성
직접 하드웨어 제어 (버튼/스위치)

**1. 이중 보드 구성 (Two-Board Setup)**
- **Master Board**: I2C 마스터로 동작, 데이터 전송 주도
- **Slave Board**: I2C 슬레이브로 동작, 주소 0x55로 응답
- PMOD 핀으로 두 보드 연결

**2. 단일 보드 구성 (Single-Board Loopback)**
- **하나의 보드**에서 Master와 Slave 모두 구현
- 내부 loopback 모드로 즉시 테스트 가능
- 외부 PMOD로 신호 모니터링 가능

### B. SoC 구성 (MicroBlaze + AXI-Lite)
소프트웨어 제어 (레지스터 기반)

**시스템 구조**:
```
MicroBlaze CPU
    |
    | (AXI-Lite Bus)
    |
    +--- axi_i2c_master (AXI-Lite Slave)
    |       |
    |       +--- I2C Bus (SCL/SDA)
    |
    +--- axi_i2c_slave (AXI-Lite Slave)
            |
            +--- I2C Bus (SCL/SDA)
```

**특징**:
- C 프로그램으로 I2C 제어
- 레지스터 맵 기반 인터페이스
- 인터럽트 지원
- Xilinx SDK/Vitis 환경에서 개발

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
│   ├── i2c_master.sv              # I2C Master Core (standalone)
│   ├── i2c_slave.sv               # I2C Slave Core (standalone)
│   ├── axi_i2c_master.sv          # AXI-Lite I2C Master Wrapper
│   ├── axi_i2c_slave.sv           # AXI-Lite I2C Slave Wrapper
│   └── i2c_single_board_top.sv    # 단일 보드 Top 모듈 (standalone)
├── tb/                            # 테스트벤치
│   ├── i2c_master_tb.sv           # Master TB
│   ├── i2c_system_tb.sv           # Master + Slave 통합 TB
│   └── i2c_single_board_tb.sv     # 단일 보드 TB
├── sw/                            # 소프트웨어 (MicroBlaze용)
│   ├── i2c_regs.h                 # 레지스터 정의
│   ├── i2c_driver.h               # 드라이버 헤더
│   ├── i2c_driver.c               # 드라이버 구현
│   └── main.c                     # 예제 프로그램
├── constraints/                   # XDC 제약 파일
│   ├── basys3_i2c_master.xdc      # Master 전용 (standalone)
│   ├── basys3_i2c_slave.xdc       # Slave 전용 (standalone)
│   └── basys3_i2c_single_board.xdc # 단일 보드 (standalone)
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
- ✅ I2C Master Core (standalone, 단일 파일)
- ✅ I2C Slave Core (standalone, 단일 파일)
- ✅ AXI-Lite I2C Master Wrapper
- ✅ AXI-Lite I2C Slave Wrapper
- ✅ 단일 보드 Top 모듈 (standalone)

### 소프트웨어
- ✅ 레지스터 정의 (i2c_regs.h)
- ✅ 드라이버 함수 (i2c_driver.h/c)
- ✅ 예제 프로그램 (main.c)

### 테스트벤치
- ✅ Master 단독 테스트벤치
- ✅ Master + Slave 통합 테스트벤치
- ✅ 단일 보드 Top 테스트벤치

### 제약 파일
- ✅ Master 전용 (standalone)
- ✅ Slave 전용 (standalone)
- ✅ 단일 보드 (standalone)

### 다음 단계
- 📋 Vivado Block Design 생성 (MicroBlaze + AXI Interconnect)
- 📋 비트스트림 생성 및 다운로드
- 📋 SDK/Vitis 프로젝트 생성
- 📋 하드웨어 검증

## 사용 방법

### A. Standalone 구성 (하드웨어 직접 제어)

**비트스트림 생성**:
1. Vivado에서 프로젝트 생성
2. Top 모듈: `i2c_single_board_top.sv`
3. 제약 파일: `basys3_i2c_single_board.xdc`
4. 합성 및 구현
5. 비트스트림 다운로드

**사용**:
- SW[7:0]: 전송할 데이터 설정
- SW[8]: Read(1) / Write(0) 선택
- BTNU: I2C 전송 시작
- LED[7:0]: 데이터 표시
- LED[8-15]: 상태 표시

### B. SoC 구성 (MicroBlaze + C 프로그래밍)

**Vivado Block Design**:
1. MicroBlaze 프로세서 추가
2. `axi_i2c_master` IP 추가 (RTL 소스에서 IP 생성)
3. `axi_i2c_slave` IP 추가
4. AXI Interconnect로 연결
5. 주소 할당 (예: Master=0x44A00000, Slave=0x44A10000)
6. 비트스트림 생성

**SDK/Vitis 프로젝트**:
1. Hardware Handoff (.xsa 파일) export
2. SDK/Vitis에서 Application 프로젝트 생성
3. `sw/` 폴더의 소스 파일 추가
4. 컴파일 및 다운로드

**C 프로그램 예제**:
```c
#include "i2c_driver.h"

// Write 예제
i2c_master_write_byte(I2C_MASTER_BASEADDR, 0x55, 0xA5);

// Read 예제
uint8_t data;
i2c_master_read_byte(I2C_MASTER_BASEADDR, 0x55, &data);
```

## 참고 문서

- [상세 스펙](docs/spec.md)
- [I2C Protocol Standard](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)

## 라이선스

MIT License

## 작성자

2025-11-11