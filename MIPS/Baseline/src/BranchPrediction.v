/* FINISH PART */
// 1-bit Branch Predictor
// 2-bit Branch Predictor

/***** Dynamic Branch Prediction *****/
// experiment : 1-bit predictor, 2-bit predictor
// p.s. module place in IF cycle

module BranchPredict_1b (  
    // input
    clk,
    rst_n,
    stall,
    If_Opcode, // Beq, Bne in IF
    predWrong, // previous prediction is wrong
    // output
    predTaken
);
    /* Inputs/Outputs Part */
    input        clk, rst_n;
    input        stall;
    input  [5:0] If_Opcode;
    input        predWrong;
    output       predTaken;

    /* Parameters Part */
    localparam S_NT = 1'b0; // not taken => don't jump
    localparam S_T  = 1'b1; // taken => jump
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;

    /* Wires/Regs Part */
    reg state_r, state_w;

    /* Assignment Part */
    assign predTaken = state_r;

    /* Combinational Part */
    always @(*) begin
        if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
            if (predWrong) begin
                state_w = ~state_r;
            end
            else begin
                state_w = state_r;
            end
        end
        else begin
            state_w = state_r;
        end
    end

    /* Sequential Part */
    always @(posedge clk) begin
        if (!rst_n) begin
            state_r <= S_NT;
        end
        else begin
            state_r <= state_w;
        end
    end

endmodule

module BranchPredict_2b (
    // input
    clk,
    rst_n,
    stall,
    If_Opcode, // Beq, Bne in IF
    predWrong,
    // output
    predTaken
);
     /* Inputs/Outputs Part */
    input        clk, rst_n;
    input        stall;
    input  [5:0] If_Opcode;
    input        predWrong;
    output       predTaken;

    /* Parameters Part */
    localparam S_SNT = 2'd0; // strong not taken
    localparam S_WNT = 2'd1; // weak not taken
    localparam S_ST  = 2'd2; // strong taken
    localparam S_WT  = 2'd3; // weak taken
    localparam BEQ = 6'b000100; // opcode
    localparam BNE = 6'b000101;

    /* Wires/Regs Part */
    reg [1:0] state_r, state_w;

    /* Assignment Part */
    assign predTaken = state_r[1];

    /* Combinational Part */
    always @(*) begin
        if ((If_Opcode == BEQ || If_Opcode == BNE) && !stall) begin
            case(state_r)
                S_SNT: begin
                    if (predWrong) begin
                        state_w = S_WNT;
                    end
                    else begin
                        state_w = S_SNT;
                    end
                end
                S_WNT: begin
                    if (predWrong) begin
                        state_w = S_ST;
                    end
                    else begin
                        state_w = S_SNT;
                    end
                end
                S_ST: begin
                    if (predWrong) begin
                        state_w = S_WT;
                    end
                    else begin
                        state_w = S_ST;
                    end
                end
                S_WT: begin
                    if (predWrong) begin
                        state_w = S_SNT;
                    end
                    else begin
                        state_w = S_ST;
                    end
                end
                default: begin
                    state_w = state_r;
                end
            endcase
        end
        else begin
            state_w = state_r;
        end
    end

    /* Sequential Part */
    always @(posedge clk) begin
        if (!rst_n) begin
            state_r <= S_SNT;
        end
        else begin
            state_r <= state_w;
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