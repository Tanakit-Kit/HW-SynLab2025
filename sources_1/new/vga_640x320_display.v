module vga_640x320_display(
    input clk_25m,
    input [11:0] pixel_in,
    output hsync, vsync,
    output [3:0] vga_r, vga_g, vga_b,
    output [16:0] frame_addr
);
    reg [9:0] h_cnt = 0, v_cnt = 0;

    always @(posedge clk_25m) begin
        if (h_cnt == 799) begin
            h_cnt <= 0;
            v_cnt <= (v_cnt == 524) ? 0 : v_cnt + 1;
        end else h_cnt <= h_cnt + 1;
    end
    assign hsync = (h_cnt >= 656 && h_cnt < 752) ? 0 : 1;
    assign vsync = (v_cnt >= 490 && v_cnt < 492) ? 0 : 1;
    
    wire display_area = (h_cnt < 640 && v_cnt < 480);
    
    // Pixel Doubling: หารตำแหน่งพิกัดบนหน้าจอด้วย 2 (>> 1) (***SUS***)
    wire [9:0] img_x = h_cnt >> 1; 
    wire [9:0] img_y = v_cnt >> 1; 
    
    // คำนวณ Address จากภาพขนาด 320x240
    assign frame_addr = display_area ? (img_y * 320 + img_x) : 0;

    assign vga_r = display_area ? pixel_in[11:8] : 4'h0;
    assign vga_g = display_area ? pixel_in[7:4] : 4'h0;
    assign vga_b = display_area ? pixel_in[3:0] : 4'h0;
endmodule
