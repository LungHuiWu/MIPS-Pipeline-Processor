module L2(
    clk,
    reset,
    addr,
    read,
    write,
    wdata,
    rdata,
    ready,
    stall,
    mem_read,
    mem_write,
    mem_addr,
    mem_rdata,
    mem_wdata,
    mem_ready
);
//==== Input/Output definition ====
    input           clk;
    // L1 cache interface
    output          ready;
    output          stall;
    output  [127:0] rdata;
    input   [127:0] wdata;
    input           read, write;
    input           reset;
    input   [29:0]  addr;
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

    parameter ONE   = 0;
    parameter TWO   = 1;
    parameter THREE = 2;
    parameter FOUR  = 3;
    parameter NONE  = 4;

    parameter IDLE      = 0;
    parameter COMPARE   = 1;
    parameter WRITEBACK = 2;
    parameter ALLOCATE  = 3;

//==== Wire & Reg ====

    // Output
        reg     ready, ready_nxt;
        reg     stall, stall_nxt;
        reg     [127:0]  rdata, rdata_nxt;
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
        wire    [3:0]                   entry_now;
        reg     [2:0]                   set_now;
        wire    [TAGLEN-1:0]            tag_now;
    // Hit, Miss
        wire    [SET_NUM-1:0]   hit_each;
        wire    hit;
    // Count
        reg     [15:0]  m_cnt, m_cnt_nxt;
        reg     [15:0]  t_cnt, t_cnt_nxt;
    // integer
        integer i, j;
        genvar  k;

//==== Combinational ====

    // Partition of address
        assign  entry_now   =   addr[5:2];
        assign  tag_now     =   addr[29:6];

    // Hit, Miss
        generate
            for(k=0;k<SET_NUM;k=k+1) begin
                assign hit_each[k] = valid[entry_now][k] && (tag[entry_now][k] == tag_now);
            end
        endgenerate
        assign hit = |hit_each;

    // Next state logic
        always @(*) begin
            stall_nxt = 0;
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
            for (i=0 ; i<ENTRY ; i=i+1) begin
                for (j=0 ; j<SET_NUM ; j=j+1) begin
                    cache_nxt[i][j]     = cache[i][j];
                    tag_nxt[i][j]       = tag[i][j];
                    dirty_nxt[i][j]     = dirty[i][j];
                    valid_nxt[i][j]     = valid[i][j];
                end
            end
            // Set now
                if (hit_each[0]) begin 
                    set_now = 0;
                end
                else if (hit_each[1]) begin
                    set_now = 1;
                end
                else if (hit_each[2]) begin
                    set_now = 2;
                end
                else if (hit_each[3]) begin
                    set_now = 3;
                end
                else begin
                    set_now = 0;
                end
            case (state)
                IDLE: begin
                    if (read || write) begin
                        state_nxt = COMPARE;
                        ready_nxt = 0;
                        stall_nxt = 1;
                    end
                end 
                COMPARE: begin
                    if (hit) begin // hit
                        ready_nxt = 1;
                        stall_nxt = 0;
                        state_nxt = IDLE;
                        // read
                        if (read) begin
                            rdata_nxt = cache[entry_now][set_now];
                        end
                        // write
                        else if (write) begin
                            dirty_nxt[entry_now][set_now] = 1;
                            cache_nxt[entry_now][set_now] = wdata;
                        end
                    end
                    else begin // miss
                        ready_nxt = 0;
                        stall_nxt = 1;
                        m_cnt_nxt = m_cnt + 1;
                        if (!valid[entry_now][0]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = ONE;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!valid[entry_now][1]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = TWO;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!valid[entry_now][2]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = THREE;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!valid[entry_now][3]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = FOUR;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!dirty[entry_now][0]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = ONE;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!dirty[entry_now][1]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = TWO;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!dirty[entry_now][2]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = THREE;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else if (!dirty[entry_now][3]) begin
                            state_nxt = ALLOCATE;
                            set_nxt = FOUR;
                            mem_read_nxt = 1;
                            mem_addr_nxt = addr[29:2];
                        end
                        else begin
                            state_nxt = WRITEBACK;
                            set_nxt = FOUR;
                            mem_write_nxt = 1;
                            mem_addr_nxt = {tag[entry_now][3], entry_now};
                        end
                    end
                end
                WRITEBACK: begin
                    ready_nxt = 0;
                    stall_nxt = 1;
                    set_nxt = set;
                    state_nxt = mem_ready ? ALLOCATE : WRITEBACK;
                    if (!mem_ready) begin
                        mem_write_nxt = 1;
                        mem_wdata_nxt = cache[entry_now][set];
                        mem_addr_nxt = {tag[entry_now][set], entry_now};
                    end
                end            
                ALLOCATE: begin
                    ready_nxt = 0;
                    stall_nxt = 1;
                    set_nxt = set;
                    if (!mem_ready) begin
                        state_nxt = ALLOCATE;
                        mem_read_nxt = 1;
                        mem_addr_nxt = addr[29:2];
                    end
                    else begin
                        state_nxt = COMPARE;
                        tag_nxt[entry_now][set] = tag_now;
                        valid_nxt[entry_now][set] = 1;
                        dirty_nxt[entry_now][set] = 0;
                        cache_nxt[entry_now][set] = mem_rdata;
                    end
                end
            endcase
        end

//==== Sequetial ====

    always @( posedge clk ) begin
        if (reset) begin
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
            stall       <= 0;
            ready       <= 0;
            rdata       <= 0;
            mem_wdata   <= 0;
            mem_read    <= 0;
            mem_write   <= 0;
            mem_addr    <= 0;
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
                    valid[i][j]     = valid_nxt[i][j];
                end
            end
            stall       <= stall_nxt;
            ready       <= ready_nxt;
            rdata       <= rdata_nxt;
            mem_wdata   <= mem_wdata_nxt;
            mem_read    <= mem_read_nxt;
            mem_write   <= mem_write_nxt;
            mem_addr    <= mem_addr_nxt;
            m_cnt       <= m_cnt_nxt;
            t_cnt       <= t_cnt_nxt;
        end
    end

endmodule