`timescale 1ns / 1ps

module frame_buffer_640x320 (
    input clk_w,
    input we,
    input [16:0] addr_w,
    input [11:0] din,
    input clk_r,
    input [16:0] addr_r,
    output reg [11:0] dout = 12'h000 // [แก้ตรงนี้] เติม = 12'h000 เพื่อตั้งค่าเริ่มต้นให้ register
);

    // 1. ประกาศหน่วยความจำ (204,800 ช่อง สำหรับ 640x320)
    reg [11:0] mem [0:204799];

    // ---------------------------------------------------------
    // 2. ล้างค่า X ให้เป็น 0 ในหน่วยความจำ
    // ---------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < 204800; i = i + 1) begin
            mem[i] = 12'h000; 
        end
    end
    // ---------------------------------------------------------

    // 3. ส่วนการเขียน (Write Port)
    always @(posedge clk_w) begin
        if (we) begin
            mem[addr_w] <= din;
        end
    end

    // 4. ส่วนการอ่าน (Read Port)
    always @(posedge clk_r) begin
        dout <= mem[addr_r];
    end

endmodule