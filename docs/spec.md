# I2C 프로젝트 스펙 (최종 확정)

## 1. 기본 파라미터

| 항목 | 값 | 설명 |
|------|-----|------|
| System Clock | 100 MHz | Basys3 온보드 클럭 |
| SCL Frequency | 100 kHz | I2C 표준 모드 |
| SCL 생성 | 500 cycles마다 toggle | 100MHz / (100kHz * 2) = 500 |
| Slave Address | 0x55 (0b1010101) | 7-bit 주소 |
| Data Size | 1 byte | 단일 바이트 전송 |
| Pull-up | 없음 (Tri-state 사용) | 내부 pull-up 대신 tri-state 제어 |
| SDA 제어 | inout with output enable | sda_oe로 제어 |

## 2. PMOD 핀 할당

### Master Board (JB 사용):
- **JB1 (A14)**: SCL (output)
- **JB2 (A16)**: SDA (inout)
- **GND**: 공통 접지 필수!

### Slave Board (JA 사용):
- **JA1 (J1)**: SCL (input)
- **JA2 (L2)**: SDA (inout)
- **GND**: 공통 접지 필수!

## 3. LED 매핑

### Master Board LED:
- **LED[7:0]** (U16~V14): RX 데이터 표시 (수신한 8-bit 데이터)
- **LED8** (V13): debug_busy (Master BUSY 상태)
- **LED9** (V3): debug_ack (ACK 받았는지)
- **LED10** (W3): debug_scl (SCL 신호 모니터링)
- **LED11** (U3): debug_sda_out (SDA 출력 값)
- **LED12** (P3): debug_sda_oe (SDA 출력 인에이블)
- **LED13** (N3): ack_error (NACK 수신)
- **LED14** (P1): done (전송 완료)
- **LED15** (L1): busy (동작 중)

### Slave Board LED:
- **LED[7:0]**: RX 데이터 표시 (수신한 8-bit 데이터)
- **LED8**: debug_addr_match (주소 매칭됨)
- **LED9**: debug_ack_sent (ACK 전송함)
- **LED10**: debug_state[0] (FSM 상태 bit 0)
- **LED11**: debug_state[1] (FSM 상태 bit 1)

## 4. I2C Master 인터페이스

### Control Signals
| 신호 | 방향 | 폭 | 설명 |
|------|------|-----|------|
| clk | Input | 1 | 100 MHz 시스템 클럭 |
| rst_n | Input | 1 | Active-low 리셋 |
| start | Input | 1 | I2C 트랜잭션 시작 (펄스) |
| rw_bit | Input | 1 | 0=Write, 1=Read |
| slave_addr | Input | 7 | 7-bit 슬레이브 주소 |
| tx_data | Input | 8 | 전송할 데이터 |
| rx_data | Output | 8 | 수신한 데이터 |
| busy | Output | 1 | 트랜잭션 진행 중 |
| done | Output | 1 | 트랜잭션 완료 (펄스) |
| ack_error | Output | 1 | NACK 수신 또는 오류 |

### I2C Bus
| 신호 | 방향 | 설명 |
|------|------|------|
| scl | Output | I2C 클럭 라인 |
| sda | Inout | I2C 데이터 라인 (tri-state) |

## 5. I2C 프로토콜 구현

### 표준 I2C Write 시퀀스:
```
START → ADDRESS(7bit) + W(0) → ACK → DATA(8bit) → ACK → STOP
```

### 표준 I2C Read 시퀀스:
```
START → ADDRESS(7bit) + R(1) → ACK → DATA(8bit) → NACK → STOP
```

### FSM 상태:
1. **IDLE**: 대기 상태
2. **START_1/2/3**: START 조건 생성
3. **ADDR_BIT**: 주소 전송 (8비트 = 7비트 주소 + 1비트 R/W)
4. **ADDR_ACK**: 주소 ACK 수신
5. **DATA_BIT**: 데이터 송신/수신
6. **DATA_ACK**: 데이터 ACK 처리
7. **STOP_1/2/3**: STOP 조건 생성

### 타이밍:
- **SCL Period**: 1000 cycles (10 μs @ 100 MHz)
- **SCL Low**: 500 cycles (5 μs)
- **SCL High**: 500 cycles (5 μs)
- **Quarter Period**: 250 cycles (2.5 μs)

## 6. 프로젝트 디렉토리 구조

```
i2c_project/
├── docs/
│   ├── spec.md                     ← 이 문서
│   └── register_map.md
│
├── rtl/
│   ├── i2c_master.sv               ← I2C Master 구현 (단일 파일)
│   └── i2c_slave.sv                ← I2C Slave 구현 (TODO)
│
├── tb/
│   ├── i2c_master_tb.sv            ← Master 테스트벤치
│   ├── i2c_slave_tb.sv             ← Slave 테스트벤치 (TODO)
│   └── i2c_system_tb.sv            ← 통합 테스트벤치 (TODO)
│
├── constraints/
│   ├── basys3_i2c_master.xdc       ← Master 보드 제약 파일
│   ├── basys3_i2c_slave.xdc        ← Slave 보드 제약 파일
│   └── basys3_single_board.xdc     ← 단일 보드 루프백 (TODO)
│
├── hw/
│   ├── vivado_master/              ← Master Vivado 프로젝트
│   └── vivado_slave/               ← Slave Vivado 프로젝트
│
└── sw/
    └── i2c_test.c                  ← SW 테스트 코드 (TODO)
```

## 7. 구현 상태

### ✅ 완료:
- [x] i2c_master.sv - 완전한 I2C Master 구현 (단일 파일, 패키지 의존성 없음)
  - [x] 모든 파라미터와 타입 정의 내부 포함
  - [x] START 조건 생성
  - [x] ADDRESS + R/W 비트 전송
  - [x] ACK/NACK 수신
  - [x] DATA 송신/수신
  - [x] STOP 조건 생성
  - [x] 100 kHz SCL 타이밍
  - [x] SDA tri-state 제어
- [x] basys3_i2c_master.xdc - Master 제약 파일
- [x] basys3_i2c_slave.xdc - Slave 제약 파일
- [x] i2c_master_tb.sv - Master 테스트벤치

### 🔄 진행 중:
- [ ] i2c_slave.sv - I2C Slave 구현

### 📋 TODO:
- [ ] i2c_slave_tb.sv - Slave 테스트벤치
- [ ] i2c_system_tb.sv - 통합 테스트
- [ ] Vivado 프로젝트 생성
- [ ] 하드웨어 검증

## 8. 주요 개선 사항

원래 코드의 문제점들을 다음과 같이 해결했습니다:

1. **✅ Slave ADDRESS 전송 추가**: 0x55 주소 + R/W 비트를 정확히 전송
2. **✅ I2C 프로토콜 완성**: START → ADDR → ACK → DATA → ACK → STOP 순서 구현
3. **✅ 타이밍 정확도**: 100 kHz SCL (1000 cycles/period) 정확히 맞춤
4. **✅ SDA tri-state 수정**: `sda_oe`로 제어, `sda_out`은 논리값만 사용
5. **✅ READ 모드 구현**: Slave로부터 데이터 수신 로직 추가
6. **✅ 인터페이스 개선**: 명확한 제어 신호와 상태 피드백
7. **✅ 4-phase SCL 생성**: 각 비트를 4개의 quarter로 나누어 정확한 타이밍 구현

## 9. 다음 단계

### Phase 1: I2C Slave 구현
1. i2c_slave.sv 설계
2. 타이밍 다이어그램 기반 FSM 구현
3. Testbench 작성 및 검증

### Phase 2: 통합 테스트
1. Master-Slave 통합 테스트벤치
2. 시뮬레이션 검증
3. 타이밍 검증

### Phase 3: 하드웨어 구현
1. Vivado 프로젝트 생성
2. 합성 및 구현
3. 비트스트림 생성

### Phase 4: 하드웨어 검증
1. 두 Basys3 보드 연결
2. 데이터 전송 테스트
3. 오실로스코프로 신호 확인

## 10. 참고 사항

- **Pull-up 저항**: 외부 pull-up 없이 tri-state로 구현했으므로, 하드웨어 테스트 시 외부 pull-up (4.7kΩ) 추가 권장
- **Clock Stretching**: 현재 구현은 clock stretching을 지원하지 않음
- **Multi-byte Transfer**: 현재는 단일 바이트 전송만 지원
- **GND 연결**: 두 보드 간 GND 연결 필수!

## 11. 스펙 확정 체크리스트 ✓

- ✅ System Clock: 100 MHz
- ✅ SCL: 100 kHz (500 cycles 마다 toggle)
- ✅ Slave Address: 0x55
- ✅ Data: 1 byte
- ✅ Pull-up: 없음 (Tri-state)
- ✅ PMOD: JB(Master), JA(Slave)
- ✅ LED 매핑: 데이터 + 디버깅
- ✅ Constraint 파일: 작성 완료
- ✅ I2C 프로토콜: 표준 준수
- ✅ Testbench: 기본 검증 완료

---

**버전**: 1.0
**작성일**: 2025-11-11
**상태**: Phase 1 완료 (Master 구현)
