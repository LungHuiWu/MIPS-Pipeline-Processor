module L1(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    stall,
    addr,
    read,
    write,
    wdata,
    rdata,
    ready
);
//==== Input/Output definition ====
    input           clk;
    // processor intrface
    input           proc_reset;
    input           proc_read, proc_write;
    input   [29:0]  proc_addr;
    input   [31:0]  proc_wdata;
    output  reg             proc_stall;
    output  reg     [31:0]  proc_rdata;
    // L2 cache interface
    input           stall;
    input           ready;
    input   [127:0] rdata;
    output  reg     [127:0] wdata;
    output  reg     read, write;
    output  reg     [29:0]  addr;

//==== Parameters ====

    parameter WORDLEN = 32;
    parameter ENTRYNUM = 8;
    parameter TAGLEN = 25;

    parameter NONE = 1'd1;
    parameter ONE = 1'd0;

    parameter IDLE = 2'd0;
    parameter WRITE_READ = 2'd1;
    parameter ALLOCATE = 2'd2;
    parameter WRITEBACK = 2'd3;
    
//==== wire/reg definition ====
    
    /// internal FF
    // state
    reg     [1:0]   state, state_nxt;
    // cache 1
    reg     [WORDLEN*4-1:0] cch1        [0:ENTRYNUM-1];
    reg     [WORDLEN*4-1:0] cch1_nxt    [0:ENTRYNUM-1];
    reg     [TAGLEN-1:0]    tag1        [0:ENTRYNUM-1];
    reg     [TAGLEN-1:0]    tag1_nxt    [0:ENTRYNUM-1];
    reg     valid1      [0:ENTRYNUM-1];
    reg     valid1_nxt  [0:ENTRYNUM-1];
    reg     dirty1      [0:ENTRYNUM-1];
    reg     dirty1_nxt  [0:ENTRYNUM-1];

    // miss & hit
    reg     [15:0]  m_cnt, m_cnt_nxt;
    reg     [15:0]  t_cnt, t_cnt_nxt;

    wire    [2:0]   block_now;
    wire    [24:0]  tag_now;
    wire    [1:0]   word_idx;
    wire    hit1;
    wire    miss1_clean;
    wire    miss1_dirty;
    wire    hit;
    wire    miss;

    integer i;

//==== combinational circuit ====

assign block_now = proc_addr[4:2];
assign tag_now = proc_addr[29:5];
assign word_idx = proc_addr[1:0];

assign hit1 = (valid1[block_now]) && (tag1[block_now] == tag_now);
assign miss1_clean = !hit1 && !dirty1[block_now];
assign miss1_dirty = !hit1 && dirty1[block_now];
assign hit = hit1;
assign miss = ~hit;

always @(*) begin
    //if (!stall) begin
        // initial value
        for(i=0;i<ENTRYNUM;i=i+1)begin
            cch1_nxt[i] = cch1[i];
            valid1_nxt[i] = valid1[i];
            tag1_nxt[i] = tag1[i];
            dirty1_nxt[i] = dirty1[i];
        end
        state_nxt = state;
        m_cnt_nxt = m_cnt;
        t_cnt_nxt = t_cnt;
        proc_stall = 0;
        proc_rdata = 0;
        read = 0;
        write = 0;
        addr = 0;
        wdata = 0;
        case (state)
            IDLE: begin
                if (hit && proc_read) begin
                    t_cnt_nxt = t_cnt + 1;
                    case (word_idx)
                        0: proc_rdata = cch1[block_now][31:0];
                        1: proc_rdata = cch1[block_now][63:32];
                        2: proc_rdata = cch1[block_now][95:64];
                        3: proc_rdata = cch1[block_now][127:96];
                        default: proc_rdata = 0;
                    endcase
                end
                else if (hit && proc_write) begin
                    t_cnt_nxt = t_cnt + 1;
                    case (word_idx)
                        0: cch1_nxt[block_now][31:0] = proc_wdata;
                        1: cch1_nxt[block_now][63:32] = proc_wdata;
                        2: cch1_nxt[block_now][95:64] = proc_wdata;
                        3: cch1_nxt[block_now][127:96] = proc_wdata;
                        default: cch1_nxt[block_now] = cch1[block_now];
                    endcase
                    dirty1_nxt[block_now] = 1;
                end
                else begin
                    t_cnt_nxt = t_cnt + 1;
                    m_cnt_nxt = m_cnt + 1;
                    proc_stall = 0;
                    if(proc_read || proc_write) begin
                        proc_stall = 1;
                    end
                    addr = proc_addr;
                    if (miss1_dirty) begin
                        state_nxt = WRITEBACK;
                        write = 1;
                        read = 0;
                        addr = {tag1[block_now], block_now, word_idx};
                        wdata = cch1[block_now];
                        proc_stall = 1;
                    end
                    else if (miss1_clean) begin
                        if (proc_read) begin
                            state_nxt = ALLOCATE;
                            write = 0;
                            read = 1;
                            proc_stall = 1;
                            addr = proc_addr;
                        end
                        else if (proc_write) begin
                            proc_stall = 1;
                            state_nxt = WRITE_READ;
                            write = 0;
                            read = 1;
                            addr = proc_addr;
                        end
                    end
                    else begin
                        state_nxt = IDLE;
                        read = 0;
                        write = 0;
                    end
                end
            end
            ALLOCATE: begin
                addr = proc_addr;
                if (ready) begin
                    cch1_nxt[block_now] = rdata;
                    valid1_nxt[block_now] = 1;
                    dirty1_nxt[block_now] = 0;
                    tag1_nxt[block_now] = tag_now;
                    addr = proc_addr;
                    proc_stall = 0;
                    state_nxt = IDLE;
                    case (word_idx)
                        0: proc_rdata = rdata[31:0];
                        1: proc_rdata = rdata[63:32];
                        2: proc_rdata = rdata[95:64];
                        3: proc_rdata = rdata[127:96];
                        default: proc_rdata = 0;
                    endcase
                    read = 1;
                    write = 0;
                end
                else begin
                    read = 1;
                    write = 0;
                    state_nxt = ALLOCATE;
                    proc_stall = 1;
                    addr = proc_addr;
                end
            end
            WRITEBACK: begin
                addr = {tag1[block_now], block_now, word_idx};
                if (ready) begin
                    dirty1_nxt[block_now] = 0;
                    proc_stall = 1;
                    state_nxt = IDLE;
                    read = 1;
                    write = 0;
                end
                else begin
                    wdata = cch1[block_now];
                    read = 0;
                    write = 1;
                    state_nxt = WRITEBACK;
                    proc_stall = 1;
                end
            end
            WRITE_READ: begin
                if (ready) begin
                    cch1_nxt[block_now] = rdata;
                    case (word_idx)
                        0: cch1_nxt[block_now][31:0] = proc_wdata;
                        1: cch1_nxt[block_now][63:32] = proc_wdata;
                        2: cch1_nxt[block_now][95:64] = proc_wdata;
                        3: cch1_nxt[block_now][127:96] = proc_wdata;
                        default: cch1_nxt[block_now] = cch1[block_now];
                    endcase
                    valid1_nxt[block_now] = 1;
                    dirty1_nxt[block_now] = 1;
                    tag1_nxt[block_now] = tag_now;
                    state_nxt = IDLE;
                    addr = proc_addr;
                    proc_stall = 0;
                    read = 1;
                    write = 0;
                end
                else begin
                    state_nxt = WRITE_READ;
                    proc_stall = 1;
                    read = 1;
                    write = 0;
                    addr = proc_addr;
                end
            end
        endcase
    //end
end

//==== sequential circuit =================================
always@( posedge clk ) begin
    if( proc_reset ) begin
        state <= IDLE;
        for (i = 0; i<ENTRYNUM; i=i+1) begin
            cch1[i]      <= 0;
            tag1[i]      <= 0;
            valid1[i]    <= 0;
            dirty1[i]    <= 0;
        end
        m_cnt       <= 0;
        t_cnt       <= 0;
    end
    else begin
        state <= state_nxt;
        for (i = 0; i<ENTRYNUM; i=i+1) begin
            cch1[i]      <= cch1_nxt[i];
            tag1[i]      <= tag1_nxt[i];
            valid1[i]    <= valid1_nxt[i];
            dirty1[i]    <= dirty1_nxt[i];
        end
        m_cnt       <= m_cnt_nxt;
        t_cnt       <= t_cnt_nxt;
    end
end

endmodule

