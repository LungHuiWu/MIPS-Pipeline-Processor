module cache(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);
    
//==== input/output definition ============================
    input          clk;
    // processor interface
    input          proc_reset;                  // synchronous reset
    input          proc_read, proc_write;       // synchronous read/write enable for processor
    input   [29:0] proc_addr;                   // 28 bit address + 2 bit offset
    input   [31:0] proc_wdata;                  // write data from processor
    output         proc_stall;                  // stall signal for 1. read miss on write-through/write-back cache 2. write hit on write-through
    output  [31:0] proc_rdata;                  // read data to processor
    // memory interface
    input  [127:0] mem_rdata;                   // read 4-word data from memory
    input          mem_ready;                   // asynchronous active-high one-cycle signal that indicates data arrives from memory/data is done written to memory
    output         mem_read, mem_write;         // synchronous read/write enable for memory
    output  [27:0] mem_addr;                    // address
    output [127:0] mem_wdata;                   // write 4-word data to memory

//==== parameters =========================================

    parameter WORDLEN = 32;
    parameter BLOCKNUM = 8;
    parameter TAGLEN = 25;

    parameter IDLE = 2'd0;
    parameter COMPARE = 2'd1;
    parameter ALLOCATE = 2'd2;
    parameter WRITEBACK = 2'd3;

//==== wire/reg definition ================================
    
    // internal FF
    reg     [WORDLEN*4-1:0] cch     [0:BLOCKNUM-1];
    reg     [WORDLEN*4-1:0] cch_nxt [0:BLOCKNUM-1];
    reg     [1:0]           state, state_nxt;
    reg     [TAGLEN-1:0]    tag     [0:BLOCKNUM-1];
    reg     [TAGLEN-1:0]    tag_nxt [0:BLOCKNUM-1];
    reg     valid       [0:BLOCKNUM-1];
    reg     valid_nxt   [0:BLOCKNUM-1];
    reg     dirty       [0:BLOCKNUM-1];
    reg     dirty_nxt   [0:BLOCKNUM-1];

    // output FF
    reg     proc_stall, proc_stall_nxt;
    reg     [31:0]  proc_rdata, proc_rdata_nxt;
    reg     mem_read, mem_read_nxt;
    reg     mem_write, mem_write_nxt;
    reg     [27:0]  mem_addr, mem_addr_nxt;
    reg     [127:0] mem_wdata, mem_wdata_nxt;

    wire    [2:0]   block_now;
    wire    [24:0]  tag_now;
    wire    [1:0]   word_idx;

    integer i;

//==== combinational circuit ==============================

assign block_now = proc_addr[4:2];
assign tag_now = proc_addr[29:5];
assign word_idx = proc_addr[1:0];

always @(*) begin // FSM
    state_nxt = state;
    case (state)
        IDLE: begin
            if (proc_read || proc_write) begin
                state_nxt = COMPARE;
                proc_stall_nxt = 1;
            end
            else begin
                state_nxt = IDLE;
                proc_stall_nxt = 0;
            end
        end 
        COMPARE: begin
            if (valid[block_now]==1) begin
                if (tag[block_now] == tag_now) begin
                    proc_stall_nxt = 0;
                    state_nxt = IDLE;
                end
                else if (dirty[block_now] == 0) begin
                    proc_stall_nxt = 1;
                    state_nxt = ALLOCATE;
                end
                else begin
                    proc_stall_nxt = 1;
                    state_nxt = WRITEBACK;
                end
            end
            else begin
                proc_stall_nxt = 1;
                state_nxt = ALLOCATE;
            end
        end
        ALLOCATE: begin
            proc_stall_nxt = 1;
            if (mem_ready) begin
                state_nxt = COMPARE;
            end
            else begin
                state_nxt = ALLOCATE;
            end
        end
        WRITEBACK: begin
            proc_stall_nxt = 1;
            if (mem_ready) begin
                state_nxt = ALLOCATE;
            end
            else begin
                state_nxt = WRITEBACK;
            end
        end
        default: begin
            proc_stall_nxt = 0;
            state_nxt = IDLE;
        end
    endcase
end

always @(*) begin
    // initial value
    for(i=0;i<BLOCKNUM;i=i+1) begin
        cch_nxt[i] = cch[i];
        valid_nxt[i] = valid[i];
        tag_nxt[i] = tag[i];
        dirty_nxt[i] = dirty[i];
    end
    proc_rdata_nxt = 0;
    mem_read_nxt = 0;
    mem_write_nxt = 0;
    mem_addr_nxt = 0;
    mem_wdata_nxt = 0;

    case (state)
        IDLE: begin
            tag_nxt[block_now] = tag[block_now];
            dirty_nxt[block_now] = dirty[block_now];
            valid_nxt[block_now] = valid[block_now];
        end
        COMPARE: begin
            if (valid[block_now]==1 && tag[block_now] == tag_now) begin
                if (proc_read && ~proc_write) begin
                    case (word_idx)
                        0: proc_rdata_nxt = cch[block_now][31:0];
                        1: proc_rdata_nxt = cch[block_now][63:32];
                        2: proc_rdata_nxt = cch[block_now][95:64];
                        3: proc_rdata_nxt = cch[block_now][127:96];
                        default: proc_rdata_nxt = 0;
                    endcase
                end
                else if (proc_write && ~proc_read) begin
                    case (word_idx)
                        0: cch_nxt[block_now][31:0] = proc_wdata;
                        1: cch_nxt[block_now][63:32] = proc_wdata;
                        2: cch_nxt[block_now][95:64] = proc_wdata;
                        3: cch_nxt[block_now][127:96] = proc_wdata;
                        default: cch_nxt[block_now] = cch[block_now];
                    endcase
                    valid_nxt[block_now] = valid[block_now];
                    tag_nxt[block_now] = tag_now;
                    dirty_nxt[block_now] = 1;
                end
            end
        end
        ALLOCATE: begin
            if (~mem_ready) begin
                mem_read_nxt = 1;
                mem_write_nxt = 0;
                mem_wdata_nxt = 0;
                mem_addr_nxt = proc_addr[29:2];
            end
            else begin
                tag_nxt[block_now] = tag_now;
                valid_nxt[block_now] = 1;
                dirty_nxt[block_now] = 0;
                cch_nxt[block_now] = mem_rdata;
            end
        end
        WRITEBACK: begin
            if (~mem_ready) begin 
                mem_write_nxt = 1;
                mem_wdata_nxt = cch[block_now];
                mem_addr_nxt = {tag[block_now],block_now};
            end
        end
        default: begin
            tag_nxt[block_now] = tag[block_now];
            valid_nxt[block_now] = valid[block_now];
            dirty_nxt[block_now] = dirty[block_now];
        end
    endcase
end

//==== sequential circuit =================================
always@( posedge clk ) begin
    if( proc_reset ) begin
        state   <= IDLE;
        for (i = 0; i<BLOCKNUM; i=i+1) begin
            cch[i]      <= 0;
            tag[i]      <= 0;
            valid[i]    <= 0;
            dirty[i]    <= 0;
        end
        proc_stall      <= 0;
        proc_rdata      <= 0;
        mem_read        <= 0;
        mem_write       <= 0;
        mem_addr        <= 0;
        mem_wdata       <= 0;
    end
    else begin
        state   <= state_nxt;
        for (i = 0; i<BLOCKNUM; i=i+1) begin
            cch[i]      <= cch_nxt[i];
            tag[i]      <= tag_nxt[i];
            valid[i]    <= valid_nxt[i];
            dirty[i]    <= dirty_nxt[i];
        end
        proc_rdata      <= proc_rdata_nxt;
        mem_read        <= mem_read_nxt;
        mem_write       <= mem_write_nxt;
        mem_addr        <= mem_addr_nxt;
        mem_wdata       <= mem_wdata_nxt;
        proc_stall      <= proc_stall_nxt;
    end
end

endmodule
