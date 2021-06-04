/* see HazardControl.v for functional details */
module ForwardUnit (
    // input
    ExMemRd, 
    MemWbRd,
    IdExRs,
    IdExRt,
    ExMem_RegWrite,
    MemWb_RegWrite,
    ExMem_data,
    MemWb_data,
    IdEx_data1,
    IdEx_data2,
    // output
    Alu_data1,
    Alu_data2
);
    /* Inputs/Outputs Part */
    input  [4:0]  ExMemRd, MemWbRd;
    input  [4:0]  IdExRs, IdExRt;
    input         ExMem_RegWrite, MemWb_RegWrite; 
    input  [32:0] ExMem_data, MemWb_data;
    input  [32:0] IdEx_data1, IdEx_data2; 
    output [32:0] Alu_data1, Alu_data2; 

    /* Wires/Regs Part */
    reg [1:0] ForwardA; // Alu_data mux control, 00 from ID/EX, 10 from EX/MEM, 01 from MEM/WB
    reg [1:0] ForwardB; 

    /* Assignment Part */
    assign Alu_data1 = (ForwardA == 2'b00) ? IdEx_data1 : (ForwardA == 2'b10) ? ExMem_data : MemWb_data;
    assign Alu_data2 = (ForwardB == 2'b00) ? IdEx_data2 : (ForwardB == 2'b10) ? ExMem_data : MemWb_data;

    /* Combinational Part */
    always @(*) begin
        if (ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IdExRs) ForwardA = 2'b10;
        else begin
            if (MemWb_RegWrite && MemWbRd != 5'd0 && MemWbRd == IdExRs) ForwardA = 2'b01;
            else ForwardA = 2'b00;        
        end
        if (ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IdExRt) ForwardB = 2'b10;
        else begin
            if (MemWb_RegWrite && MemWbRd != 5'd0 && MemWbRd == IdExRt) ForwardB = 2'b01;
            else ForwardB = 2'b00;        
        end
    end

endmodule

module ForwardBranchUnit (
    // input
    ExMemRd, 
    IfIdRs,
    IfIdRt,
    ExMem_RegWrite,
    IfId_Opcode,
    IfId_Funct4b,
    ExMem_data,
    Reg_data1,
    Reg_data2,
    // output
    Branch_data1,
    Branch_data2
);
    /* Inputs/Outputs Part */
    input  [4:0]  ExMemRd;
    input  [4:0]  IfIdRs, IfIdRt;
    input         ExMem_RegWrite; 
    input  [5:0]  IfId_Opcode;
    input  [3:0]  IfId_Funct4b;
    input  [32:0] ExMem_data;
    input  [32:0] Reg_data1, Reg_data2; 
    output [32:0] Branch_data1, Branch_data2; 

    /* Parameters Part */
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;

    localparam R_type = 6'b000000; // opcode
    localparam JR     = 4'b1000; // funct4b
    localparam JALR   = 4'b1001;

    /* Wires/Regs Part */
    wire IfId_isBranchUseType;
    reg ForwardA; // Branch_data mux control, 0 from register, 1 from EX/MEM
    reg ForwardB; 

    /* Assignment Part */
    assign IfId_isBranchUseType = (IfId_Opcode == BEQ) || (IfId_Opcode == BNE) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR));
    assign Branch_data1 = (ForwardA) ? ExMem_data : Reg_data1;
    assign Branch_data2 = (ForwardB) ? ExMem_data : Reg_data2;

    /* Combinational Part */
    always @(*) begin
        if (IfId_isBranchUseType && ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IfIdRs) ForwardA = 1'b1;
        else ForwardA = 1'b0;
        if (IfId_isBranchUseType && ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IfIdRt) ForwardB = 1'b1;
        else ForwardB = 1'b0;
    end

endmodule
