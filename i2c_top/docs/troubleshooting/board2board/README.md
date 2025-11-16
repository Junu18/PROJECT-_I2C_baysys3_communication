# Board-to-Board I2C 통신 문제 해결 과정

## 개요

두 개의 Basys3 보드 간 I2C 통신을 시뮬레이션으로 검증하는 과정에서 발생한 문제들과 해결 방법을 문서화합니다.

**최종 결과:** 12/12 테스트 통과 ✓

---

## 문제 1: Master Board 포트 연결 오류

### 에러 메시지
```
[VRFC 10-3180] cannot find port 'scl_oe' on this module
["i2c_master_board.sv":48]
```

### 문제 상황
- Vivado Simulation에서 Elaboration 단계 실패
- `i2c_master_board.sv`에서 `i2c_master` 인스턴스 연결 시 오류 발생
- `scl_oe`, `sda_oe`, `sda_in`, `sda_out` 등의 포트가 존재하지 않음

### 원인 분석

**잘못된 가정:**
```systemverilog
// 잘못된 코드 (초기 버전)
i2c_master u_master (
    .sda_in  (sda_in),   // ✗ i2c_master에 이런 포트 없음
    .sda_out (sda_out),  // ✗ i2c_master에 이런 포트 없음
    .sda_oe  (sda_oe),   // ✗ i2c_master에 이런 포트 없음
    .scl_out (scl_out),  // ✗ i2c_master에 이런 포트 없음
    .scl_oe  (scl_oe),   // ✗ i2c_master에 이런 포트 없음
    ...
);
```

**실제 `i2c_master.sv` 포트 정의:**
```systemverilog
module i2c_master (
    // I2C Bus
    inout  logic        sda,    // ✓ 직접 연결 (tri-state 내장)
    output logic        scl,    // ✓ 직접 출력
    ...
);
```

**근본 원인:**
- `i2c_master`는 **내부에서 tri-state 로직을 처리**함
- 외부에서 분리된 `sda_in`, `sda_out`, `sda_oe` 신호를 제공하지 않음
- `i2c_system_top.sv` (단일 보드)에서는 이미 직접 연결 방식 사용 중

### 해결 방법

```systemverilog
// 수정된 코드
module i2c_master_board (
    inout  tri1  sda,  // tri1 = 내장 풀업
    inout  tri1  scl,
    ...
);

    i2c_master u_master (
        .sda  (sda),  // ✓ 직접 연결
        .scl  (scl),  // ✓ 직접 연결
        // Debug 포트들은 연결 안 함
        .debug_busy    (),
        .debug_ack     (),
        .debug_state   (),
        .debug_scl     (),
        .debug_sda_out (),
        .debug_sda_oe  ()
    );
endmodule
```

**변경 사항:**
1. Tri-state 제어 로직 제거
2. `sda`, `scl`을 `tri1` 타입으로 선언 (시뮬레이션 풀업)
3. Master와 직접 연결
4. Debug 포트는 open (연결 안 함)

### 커밋
```
Commit: 1c89c23
Message: Fix i2c_master_board port connections - use direct sda/scl
```

---

## 문제 2: Slave Board 포트 연결 오류

### 에러 메시지
```
[VRFC 10-3180] cannot find port 'sda_oe' on this module
["i2c_slave_board.sv":48]
```

### 문제 상황
- Master Board 수정 후에도 여전히 Elaboration 실패
- `i2c_slave_board.sv`에서 세 개의 슬레이브 인스턴스 연결 시 오류
- `sda_oe`, `sda_out`, `sda_in` 등의 포트가 존재하지 않음

### 원인 분석

**잘못된 코드 (초기 버전):**
```systemverilog
// Wired-AND 로직 시도 (잘못됨)
logic sda_in;
logic sda_out_led, sda_oe_led;
logic sda_out_fnd, sda_oe_fnd;
logic sda_out_sw, sda_oe_sw;

i2c_led_slave u_led_slave (
    .sda_in  (sda_in),      // ✗ 이런 포트 없음
    .sda_out (sda_out_led), // ✗ 이런 포트 없음
    .sda_oe  (sda_oe_led),  // ✗ 이런 포트 없음
    .scl     (scl),
    ...
);

// 3개 슬레이브 출력을 조합 (불필요한 복잡도)
assign sda_oe_combined = sda_oe_led | sda_oe_fnd | sda_oe_sw;
assign sda_out_combined = (sda_oe_led ? sda_out_led : 1'b1) &
                          (sda_oe_fnd ? sda_out_fnd : 1'b1) &
                          (sda_oe_sw  ? sda_out_sw  : 1'b1);
```

**실제 슬레이브 포트 정의:**
```systemverilog
module i2c_led_slave (
    input  logic       scl,
    inout  logic       sda,  // ✓ 직접 연결 (tri-state 내장)
    output logic [7:0] LED,
    ...
);
```

**근본 원인:**
- 각 슬레이브도 **내부에서 tri-state 로직을 처리**함
- `assign sda = sda_oe ? sda_out : 1'bz;` 로직이 슬레이브 내부에 이미 있음
- I2C는 **wired-AND** 특성상 여러 슬레이브가 같은 `sda`에 직접 연결되어도 정상 동작
- 외부에서 조합할 필요 없음

### 해결 방법

```systemverilog
// 수정된 코드
module i2c_slave_board (
    inout  wire  sda,  // 모든 슬레이브가 공유
    inout  wire  scl,
    ...
);

    // 3개 슬레이브 모두 같은 sda/scl에 직접 연결
    i2c_led_slave u_led_slave (
        .clk   (clk),
        .rst_n (rst_n),
        .scl   (scl),  // ✓ 직접 연결
        .sda   (sda),  // ✓ 직접 연결
        .LED   (LED),
        .debug_addr_match (),
        .debug_state      ()
    );

    i2c_fnd_slave u_fnd_slave (
        .clk   (clk),
        .rst_n (rst_n),
        .scl   (scl),  // ✓ 같은 버스
        .sda   (sda),  // ✓ 같은 버스
        .SEG   (SEG),
        .AN    (AN),
        .debug_addr_match (),
        .debug_state      ()
    );

    i2c_switch_slave u_switch_slave (
        .clk   (clk),
        .rst_n (rst_n),
        .scl   (scl),  // ✓ 같은 버스
        .sda   (sda),  // ✓ 같은 버스
        .SW    (SW),
        .debug_addr_match (),
        .debug_state      ()
    );
endmodule
```

**I2C Wired-AND 동작 원리:**
```
SDA 버스 (tri1 = pull-up to '1')
    │
    ├─── LED Slave:  sda_oe=0 → Hi-Z (풀업으로 '1')
    │                sda_oe=1 & sda_out=0 → '0' (강제)
    │
    ├─── FND Slave:  sda_oe=0 → Hi-Z (풀업으로 '1')
    │                sda_oe=1 & sda_out=0 → '0' (강제)
    │
    └─── SW Slave:   sda_oe=0 → Hi-Z (풀업으로 '1')
                     sda_oe=1 & sda_out=0 → '0' (강제)

결과: 어느 하나라도 '0'을 구동하면 버스는 '0'
      모두 Hi-Z이면 풀업에 의해 '1'
```

### 커밋
```
Commit: a6d0069
Message: Fix i2c_slave_board port connections - slaves use direct sda/scl
```

---

## 문제 3: FND 7-Segment 디코딩 테스트 실패

### 에러 메시지
```
Test 4: Sequential - LED write → FND write → Switch read
  ✗ FAIL (LED=0xaa, SEG=0b0001110, rx_data=0x12, ack_error=0)

Test 6: FND Counter (0 → F)
  ✗ FAIL (SEG=0b0001110, expected=0b0001000)
```

### 문제 상황
- 포트 연결 수정 후 시뮬레이션은 실행됨
- 12개 테스트 중 10개 통과, 2개 실패
- Test 4, Test 6에서 FND 값 검증 실패
- 실제 값: `0b0001110`, 기대 값: `0b0001000`

### 원인 분석

**실제 RTL 코드 (`i2c_fnd_slave.sv`):**
```systemverilog
case (digit_reg)
    4'h0: seg_pattern = 7'b1000000;  // 0
    4'h1: seg_pattern = 7'b1111001;  // 1
    ...
    4'hA: seg_pattern = 7'b0001000;  // A  ← 이게 0b0001000
    ...
    4'hE: seg_pattern = 7'b0000110;  // E
    4'hF: seg_pattern = 7'b0001110;  // F  ← 실제 F는 0b0001110
    default: seg_pattern = 7'b1111111;
endcase
```

**테스트벤치 코드 (`i2c_board2board_tb.sv` 초기 버전):**
```systemverilog
// Test 4
master_write(7'h56, 8'h0F);  // F를 쓰기
if (slave_seg == 7'b0001000 ...)  // ✗ 0b0001000은 A의 값!

// Test 6
for (int i = 0; i < 16; i++) begin
    master_write(7'h56, i);  // 0~F 쓰기
end
if (slave_seg == 7'b0001000 ...)  // ✗ 마지막 값(F)이 0b0001000이 아님
```

**근본 원인:**
- 테스트벤치 작성 시 **잘못된 기대값** 사용
- F의 7-segment 인코딩 = `0b0001110` (정확함)
- 테스트가 `0b0001000` (A의 값)을 기대함
- RTL 코드는 정상, 테스트벤치가 잘못됨

**왜 이런 일이 발생했나?**

1. **기존 `i2c_system_tb.sv` 검증 부족:**
   ```systemverilog
   // Test 6: FND Counter Test (0-F)
   for (int i = 0; i < 16; i++) begin
       master_write(ADDR_FND, i[7:0]);
       repeat(30) @(posedge clk);
   end
   $display("  ✓ PASS\n");  // ← SEG 값 검증 안 함!
   ```
   - 단일 보드 테스트는 **쓰기만 확인**하고 출력 값은 검증하지 않음
   - FND 디코딩 오류가 발견되지 않았음

2. **Board2Board 테스트에서 강화된 검증:**
   - 실제 출력 값(`slave_seg`)을 검증하는 코드 추가
   - 더 엄격한 테스트로 인해 기대값 오류 발견

### 해결 방법

**테스트벤치 수정:**
```systemverilog
// Test 4 수정
if (slave_led == 8'hAA && slave_seg == 7'b0001110 && ...)  // ✓ 0b0001110 = F
    begin pass_count++; $display("  ✓ PASS\n"); end

// Test 6 수정
if (slave_seg == 7'b0001110 && !master_ack_error)  // ✓ F = 0b0001110
    begin pass_count++; $display("  ✓ PASS\n"); end
```

**검증:**
```
실제 RTL 디코딩 테이블:
0: 0b1000000
1: 0b1111001
2: 0b0100100
...
9: 0b0010000
A: 0b0001000  ← 테스트가 잘못 사용한 값
B: 0b0000011
C: 0b1000110
D: 0b0100001
E: 0b0000110
F: 0b0001110  ← 올바른 F 값
```

### 커밋
```
Commit: 60cebac
Message: Fix board2board testbench FND expected values - F is 0b0001110 not 0b0001000
```

---

## 문제 발생 근본 원인 정리

### 1. 포트 연결 오류 (문제 1, 2)

**왜 발생했나?**
- **가정의 오류:** 기존 시스템 (`i2c_system_top.sv`)을 확인하지 않고 새로 작성
- **문서 부족:** 각 모듈의 인터페이스가 명확히 문서화되지 않음
- **테스트 없이 작성:** 컴파일 없이 코드 작성 후 한 번에 테스트

**교훈:**
- ✓ 기존 동작하는 코드 참조
- ✓ 모듈 포트 정의 먼저 확인
- ✓ 점진적 테스트 (모듈별로 검증)

### 2. 기대값 오류 (문제 3)

**왜 발생했나?**
- **검증 부족:** 단일 보드 테스트가 출력 값을 검증하지 않음
- **수동 입력 오류:** 7-segment 인코딩을 수동으로 입력하면서 실수
- **테스트 강화:** Board2Board 테스트에서 더 엄격한 검증 추가

**교훈:**
- ✓ Golden Reference 사용 (RTL 코드의 실제 값 확인)
- ✓ 모든 출력 값 검증
- ✓ 자동화된 검증 (하드코딩된 값 대신 파라미터 사용)

### 3. 시뮬레이션 vs 실제 하드웨어 차이

**중요한 발견:**
- `tri1` 타입: 시뮬레이션에서는 내장 풀업, 하드웨어에서는 외부 4.7kΩ 필요
- Wired-AND: 여러 디바이스가 같은 버스에 직접 연결 가능 (내부 tri-state)
- PMOD 케이블: 실제 배포 시 풀업 저항 추가 필요

---

## 최종 결과

### 시뮬레이션 결과
```
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

### 검증된 기능
1. ✓ LED 슬레이브 쓰기 (0x55)
2. ✓ FND 슬레이브 쓰기 (0x56)
3. ✓ Switch 슬레이브 읽기 (0x57)
4. ✓ 순차 동작 (쓰기+읽기 조합)
5. ✓ LED 패턴 변경
6. ✓ FND 카운터 (0~F)
7. ✓ Switch→LED 복사
8. ✓ 잘못된 주소 NACK 검출
9. ✓ 연속 읽기 (5회)
10. ✓ 즉시 전환 (Write→Read)
11. ✓ 비트 패턴 (0x00, 0xFF, 0xAA, 0x55)
12. ✓ 동적 Switch 변경

### 파일 구조
```
i2c_top/
├── rtl/
│   └── integration/
│       ├── i2c_master_board.sv  ← Master 보드
│       └── i2c_slave_board.sv   ← Slave 보드
├── tb/
│   └── i2c_board2board_tb.sv    ← 12개 테스트
└── sim/
    ├── run_board2board.sh       ← Icarus 실행
    └── run_board2board_vivado.tcl  ← Vivado 실행
```

---

## 문제 해결 요약표

| # | 문제 | 에러 코드 | 원인 | 해결 방법 | 커밋 |
|---|------|----------|------|----------|------|
| **1** | Master Board 포트 연결 오류 | `VRFC 10-3180: cannot find port 'scl_oe'` | `i2c_master`는 분리된 `sda_oe`, `scl_oe` 포트가 없음 | `sda`, `scl` 직접 연결, tri-state 제거 | `1c89c23` |
| **2** | Slave Board 포트 연결 오류 | `VRFC 10-3180: cannot find port 'sda_oe'` | 슬레이브들도 분리된 tri-state 포트가 없음 | 3개 슬레이브 모두 같은 `sda`/`scl`에 직접 연결 | `a6d0069` |
| **3** | FND 디코딩 테스트 실패 | Test 4, 6 FAIL: `SEG=0b0001110, expected=0b0001000` | 테스트벤치의 잘못된 기대값 (F=0b0001110인데 0b0001000 기대) | RTL 코드 확인 후 테스트 기대값 수정 | `60cebac` |

**총 수정 파일:** 3개
**총 커밋:** 3개
**최종 테스트 결과:** 12/12 통과 (100%)

---

## 다음 단계

### 실제 하드웨어 배포 준비

**Master Board:**
1. Vivado 프로젝트 생성
2. RTL 추가: `i2c_master_board.sv`, `i2c_master.sv`
3. 제약 파일: `constraints/basys3_master.xdc`
4. 합성 → 구현 → 비트스트림 생성
5. PMOD JA 핀 확인 (JA1=SCL, JA2=SDA)

**Slave Board:**
1. Vivado 프로젝트 생성
2. RTL 추가: `i2c_slave_board.sv`, 3개 슬레이브 파일
3. 제약 파일: `constraints/basys3_slaves.xdc`
4. 합성 → 구현 → 비트스트림 생성
5. PMOD JA 핀 확인 (JA1=SCL, JA2=SDA)

**PMOD 케이블 연결:**
```
Master (PMOD JA)  <--케이블-->  Slave (PMOD JA)
    JA1 (SCL) ------------------- JA1 (SCL)
    JA2 (SDA) ------------------- JA2 (SDA)
    GND ----------------------- GND

중요: 4.7kΩ 풀업 저항 필요 (SDA, SCL 각각 3.3V에 연결)
```

### 추가 테스트 권장사항

1. **하드웨어 검증:** 실제 보드에서 8개 기본 테스트 수행
2. **장거리 케이블:** PMOD 케이블 길이에 따른 신호 품질 확인
3. **노이즈 테스트:** 보드 간 거리, 주변 전자기 환경 영향 확인
4. **전력 관리:** 두 보드의 전원 안정성 확인

---

## 참고 문서

- [BOARD2BOARD_TEST.md](../BOARD2BOARD_TEST.md) - 사용 가이드
- [FILE_USAGE_GUIDE.md](../FILE_USAGE_GUIDE.md) - 파일 설명
- [QUICKSTART.md](../QUICKSTART.md) - 빠른 시작 가이드
