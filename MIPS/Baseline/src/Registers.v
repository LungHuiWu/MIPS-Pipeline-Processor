module Registers(
        clk, 
        rst_n,
        RegWrite,
        Read_register_1,
        Read_register_2,
        Write_register,
        Write_data,
        Read_data_1,
        Read_data_2,
    );

    input clk, rst_n, RegWrite;
    input [4:0] Read_register_1, Read_register_2, Write_register;
    input [31:0] Write_data;
    output [31:0] Read_data_1, Read_data_2;

    reg [31:0] register_w [31:0], register_r [31:0];
    integer i;

    assign Read_data_1 = register_r[Read_register_1];
    assign Read_data_2 = register_r[Read_register_2];

    always@(*) begin

        register_w[0] = 32'b0;
        for (i = 1; i < 32; i=i+1)
            register_w[i] = register_r[i];

        if (RegWrite) begin
            register_w[Write_register] = Write_data;
        end
        else begin
            register_w[Write_register] = register_r[Write_register];
        end

    end

    always@(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i=i+1)
                register_r[i] <= 8'b0000_0000;
        end
        else begin
            register_r[0] <= 8'b0000_0000;
            for (i = 1; i < 32; i=i+1)
                register_r[i] <= register_w[i];
        end
    end	
    
endmodule