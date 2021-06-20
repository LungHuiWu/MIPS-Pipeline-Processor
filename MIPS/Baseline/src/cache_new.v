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
    input          proc_reset;
    input          proc_read, proc_write;
    input   [29:0] proc_addr;
    input   [31:0] proc_wdata;
    output reg        proc_stall;
    output reg [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output reg        mem_read, mem_write;
    output reg [27:0] mem_addr;
    output reg [127:0] mem_wdata;

//==== parameter definition ===============================
    parameter IDLE  = 0;
    parameter READ  = 1;
    parameter WRITE_READ  = 2;
    parameter WRITE_BACK  = 3;
    
//==== wire/reg definition ================================
    reg         valid0_w   [3:0], valid1_w   [3:0];
    reg         valid0_r   [3:0], valid1_r   [3:0];
    reg         dirty0_w   [3:0], dirty1_w   [3:0];
    reg         dirty0_r   [3:0], dirty1_r   [3:0];
    reg [25:0]  tag0_w     [3:0], tag1_w     [3:0];
    reg [25:0]  tag0_r     [3:0], tag1_r     [3:0];
    reg [127:0] data0_w    [3:0], data1_w    [3:0];
    reg [127:0] data0_r    [3:0], data1_r    [3:0];

    wire [1:0]   block;
    wire [1:0]   offset;
    wire         hit0, hit1;

    reg [2:0]   state_w, state_r;
    reg         mode_w [3:0], mode_r [3:0];

    assign block    = proc_addr[3:2];
    assign offset   = proc_addr[1:0];
    assign hit0     = (valid0_r[block] == 1 && tag0_r[block] == proc_addr[29:4]); 
    assign hit1     = (valid1_r[block] == 1 && tag1_r[block] == proc_addr[29:4]);

    integer i,j,k;
    
//==== combinational circuit ==============================
    always@(*) begin
        
        for (i = 0; i < 4; i=i+1) begin
            valid0_w[i]  = valid0_r[i];
            valid1_w[i]  = valid1_r[i];
            dirty0_w[i]  = dirty0_r[i];
            dirty1_w[i]  = dirty1_r[i];
            tag0_w[i]    = tag0_r[i];
            tag1_w[i]    = tag1_r[i];
            data0_w[i]   = data0_r[i];
            data1_w[i]   = data1_r[i];
            mode_w[i]    = mode_r[i];
        end
        state_w = state_r;

        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_addr    = 28'b0;
        mem_wdata   = 128'b0;
        proc_stall  = 1'b0;
        proc_rdata  = 32'b0;
        
        case (state_r)
        
            IDLE: begin
                if (proc_read && hit0) begin
                    proc_rdata = data0_r[block][32 * offset + 31-:32];
                    proc_stall = 0;
                    mem_read = 0;
                    mem_write = 0;
                end
                else if (proc_read && hit1) begin
                    proc_rdata = data1_r[block][32 * offset + 31-:32];
                    proc_stall = 0;
                    mem_read = 0;
                    mem_write = 0;
                end
                else if (proc_write && hit0) begin
                    data0_w[block][32 * offset + 31-:32] = proc_wdata;
                    proc_stall = 0;
                    dirty0_w[block] = 1;
                    mem_read = 0;
                    mem_write = 0;
                end
                else if (proc_write && hit1) begin
                    data1_w[block][32 * offset + 31-:32] = proc_wdata;
                    proc_stall = 0;
                    dirty1_w[block] = 1;
                    mem_read = 0;
                    mem_write = 0;
                end
                else begin
                    proc_stall = 0;
                    if (proc_read || proc_write) begin
                        proc_stall = 1;
                    end
                    mem_addr = proc_addr[29:2];
                    if ((dirty0_r[block] && !mode_r[block]) || (dirty1_r[block] && mode_r[block])) begin
                        state_w = WRITE_BACK;
                        mem_read = 0;
                        mem_write = 1;
                    end
                    else if (proc_write) begin
                        state_w = WRITE_READ;
                        mem_read = 1;
                        mem_write = 0;
                    end
                    else if (proc_read) begin
                        state_w = READ;
                        mem_read = 1;
                        mem_write = 0;
                    end
                    else begin
                        state_w = IDLE;
                        mem_read = 0;
                        mem_write = 0;
                    end
                end
            end
            READ: begin
                mem_addr    = proc_addr[29:2];
                if (mem_ready) begin
                    if (mode_r[block]) begin
                        data1_w[block] = mem_rdata;
                        valid1_w[block] = 1;
                        dirty1_w[block] = 0;
                        tag1_w[block] = proc_addr[29:4];
                        mode_w[block] = 0;
                    end
                    else begin
                        data0_w[block] = mem_rdata;
                        valid0_w[block] = 1;
                        dirty0_w[block] = 0;
                        tag0_w[block] = proc_addr[29:4];
                        mode_w[block] = 1;
                    end
                    mem_addr = 27'b0;
                    proc_stall = 0;
                    mem_read = 0;
                    mem_write = 0;
                    state_w = IDLE;
                    proc_rdata = mem_rdata[32 * offset + 31-:32];
                end
                else begin
                    state_w = state_r;
                    proc_stall = 1;
                    mem_read = 1;
                    mem_write = 0;
                end
            end
            WRITE_READ: begin
                if (mem_ready) begin
                    if (mode_r[block]) begin
                        data1_w[block] = mem_rdata;
                        data1_w[block][32 * offset + 31-:32] = proc_wdata;
                        valid1_w[block] = 1;
                        dirty1_w[block] = 1;
                        tag1_w[block] = proc_addr[29:4];
                        mode_w[block] = 0;
                    end
                    else begin
                        data0_w[block] = mem_rdata;
                        data0_w[block][32 * offset + 31-:32] = proc_wdata;
                        valid0_w[block] = 1;
                        dirty0_w[block] = 1;
                        tag0_w[block] = proc_addr[29:4];
                        mode_w[block] = 1;
                    end
                    state_w = IDLE;
                    mem_addr = 27'b0;
                    proc_stall = 0;
                    mem_read = 0;
                    mem_write = 0;
                end
                else begin
                    state_w = state_r;
                    proc_stall = 1;
                    mem_read = 1;
                    mem_write = 0;
                end
            end
            WRITE_BACK: begin
                if (mem_ready) begin
                    state_w = IDLE;
                    proc_stall = 1;
                    if (mode_r[block]) begin
                        dirty1_w[block] = 0;
                    end
                    else begin
                        dirty0_w[block] = 0;
                    end
                    mem_read = 1;
                    mem_write = 0;
                end
                else begin
                    if (mode_r[block]) begin
                        mem_addr = {tag1_r[block], block};
                        mem_wdata = data1_r[block];
                    end
                    else begin
                        mem_addr = {tag0_r[block], block};
                        mem_wdata = data0_r[block];
                    end
                    state_w = state_r;
                    proc_stall = 1;
                    mem_read = 0;
                    mem_write = 1;
                end
            end
            default begin
                
            end
        endcase
    end
//==== sequential circuit =================================
    always@( posedge clk ) begin
        if( proc_reset ) begin
            for (j = 0; j < 4; j=j+1) begin
                valid0_r[j]  <= 1'b0;
                valid1_r[j]  <= 1'b0;
                dirty0_r[j]  <= 1'b0;
                dirty1_r[j]  <= 1'b0;
                tag0_r[j]    <= 26'b0;
                tag1_r[j]    <= 26'b0;
                data0_r[j]   <= 127'b0;
                data1_r[j]   <= 127'b0; 
                mode_r[j]    <= 1'b0;       
            end
            state_r         <= IDLE;
        end
        else begin
            for (k = 0; k < 4; k=k+1) begin
                valid0_r[k]  <= valid0_w[k];
                valid1_r[k]  <= valid1_w[k];
                dirty0_r[k]  <= dirty0_w[k];
                dirty1_r[k]  <= dirty1_w[k];
                tag0_r[k]    <= tag0_w[k];
                tag1_r[k]    <= tag1_w[k];
                data0_r[k]   <= data0_w[k];
                data1_r[k]   <= data1_w[k];
                mode_r[k]    <= mode_w[k];
            end
            state_r         <= state_w;
        end
    end

endmodule