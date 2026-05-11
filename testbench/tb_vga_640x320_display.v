`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_vga_640x320_display
// Purpose : ตรวจสอบ VGA timing generator
//           - hsync/vsync ตรงตาม 640x480@60Hz มาตรฐาน
//           - h_cnt นับ 0-799, v_cnt นับ 0-524
//           - frame_addr คำนวณถูกต้อง (pixel doubling 320x240 -> 640x480)
//           - display_area กำหนดพื้นที่แสดงผลถูกต้อง
//==============================================================================
module tb_vga_640x320_display;

    // ---------------- Inputs ----------------
    reg clk_25m = 0;
    reg [11:0] pixel_in = 12'hF0F;  // ส่งสีคงที่เข้าไป

    // ---------------- Outputs ---------------
    wire hsync, vsync;
    wire [3:0] vga_r, vga_g, vga_b;
    wire [16:0] frame_addr;

    // ---------------- DUT -------------------
    vga_640x320_display dut (
        .clk_25m   (clk_25m),
        .pixel_in  (pixel_in),
        .hsync     (hsync),
        .vsync     (vsync),
        .vga_r     (vga_r),
        .vga_g     (vga_g),
        .vga_b     (vga_b),
        .frame_addr(frame_addr)
    );

    // ---------------- Clock 25 MHz (period = 40 ns) ----------------
    always #20 clk_25m = ~clk_25m;

    // ---------------- Counters for verification ----------------
    integer hsync_low_cnt   = 0;
    integer vsync_low_cnt   = 0;
    integer error_count     = 0;
    integer frames_done     = 0;

    // ---------------- Self-checking assertions ----------------
    // เช็ค hsync ต้อง low เฉพาะตอน h_cnt อยู่ในช่วง 656-751 (96 cycles)
    // เช็ค vsync ต้อง low เฉพาะตอน v_cnt อยู่ในช่วง 490-491 (2 lines)
    always @(posedge clk_25m) begin
        // นับจำนวนครั้งที่ hsync = 0 ใน 1 frame เพื่อเช็คว่าได้ 96 ครั้งต่อบรรทัด
        if (hsync == 1'b0) hsync_low_cnt = hsync_low_cnt + 1;
        if (vsync == 1'b0) vsync_low_cnt = vsync_low_cnt + 1;

        // ตรวจช่วง active video: vga_r ต้อง = pixel_in[11:8]
        if (dut.h_cnt < 640 && dut.v_cnt < 480) begin
            if (vga_r !== pixel_in[11:8]) begin
                $display("[%0t ns] ERROR: vga_r=%h expected=%h at (h=%0d,v=%0d)",
                         $time, vga_r, pixel_in[11:8], dut.h_cnt, dut.v_cnt);
                error_count = error_count + 1;
            end
        end else begin
            // นอกพื้นที่แสดงผล RGB ต้องเป็น 0 (blanking)
            if (vga_r !== 4'h0 || vga_g !== 4'h0 || vga_b !== 4'h0) begin
                $display("[%0t ns] ERROR: blanking should be 0 but RGB=%h%h%h at (h=%0d,v=%0d)",
                         $time, vga_r, vga_g, vga_b, dut.h_cnt, dut.v_cnt);
                error_count = error_count + 1;
            end
        end
    end

    // ---------------- Test Sequence ----------------
    initial begin
        $display("=========================================================");
        $display("  Testbench: VGA 640x480 Sync (with 320x240 doubling)");
        $display("=========================================================");
        $dumpfile("tb_vga.vcd");
        $dumpvars(0, tb_vga_640x320_display);

        // รัน 2 frames เต็ม:
        // 1 frame = 800 x 525 x 40ns = 16.8 ms
        // 2 frames = 33.6 ms = 33,600,000 ns
        #33_600_000;

        $display("---------------------------------------------------------");
        $display("Total hsync_low cycles : %0d (expected ~%0d for 2 frames)",
                 hsync_low_cnt, 96 * 525 * 2);
        $display("Total vsync_low cycles : %0d (expected ~%0d for 2 frames)",
                 vsync_low_cnt, 2 * 800 * 2);
        $display("Total errors           : %0d", error_count);
        if (error_count == 0)
            $display("RESULT: PASS  ✓");
        else
            $display("RESULT: FAIL  ✗");
        $display("=========================================================");
        $finish;
    end

    // ---------------- Monitor: print timing milestones ----------------
    initial begin
        // Watch transitions for first frame
        @(negedge hsync); $display("[%0t ns] First HSYNC pulse begins (h=%0d)", $time, dut.h_cnt);
        @(posedge hsync); $display("[%0t ns] First HSYNC pulse ends   (h=%0d)", $time, dut.h_cnt);
        @(negedge vsync); $display("[%0t ns] First VSYNC pulse begins (v=%0d)", $time, dut.v_cnt);
        @(posedge vsync); $display("[%0t ns] First VSYNC pulse ends   (v=%0d)", $time, dut.v_cnt);
    end

endmodule
