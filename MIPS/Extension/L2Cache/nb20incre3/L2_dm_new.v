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
    output reg      ready;
    output reg      stall;
    output reg      [127:0] rdata;
    input   [127:0] wdata;
    input           read, write;
    input           reset;
    input   [29:0]  addr;
    // memory intrface
    input   [127:0] mem_rdata;
    input           mem_ready;
    output reg      mem_read, mem_write;
    output reg      [27:0]  mem_addr;
    output reg      [127:0] mem_wdata;

//==== Parameter ====

    parameter WORDLEN = 32;
    parameter ENTRY = 64;
    parameter SET_NUM = 1;
    parameter WORDPERDATA = 4;
    // TAGLEN = 32 - 2(Byte Offset) - ln(4(Words per data)) - ln(16(Entry))
    parameter TAGLEN = 22;

    parameter ONE   = 0;
    parameter NONE  = 1;

    parameter IDLE      = 0;
    parameter WRITE_READ   = 1;
    parameter WRITEBACK = 2;
    parameter ALLOCATE  = 3;

//==== Wire & Reg ====

    // State
        reg     [1:0]   state, state_nxt;
    // Cache memory
        reg     [WORDLEN*WORDPERDATA-1 : 0]   cache       [0:ENTRY-1];
        reg     [WORDLEN*WORDPERDATA-1 : 0]   cache_nxt   [0:ENTRY-1];
        reg     [TAGLEN-1 : 0]      tag         [0:ENTRY-1];
        reg     [TAGLEN-1 : 0]      tag_nxt     [0:ENTRY-1];
        reg     valid       [0:ENTRY-1];
        reg     valid_nxt   [0:ENTRY-1];
        reg     dirty       [0:ENTRY-1];
        reg     dirty_nxt   [0:ENTRY-1];
    // Partition of address
        wire    [5:0]                   entry_now;
        reg     [1:0]                   set_now;
        wire    [TAGLEN-1:0]            tag_now;
    // Hit, Miss
        wire    hit;
        wire    miss1_clean;
        wire    miss1_dirty;
    // Count
        reg     [15:0]  m_cnt, m_cnt_nxt;
        reg     [15:0]  t_cnt, t_cnt_nxt;
    // integer
        integer i, j;
        genvar  k;

//==== Combinational ====

    // Partition of address
        assign  entry_now   =   addr[7:2];
        assign  tag_now     =   addr[29:8];

    // Hit, Miss
        assign hit = valid[entry_now] && (tag[entry_now] == tag_now);
        assign miss1_clean = !hit && !dirty[entry_now];
        assign miss1_dirty = !hit && dirty[entry_now];

    // Next state logic
        always @(*) begin
            stall = 0;
            ready = 0;
            rdata = 0;
            mem_read = 0;
            mem_write = 0;
            mem_addr = 0;
            mem_wdata = 0;
            state_nxt = state;
            t_cnt_nxt = t_cnt;
            m_cnt_nxt = m_cnt;
            for (i=0 ; i<ENTRY ; i=i+1) begin
                cache_nxt[i]     = cache[i];
                tag_nxt[i]       = tag[i];
                dirty_nxt[i]     = dirty[i];
                valid_nxt[i]     = valid[i];
            end
            case (state)
                IDLE: begin
                    if (hit && read) begin
                        t_cnt_nxt = t_cnt + 1;
                        rdata = cache[entry_now];
                        stall = 0;
                        ready = 1;
                    end
                    else if (hit && write) begin
                        t_cnt_nxt = t_cnt + 1;
                        cache_nxt[entry_now] = wdata;
                        dirty[entry_now] = 1;
                        stall = 0;
                        ready = 1;
                    end
                    else begin
                        t_cnt_nxt = t_cnt + 1;
                        m_cnt_nxt = m_cnt + 1;
                        mem_addr = addr[29:2];
                        if (miss1_dirty && (read||write)) begin
                            state_nxt = WRITEBACK;
                            mem_write = 1;
                            mem_read = 0;
                            mem_addr = {tag[entry_now], entry_now};
                            mem_wdata = cache[entry_now];
                            stall = 1;
                            ready = 0;
                        end
                        else if (miss1_clean) begin
                            if (read) begin
                                state_nxt = ALLOCATE;
                                mem_write = 0;
                                mem_read = 1;
                                mem_addr = addr[29:2];
                                stall = 1;
                                ready = 0;
                            end
                            else if (write) begin
                                /*state_nxt = WRITE_READ;
                                mem_write = 0;
                                mem_read = 1;
                                mem_addr = addr[29:2];
                                stall = 1;
                                ready = 0;*/
                                cache_nxt[entry_now] = wdata;
                                valid_nxt[entry_now] = 1;
                                dirty_nxt[entry_now] = 1;
                                tag_nxt[entry_now] = tag_now;
                                state_nxt = IDLE;
                                stall = 0;
                                ready = 1;
                                mem_read = 0;
                                mem_write = 0;
                            end
                            else begin
                                state_nxt = IDLE;
                                mem_read = 0;
                                mem_write = 0;
                            end
                        end
                        else begin
                            state_nxt = IDLE;
                            mem_write = 0;
                            mem_read = 0;
                        end
                    end
                end
                WRITEBACK: begin
                    mem_addr = {tag[entry_now], entry_now};
                    if (mem_ready) begin
                        dirty_nxt[entry_now] = 0;
                        stall = 1;
                        ready = 0;
                        state_nxt = IDLE;
                        mem_read = 1;
                        mem_write = 0;
                    end
                    else begin
                        mem_wdata = cache[entry_now];
                        mem_read = 0;
                        mem_write = 1;
                        state_nxt = WRITEBACK;
                        stall = 1;
                        ready = 0;
                    end
                end            
                ALLOCATE: begin
                    mem_addr = addr[29:2];
                    if (mem_ready) begin
                        cache_nxt[entry_now] = mem_rdata;
                        valid_nxt[entry_now] = 1;
                        dirty_nxt[entry_now] = 0;
                        tag_nxt[entry_now] = tag_now;
                        stall = 0;
                        ready = 1;
                        state_nxt = IDLE;
                        rdata = mem_rdata;
                        mem_read = 0;
                        mem_write = 0;
                    end
                    else begin
                        mem_read = 1;
                        mem_write = 0;
                        state_nxt = ALLOCATE;
                        stall = 1;
                        ready = 0;
                    end
                end
                WRITE_READ: begin
                    mem_addr = addr[29:2];
                    if (mem_ready) begin
                        cache_nxt[entry_now] = wdata;
                        valid_nxt[entry_now] = 1;
                        dirty_nxt[entry_now] = 1;
                        tag_nxt[entry_now] = tag_now;
                        state_nxt = IDLE;
                        stall = 0;
                        ready = 1;
                        mem_read = 0;
                        mem_write = 0;
                    end
                    else begin
                        state_nxt = WRITE_READ;
                        stall = 1;
                        ready = 0;
                        mem_read = 1;
                        mem_write = 0;
                    end
                end
            endcase
        end

//==== Sequetial ====

    always @( posedge clk ) begin
        if (reset) begin
            state   <= IDLE;
            for (i=0 ; i<ENTRY ; i=i+1) begin
                for (j=0 ; j<SET_NUM ; j=j+1) begin
                    cache[i]     <= 0;
                    tag[i]       <= 0;
                    dirty[i]     <= 0;
                    valid[i]     <= 0;
                end
            end
            m_cnt       <= 0;
            t_cnt       <= 0;
        end
        else begin
            state   <= state_nxt;
            for (i=0 ; i<ENTRY ; i=i+1) begin
                cache[i]     <= cache_nxt[i];
                tag[i]       <= tag_nxt[i];
                dirty[i]     <= dirty_nxt[i];
                valid[i]     = valid_nxt[i];
            end
            m_cnt       <= m_cnt_nxt;
            t_cnt       <= t_cnt_nxt;
        end
    end

endmodule