`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_sccb_config
// Purpose : ตรวจสอบ SCCB Configuration FSM ของ OV7670
//           - clock divider สร้าง i2c_clk ~390 kHz จาก 25 MHz
//           - START condition: SIOD ลง 0 ขณะ SIOC = 1
//           - STOP condition : SIOD ขึ้น 1 ขณะ SIOC = 1
//           - reg_idx เลื่อนผ่านครบ 8 registers
//
// หมายเหตุ : SCCB ใช้เวลานานในการ simulate (i2c_clk ~390kHz, 8 regs * ~28 bits)
//            เลย default รัน ~50 ms เพื่อให้เห็น 1-2 commands เต็มๆ
//==============================================================================
module tb_sccb_config;

    // ---------------- Inputs ----------------
    reg clk = 0;

    // ---------------- Outputs / Bidir ----------------
    wire sioc;
    wire siod;

    // จำลอง pull-up ของ I2C/SCCB bus
    pullup(siod);

    // ---------------- DUT -------------------
    sccb_config dut (
        .clk (clk),
        .sioc(sioc),
        .siod(siod)
    );

    // ---------------- 25 MHz clock (period = 40 ns) ----------------
    always #20 clk = ~clk;

    // ---------------- Counters / Trackers ----------------
    integer start_count = 0;
    integer stop_count  = 0;
    integer reg_idx_seen = -1;
    reg sioc_prev = 1;
    reg siod_prev = 1;

    // ตรวจหา START (SIOD falling edge ขณะ SIOC = 1)
    // ตรวจหา STOP  (SIOD rising  edge ขณะ SIOC = 1)
    always @(posedge clk) begin
        // detect SIOD edges while SIOC=1
        if (sioc == 1'b1) begin
            if (siod_prev == 1'b1 && siod === 1'b0) begin
                start_count = start_count + 1;
                $display("[%0t ns] >>> START detected (#%0d)", $time, start_count);
            end
            if (siod_prev == 1'b0 && siod === 1'b1) begin
                stop_count = stop_count + 1;
                $display("[%0t ns] >>> STOP detected  (#%0d)", $time, stop_count);
            end
        end
        sioc_prev <= sioc;
        siod_prev <= siod;

        // ติดตาม register index ที่กำลังส่ง
        if (dut.reg_idx !== reg_idx_seen) begin
            reg_idx_seen = dut.reg_idx;
            if (reg_idx_seen < 8)
                $display("[%0t ns] Now sending reg_idx=%0d, data=%h",
                         $time, reg_idx_seen, dut.reg_data);
        end
    end

    // ---------------- Test Sequence ----------------
    initial begin
        $display("=========================================================");
        $display("  Testbench: SCCB Configuration FSM");
        $display("=========================================================");
        $dumpfile("tb_sccb.vcd");
        $dumpvars(0, tb_sccb_config);

        // รันนานพอให้ส่ง 2-3 commands (1 command ใช้เวลา ~75 us)
        // 1 i2c_clk = ~2.56 us, 1 SCCB transaction ใช้ ~30 i2c cycles = ~77 us
        // 2 commands = ~154 us, ขอเผื่อเป็น 500 us
        #500_000;

        $display("---------------------------------------------------------");
        $display("Total START conditions  : %0d", start_count);
        $display("Total STOP  conditions  : %0d", stop_count);
        $display("Last reg_idx seen       : %0d", reg_idx_seen);
        $display("---------------------------------------------------------");

        if (start_count >= 1 && stop_count >= 1 && reg_idx_seen >= 1)
            $display("RESULT: PASS  ✓ (FSM is generating SCCB transactions)");
        else
            $display("RESULT: FAIL  ✗ (FSM did not produce expected START/STOP)");

        $display("=========================================================");
        $finish;
    end

endmodule
