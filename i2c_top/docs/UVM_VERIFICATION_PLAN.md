# UVM Verification Plan - I2C Multi-Slave System

## 📋 Overview

이 문서는 I2C Master-Slave 시스템의 UVM verification을 위한:
- Functional Coverage 시나리오
- Corner Case 목록
- Testbench 구조
- Coverage Group 정의

---

## 🎯 Functional Coverage 시나리오

### 1. Basic Operations (기본 동작)

#### 1.1 Write Operations
```systemverilog
covergroup cg_write_operations @(posedge clk);
    // Slave address coverage
    cp_slave_addr: coverpoint slave_addr {
        bins led_slave   = {7'h55};
        bins fnd_slave   = {7'h56};
        bins sw_slave    = {7'h57};
        bins invalid_addr = {[0:127]} with (item != 7'h55 &&
                                            item != 7'h56 &&
                                            item != 7'h57);
    }

    // Data patterns
    cp_write_data: coverpoint tx_data {
        bins all_zeros  = {8'h00};
        bins all_ones   = {8'hFF};
        bins alternating_1 = {8'hAA};
        bins alternating_2 = {8'h55};
        bins walking_1 = {8'h01, 8'h02, 8'h04, 8'h08,
                         8'h10, 8'h20, 8'h40, 8'h80};
        bins walking_0 = {8'hFE, 8'hFD, 8'hFB, 8'hF7,
                         8'hEF, 8'hDF, 8'hBF, 8'h7F};
        bins random_data = default;
    }

    // R/W bit
    cp_rw_bit: coverpoint rw_bit {
        bins write = {1'b0};
        bins read  = {1'b1};
    }

    // Cross coverage
    cross cp_slave_addr, cp_write_data;
    cross cp_slave_addr, cp_rw_bit;
endgroup
```

**시나리오:**
- ✅ LED Slave에 0x00, 0xFF, 0xAA, 0x55 쓰기
- ✅ FND Slave에 0x00~0x0F (모든 hex digit) 쓰기
- ✅ 각 Slave에 walking 1/0 패턴 쓰기
- ✅ 유효하지 않은 주소에 쓰기 시도

#### 1.2 Read Operations
```systemverilog
covergroup cg_read_operations @(posedge clk);
    cp_read_slave: coverpoint slave_addr {
        bins sw_slave = {7'h57};  // Only Switch supports read
        bins invalid_read_led = {7'h55};  // LED doesn't support read
        bins invalid_read_fnd = {7'h56};  // FND doesn't support read
    }

    cp_read_data: coverpoint rx_data {
        bins all_zeros  = {8'h00};
        bins all_ones   = {8'hFF};
        bins alternating = {8'hAA, 8'h55};
        bins corners = {8'h00, 8'hFF};
        bins random = default;
    }

    cross cp_read_slave, cp_read_data;
endgroup
```

**시나리오:**
- ✅ Switch Slave에서 모든 스위치 조합 읽기
- ✅ Read 미지원 Slave에 읽기 시도 (LED, FND)

---

### 2. Timing Scenarios (타이밍 시나리오)

#### 2.1 Transaction Timing
```systemverilog
covergroup cg_timing @(posedge clk);
    // Back-to-back transactions
    cp_transaction_gap: coverpoint gap_cycles {
        bins immediate     = {[0:10]};      // 즉시 다음 트랜잭션
        bins short_gap     = {[11:100]};    // 짧은 간격
        bins medium_gap    = {[101:1000]};  // 중간 간격
        bins long_gap      = {[1001:10000]}; // 긴 간격
    }

    // Transaction duration
    cp_transaction_duration: coverpoint duration_cycles {
        bins normal = {[1500:2000]};  // 정상 범위
        bins fast   = {[1000:1499]};  // 빠른 경우
        bins slow   = {[2001:3000]};  // 느린 경우
    }
endgroup
```

**시나리오:**
- ✅ Back-to-back write (간격 없음)
- ✅ Back-to-back read
- ✅ Write 직후 즉시 Read
- ✅ 긴 대기 후 트랜잭션

#### 2.2 Reset Timing
```systemverilog
covergroup cg_reset_timing @(negedge rst_n);
    cp_reset_phase: coverpoint current_state {
        bins reset_in_idle = {IDLE};
        bins reset_in_start = {START_1, START_2, START_3};
        bins reset_in_addr = {ADDR_BIT, ADDR_ACK};
        bins reset_in_data = {DATA_BIT, DATA_ACK};
        bins reset_in_stop = {STOP_1, STOP_2, STOP_3};
    }
endgroup
```

**시나리오:**
- ✅ IDLE 상태에서 리셋
- ✅ START 조건 생성 중 리셋
- ✅ Address 전송 중 리셋
- ✅ Data 전송 중 리셋
- ✅ STOP 조건 생성 중 리셋

---

### 3. Protocol Compliance (프로토콜 준수)

#### 3.1 START/STOP Conditions
```systemverilog
covergroup cg_protocol @(posedge clk);
    cp_start_condition: coverpoint {sda_prev, sda, scl} {
        bins valid_start = {3'b110};  // SDA: 1→0, SCL=1
        bins invalid_start = default;
    }

    cp_stop_condition: coverpoint {sda_prev, sda, scl} {
        bins valid_stop = {3'b011};   // SDA: 0→1, SCL=1
        bins invalid_stop = default;
    }
endgroup
```

**시나리오:**
- ✅ 올바른 START 조건
- ✅ 올바른 STOP 조건
- ✅ Repeated START (현재 미지원이지만 테스트)
- ✅ Missing STOP 조건

#### 3.2 ACK/NACK Handling
```systemverilog
covergroup cg_ack_nack @(posedge clk);
    cp_ack_response: coverpoint ack_bit {
        bins ack  = {1'b0};
        bins nack = {1'b1};
    }

    cp_ack_phase: coverpoint current_state {
        bins addr_ack = {ADDR_ACK};
        bins data_ack = {DATA_ACK};
    }

    cross cp_ack_response, cp_ack_phase;
endgroup
```

**시나리오:**
- ✅ Address ACK (정상)
- ✅ Address NACK (주소 불일치)
- ✅ Data ACK (Write 정상)
- ✅ Data NACK (Write 실패)
- ✅ Master NACK (Read 종료)

---

### 4. Multi-Slave Scenarios (다중 슬레이브)

#### 4.1 Slave Selection
```systemverilog
covergroup cg_multi_slave @(posedge clk);
    cp_slave_sequence: coverpoint slave_addr {
        bins led_to_fnd = (7'h55 => 7'h56);
        bins fnd_to_sw  = (7'h56 => 7'h57);
        bins sw_to_led  = (7'h57 => 7'h55);
        bins led_to_sw  = (7'h55 => 7'h57);
        bins same_slave = (7'h55 => 7'h55),
                         (7'h56 => 7'h56),
                         (7'h57 => 7'h57);
    }

    cp_simultaneous_activity: coverpoint {led_active, fnd_active, sw_active} {
        bins only_led = {3'b100};
        bins only_fnd = {3'b010};
        bins only_sw  = {3'b001};
        bins none     = {3'b000};
        illegal_bins multiple = {3'b110, 3'b101, 3'b011, 3'b111};
    }
endgroup
```

**시나리오:**
- ✅ LED → FND → Switch 순차 액세스
- ✅ 같은 Slave 연속 액세스
- ✅ Random Slave 순서
- ✅ 모든 Slave round-robin

---

## 🔥 Corner Cases (코너 케이스)

### 1. Timing Corner Cases

#### 1.1 최소/최대 타이밍
```
시나리오: SCL 주파수 변화
- ✅ Minimum SCL frequency (99 kHz)
- ✅ Maximum SCL frequency (101 kHz)
- ✅ SCL jitter (±5%)
```

#### 1.2 Setup/Hold Time 위반
```
시나리오: SDA 타이밍 위반
- ✅ SDA changes during SCL high (에러 발생해야 함)
- ✅ SDA setup time < min
- ✅ SDA hold time < min
```

#### 1.3 Glitch on SDA/SCL
```
시나리오: 노이즈 시뮬레이션
- ✅ Short pulse on SDA (< 50ns) - 무시되어야 함
- ✅ Short pulse on SCL (< 50ns) - 무시되어야 함
- ✅ Multiple glitches during transaction
```

---

### 2. Protocol Corner Cases

#### 2.1 Repeated START (현재 미지원)
```systemverilog
// 테스트 시나리오
sequence seq_repeated_start;
    start_condition ##[1:$] !stop_condition ##[1:$] start_condition;
endsequence

// 현재 설계: STOP 후에만 다음 START 가능
// Coverage: Repeated START 시도 시 동작 확인
```

**시나리오:**
- ✅ Write 후 STOP 없이 Read 시도
- ✅ Address 후 STOP 없이 다른 Address 시도

#### 2.2 Clock Stretching (현재 미지원)
```
시나리오: Slave가 SCL을 low로 hold
- ✅ Slave가 SCL stretch 시도
- ✅ Master는 계속 진행 (무시)
```

#### 2.3 Bus Arbitration (Multi-master, 현재 미지원)
```
시나리오: 여러 Master 동시 접근
- ✅ 두 Master가 동시 START
- ✅ SDA collision detection
```

---

### 3. Data Corner Cases

#### 3.1 경계값 테스트
```systemverilog
// Address boundaries
- ✅ Minimum valid address: 0x55
- ✅ Maximum valid address: 0x57
- ✅ Just below valid: 0x54
- ✅ Just above valid: 0x58
- ✅ Address 0x00 (General call - I2C spec)
- ✅ Address 0x7F (Reserved)

// Data boundaries
- ✅ 0x00 (all zeros)
- ✅ 0xFF (all ones)
- ✅ 0x7F (MSB=0, others=1)
- ✅ 0x80 (MSB=1, others=0)
```

#### 3.2 Bit Transitions
```systemverilog
covergroup cg_bit_transitions;
    cp_data_transitions: coverpoint tx_data {
        bins max_transitions = {8'hAA, 8'h55}; // 1010... / 0101...
        bins min_transitions = {8'h00, 8'hFF}; // 0000... / 1111...
        bins single_0 = {8'hFE, 8'hFD, 8'hFB, 8'hF7, ...};
        bins single_1 = {8'h01, 8'h02, 8'h04, 8'h08, ...};
    }
endgroup
```

**시나리오:**
- ✅ Maximum bit transitions (0xAA)
- ✅ Minimum bit transitions (0x00, 0xFF)
- ✅ Single bit set
- ✅ Single bit clear

---

### 4. Error Injection Corner Cases

#### 4.1 Invalid Transactions
```
시나리오: 비정상 트랜잭션
- ✅ START 없이 데이터 전송
- ✅ STOP 없이 트랜잭션 종료
- ✅ ACK 없이 다음 바이트 전송
- ✅ 9비트 전송 (8 data + ACK 무시)
```

#### 4.2 Bus Stuck Conditions
```
시나리오: 버스 고착
- ✅ SDA stuck low
- ✅ SDA stuck high
- ✅ SCL stuck low
- ✅ SCL stuck high
```

#### 4.3 Partial Transactions
```
시나리오: 중단된 트랜잭션
- ✅ START 후 즉시 리셋
- ✅ Address 6비트만 전송 후 중단
- ✅ Data 4비트만 전송 후 중단
- ✅ STOP 생성 중 리셋
```

---

### 5. State Machine Corner Cases

#### 5.1 State Transitions
```systemverilog
covergroup cg_state_transitions @(posedge clk);
    cp_state_trans: coverpoint {state, state_next} {
        // Valid transitions
        bins idle_to_start = {[IDLE, START_1]};
        bins start_to_addr = {[START_3, ADDR_BIT]};
        bins addr_to_data  = {[ADDR_ACK, DATA_BIT]};
        bins data_to_stop  = {[DATA_ACK, STOP_1]};
        bins stop_to_idle  = {[STOP_3, IDLE]};

        // Error transitions
        bins addr_to_stop_on_nack = {[ADDR_ACK, STOP_1]};
        bins data_to_stop_on_nack = {[DATA_ACK, STOP_1]};

        // Invalid transitions (should never happen)
        illegal_bins invalid = {
            [IDLE, DATA_BIT],
            [START_1, STOP_1],
            [ADDR_BIT, IDLE]
        };
    }
endgroup
```

**시나리오:**
- ✅ 모든 정상 state transition 발생
- ✅ Error state 진입 후 복구
- ✅ Unexpected state jump 감지

#### 5.2 State Timeout
```
시나리오: State에서 무한 대기
- ✅ ADDR_ACK에서 Slave ACK 안 옴 (timeout)
- ✅ DATA_ACK에서 ACK 안 옴
- ✅ Slave가 응답 없을 때 Master timeout
```

---

### 6. Slave-Specific Corner Cases

#### 6.1 LED Slave (0x55)
```
시나리오:
- ✅ 읽기 시도 (미지원 동작)
- ✅ 연속 쓰기 (같은 값)
- ✅ 최대 속도로 쓰기 (back-to-back)
- ✅ LED 값이 변하는 순간 읽기 시도
```

#### 6.2 FND Slave (0x56)
```
시나리오:
- ✅ Invalid digit (0x10-0xFF) 전송
- ✅ 0x00-0x0F 모든 조합
- ✅ 같은 digit 반복 쓰기
- ✅ 빠른 카운팅 (짧은 간격)
```

#### 6.3 Switch Slave (0x57)
```
시나리오:
- ✅ 쓰기 시도 (미지원 동작)
- ✅ 스위치 값이 변하는 순간 읽기
- ✅ 연속 읽기 (같은 값)
- ✅ 연속 읽기 (다른 값)
```

---

## 🎨 UVM Testbench 구조

```
                         ┌─────────────────┐
                         │   UVM Test      │
                         │  (Scenarios)    │
                         └────────┬────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
            ┌───────▼──────┐           ┌───────▼──────┐
            │  Master Seq  │           │  Slave Seq   │
            │   Library    │           │   Library    │
            └───────┬──────┘           └───────┬──────┘
                    │                           │
            ┌───────▼──────┐           ┌───────▼──────┐
            │ Master Agent │           │ Slave Agent  │
            │  (Active)    │           │  (Passive)   │
            └───────┬──────┘           └───────┬──────┘
                    │                           │
                    │      ┌─────────────┐      │
                    └─────►│ Scoreboard  │◄─────┘
                           │  + Checker  │
                           └──────┬──────┘
                                  │
                           ┌──────▼──────┐
                           │  Coverage   │
                           │  Collector  │
                           └─────────────┘
```

---

## 📊 Coverage Goals

### Minimum Coverage Targets

```
✅ Code Coverage: 100%
   - Line coverage
   - Branch coverage
   - FSM coverage
   - Toggle coverage

✅ Functional Coverage: 95%+
   - Basic operations: 100%
   - Timing scenarios: 90%+
   - Protocol compliance: 100%
   - Multi-slave: 95%+
   - Corner cases: 80%+

✅ Assertion Coverage: 100%
   - Protocol assertions
   - Timing assertions
   - State machine assertions
```

### Coverage Bins 우선순위

**P0 (Must have):**
- ✅ All valid slave addresses
- ✅ All data patterns (0x00, 0xFF, 0xAA, 0x55)
- ✅ Write/Read operations
- ✅ ACK/NACK responses
- ✅ Valid START/STOP conditions

**P1 (Should have):**
- ✅ Invalid addresses
- ✅ Back-to-back transactions
- ✅ Reset during transaction
- ✅ All state transitions
- ✅ Walking bit patterns

**P2 (Nice to have):**
- ✅ Timing variations (fast/slow)
- ✅ Glitch tolerance
- ✅ Bus stuck conditions
- ✅ Repeated START (미지원 확인)
- ✅ Clock stretching (미지원 확인)

---

## 🚀 Test Cases 예시

### Test 1: Basic Write
```systemverilog
class test_basic_write extends base_test;
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // LED slave에 0xFF 쓰기
        write_transaction(8'h55, 8'hFF);

        // FND slave에 0x05 쓰기
        write_transaction(8'h56, 8'h05);

        phase.drop_objection(this);
    endtask
endclass
```

### Test 2: Address Corner Cases
```systemverilog
class test_address_corners extends base_test;
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // Valid addresses
        foreach(valid_addr[i]) begin
            write_transaction(valid_addr[i], 8'hAA);
        end

        // Invalid addresses (expect NACK)
        write_transaction(8'h00, 8'hAA); // Expect NACK
        write_transaction(8'h7F, 8'hAA); // Expect NACK

        phase.drop_objection(this);
    endtask
endclass
```

### Test 3: Reset During Transaction
```systemverilog
class test_reset_corner extends base_test;
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        fork
            // Transaction
            write_transaction(8'h55, 8'hFF);

            // Reset injection
            #random_delay rst_n = 0;
        join_any

        // Verify recovery
        #100ns rst_n = 1;
        write_transaction(8'h55, 8'hAA); // Should work

        phase.drop_objection(this);
    endtask
endclass
```

---

## 📝 Summary

**총 Coverage Points:** ~200+

**주요 시나리오:** 50+
- Basic operations: 10
- Timing: 8
- Protocol: 12
- Multi-slave: 8
- Error injection: 12

**코너 케이스:** 40+
- Timing corners: 10
- Protocol corners: 8
- Data corners: 8
- Error cases: 8
- State corners: 6

**예상 테스트 시간:**
- Regression: ~2-4 hours
- Full coverage: ~8-12 hours
- Corner cases: +4 hours

이 verification plan은 I2C IP의 robustness를 보장하고, 실제 하드웨어 배포 전 모든 edge case를 검증할 수 있습니다! 🎯
