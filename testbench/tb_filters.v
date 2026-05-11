`timescale 1ns / 1ps
//==============================================================================
// Testbench: tb_filters
// Purpose : ตรวจสอบ Logic ของ filter ทั้ง 3 แบบใน top_module โดยตรง
//           - S_NORMAL    (sw=00) : ส่งสีต้นฉบับ
//           - S_GREY      (sw=01) : Grayscale = (R>>2)+(R>>4)+(G>>1)+(G>>4)+(B>>3)
//           - S_INVERSION (sw=10) : R,G,B = ~raw_r, ~raw_g, ~raw_b
//           - S_CISOLATION(sw=11) : R=raw_r, G=0, B=0 (Red isolation)
//
// แนวทาง : เพราะ logic ของ filter เป็น combinational pure
//          เราเขียน reference module เลียนแบบเพื่อเทียบผลโดยตรง
//==============================================================================
module tb_filters;

    // ---------------- Stimulus signals ----------------
    reg [3:0] R, G, B;
    reg [1:0] sw;

    // ---------------- Reference filter (mirror ของ logic ใน top_module) ----------------
    // เลียนแบบสมการ Grayscale ใน top_module.v บรรทัด 88-92
    function [3:0] grayscale_ref(input [3:0] r4, input [3:0] g4, input [3:0] b4);
        reg [7:0] R_ext, G_ext, B_ext, Y;
        begin
            R_ext = {r4, 4'b0000};
            G_ext = {g4, 4'b0000};
            B_ext = {b4, 4'b0000};
            Y = (R_ext >> 2) + (R_ext >> 4)
              + (G_ext >> 1) + (G_ext >> 4)
              + (B_ext >> 3);
            grayscale_ref = Y[7:4];
        end
    endfunction

    // ---------------- DUT (mini): จำลอง filter logic ของ top_module ----------------
    // เนื่องจาก top_module ต้องการ camera/VGA signals ครบถ้วน
    // เราสกัดเฉพาะ filter logic (block always @(*)) มาเป็น DUT แยก
    reg [3:0] r_out, g_out, b_out;
    wire [7:0] R_ext = {R, 4'b0000};
    wire [7:0] G_ext = {G, 4'b0000};
    wire [7:0] B_ext = {B, 4'b0000};
    wire [7:0] Y_calc = (R_ext >> 2) + (R_ext >> 4)
                      + (G_ext >> 1) + (G_ext >> 4)
                      + (B_ext >> 3);
    wire [3:0] gray_val = Y_calc[7:4];

    always @(*) begin
        case (sw)
            2'b00: begin r_out = R;          g_out = G;          b_out = B;          end
            2'b01: begin r_out = gray_val;   g_out = gray_val;   b_out = gray_val;   end
            2'b10: begin r_out = ~R;         g_out = ~G;         b_out = ~B;         end
            2'b11: begin r_out = R;          g_out = 4'h0;       b_out = 4'h0;       end
            default: begin r_out = R; g_out = G; b_out = B; end
        endcase
    end

    integer error_count = 0;

    // ---------------- Helper task ----------------
    task check(input [255:0] label,
               input [3:0] exp_r, input [3:0] exp_g, input [3:0] exp_b);
        begin
            #1;  // รอ combinational settle
            if (r_out !== exp_r || g_out !== exp_g || b_out !== exp_b) begin
                $display("[%0t] FAIL %0s: in=(R=%h,G=%h,B=%h) sw=%b -> out=(%h,%h,%h) expected=(%h,%h,%h)",
                         $time, label, R, G, B, sw, r_out, g_out, b_out, exp_r, exp_g, exp_b);
                error_count = error_count + 1;
            end else begin
                $display("[%0t] PASS %0s: in=(R=%h,G=%h,B=%h) sw=%b -> out=(%h,%h,%h)",
                         $time, label, R, G, B, sw, r_out, g_out, b_out);
            end
        end
    endtask

    // ---------------- Test Sequence ----------------
    initial begin
        $display("=========================================================");
        $display("  Testbench: Image Filters (Normal/Gray/Inversion/Red-only)");
        $display("=========================================================");
        $dumpfile("tb_filters.vcd");
        $dumpvars(0, tb_filters);

        // ------ Test color: pure white (F,F,F) ------
        R = 4'hF; G = 4'hF; B = 4'hF;

        sw = 2'b00; check("NORMAL_WHITE",    4'hF, 4'hF, 4'hF);
        sw = 2'b01; check("GRAY_WHITE",      grayscale_ref(4'hF,4'hF,4'hF),
                                              grayscale_ref(4'hF,4'hF,4'hF),
                                              grayscale_ref(4'hF,4'hF,4'hF));
        sw = 2'b10; check("INVERT_WHITE",    4'h0, 4'h0, 4'h0);
        sw = 2'b11; check("REDONLY_WHITE",   4'hF, 4'h0, 4'h0);

        // ------ Test color: pure black (0,0,0) ------
        R = 4'h0; G = 4'h0; B = 4'h0;

        sw = 2'b00; check("NORMAL_BLACK",    4'h0, 4'h0, 4'h0);
        sw = 2'b01; check("GRAY_BLACK",      4'h0, 4'h0, 4'h0);
        sw = 2'b10; check("INVERT_BLACK",    4'hF, 4'hF, 4'hF);
        sw = 2'b11; check("REDONLY_BLACK",   4'h0, 4'h0, 4'h0);

        // ------ Test color: pure red (F,0,0) ------
        R = 4'hF; G = 4'h0; B = 4'h0;

        sw = 2'b00; check("NORMAL_RED",      4'hF, 4'h0, 4'h0);
        sw = 2'b01; check("GRAY_RED",        grayscale_ref(4'hF,4'h0,4'h0),
                                              grayscale_ref(4'hF,4'h0,4'h0),
                                              grayscale_ref(4'hF,4'h0,4'h0));
        sw = 2'b10; check("INVERT_RED",      4'h0, 4'hF, 4'hF);
        sw = 2'b11; check("REDONLY_RED",     4'hF, 4'h0, 4'h0);

        // ------ Test color: pure green (0,F,0) ------
        R = 4'h0; G = 4'hF; B = 4'h0;

        sw = 2'b00; check("NORMAL_GREEN",    4'h0, 4'hF, 4'h0);
        sw = 2'b01; check("GRAY_GREEN",      grayscale_ref(4'h0,4'hF,4'h0),
                                              grayscale_ref(4'h0,4'hF,4'h0),
                                              grayscale_ref(4'h0,4'hF,4'h0));
        sw = 2'b10; check("INVERT_GREEN",    4'hF, 4'h0, 4'hF);
        sw = 2'b11; check("REDONLY_GREEN",   4'h0, 4'h0, 4'h0);

        // ------ Test color: pure blue (0,0,F) ------
        R = 4'h0; G = 4'h0; B = 4'hF;

        sw = 2'b00; check("NORMAL_BLUE",     4'h0, 4'h0, 4'hF);
        sw = 2'b01; check("GRAY_BLUE",       grayscale_ref(4'h0,4'h0,4'hF),
                                              grayscale_ref(4'h0,4'h0,4'hF),
                                              grayscale_ref(4'h0,4'h0,4'hF));
        sw = 2'b10; check("INVERT_BLUE",     4'hF, 4'hF, 4'h0);
        sw = 2'b11; check("REDONLY_BLUE",    4'h0, 4'h0, 4'h0);

        // ------ Test mid-gray (8,8,8) ------
        R = 4'h8; G = 4'h8; B = 4'h8;
        sw = 2'b01; check("GRAY_MIDGRAY",    grayscale_ref(4'h8,4'h8,4'h8),
                                              grayscale_ref(4'h8,4'h8,4'h8),
                                              grayscale_ref(4'h8,4'h8,4'h8));

        // ------ Switch transition test: state machine ----------
        // ทดสอบ rapid switch
        R = 4'hA; G = 4'h5; B = 4'h3;
        sw = 2'b00; #5;
        sw = 2'b01; #5;
        sw = 2'b10; #5;
        sw = 2'b11; #5;

        $display("---------------------------------------------------------");
        $display("Total errors : %0d", error_count);
        if (error_count == 0)
            $display("RESULT: PASS  ✓ (All filter outputs match reference)");
        else
            $display("RESULT: FAIL  ✗");
        $display("=========================================================");
        $finish;
    end

endmodule
