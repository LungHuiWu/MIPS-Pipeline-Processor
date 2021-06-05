/* UNFINISH */


/***** Dynamic Branch Prediction *****/
// experiment : 1-bit predictor, 2-bit predictor
// p.s. module place in IF cycle

// Dynamic prediction 的 branch history table，以 branch instruction 的 address (取最後 n 個 bit) 做索引，並儲存 branch 的結果。如果猜錯的話就做之前一樣的 flush 並修改表。
// 跳出 loop 時會猜繼續，第一次進入 loop 會猜跳出 -> 導致錯誤率大幅提高
// -> 2bit 的 predictor, 連續兩個 taken/not taken 才會改變狀態

// 但就算猜對，還是要算出 target address，所以在 branch taken 時會有一個 cycle 的 penalty。解決的方法是新增 buffer 存放 branch target address。

/* Use one LSB of the PC address as two states */
module BranchPredict_1b (  


// If the prediction is wrong, flush the pipeline and also flip prediction
// the best option is to use only some of the least significant bits of the PC address.


    // input
    clk,
    rst_n,
    lastTaken,
    // output
    predictTaken,
);
    /* Inputs/Outputs Part */
    /* Parameters Part */
    localparam PredTaken    = 1'b0; // taken => jump
    localparam PredNotTaken = 1'b1; // not taken => don't jump

    /* Wires/Regs Part */
    reg state_r, state_w;
    /* Assignment Part */
    /* Combinational Part */
    /* Sequential Part */

endmodule

/* Use two LSBs of the PC address as four states */
module BranchPredict_2b (


// Two bits are maintained in the prediction buffer and there are four different states.
// especially useful when multiple branches share the same counter

);

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