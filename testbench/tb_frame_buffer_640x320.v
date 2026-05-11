`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_frame_buffer_640x320
// Purpose : ตรวจสอบ Frame Buffer (BRAM)
//           - เขียนได้ที่ทุก address (0 ถึง 76799)
//           - อ่านกลับมาได้ค่าเดิม (1-cycle read latency)
//           - dual-port: write กับ read ใช้ clock ต่างกันได้
//           - we = 0 ต้องไม่เขียน
//==============================================================================
module tb_frame_buffer_640x320;

    // ---------------- Inputs ----------------
    reg clk_w = 0, clk_r = 0;
    reg we = 0;
    reg [16:0] addr_w = 0, addr_r = 0;
    reg [11:0] din = 0;

    // ---------------- Outputs ---------------
    wire [11:0] dout;

    // ---------------- DUT -------------------
    frame_buffer_640x320 dut (
        .clk_w (clk_w),
        .we    (we),
        .addr_w(addr_w),
        .din   (din),
        .clk_r (clk_r),
        .addr_r(addr_r),
        .dout  (dout)
    );

    // ---------------- Clocks ----------------
    // clk_w = 24 MHz (PCLK ของกล้อง)  period ≈ 41.67 ns
    // clk_r = 25 MHz (VGA pixel clock) period = 40 ns
    always #20 clk_r = ~clk_r;
    always #21 clk_w = ~clk_w;

    integer error_count = 0;

    // ---------------- Helper task: write 1 cell ----------------
    task write_cell(input [16:0] a, input [11:0] d);
        begin
            @(negedge clk_w);
            addr_w = a;
            din    = d;
            we     = 1;
            @(posedge clk_w);
            @(negedge clk_w);
            we = 0;
        end
    endtask

    // ---------------- Helper task: read & verify 1 cell ----------------
    task read_check(input [16:0] a, input [11:0] expected);
        begin
            @(negedge clk_r);
            addr_r = a;
            @(posedge clk_r);  // 1-cycle latency
            @(posedge clk_r);
            if (dout !== expected) begin
                $display("ERROR: addr=%0d expected=%h got=%h", a, expected, dout);
                error_count = error_count + 1;
            end else begin
                $display("[%0t ns] OK: addr=%0d -> dout=%h", $time, a, dout);
            end
        end
    endtask

    // ---------------- Test Sequence ----------------
    initial begin
        $display("=========================================================");
        $display("  Testbench: Frame Buffer 320x240 (76800 x 12-bit)");
        $display("=========================================================");
        $dumpfile("tb_buffer.vcd");
        $dumpvars(0, tb_frame_buffer_640x320);

        we = 0;
        repeat (5) @(posedge clk_w);

        // ------ Test 1: เขียนค่าที่ขอบ (boundary addresses) ------
        $display("--- Test 1: Boundary writes ---");
        write_cell(17'd0,     12'hABC);
        write_cell(17'd1,     12'h123);
        write_cell(17'd76799, 12'hFFF);  // address สุดท้าย
        write_cell(17'd38400, 12'h555);  // กลาง buffer

        // ------ Test 2: อ่านกลับมาตรวจ ------
        $display("--- Test 2: Read back and verify ---");
        read_check(17'd0,     12'hABC);
        read_check(17'd1,     12'h123);
        read_check(17'd76799, 12'hFFF);
        read_check(17'd38400, 12'h555);

        // ------ Test 3: เขียนต่อเนื่องหลายๆ cell แบบ pipeline ------
        $display("--- Test 3: Sequential writes (100 cells) ---");
        begin : seq_write
            integer i;
            for (i = 0; i < 100; i = i + 1) begin
                write_cell(i + 100, i[11:0] ^ 12'hAA);
            end
        end

        $display("--- Test 4: Sequential reads ---");
        begin : seq_read
            integer i;
            for (i = 0; i < 100; i = i + 1) begin
                read_check(i + 100, i[11:0] ^ 12'hAA);
            end
        end

        // ------ Test 5: WE=0 ต้องไม่เขียน ------
        $display("--- Test 5: WE=0 should NOT overwrite ---");
        @(negedge clk_w);
        addr_w = 17'd0;
        din    = 12'h999;  // ค่าใหม่
        we     = 0;        // แต่ disable write
        repeat (3) @(posedge clk_w);
        read_check(17'd0, 12'hABC);  // ค่าเดิมต้องยังอยู่

        $display("---------------------------------------------------------");
        $display("Total errors : %0d", error_count);
        if (error_count == 0)
            $display("RESULT: PASS  ✓");
        else
            $display("RESULT: FAIL  ✗");
        $display("=========================================================");
        $finish;
    end

endmodule
