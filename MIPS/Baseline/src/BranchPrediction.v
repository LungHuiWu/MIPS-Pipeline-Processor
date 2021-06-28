/* FINISH PART */
// 1-bit Branch Predictor
// 2-bit Branch Predictor

/***** Dynamic Branch Prediction *****/
// experiment : 1-bit predictor, 2-bit predictor
// p.s. module place in IF cycle

/** local branch predictor **/
module BranchPredict_1b (  
    // input
    clk,
    rst_n,
    stall,
    If_Opcode, // Beq, Bne in IF
    PC,
    S1_PC4,
    predWrong, // previous prediction is wrong
    // output
    predTaken
);
    /* Inputs/Outputs Part */
    input        clk, rst_n;
    input        stall;
    input [5:0]  If_Opcode;
    input [31:0] PC;
    input [31:0] S1_PC4;
    input        predWrong;
    output       predTaken;

    /* Parameters Part */
    localparam TABLESIZE = 128;
    localparam INDEXBITS = 7;
    localparam S_NT = 1'b0; // not taken => don't jump
    localparam S_T  = 1'b1; // taken => jump
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;

    /* Wires/Regs Part */
    reg table_r [0:TABLESIZE - 1]; // assume big enough for all instruction's PC
    reg table_w [0:TABLESIZE - 1];

    /* Assignment Part */
    assign predTaken = table_r[PC[INDEXBITS + 1:2]];

    /* Combinational Part */
    integer i;
    always @(*) begin
        for(i = 0;i < TABLESIZE;i = i + 1)
            table_w[i] = table_r[i];
        if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
            if (predWrong) begin
                table_w[S1_PC4[INDEXBITS + 1:2]] = ~table_r[S1_PC4[INDEXBITS + 1:2]];
            end
            else begin
                table_w[S1_PC4[INDEXBITS + 1:2]] =  table_r[S1_PC4[INDEXBITS + 1:2]];
            end
        end
    end

    /* Sequential Part */
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0;i < TABLESIZE;i = i + 1) begin
                table_r[i] <= S_NT;
            end
        end
        else begin
            for (i = 0;i < TABLESIZE;i = i + 1) begin
                table_r[i] <= table_w[i];
            end
        end
    end

endmodule
/** global branch predictor **/
// module BranchPredict_1b (  
//     // input
//     clk,
//     rst_n,
//     stall,
//     If_Opcode, // Beq, Bne in IF
//     predWrong, // previous prediction is wrong
//     // output
//     predTaken
// );
//     /* Inputs/Outputs Part */
//     input        clk, rst_n;
//     input        stall;
//     input  [5:0] If_Opcode;
//     input        predWrong;
//     output       predTaken;

//     /* Parameters Part */
//     localparam S_NT = 1'b0; // not taken => don't jump
//     localparam S_T  = 1'b1; // taken => jump
//     localparam BEQ = 6'b000100; // opcode
//     localparam BNE = 6'b000101;

//     /* Wires/Regs Part */
//     reg state_r, state_w;

//     /* Assignment Part */
//     assign predTaken = state_r;

//     /* Combinational Part */
//     always @(*) begin
//         if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
//             if (predWrong) begin
//                 state_w = ~state_r;
//             end
//             else begin
//                 state_w = state_r;
//             end
//         end
//         else begin
//             state_w = state_r;
//         end
//     end

//     /* Sequential Part */
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             state_r <= S_NT;
//         end
//         else begin
//             state_r <= state_w;
//         end
//     end

// endmodule
/** local branch predictor **/
module BranchPredict_2b (
    // input
    clk,
    rst_n,
    stall,
    If_Opcode, // Beq, Bne in IF
    PC,
    S1_PC4,
    predWrong,
    // output
    predTaken
);
    /* Inputs/Outputs Part */
    input        clk, rst_n;
    input        stall;
    input [5:0]  If_Opcode;
    input [31:0] PC;
    input [31:0] S1_PC4;
    input        predWrong;
    output       predTaken;

    /* Parameters Part */
    localparam TABLESIZE = 128;
    localparam INDEXBITS = 7;
    localparam S_SNT     = 2'b00; // strong not taken
    localparam S_WNT     = 2'b01; // weak not taken
    localparam S_ST      = 2'b10; // strong taken
    localparam S_WT      = 2'b11; // weak taken
    localparam BEQ       = 6'b000100; // opcode
    localparam BNE       = 6'b000101;

    /* Wires/Regs Part */
    reg  [1:0] table_r [0:TABLESIZE - 1]; // assume big enough for all instruction's PC
    reg  [1:0] table_w [0:TABLESIZE - 1];

    /* Assignment Part */
    assign predTaken = table_r[PC[INDEXBITS + 1:2]][1];
    assign A = (If_Opcode == BEQ || If_Opcode == BNE) && !stall;

    /* Combinational Part */
    integer i;
    always @(*) begin
        for(i = 0;i < TABLESIZE;i = i + 1)
            table_w[i] = table_r[i];
        if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
            if (predWrong) begin
                table_w[S1_PC4[INDEXBITS + 1:2]] = table_r[S1_PC4[INDEXBITS + 1:2]] + 2'b01; // update state simply by + 1
            end
            else begin
                if (!table_r[S1_PC4[INDEXBITS + 1:2]][0]) begin // state is strong
                    table_w[S1_PC4[INDEXBITS + 1:2]] = table_r[S1_PC4[INDEXBITS + 1:2]];
                end
                else begin // state is weak
                    table_w[S1_PC4[INDEXBITS + 1:2]] = table_r[S1_PC4[INDEXBITS + 1:2]] - 2'b01;
                end
            end
        end
    end

    /* Sequential Part */
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0;i < TABLESIZE;i = i + 1) begin
                table_r[i] <= S_SNT;
            end
        end
        else begin
            for (i = 0;i < TABLESIZE;i = i + 1) begin
                table_r[i] <= table_w[i];
            end
        end
    end

endmodule
/** global branch predictor **/
// module BranchPredict_2b (
//     // input
//     clk,
//     rst_n,
//     stall,
//     If_Opcode, // Beq, Bne in IF
//     predWrong,
//     // output
//     predTaken
// );
//     /* Inputs/Outputs Part */
//     input        clk, rst_n;
//     input        stall;
//     input  [5:0] If_Opcode;
//     input        predWrong;
//     output       predTaken;

//     /* Parameters Part */
//     localparam S_SNT = 2'd0; // strong not taken
//     localparam S_WNT = 2'd1; // weak not taken
//     localparam S_ST  = 2'd2; // strong taken
//     localparam S_WT  = 2'd3; // weak taken
//     localparam BEQ = 6'b000100; // opcode
//     localparam BNE = 6'b000101;

//     /* Wires/Regs Part */
//     reg [1:0] state_r, state_w;

//     /* Assignment Part */
//     assign predTaken = state_r[1];

//     /* Combinational Part */
//     always @(*) begin
//         if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
//             case(state_r)
//                 S_SNT: begin
//                     if (predWrong) begin
//                         state_w = S_WNT;
//                     end
//                     else begin
//                         state_w = S_SNT;
//                     end
//                 end
//                 S_WNT: begin
//                     if (predWrong) begin
//                         state_w = S_ST;
//                     end
//                     else begin
//                         state_w = S_SNT;
//                     end
//                 end
//                 S_ST: begin
//                     if (predWrong) begin
//                         state_w = S_WT;
//                     end
//                     else begin
//                         state_w = S_ST;
//                     end
//                 end
//                 S_WT: begin
//                     if (predWrong) begin
//                         state_w = S_SNT;
//                     end
//                     else begin
//                         state_w = S_ST;
//                     end
//                 end
//                 default: begin
//                     state_w = state_r;
//                 end
//             endcase
//         end
//         else begin
//             state_w = state_r;
//         end
//     end
//     /* Sequential Part */
//     always @(posedge clk) begin
//         if (!rst_n) begin
//             state_r <= S_SNT;
//         end
//         else begin
//             state_r <= state_w;
//         end
//     end

// endmodule

/** global correlated branch predictor **/

module BranchPredict_Correlated (  
    // input
    clk,
    rst_n,
    stall,
    If_Opcode, // Beq, Bne in IF
    PC,
    S1_PC4,
    predWrong,
    realTaken, // update global state
    // output
    predTaken
);
    /* Inputs/Outputs Part */
    input         clk, rst_n;
    input         stall;
    input  [5:0]  If_Opcode;
    input  [31:0] PC;
    input  [31:0] S1_PC4;
    input         predWrong;
    input         realTaken;
    output        predTaken;

    /* Parameters Part */
    localparam M     = 2; // (M, N)-predictor
    localparam BPNUM = 4; // M^2

    /* Wires/Regs Part */
    wire           BPtaken [0:BPNUM - 1]; // predTaken of sub BP
    reg  [M - 1:0] glob_state_r, glob_state_w; // global state

    /* Assignment Part */
    assign predTaken = BPtaken[glob_state_r];
    localparam BEQ       = 6'b000100; // opcode
    localparam BNE       = 6'b000101;
    
    /* Module Part */
    BranchPredict_2b BP2_0(
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall || glob_state_r != 2'b00),
        .If_Opcode(If_Opcode),
        .PC(PC),
        .S1_PC4(S1_PC4),
        .predWrong(predWrong),
        // output
        .predTaken(BPtaken[0])
    );
    BranchPredict_2b BP2_1(
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall || glob_state_r != 2'b01),
        .If_Opcode(If_Opcode),
        .PC(PC),
        .S1_PC4(S1_PC4),
        .predWrong(predWrong),
        // output
        .predTaken(BPtaken[1])
    );
    BranchPredict_2b BP2_2(
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall || glob_state_r != 2'b10),
        .If_Opcode(If_Opcode),
        .PC(PC),
        .S1_PC4(S1_PC4),
        .predWrong(predWrong),
        // output
        .predTaken(BPtaken[2])
    );
    BranchPredict_2b BP2_3(
        .clk(clk),
        .rst_n(rst_n),
        .stall(stall || glob_state_r != 2'b11),
        .If_Opcode(If_Opcode),
        .PC(PC),
        .S1_PC4(S1_PC4),
        .predWrong(predWrong),
        // output
        .predTaken(BPtaken[3])
    );

    /* Combinational Part */
    always @(*) begin
        if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
            glob_state_w = {glob_state_r[0], realTaken}; // shift register
        end
        else begin
            glob_state_w = glob_state_r;
        end
    end

    /* Sequential Part */
    always @(posedge clk) begin
        if (!rst_n) begin
            glob_state_r <= 0;
        end
        else begin
            glob_state_r <= glob_state_w;
        end
    end

endmodule

module PredictionCheck ( // place in ID stage to check whether previous branch prediction is wrong.
    // input
    IfId_PredTaken,
    IfId_Equal,
    IfId_Opcode, // Beq, Bne in ID
    // output
    Wrong
);
    /* Inputs/Outputs Part */
    input       IfId_PredTaken;
    input       IfId_Equal;
    input [5:0] IfId_Opcode;
    output reg  Wrong;

    /* Parameters Part */
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;

    /* Combinational Part */
    always @(*) begin
        if ((IfId_Opcode == BEQ && (IfId_Equal ^ IfId_PredTaken)) ||      // 1. BEQ result : Taken, pred : Not Taken 
            (IfId_Opcode == BNE && (IfId_Equal ~^ IfId_PredTaken))) begin // 2. BEQ result : Not Taken, pred : Taken
            Wrong = 1'b1;                                               // 3. BNE result : Taken, pred : Not Taken
        end                                                               // 4. BNE result : Not Taken, pred : Taken
        else begin
            Wrong = 1'b0;
        end
    end

endmodule


// more we can implement and do experiment : 
// 1. 1-bit Branch-Prediction Buffer -> can test nested loops
// 2. 2-bit Branch-Prediction Buffer -> can test nested loops
// 3. Correlating Branch Prediction Buffer
// 4. Tournament Branch Predictor
// 5. Branch Target Buffer
// 6. Return Address Predictors
// 7.  Integrated Instruction Fetch Units
// ref: https://www.cs.umd.edu/~meesh/411/CA-online/chapter/dynamic-branch-prediction/index.html
// 8 Use n bits LSB of the PC address as 1. 2.'s states