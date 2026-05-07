module vga_640x320_display(
    input clk_25m,
    input [11:0] pixel_in,
    output hsync, vsync,
    output [3:0] vga_r, vga_g, vga_b,
    output [16:0] frame_addr,
    output active
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
    
    // [FIXED] เพิ่ม Delay 1 Clock ให้สัญญาณ active เพื่อให้ตรงกับความหน่วงของ RAM
    reg active_d = 0;
    always @(posedge clk_25m) active_d <= display_area;
    assign active = active_d;
    
    // [FIXED] ใช้เทคนิคการยืดภาพ (Scaling) แบบเนียนตา
    // เรามีภาพจริง 312 พิกเซลใน RAM (ข้าม 8 พิกเซลแรกที่เป็นแถบดำ)
    // เราจะยืด 312 พิกเซลนี้ให้เต็ม 640 พิกเซลบนจอ ด้วยสมการ: h_cnt * (312/640)
    // ประมาณค่าคณิตศาสตร์แบบไม่ใช้การหาร: (h_cnt * 499) / 1024
    wire [19:0] scaled_x = (h_cnt * 499) >> 10;
    wire [9:0] img_x = scaled_x + 8; // เริ่มอ่านที่ Index 8 เพื่อข้ามแถบดำ
    wire [9:0] img_y = v_cnt >> 1; 
    
    // คำนวณ Address จากภาพขนาด 320x240
    assign frame_addr = display_area ? (img_y * 320 + img_x) : 0;

    assign vga_r = active_d ? pixel_in[11:8] : 4'h0;
    assign vga_g = active_d ? pixel_in[7:4] : 4'h0;
    assign vga_b = active_d ? pixel_in[3:0] : 4'h0;
endmodule