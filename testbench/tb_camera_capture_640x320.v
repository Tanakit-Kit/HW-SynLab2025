`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_camera_capture_640x320
// Purpose : ตรวจสอบ OV7670 capture module
//           - byte_sel ทำงานสลับ high/low byte ถูกต้อง
//           - Downsampling: เก็บเฉพาะ pixel คู่ และ line คู่ (ลด 640x480 -> 320x240)
//           - reset เมื่อ vsync = 1
//           - addr_out เพิ่มขึ้นถูกต้อง, write_en pulse ถูกต้อง
//==============================================================================
module tb_camera_capture_640x320;

    // ---------------- Inputs ----------------
    reg pclk = 0;
    reg vsync = 0;
    reg href = 0;
    reg [7:0] d_in = 0;

    // ---------------- Outputs ---------------
    wire [16:0] addr_out;
    wire [11:0] data_out;
    wire write_en;

    // ---------------- DUT -------------------
    camera_capture_640x320 dut (
        .pclk    (pclk),
        .vsync   (vsync),
        .href    (href),
        .d_in    (d_in),
        .addr_out(addr_out),
        .data_out(data_out),
        .write_en(write_en)
    );

    // ---------------- PCLK 24 MHz (period ≈ 41.67 ns) ----------------
    always #20 pclk = ~pclk;  // ~25MHz, ใกล้เคียง pclk จริงของกล้อง

    // ---------------- Counters for verification ----------------
    integer write_count = 0;
    integer error_count = 0;

    always @(posedge pclk) begin
        if (write_en) write_count = write_count + 1;
    end

    // ---------------- Helper task: ส่ง 1 byte เข้ามาทาง d_in ----------------
    // ตั้งค่า d_in ก่อน posedge pclk เพื่อให้ DUT sample ได้ครบ 1 รอบ
    task send_byte(input [7:0] b);
        begin
            @(negedge pclk);
            d_in = b;
            @(posedge pclk);
            #1;  // ให้ DUT update เสร็จก่อน
        end
    endtask

    // ---------------- Helper task: ส่ง 1 บรรทัด (640 pixel = 1280 bytes) ----------------
    // OV7670 RGB565 mode: 1 pixel = 2 bytes (high byte ก่อน แล้ว low byte)
    // ตั้ง href=1 ก่อนรอบแรกที่จะส่ง byte
    task send_one_line;
        integer i;
        begin
            // เริ่มต้นบรรทัด: yank href ขึ้นที่ negedge เพื่อ stable ก่อน posedge
            @(negedge pclk);
            href = 1;
            d_in = 8'hAA;
            @(posedge pclk);
            #1;

            // ส่ง 1280 bytes = 640 pixel (ตัวแรกส่งไปแล้วใน cycle ข้างบน คือ 0xAA = b1 ของ pixel 0)
            // ทีนี้ส่งต่ออีก 1279 bytes
            for (i = 0; i < 1279; i = i + 1) begin
                @(negedge pclk);
                d_in = (i % 2 == 0) ? 8'h55 : 8'hAA;  // สลับ low/high
                @(posedge pclk);
                #1;
            end

            // จบบรรทัด: ดึง href ลงที่ negedge
            @(negedge pclk);
            href = 0;
            // รอ horizontal blanking สักหน่อย
            repeat (10) @(posedge pclk);
        end
    endtask

    // ---------------- Test Sequence ----------------
    initial begin
        $display("=========================================================");
        $display("  Testbench: OV7670 Camera Capture (640x480 -> 320x240)");
        $display("=========================================================");
        $dumpfile("tb_capture.vcd");
        $dumpvars(0, tb_camera_capture_640x320);

        // Initial state
        vsync = 1; href = 0; d_in = 0;
        repeat (20) @(posedge pclk);

        // Pulse VSYNC เพื่อ reset capture
        $display("[%0t ns] Asserting VSYNC (frame start)", $time);
        vsync = 1;
        repeat (10) @(posedge pclk);
        vsync = 0;
        repeat (10) @(posedge pclk);

        if (addr_out !== 17'd0) begin
            $display("ERROR: addr_out should be 0 after VSYNC, got %0d", addr_out);
            error_count = error_count + 1;
        end else begin
            $display("[%0t ns] OK: addr_out reset to 0", $time);
        end

        // ------ ส่ง 4 บรรทัดแรกของ frame ------
        // Line 0 (line_cnt[0]==0): ควรเก็บทุก pixel คู่ -> 320 writes
        // Line 1 (line_cnt[0]==1): ควรไม่เก็บอะไร (skip บรรทัดคี่) -> 0 writes
        // Line 2 (line_cnt[0]==0): เก็บอีก 320 writes
        // Line 3: skip
        $display("[%0t ns] Sending 4 lines of pixel data...", $time);
        send_one_line;
        $display("[%0t ns] After line 0: write_count=%0d (expected 320)", $time, write_count);

        send_one_line;
        $display("[%0t ns] After line 1: write_count=%0d (expected 320, skip odd line)", $time, write_count);

        send_one_line;
        $display("[%0t ns] After line 2: write_count=%0d (expected 640)", $time, write_count);

        send_one_line;
        $display("[%0t ns] After line 3: write_count=%0d (expected 640, skip odd line)", $time, write_count);

        // ตรวจผล
        if (write_count !== 640) begin
            $display("ERROR: Expected 640 writes after 4 lines, got %0d", write_count);
            error_count = error_count + 1;
        end

        // ตรวจ data_out ของ pixel ล่าสุด: b1=0xAA, d_in=0x55
        // data_out = {b1[7:4], b1[2:0], d_in[7], d_in[4:1]}
        //         = {4'hA,    3'b010,  1'b0,    4'b1010}
        //         = 12'b1010_010_0_1010 = 12'hA4A
        $display("[%0t ns] Last data_out=%h (expected A4A)", $time, data_out);
        if (data_out !== 12'hA4A) begin
            $display("ERROR: data_out mismatch");
            error_count = error_count + 1;
        end

        // ------ Test VSYNC reset กลางคัน ------
        $display("[%0t ns] Triggering mid-frame VSYNC...", $time);
        vsync = 1;
        repeat (5) @(posedge pclk);
        vsync = 0;
        repeat (5) @(posedge pclk);

        if (addr_out !== 17'd0) begin
            $display("ERROR: addr_out should reset to 0 on VSYNC, got %0d", addr_out);
            error_count = error_count + 1;
        end

        $display("---------------------------------------------------------");
        $display("Total writes captured : %0d", write_count);
        $display("Total errors          : %0d", error_count);
        if (error_count == 0)
            $display("RESULT: PASS  ✓");
        else
            $display("RESULT: FAIL  ✗");
        $display("=========================================================");
        $finish;
    end

endmodule
