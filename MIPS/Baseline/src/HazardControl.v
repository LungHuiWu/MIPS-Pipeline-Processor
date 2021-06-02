/***** structure hazard *****/
// def : two instructions try to wrtie same register at the same time
// solution : maintain five stage pipeline, e.g. R-type MEM is a NOP, BEQ's MEM, WB are NOPs

/*****   data hazard    *****/
// def : an instruction depends on completion of data access by a previous instruction 
// solution : forwarding & (stall)
// case 1 : add x1, x2, x3
//          sub x4, x1, x5
//          <ForwardUnit>
//          => ID/EX.Rs1(Rs2) = EX/MEM.Rd
//          => ID/EX.Rs1(Rs2) = MEM/WB.Rd
//          => but only if EX/MEM.Regwrite or MEM/WB.Regwrite == true (e.g. R-type)
//          => but only if EX/MEM.Rd or MEM/WB.Rd != 0 (e.g. x0)
//          => double data hazard : both hazards occur, we use EX/MEM
// case 2 : load-use hazard (needs forwarding & stall once)
//          ld x1, 0(x2)
//          sub x4, x1, x5
//          <HazardControl>
//          => IF/ID.Rs1(Rs2) = ID/EX.Rd
//          => but only if ID/EX.MemRead == true
//          => if detected, stall and insert bubble
//          => use case 1 module ForwardUnit to forward

/*****  branch hazard   *****/
// def : fetching next instruction depends on branch outcome
// solution : stall on branch until outcome determined


// data forwarding unit
// pipeline stall unit (insert bubble?)

module HazardControl (
    // input
    IdExRd,
    IfIdRs1,
    IfIdRs2,
    IdEx_MemRead,
    // output
    Ctrl_Flush,
    Pc_Write,
    IfId_Write
);
    /* Inputs/Outputs Part */
    input [4:0] IdExRd;
    input [4:0] IfIdRs1, IfIdRs2;
    input       IdEx_MemRead;
    output reg  Ctrl_Flush, Pc_Write, IfId_Write;

    /* Combinational Part */
    always @(*) begin
        if (IdEx_MemRead && (IdExRd == IfIdRs1 || IdExRd == IfIdRs2)) begin
            Ctrl_Flush = 1;
            Pc_Write   = 1;
            IfId_Write = 1;
        end
        else begin
            Ctrl_Flush = 0;
            Pc_Write   = 0;
            IfId_Write = 0;
        end
    end

endmodule

module ForwardUnit (
    // input
    ExMemRd, 
    MemWbRd,
    IdExRs1,
    IdExRs2,
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
    input  [4:0]  IdExRs1, IdExRs2;
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
        if (ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IdExRs1) ForwardA = 2'b10;
        else begin
            if (MemWb_RegWrite && MemWbRd != 5'd0 && MemWbRd == IdExRs1) ForwardA = 2'b01;
            else ForwardA = 2'b00;        
        end
        if (ExMem_RegWrite && ExMemRd != 5'd0 && ExMemRd == IdExRs2) ForwardB = 2'b10;
        else begin
            if (MemWb_RegWrite && MemWbRd != 5'd0 && MemWbRd == IdExRs2) ForwardB = 2'b01;
            else ForwardB = 2'b00;        
        end
    end

endmodule

module StallUnit (

);
    /* Inputs/Outputs Part */
    /* Parameters Part */
    /* Wires/Regs Part */
    /* Assignment Part */
    /* Combinational Part */
    /* Sequential Part */

endmodule
