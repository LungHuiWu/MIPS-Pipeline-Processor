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
    output          proc_stall;
    output  [31:0]  proc_rdata;
    // L2 cache interface
    input           stall;
    input           ready;
    input   [127:0] rdata;
    output  [127:0] wdata;
    output          read, write;
    output  [29:0]  addr;

//==== Parameters ====

    parameter WORDLEN = 32;
    parameter BLOCKNUM = 4;
    parameter TAGLEN = 26;

    parameter NONE = 2'd0;
    parameter ONE = 2'd1;
    parameter TWO = 2'd2;

    parameter IDLE = 2'd0;
    parameter COMPARE = 2'd1;
    parameter ALLOCATE = 2'd2;
    parameter WRITEBACK = 2'd3;
    
//==== wire/reg definition ====
    
    /// internal FF
    // state
    reg     [1:0]   state, state_nxt;
    reg     [1:0]   set, set_nxt;
    // cache 1
    reg     [WORDLEN*4-1:0] cch1        [0:BLOCKNUM-1];
    reg     [WORDLEN*4-1:0] cch1_nxt    [0:BLOCKNUM-1];
    reg     [TAGLEN-1:0]    tag1        [0:BLOCKNUM-1];
    reg     [TAGLEN-1:0]    tag1_nxt    [0:BLOCKNUM-1];
    reg     valid1      [0:BLOCKNUM-1];
    reg     valid1_nxt  [0:BLOCKNUM-1];
    reg     dirty1      [0:BLOCKNUM-1];
    reg     dirty1_nxt  [0:BLOCKNUM-1];
    // cache 1
    reg     [WORDLEN*4-1:0] cch2        [0:BLOCKNUM-1];
    reg     [WORDLEN*4-1:0] cch2_nxt    [0:BLOCKNUM-1];
    reg     [TAGLEN-1:0]    tag2        [0:BLOCKNUM-1];
    reg     [TAGLEN-1:0]    tag2_nxt    [0:BLOCKNUM-1];
    reg     valid2      [0:BLOCKNUM-1];
    reg     valid2_nxt  [0:BLOCKNUM-1];
    reg     dirty2      [0:BLOCKNUM-1];
    reg     dirty2_nxt  [0:BLOCKNUM-1];

    /// output FF
    reg     proc_stall, proc_stall_nxt;
    reg     [31:0]  proc_rdata, proc_rdata_nxt;
    reg     read, read_nxt;
    reg     write, write_nxt;
    reg     [29:0]  addr, addr_nxt;
    reg     [127:0] wdata, wdata_nxt;

    // miss & hit
    reg     [15:0]  m_cnt, m_cnt_nxt;
    reg     [15:0]  t_cnt, t_cnt_nxt;

    wire    [1:0]   block_now;
    wire    [25:0]  tag_now;
    wire    [1:0]   word_idx;
    wire    hit1;
    wire    hit2;
    wire    miss1_clean;
    wire    miss1_dirty;
    wire    miss2_clean;
    wire    miss2_dirty;
    wire    hit;
    wire    miss;

    integer i;

//==== combinational circuit ====

assign block_now = proc_addr[3:2];
assign tag_now = proc_addr[29:4];
assign word_idx = proc_addr[1:0];

assign hit1 = (valid1[block_now]) && (tag1[block_now] == tag_now);
assign hit2 = (valid2[block_now]) && (tag2[block_now] == tag_now);
assign miss1_clean = !hit1 && !dirty1[block_now];
assign miss2_clean = !hit2 && !dirty2[block_now];
assign miss1_dirty = !hit1 && dirty1[block_now];
assign miss2_dirty = !hit2 && dirty2[block_now];
assign hit = hit1 || hit2;
assign miss = ~hit;

always @(*) begin // FSM
    if (stall) begin
        state_nxt = state;
        set_nxt = set;
        proc_stall_nxt = proc_stall;
        t_cnt_nxt = t_cnt;
        m_cnt_nxt = m_cnt;
    end
    else begin
        state_nxt = state;
        set_nxt = NONE;
        proc_stall_nxt = 0;
        t_cnt_nxt = t_cnt;
        m_cnt_nxt = m_cnt;
        case (state)
            IDLE: begin
                //$display("idle");
                if (proc_read || proc_write) begin
                    state_nxt = COMPARE;
                    proc_stall_nxt = 1;
                    set_nxt = NONE;
                    t_cnt_nxt = t_cnt + 1;
                end
                else begin
                    state_nxt = IDLE;
                    proc_stall_nxt = 0;
                    set_nxt = NONE;
                end
            end 
            COMPARE: begin
                //$display("compare");
                if (hit) begin
                    state_nxt = IDLE;
                    set_nxt = NONE;
                    proc_stall_nxt = 0;
                end
                else begin
                    proc_stall_nxt = 1;
                    m_cnt_nxt = m_cnt + 1;
                    $display("L1(2way) : Miss/Total = %d/%d", m_cnt_nxt, t_cnt_nxt);
                    if (miss1_clean) begin
                        state_nxt = ALLOCATE;
                        read_nxt = 1;
                        addr_nxt = proc_addr[29:0];
                        set_nxt = ONE;
                    end
                    else if (miss2_clean) begin
                        state_nxt = ALLOCATE;
                        read_nxt = 1;
                        addr_nxt = proc_addr[29:0];
                        set_nxt = TWO;
                    end
                    else if (miss2_dirty) begin
                        state_nxt = WRITEBACK;
                        write_nxt = 1;
                        addr_nxt = {tag2[block_now],block_now, word_idx};
                        set_nxt = TWO;
                    end
                    else begin
                        state_nxt = ALLOCATE;
                        read_nxt = 1;
                        addr_nxt = proc_addr[29:0];
                        set_nxt = ONE;
                    end
                end
            end
            ALLOCATE: begin
                //$display("allocate");
                proc_stall_nxt = 1;
                set_nxt = set;
                if (ready) begin
                    state_nxt = COMPARE;
                end
                else begin
                    state_nxt = ALLOCATE;
                end
            end
            WRITEBACK: begin
                //$display("writeback");
                proc_stall_nxt = 1;
                set_nxt = set;
                if (ready) begin
                    state_nxt = ALLOCATE;
                end
                else begin
                    state_nxt = WRITEBACK;
                end
            end
            default: begin
                state_nxt = IDLE;
                proc_stall_nxt = 0;
                set_nxt = NONE;
            end
        endcase
    end
end

always @(*) begin
    // initial value
    for(i=0;i<BLOCKNUM;i=i+1)begin
        cch1_nxt[i] = cch1[i];
        valid1_nxt[i] = valid1[i];
        tag1_nxt[i] = tag1[i];
        dirty1_nxt[i] = dirty1[i];
        cch2_nxt[i] = cch2[i];
        valid2_nxt[i] = valid2[i];
        tag2_nxt[i] = tag2[i];
        dirty2_nxt[i] = dirty2[i];
    end
    // proc_stall_nxt = 0;
    proc_rdata_nxt = 0;
    read_nxt = 0;
    write_nxt = 0;
    addr_nxt = 0;
    wdata_nxt = 0;
    case (state)
        COMPARE: begin
            if(hit) begin
                if (proc_write && ~proc_read) begin
                    if (hit1) begin
                        case (word_idx)
                            0: cch1_nxt[block_now][31:0] = proc_wdata;
                            1: cch1_nxt[block_now][63:32] = proc_wdata;
                            2: cch1_nxt[block_now][95:64] = proc_wdata;
                            3: cch1_nxt[block_now][127:96] = proc_wdata;
                            default: cch1_nxt[block_now] = cch1[block_now];
                        endcase
                        tag1_nxt[block_now] = tag_now;
                        dirty1_nxt[block_now] = 1;
                    end
                    else if (hit2) begin
                        case (word_idx)
                            0: cch2_nxt[block_now][31:0] = proc_wdata;
                            1: cch2_nxt[block_now][63:32] = proc_wdata;
                            2: cch2_nxt[block_now][95:64] = proc_wdata;
                            3: cch2_nxt[block_now][127:96] = proc_wdata;
                            default: cch2_nxt[block_now] = cch2[block_now];
                        endcase
                        tag2_nxt[block_now] = tag_now;
                        dirty2_nxt[block_now] = 1;
                    end
                end
                else if (proc_read && ~proc_write) begin
                    if (hit1) begin
                        case (word_idx)
                            0: proc_rdata_nxt = cch1[block_now][31:0];
                            1: proc_rdata_nxt = cch1[block_now][63:32];
                            2: proc_rdata_nxt = cch1[block_now][95:64];
                            3: proc_rdata_nxt = cch1[block_now][127:96];
                            default: proc_rdata_nxt = 0; 
                        endcase
                    end
                    else if (hit2) begin
                        case (word_idx)
                            0: proc_rdata_nxt = cch2[block_now][31:0];
                            1: proc_rdata_nxt = cch2[block_now][63:32];
                            2: proc_rdata_nxt = cch2[block_now][95:64];
                            3: proc_rdata_nxt = cch2[block_now][127:96];
                            default: proc_rdata_nxt = 0; 
                        endcase
                    end
                end
            end
        end
        ALLOCATE: begin
            if (ready)  begin
                if (set == ONE) begin
                    tag1_nxt[block_now] = tag_now;
                    valid1_nxt[block_now] = 1;
                    dirty1_nxt[block_now] = 0;
                    cch1_nxt[block_now] = rdata;
                end
                else if (set == TWO) begin
                    tag2_nxt[block_now] = tag_now;
                    valid2_nxt[block_now] = 1;
                    dirty2_nxt[block_now] = 0;
                    cch2_nxt[block_now] = rdata;
                end
            end
            else begin
                read_nxt = 1;
                write_nxt = 0;
                wdata_nxt = 0;
                addr_nxt = proc_addr[29:0];
            end
        end
        WRITEBACK: begin
            if (~ready) begin
                write_nxt = 1;
                if (set == ONE) begin
                    wdata_nxt = cch1[block_now];
                    addr_nxt = {tag1[block_now],block_now, word_idx};
                end
                else if (set == TWO) begin
                    wdata_nxt = cch2[block_now];
                    addr_nxt = {tag2[block_now],block_now, word_idx};
                end
            end
            else begin
                read_nxt = 1;
                addr_nxt = proc_addr[29:0];
            end
        end
        default: begin
            // initial value
            for(i=0;i<BLOCKNUM;i=i+1)
                cch1_nxt[i] = cch1[i];
                valid1_nxt[i] = valid1[i];
                tag1_nxt[i] = tag1[i];
                dirty1_nxt[i] = dirty1[i];
                cch2_nxt[i] = cch2[i];
                valid2_nxt[i] = valid2[i];
                tag2_nxt[i] = tag2[i];
                dirty2_nxt[i] = dirty2[i];
            // proc_stall_nxt = 0;
            proc_rdata_nxt = 0;
            read_nxt = 0;
            write_nxt = 0;
            addr_nxt = 0;
            wdata_nxt = 0;
        end
    endcase
end

//==== sequential circuit =================================
always@( posedge clk ) begin
    if( proc_reset ) begin
        state <= IDLE;
        set <= NONE;
        for (i = 0; i<BLOCKNUM; i=i+1) begin
            cch1[i]      <= 0;
            tag1[i]      <= 0;
            valid1[i]    <= 0;
            dirty1[i]    <= 0;
            cch2[i]      <= 0;
            tag2[i]      <= 0;
            valid2[i]    <= 0;
            dirty2[i]    <= 0;
        end
        proc_stall      <= 0;
        proc_rdata      <= 0;
        read        <= 0;
        write       <= 0;
        addr        <= 0;
        wdata       <= 0;
        m_cnt       <= 0;
        t_cnt       <= 0;
    end
    else begin
        state <= state_nxt;
        set <= set_nxt;
        for (i = 0; i<BLOCKNUM; i=i+1) begin
            cch1[i]      <= cch1_nxt[i];
            tag1[i]      <= tag1_nxt[i];
            valid1[i]    <= valid1_nxt[i];
            dirty1[i]    <= dirty1_nxt[i];
            cch2[i]      <= cch2_nxt[i];
            tag2[i]      <= tag2_nxt[i];
            valid2[i]    <= valid2_nxt[i];
            dirty2[i]    <= dirty2_nxt[i];
        end
        proc_stall      <= proc_stall_nxt;
        proc_rdata      <= proc_rdata_nxt;
        read        <= read_nxt;
        write       <= write_nxt;
        addr        <= addr_nxt;
        wdata       <= wdata_nxt;
        m_cnt       <= m_cnt_nxt;
        t_cnt       <= t_cnt_nxt;
    end
end

endmodule

