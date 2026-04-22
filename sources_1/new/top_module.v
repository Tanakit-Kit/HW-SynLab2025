`timescale 1ns / 1ps

module top_module(
    input clk_100mhz,
    input reset,
    input [1:0] sw,      // ใช้ Switch (00: Normal, 01: Filter)
    output ov7670_xclk,
    input ov7670_pclk,
    input ov7670_vsync,
    input ov7670_href,
    input [7:0] ov7670_data,
    output ov7670_sioc,
    inout ov7670_siod,
    output ov7670_pwdn,
    output ov7670_rst,
    // VGA Pins
    output [3:0] vga_r, vga_g, vga_b,
    output vga_hsync, vga_vsync
);
    // --- State Definition ---
    parameter S_INIT   = 2'b00;
    parameter S_NORMAL = 2'b01;
    parameter S_FILTER = 2'b10;
    
    reg [1:0] current_state = S_INIT;
    
    // --- Signals ---
    wire clk_25m, clk_24m;
    wire [16:0] frame_addr;
    wire [7:0] pixel_8bit; 
    wire [17:0] capture_addr;
    wire [7:0] capture_data;
    wire capture_we;
    
    // สัญญาณสีที่จะส่งออก VGA จริงๆ
    reg [3:0] r_out, g_out, b_out;

    // --- Module Instantiations ---
    clk_wiz_0 clock_gen (.clk_in1(clk_100mhz), .clk_out1(clk_25m), .clk_out2(clk_24m));
    assign ov7670_xclk = clk_24m;
    assign ov7670_pwdn = 1'b0;
    assign ov7670_rst  = 1'b1;

    sccb_config config_inst (.clk(clk_25m), .sioc(ov7670_sioc), .siod(ov7670_siod));

    camera_capture_640x320 capture_inst (
        .pclk(ov7670_pclk), .vsync(ov7670_vsync), .href(ov7670_href),
        .d_in(ov7670_data), .addr_out(capture_addr), .data_out(capture_data), .write_en(capture_we)
    );

    frame_buffer_640x320 ram_inst (
        .clk_w(ov7670_pclk), .we(capture_we), .addr_w(capture_addr), .din(capture_data),
        .clk_r(clk_25m), .addr_r(frame_addr), .dout(pixel_8bit)
    );


    wire [3:0] raw_r, raw_g, raw_b;
    vga_640x320_display vga_inst (
        .clk_25m(clk_25m), .pixel_in(pixel_8bit),
        .hsync(vga_hsync), .vsync(vga_vsync),
        .vga_r(raw_r), .vga_g(raw_g), .vga_b(raw_b),
        .frame_addr(frame_addr)
    );

    // --- State Machine Logic ---
    always @(posedge clk_25m) begin
        if (reset) begin
            current_state <= S_INIT;
        end else begin
            case (sw)
                2'b00: current_state <= S_NORMAL;
                2'b01: current_state <= S_FILTER;
                default: current_state <= S_NORMAL;
            endcase
        end
    end

    // (จุดที่จะ implement ต่อ)
    always @(*) begin
        case (current_state)
            S_NORMAL: begin
                r_out = raw_r;
                g_out = raw_g;
                b_out = raw_b;
            end
            // ทำ Filter
            S_FILTER: begin
                r_out = ~raw_r;
                g_out = ~raw_g;
                b_out = ~raw_b;
            end
            default: begin
                r_out = raw_r; g_out = raw_g; b_out = raw_b;
            end
        endcase
    end

    assign vga_r = r_out;
    assign vga_g = g_out;
    assign vga_b = b_out;

endmodule