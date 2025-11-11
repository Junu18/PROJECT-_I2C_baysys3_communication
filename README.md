# I2C Master-Slave Communication for Basys3

Basys3 FPGA 보드를 사용한 I2C 통신 프로젝트입니다.

## 프로젝트 개요

두 개의 Basys3 보드를 I2C 프로토콜로 연결하여 데이터를 송수신하는 프로젝트입니다.
- **Master Board**: I2C 마스터로 동작, 데이터 전송 주도
- **Slave Board**: I2C 슬레이브로 동작, 주소 0x55로 응답

## 주요 사양

- **System Clock**: 100 MHz
- **SCL Frequency**: 100 kHz (표준 모드)
- **Data Transfer**: 1 byte per transaction
- **Addressing**: 7-bit (0x55)
- **Bus Control**: Tri-state SDA, open-drain emulation

## 파일 구조

```
├── docs/                   # 문서
│   └── spec.md            # 상세 스펙
├── rtl/                   # RTL 소스
│   ├── i2c_master.sv      # I2C Master (단일 파일)
│   └── i2c_slave.sv       # I2C Slave (TODO)
├── tb/                    # 테스트벤치
│   └── i2c_master_tb.sv   # Master TB
├── constraints/           # XDC 제약 파일
│   ├── basys3_i2c_master.xdc
│   └── basys3_i2c_slave.xdc
└── hw/                    # Vivado 프로젝트
```

## 핀 배치

### Master Board (JB PMOD)
- **JB1 (A14)**: SCL
- **JB2 (A16)**: SDA
- **GND**: Common ground

### Slave Board (JA PMOD)
- **JA1 (J1)**: SCL
- **JA2 (L2)**: SDA
- **GND**: Common ground

## 시뮬레이션 실행

```bash
# Master 테스트벤치 실행
cd tb/
iverilog -g2012 -o i2c_master_tb.out \
    ../rtl/i2c_master.sv \
    i2c_master_tb.sv
vvp i2c_master_tb.out
gtkwave i2c_master_tb.vcd
```

## 구현 상태

- ✅ I2C Master 구현 완료
- ✅ Master 테스트벤치 완료
- ✅ 제약 파일 작성 완료
- 🔄 I2C Slave 구현 중
- 📋 통합 테스트 예정

## 참고 문서

- [상세 스펙](docs/spec.md)
- [I2C Protocol Standard](https://www.nxp.com/docs/en/user-guide/UM10204.pdf)

## 라이선스

MIT License

## 작성자

2025-11-11