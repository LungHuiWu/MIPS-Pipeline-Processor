module L2(
    clk,
    reset,
    addr,
    read,
    write,
    wdata,
    rdata,
    ready,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
)
//==== Input/Output definition ====
    input           clk;
    // L1 cache interface
    output          ready;
    output  [31:0]  rdata;
    input   [127:0] wdata;
    input           read, write;
    input           reset;
    input   [27:0]  addr;
    // memory intrface
    input   [127:0] mem_rdata;
    input           mem_ready;
    output          mem_read, mem_write;
    output  [27:0]  mem_addr;
    output  [127:0] mem_wdata;

//==== Parameter ====

    parameter WORDLEN = 32;
    parameter ENTRY = 16;
    parameter SET_NUM = 4;
    parameter WORDPERDATA = 4;
    // TAGLEN = 32 - 2(Byte Offset) - ln(4(Words per data)) - ln(16(Entry))
    parameter TAGLEN = 24;

    parameter NONE  = 4;
    parameter ONE   = 0;
    parameter TWO   = 1;
    parameter THREE = 2;
    parameter FOUR  = 3;

    parameter IDLE      = 0;
    parameter COMPARE   = 1;
    parameter WRITEBACK = 2;
    parameter ALLOCATE  = 3;

//==== Wire & Reg ====

    // Output
        reg     ready, ready_nxt;
        reg     [31:0]  rdata, rdata_nxt;
        reg     mem_read, mem_read_nxt;
        reg     mem_write, mem_write_nxt;
        reg     [27:0]  mem_addr, mem_addr_nxt;
        reg     [127:0] mem_wdata, mem_wdata_nxt;
    // State
        reg     [2:0]   set, set_nxt;
        reg     [1:0]   state, state_nxt;
    // Cache memory
        reg     [WORDLEN*WORDPERDATA-1 : 0]   cache       [0:ENTRY-1][0:SET_NUM-1];
        reg     [WORDLEN*WORDPERDATA-1 : 0]   cache_nxt   [0:ENTRY-1][0:SET_NUM-1];
        reg     [TAGLEN-1 : 0]      tag         [0:ENTRY-1][0:SET_NUM-1];
        reg     [TAGLEN-1 : 0]      tag_nxt     [0:ENTRY-1][0:SET_NUM-1];
        reg     valid       [0:ENTRY-1][0:SET_NUM-1];
        reg     valid_nxt   [0:ENTRY-1][0:SET_NUM-1];
        reg     dirty       [0:ENTRY-1][0:SET_NUM-1];
        reg     dirty_nxt   [0:ENTRY-1][0:SET_NUM-1];
    // Partition of address
        wire    [ENTRY-1:0]             entry_now;
        wire    [2:0]                   set_now;
        wire    [TAGLEN-1:0]            tag_now;
    // Hit, Miss
        wire    [SET_NUM-1:0]   hit_each;
        wire    hit;
    // Count
        reg     [15:0]  m_cnt, m_cnt_nxt;
        reg     [15:0]  t_cnt, t_cnt_nxt;
    // integer
        integer i, j;

//==== Combinational ====

    // Partition of address
        assign  entry_now   =   proc_addr[3:0];
        assign  tag_now     =   proc_addr[27:4];

    // Hit, Miss
        for(i=0;i<SET_NUM;i=i+1) begin
            assign hit_each[i] = valid[entry_now][i] && (tag[entry_now][i] == tag_now);
        end
        assign hit = |hit_each;

    // Set now
        if (hit_each[0]) set_now = 0;
        else if (hit_each[1]) set_now = 1;
        else if (hit_each[2]) set_now = 2;
        else if (hit_each[3]) set_now = 3;
        else set_now = 0;

    // Next state logic
        always @(*) begin
            ready_nxt = 0;
            rdata_nxt = 0;
            mem_read_nxt = 0;
            mem_write_nxt = 0;
            mem_addr_nxt = 0;
            mem_wdata_nxt = 0;
            state_nxt = IDLE;
            set_nxt = NONE;
            t_cnt_nxt = t_cnt + 1;
            m_cnt_nxt = m_cnt;
            cache_nxt   = cache;
            valid_nxt   = valid;
            tag_nxt     = tag;
            dirty_nxt   = dirty;
            case (state)
                IDLE: begin
                    if (read || write) begin
                        state_nxt = COMPARE;
                        ready_nxt = 0;
                        set_nxt = NONE;
                    end
                end 
                COMPARE: begin
                    if (hit) begin // hit
                        ready_nxt = 1;
                        state_nxt = IDLE;
                        set_nxt = NONE;
                        // read
                        if (read) begin
                            rdata_nxt = cache[entry_now][set_now];
                        end
                        // write
                        else if (write) begin
                            dirty_nxt[entry_now][set_now] = 0;
                            cache_nxt[entry_now][set_now] = wdata;
                        end
                    end
////////////////////////////////////////////////////////////////////////
                    else begin // miss
                        ready_nxt = 0;
                        m_cnt_nxt = m_cnt + 1;
                        if (&dirty[entry_now]) begin
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