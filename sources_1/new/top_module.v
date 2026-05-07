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
    parameter S_NORMAL   = 2'b00;
    parameter S_GREY = 2'b01;
    parameter S_INVERSION = 2'b10;
    parameter S_CISOLATION = 2'b11;
    
    reg [1:0] current_state = S_NORMAL;
    
    // --- Signals ---
    wire clk_25m, clk_24m;
    wire [16:0] frame_addr;
    wire [11:0] pixel_12bit; 
    wire [16:0] capture_addr; // [FIXED] ขนาดต้องเป็น 17-bit ให้ตรงกับ capture module
    wire [11:0] capture_data;
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
        .clk_r(clk_25m), .addr_r(frame_addr), .dout(pixel_12bit) // [FIXED] แก้จาก pixel_8bit เป็น pixel_12bit
    );


    wire [3:0] raw_r, raw_g, raw_b;
    wire video_active;
    vga_640x320_display vga_inst (
        .clk_25m(clk_25m), .pixel_in(pixel_12bit),
        .hsync(vga_hsync), .vsync(vga_vsync),
        .vga_r(raw_r), .vga_g(raw_g), .vga_b(raw_b),
        .frame_addr(frame_addr),
        .active(video_active)
    );

    // --- State Machine Logic ---
    always @(posedge clk_25m) begin
        if (reset) begin
            current_state <= S_NORMAL;
        end else begin
            case (sw)
                2'b00: current_state <= S_NORMAL;
                2'b01: current_state <= S_GREY;
		2'b10: current_state <= S_INVERSION;
		2'b11: current_state <= S_CISOLATION; // [FIXED] แก้ typo จาก <+ เป็น <=
                default: current_state <= S_NORMAL;
            endcase
        end
    end

    // --- Grayscale Math (Shift-and-Add) ---
// Zero-extend to 8 bits to preserve precision during division/shifting
wire [7:0] R_ext = {raw_r, 4'b0000};
wire [7:0] G_ext = {raw_g, 4'b0000};
wire [7:0] B_ext = {raw_b, 4'b0000};

// Divide by powers of 2 using right shifts to approximate luminance 
wire [7:0] Y_calc = (R_ext >> 2) + (R_ext >> 4) + 
                    (G_ext >> 1) + (G_ext >> 4) + 
                    (B_ext >> 3);

wire [3:0] gray_val = Y_calc[7:4]; 

always @(*) begin
    case (current_state)
        S_NORMAL: begin
            r_out = raw_r;
            g_out = raw_g;
            b_out = raw_b;
        end
        S_GREY: begin
            r_out = gray_val;
            g_out = gray_val;
            b_out = gray_val;
        end
        S_INVERSION: begin
            r_out = ~raw_r;
            g_out = ~raw_g;
            b_out = ~raw_b;
        end
        S_CISOLATION: begin
            // Isolate Red, force Green and Blue to 0
            r_out = raw_r;
            g_out = 4'h0;
            b_out = 4'h0;
        end
        default: begin
            r_out = raw_r;
            g_out = raw_g;
            b_out = raw_b;
        end
    endcase
end
    assign vga_r = video_active ? r_out : 4'h0;
    assign vga_g = video_active ? g_out : 4'h0;
    assign vga_b = video_active ? b_out : 4'h0;

endmodule
