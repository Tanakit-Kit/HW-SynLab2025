module sccb_config(
    input clk,           
    output sioc,        
    inout siod           
);
    // ---------------------------------------------------------
    // 1. Clock Divider: สร้าง Clock ช้าๆ สำหรับ I2C (~100 kHz)
    // ---------------------------------------------------------
    reg [7:0] clk_div = 0;
    reg i2c_clk = 0;
    always @(posedge clk) begin
        if (clk_div == 124) begin // 25MHz / (125 * 2) = 100 kHz
            clk_div <= 0;
            i2c_clk <= ~i2c_clk;
        end else begin
            clk_div <= clk_div + 1;
        end
    end

    // ---------------------------------------------------------
    // 2. Register ROM: ตารางเก็บค่าตั้งค่ากล้อง
    // ---------------------------------------------------------
    reg [7:0] reg_idx = 0;      // ตัวนับว่าส่งไปกี่คำสั่งแล้ว
    reg [15:0] reg_data;        // [15:8] = Register Address, [7:0] = Data
    wire [7:0] TOTAL_REGS = 5;  // จำนวนคำสั่งทั้งหมด

    always @(reg_idx) begin
        case(reg_idx)
            // โครงสร้าง: 16'h[Reg_Addr][Data]
            0: reg_data = 16'h1280; // COM7 (0x12) : 0x80 = RESET กล้องทั้งหมด
            1: reg_data = 16'h1204; // COM7 (0x12) : 0x04 = ตั้งเป็นโหมด RGB, ขนาด VGA (640x480)
            2: reg_data = 16'h8C00; // RGB444 (0x8C): 0x00 = ปิดโหมด RGB444
            3: reg_data = 16'h40D0; // COM15 (0x40): 0xD0 = RGB565 เต็มสเกล
            4: reg_data = 16'h3A04; // TSLB (0x3A) : 0x04 = เรียงลำดับสี
            default: reg_data = 16'hFFFF; // ค่าสิ้นสุด
        endcase
    end

    // ---------------------------------------------------------
    // 3. I2C/SCCB State Machine (ตัวส่งสัญญาณ)
    // ---------------------------------------------------------
    reg [3:0] state = 0;
    reg [5:0] bit_cnt = 0;
    reg [23:0] shift_reg = 0;   // เก็บ {Device ID, Reg Addr, Data}
    reg sioc_reg = 1;
    reg siod_reg = 1;
    reg siod_out_en = 1;        // 1 = FPGA ส่ง, 0 = FPGA รอรับ ACK
    
    wire [7:0] DEV_ADDR = 8'h42; // Device ID ของ OV7670 สำหรับการ "เขียน"

    assign sioc = sioc_reg;
    assign siod = (siod_out_en) ? siod_reg : 1'bz;

    always @(posedge i2c_clk) begin
        case (state)
            0: begin // IDLE: รอเตรียมส่งข้อมูล
                if (reg_idx < TOTAL_REGS) begin
                    shift_reg <= {DEV_ADDR, reg_data[15:8], reg_data[7:0]};
                    siod_out_en <= 1;
                    sioc_reg <= 1;
                    siod_reg <= 1;
                    state <= 1;
                end
            end
            1: begin // START Condition
                siod_reg <= 0;
                bit_cnt <= 23;
                state <= 2;
            end
            2: begin // SEND BITS
                sioc_reg <= 0;
                siod_reg <= shift_reg[bit_cnt];
                state <= 3;
            end
            3: begin // PULL CLOCK HIGH
                sioc_reg <= 1;
                if (bit_cnt == 16 || bit_cnt == 8 || bit_cnt == 0) begin
                    state <= 4;
                end else begin
                    bit_cnt <= bit_cnt - 1;
                    state <= 2;
                end
            end
            4: begin // WAIT ACK
                sioc_reg <= 0;
                siod_out_en <= 0; // ปล่อยสายเป็น High-Z
                state <= 5;
            end
            5: begin // READ ACK
                sioc_reg <= 1;
                state <= 6;
            end
            6: begin // NEXT BYTE or STOP
                sioc_reg <= 0;
                siod_out_en <= 1; // กลับมาคุมสาย Data อีกครั้ง
                if (bit_cnt == 0) begin
                    state <= 7;
                    siod_reg <= 0;
                end else begin
                    bit_cnt <= bit_cnt - 1;
                    state <= 2;
                end
            end
            7: begin // STOP Condition
                sioc_reg <= 1;
                state <= 8;
            end
            8: begin // จบการส่ง 1 คำสั่ง
                siod_reg <= 1;
                reg_idx <= reg_idx + 1; // เลื่อนไปอ่านคำสั่งบรรทัดถัดไป
                state <= 0;
            end
        endcase
    end
endmodule