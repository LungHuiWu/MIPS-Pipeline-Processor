module L1(
    clk,
    proc_reset,
    proc_read,
    proc_write,
    proc_addr,
    proc_rdata,
    proc_wdata,
    proc_stall,
    reset,
    addr,
    read,
    write,
    wdata,
    rdata,
    ready
)
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
    input           ready;
    input   [31:0]  rdata;
    output  [31:0]  wdata;
    output          read, write;
    output          reset;
    output  [27:0]  addr;

//==== Parameter ====

    parameter WORDLEN = 32;
    parameter ENTRY = 4;
    parameter BYTEOFFSET = 2;
    parameter SET_NUM = 2;
    // TAGLEN = 32 - 2(Byte Offset) - ln(4(Words per data)) - ln(4(Entry))
    parameter TAGLEN = 26;

    parameter NONE  = 0;
    parameter ONE   = 1;
    parameter TWO   = 2;

    parameter IDLE      = 0;
    parameter COMPARE   = 1;
    parameter WRITEBACK = 2;
    parameter ALLOCATE  = 3;

//==== Wire & Reg ====

    // Output
        reg     proc_stall, proc_stall_nxt;
        reg     [31:0]  proc_rdata, proc_rdata_nxt;
        reg     [31:0]  wdata, wdata_nxt;
        reg     read, read_nxt;
        reg     write, write_nxt;
        reg     [27:0]  addr, addr_nxt;
        assign  reset = proc_reset;
    // State
        reg     [1:0]   set, set_nxt;
        reg     [1:0]   state, state_nxt;
    // Cache memory
        reg     [WORDLEN*4-1 : 0]   cache       [0:ENTRY-1][0:SET_NUM-1];
        reg     [WORDLEN*4-1 : 0]   cache_nxt   [0:ENTRY-1][0:SET_NUM-1];
        reg     [TAGLEN-1 : 0]      tag         [0:ENTRY-1][0:SET_NUM-1];
        reg     [TAGLEN-1 : 0]      tag_nxt     [0:ENTRY-1][0:SET_NUM-1];
        reg     valid       [0:ENTRY-1][0:SET_NUM-1];
        reg     valid_nxt   [0:ENTRY-1][0:SET_NUM-1];
        reg     dirty       [0:ENTRY-1][0:SET_NUM-1];
        reg     dirty_nxt   [0:ENTRY-1][0:SET_NUM-1];
    // Partition of address
        wire    [ENTRY-1:0]             entry_now;
        wire    [TAGLEN-1:0]            tag_now;
        wire    [BYTEOFFSET-1:0]        word_idx;
    // Hit, Miss, Read, Write
        wire    [SET_NUM-1:0]   hit_each;
        wire    hit;
    // Count
        reg     [15:0]  m_cnt, m_cnt_nxt;
        reg     [15:0]  t_cnt, t_cnt_nxt;
    // integer
        integer i, j;

//==== Combinational ====

    assign  word_idx    =   proc_addr[1:0];
    assign  entry_now   =   proc_addr[3:2];
    assign  tag_now     =   proc_addr[29:4];

    // Hit, Miss, Read, Write
    for(i=0;i<SET_NUM;i=i+1) begin
        assign hit_each[i] = valid[entry_now][i] && (tag[entry_now][i] == tag_now);
    end
    assign hit = |hit_each;

    // FSM
    always @(*) begin
        state_nxt = IDLE;
        set_nxt = NONE;
        proc_stall_nxt = 0;
        t_cnt_nxt = t_cnt + 1;
        m_cnt_nxt = m_cnt;
        cache_nxt   = cache;
        valid_nxt   = valid;
        tag_nxt     = tag;
        dirty_nxt   = dirty;
        proc_rdata_nxt  = 0;
        wdata_nxt       = 0;
        read_nxt        = 0;
        write_nxt       = 0;
        addr_nxt        = 0;
        case (state)
            IDLE: begin
                if (proc_read || proc_write) begin
                    state_nxt = COMPARE;
                    proc_stall_nxt = 1;
                    set_nxt = NONE;
                end
            end 
            COMPARE: begin
                if (hit) begin // hit
                    proc_stall_nxt = 0;
                    state_nxt = IDLE;
                    set_nxt = NONE;
                    // read
                    if (proc_read) begin
                        if (hit_each[0]) begin
                            case (word_idx)
                                0: proc_rdata_nxt = cache[entry_now][0][31:0];
                                1: proc_rdata_nxt = cache[entry_now][0][63:32];
                                2: proc_rdata_nxt = cache[entry_now][0][95:64];
                                3: proc_rdata_nxt = cache[entry_now][0][127:96];
                            endcase
                        end
                        else begin
                            case (word_idx)
                                0: proc_rdata_nxt = cache[entry_now][1][31:0];
                                1: proc_rdata_nxt = cache[entry_now][1][63:32];
                                2: proc_rdata_nxt = cache[entry_now][1][95:64];
                                3: proc_rdata_nxt = cache[entry_now][1][127:96];
                            endcase
                        end
                    end
                    // write
                    else if (proc_write) begin
                        if (hit_each[0]) begin
                            dirty_nxt[entry_now][0] = 0;
                            case (word_idx)
                                0: cache_nxt[entry_now][0][31:0] = proc_wdata;
                                1: cache_nxt[entry_now][0][63:32] = proc_wdata;
                                2: cache_nxt[entry_now][0][95:64] = proc_wdata;
                                3: cache_nxt[entry_now][0][128:96] = proc_wdata;
                            endcase
                        end
                        else begin
                            dirty_nxt[entry_now][1] = 0;
                            case (word_idx)
                                0: cache_nxt[entry_now][1][31:0] = proc_wdata;
                                1: cache_nxt[entry_now][1][63:32] = proc_wdata;
                                2: cache_nxt[entry_now][1][95:64] = proc_wdata;
                                3: cache_nxt[entry_now][1][128:96] = proc_wdata;
                            endcase
                        end
                    end
                end
                else begin // miss
                    proc_stall_nxt = 1;
                    m_cnt_nxt = m_cnt + 1;
                    if (!dirty[entry_now][0]) begin
                        state_nxt = ALLOCATE;
                        set_nxt = ONE;
                    end
                    else if (!dirty[entry_now][0]) begin
                        state_nxt = ALLOCATE;
                        set_nxt = TWO;
                    end
                    else begin
                        state_nxt = WRITEBACK;
                        set_nxt = ONE;
                    end
                end
            end
            WRITEBACK: begin
                proc_stall_nxt = 1;
                set_nxt = set;
                state_nxt = ready ? ALLOCATE : WRITEBACK;
                if (!ready) begin
                    write_nxt = 1;
                    if (set == ONE) begin
                        wdata_nxt = cache[entry_now][0];
                        addr_nxt = {tag[entry_now][0], entry_now};
                    end
                    else if (set == TWO) begin
                        wdata_nxt = cache[entry_now][1];
                        addr_nxt = {tag[entry_now][1], entry_now};
                    end
                end
            end
            ALLOCATE: begin
                proc_stall_nxt = 1;
                set_nxt = set;
                state_nxt = ready ? COMPARE: ALLOCATE;
                if (!ready) begin
                    read_nxt = 1;
                    addr_nxt = proc_addr[29:2];
                end
                else begin
                    if (set == ONE) begin
                        tag_nxt[entry_now][0] = tag_now;
                        valid_nxt[entry_now][0] = 1;
                        dirty_nxt[entry_now][0] = 0;
                        cache_nxt[entry_now][0] = rdata;
                    end
                    else if (set == TWO) begin
                        tag_nxt[entry_now][1] = tag_now;
                        valid_nxt[entry_now][1] = 1;
                        dirty_nxt[entry_now][1] = 0;
                        cache_nxt[entry_now][1] = rdata;
                    end
                end
            end
        endcase
    end

//==== Sequetial ====

    always @( posedge clk ) begin
        if (proc_reset) begin
            state   <= IDLE;
            set     <= NONE;
            for (i=0 ; i<ENTRY ; i=i+1) begin
                for (j=0 ; j<SET_NUM ; j=j+1) begin
                    cache[i][j]     <= 0;
                    tag[i][j]       <= 0;
                    dirty[i][j]     <= 0;
                    valid[i][j]     <= 0;
                end
            end
            proc_stall  <= 0;
            proc_rdata  <= 0;
            wdata       <= 0;
            read        <= 0;
            write       <= 0;
            addr        <= 0;
            m_cnt       <= 0;
            t_cnt       <= 0;
        end
        else begin
            state   <= state_nxt;
            set     <= set_nxt;
            for (i=0 ; i<ENTRY ; i=i+1) begin
                for (j=0 ; j<SET_NUM ; j=j+1) begin
                    cache[i][j]     <= cache_nxt[i][j];
                    tag[i][j]       <= tag_nxt[i][j];
                    dirty[i][j]     <= dirty_nxt[i][j];
                    valid[i][j]     <= valid_nxt[i][j];
                end
            end
            proc_stall  <= proc_stall_nxt;
            proc_rdata  <= proc_rdata_nxt;
            wdata       <= wdata_nxt;
            read        <= read_nxt;
            write       <= write_nxt;
            addr        <= addr_nxt;
            m_cnt       <= m_cnt_nxt;
            t_cnt       <= t_cnt_nxt;
        end
    end

endmodule