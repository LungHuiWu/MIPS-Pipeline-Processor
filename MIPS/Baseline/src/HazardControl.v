/*------------------------------------ structure hazard -------------------------------------*/
/* def : two instructions try to wrtie same register at the same time                        */
/* solution : maintain five stage pipeline, e.g. R-type MEM is a NOP, BEQ's MEM, WB are NOPs */
/*-------------------------------------------------------------------------------------------*/

/*--------------------------------------------------  data hazard   ------------------------------------------------*/
/* def : an instruction depends on completion of data access by a previous instruction                              */
/* solution : forwarding & (stall)                                                                                  */
/* case 1 : add x1, x2, x3 (or jal, jalr)                                                                           */
/*          sub x4, x1, x5                                                                                          */
/*          <ForwardUnit>                                                                                           */
/*          => ID/EX.Rs(Rt) = EX/MEM.Rd                                                                             */
/*          => ID/EX.Rs(Rt) = MEM/WB.Rd                                                                             */
/*          => but only if EX/MEM.Regwrite or MEM/WB.Regwrite == true (e.g. R-type)                                 */
/*          => but only if EX/MEM.Rd or MEM/WB.Rd != 0 (e.g. x0)                                                    */
/*          => double data hazard : both hazards occur, we use EX/MEM                                               */
/*          p.s. we found that we still need register file forwading (data hazard && two insts have distance == 3)  */
/* case 2 : load-use hazard (needs to stall once & forward)                                                         */
/*          ld  x1, 0(x2)                                                                                           */
/*          sub x4, x1, x5                                                                                          */
/*          <HazardControl>                                                                                         */
/*          => IF/ID.Rs(Rt) = ID/EX.Rt                                                                              */
/*          => but only if ID/EX.MemRead == true                                                                    */
/*          => if detected, stall and insert bubble                                                                 */
/*          => use <ForwardUnit> to forward                                                                         */
/* case 3 : data hazard for branch (since 1. we move branch determination part to ID. 2. jump reg regdata is in ID) */
/*    3-a : add x3, x1, x2 (or jal, jalr)                                                                           */
/*          beq x3, x4, label (or bne, jr, jalr)                                                                    */
/*          <HazardControl>                                                                                         */
/*          => stall once & <ForwardBranchUnit> forward (see below codes for details)                               */
/*    3-b : ld x3, 0(x2)                                                                                            */
/*          beq x3, x4, label (or bne, jr, jalr)                                                                    */
/*          <HazardControl>                                                                                         */
/*          => stall twice & <ForwardBranchUnit> forward (see below codes for details)                              */
/*------------------------------------------------------------------------------------------------------------------*/

/*--------------------------------------------   branch hazard   --------------------------------------------*/
/* def : 1. next PC depends on branch outcome, which is in ID state => beq, bne                              */
/*       2. needs controller decoded value to jump, which is in ID state => jr, jalr, j, jal                 */
/* solution : assume not taken(jump), flush process if branch determined taken in ID state                   */
/*          => tips : move branch determination part & branch target address calculation part from MEM to ID */
/*          => thus, we need to flush only one cycle.                                                        */
/*          <HazardControl>                                                                                  */
/*          => if beq(bne) taken   , If_Flush = 1                                                            */
/*          => if jr, jalr, j, jal , If_Flush = 1                                                            */
/*-----------------------------------------------------------------------------------------------------------*/
module HazardControl ( // stall or flush control
    // input
    IdExRt,
    IdExRd, // right after Rd, Rt mux
    IfIdRs,
    IfIdRt,
    ExMemRd,
    IdEx_MemRead,
    IdEx_RegWrite,
    ExMem_MemRead,
    IfId_Opcode,
    IfId_Funct4b,
    IfId_Equal,
    // output
    Ctrl_Flush,
    Pc_Write,
    IfId_Write,
    If_Flush // for branch hazard
);
    /* Inputs/Outputs Part */
    input [4:0] IdExRt, IdExRd;
    input [4:0] IfIdRs, IfIdRt;
    input [4:0] ExMemRd;
    input       IdEx_MemRead, IdEx_RegWrite;
    input       ExMem_MemRead;
    input [5:0] IfId_Opcode;
    input [3:0] IfId_Funct4b;
    input       IfId_Equal;
    output reg  Ctrl_Flush, Pc_Write, IfId_Write, If_Flush;

    /* Parameters Part */
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;
    localparam J   = 6'b000010;
    localparam JAL = 6'b000011;

    localparam R_type = 6'b000000; // opcode
    localparam JR     = 4'b1000; // funct4b
    localparam JALR   = 4'b1001;

    /* Wires/Regs Part */
    wire IfId_isBranchUseType; 
    wire IfId_toBranch;

    /* Assignment Part */
    assign IfId_isBranchUseType = (IfId_Opcode == BEQ) || (IfId_Opcode == BNE) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR));
    assign IfId_toBranch = (IfId_Opcode == BEQ && IfId_Equal) || (IfId_Opcode == BNE && !IfId_Equal) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR)) || (IfId_Opcode == J) || (IfId_Opcode == JAL);

    /* Combinational Part */
    always @(*) begin
        if (IdEx_MemRead && (IdExRt == IfIdRs || IdExRt == IfIdRt)) begin // case 2 load-use hazard stall
            Ctrl_Flush = 1; // flush ID control signal                    // case 3-b first stall
            Pc_Write   = 0; // PC suspend, instruction fetch again
            IfId_Write = 0; // IF/ID suspend, instruction decode again
            If_Flush   = 0;
        end
        else if (IfId_isBranchUseType &&
                 ((IdEx_RegWrite && (IdExRd  == IfIdRs || IdExRd  == IfIdRt)) || // case 3-a stall
                  (ExMem_MemRead && (ExMemRd == IfIdRs || ExMemRd == IfIdRt)))   // case 3-b second stall
                ) begin 
            Ctrl_Flush = 1; 
            Pc_Write   = 0; 
            IfId_Write = 0; 
            If_Flush   = 0;        
        end
        else if (IfId_toBranch) begin // branch hazard flush
            Ctrl_Flush = 0;
            Pc_Write   = 1; 
            IfId_Write = 1;  
            If_Flush   = 1;   
        end
        else begin
            Ctrl_Flush = 0;
            Pc_Write   = 1;
            IfId_Write = 1;
            If_Flush   = 0;
        end
    end

endmodule

module HazardControlforBrPred ( // stall or flush control
    // input
    IdExRt,
    IdExRd, // right after Rd, Rt mux
    IfIdRs,
    IfIdRt,
    ExMemRd,
    IdEx_MemRead,
    IdEx_RegWrite,
    ExMem_MemRead,
    IfId_Opcode,
    IfId_Funct4b,
    // IfId_Equal,
    predWrong, // for branch prediction
    // output
    Ctrl_Flush,
    Pc_Write,
    IfId_Write,
    If_Flush // for branch hazard
);
    /* Inputs/Outputs Part */
    input [4:0] IdExRt, IdExRd;
    input [4:0] IfIdRs, IfIdRt;
    input [4:0] ExMemRd;
    input       IdEx_MemRead, IdEx_RegWrite;
    input       ExMem_MemRead;
    input [5:0] IfId_Opcode;
    input [3:0] IfId_Funct4b;
    // input       IfId_Equal; 
    input       predWrong;
    output reg  Ctrl_Flush, Pc_Write, IfId_Write, If_Flush;

    /* Parameters Part */
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;
    localparam J   = 6'b000010;
    localparam JAL = 6'b000011;

    localparam R_type = 6'b000000; // opcode
    localparam JR     = 4'b1000; // funct4b
    localparam JALR   = 4'b1001;

    /* Wires/Regs Part */
    wire IfId_isBranchUseType; 
    wire IfId_toBranch;

    /* Assignment Part */
    assign IfId_isBranchUseType = (IfId_Opcode == BEQ) || (IfId_Opcode == BNE) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR));
    // assign IfId_toBranch = (IfId_Opcode == BEQ && IfId_Equal) || (IfId_Opcode == BNE && !IfId_Equal) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR)) || (IfId_Opcode == J) || (IfId_Opcode == JAL); // origin
    assign IfId_toBranch = ((IfId_Opcode == BEQ || IfId_Opcode == BNE) && predWrong) || (IfId_Opcode == R_type && (IfId_Funct4b == JR || IfId_Funct4b == JALR)); // for branch prediction

    /* Combinational Part */
    always @(*) begin
        if (IdEx_MemRead && (IdExRt == IfIdRs || IdExRt == IfIdRt)) begin // case 2 load-use hazard stall
            Ctrl_Flush = 1; // flush ID control signal                    // case 3-b first stall
            Pc_Write   = 0; // PC suspend, instruction fetch again
            IfId_Write = 0; // IF/ID suspend, instruction decode again
            If_Flush   = 0;
        end
        else if (IfId_isBranchUseType &&
                 ((IdEx_RegWrite && (IdExRd  == IfIdRs || IdExRd  == IfIdRt)) || // case 3-a stall
                  (ExMem_MemRead && (ExMemRd == IfIdRs || ExMemRd == IfIdRt)))   // case 3-b second stall
                ) begin 
            Ctrl_Flush = 1; 
            Pc_Write   = 0; 
            IfId_Write = 0; 
            If_Flush   = 0;        
        end
        else if (IfId_toBranch) begin // branch hazard flush
            Ctrl_Flush = 0;
            Pc_Write   = 1; 
            IfId_Write = 1;  
            If_Flush   = 1;   
        end
        else begin
            Ctrl_Flush = 0;
            Pc_Write   = 1;
            IfId_Write = 1;
            If_Flush   = 0;
        end
    end

endmodule

// ref: branch hazard & forwarding & prediction
//      https://courses.cs.vt.edu/cs2506/Spring2009/Notes/pdf/L13.BranchPrediction.pdf
// ref: jump & branch target buffer
//      https://passlab.github.io/CSE564/notes/lecture09_RISCV_Impl_pipeline.pdf
// ref: github code for complex branc's data hazard & forwarding
//      https://github.com/MatrixPecker/VE370-Pipelined-Processor/blob/main/hazard_det.v
//      https://github.com/tjsparks5/Pipelined-MIPS-Processor/blob/master/source_files/hazardDetectionUnit.v
