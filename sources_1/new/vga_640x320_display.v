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
    wire [9:0] next_h_cnt = (h_cnt == 799) ? 0 : h_cnt + 1;
    wire [9:0] next_v_cnt = (h_cnt == 799) ? ((v_cnt == 524) ? 0 : v_cnt + 1) : v_cnt;
    wire next_display_area = (next_h_cnt < 640 && next_v_cnt < 480);
    
    // [FIXED] ใช้เทคนิคการอ่านล่วงหน้า (Read-Ahead) 1 Clock Cycle
    // เพื่อชดเชยความหน่วงของ Block RAM (ใช้ next_h_cnt, next_v_cnt)
    // [FIXED] เพิ่มการตัดขอบดำ (Crop) เป็น 16 พิกเซล
    // มีภาพจริง 304 พิกเซลใน RAM (ข้าม 16 พิกเซลแรก)
    // สมการยืดภาพ 304 -> 640: (next_h_cnt * 304) / 640 = next_h_cnt * 0.475
    // ประมาณค่าคณิตศาสตร์: (next_h_cnt * 486) / 1024
    wire [19:0] scaled_x = (next_h_cnt * 486) >> 10;
    wire [9:0] img_x = scaled_x + 16; // เริ่มอ่านที่ Index 16
    wire [9:0] img_y = next_v_cnt >> 1; 
    
    // คำนวณ Address ล่วงหน้า 1 Clock
    assign frame_addr = next_display_area ? (img_y * 320 + img_x) : 0;

    // ส่งสัญญาณ active และสีออกไปตรงๆ ไม่ต้อง delay เพราะเราดึงข้อมูลมารอแล้ว
    assign active = display_area;
    assign vga_r = display_area ? pixel_in[11:8] : 4'h0;
    assign vga_g = display_area ? pixel_in[7:4] : 4'h0;
    assign vga_b = display_area ? pixel_in[3:0] : 4'h0;
endmodule