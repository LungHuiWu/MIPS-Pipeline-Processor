// Top module of your design, you cannot modify this module!!
module CHIP (	clk,
				rst_n,
//----------for slow_memD------------
				mem_read_D,
				mem_write_D,
				mem_addr_D,
				mem_wdata_D,
				mem_rdata_D,
				mem_ready_D,
//----------for slow_memI------------
				mem_read_I,
				mem_write_I,
				mem_addr_I,
				mem_wdata_I,
				mem_rdata_I,
				mem_ready_I,
//----------for TestBed--------------				
				DCACHE_addr, 
				DCACHE_wdata,
				DCACHE_wen   
			);
input			clk, rst_n;
//--------------------------

output			mem_read_D;
output			mem_write_D;
output	[31:4]	mem_addr_D;
output	[127:0]	mem_wdata_D;
input	[127:0]	mem_rdata_D;
input			mem_ready_D;
//--------------------------
output			mem_read_I;
output			mem_write_I;
output	[31:4]	mem_addr_I;
output	[127:0]	mem_wdata_I;
input	[127:0]	mem_rdata_I;
input			mem_ready_I;
//----------for TestBed--------------
output	[29:0]	DCACHE_addr;
output	[31:0]	DCACHE_wdata;
output			DCACHE_wen;
//--------------------------

// wire declaration
wire        ICACHE_ren;
wire        ICACHE_wen;
wire [29:0] ICACHE_addr;
wire [31:0] ICACHE_wdata;
wire        ICACHE_stall;
wire [31:0] ICACHE_rdata;

wire        DCACHE_ren;
wire        DCACHE_wen;
wire [29:0] DCACHE_addr;
wire [31:0] DCACHE_wdata;
wire        DCACHE_stall;
wire [31:0] DCACHE_rdata;

//=========================================
	// Note that the overall design of your MIPS includes:
	// 1. pipelined MIPS processor
	// 2. data cache
	// 3. instruction cache


	MIPS_Pipeline i_MIPS(
		// control interface
		.clk            (clk)           , 
		.rst_n          (rst_n)         ,
//----------I cache interface-------		
		.ICACHE_ren     (ICACHE_ren)    ,
		.ICACHE_wen     (ICACHE_wen)    ,
		.ICACHE_addr    (ICACHE_addr)   ,
		.ICACHE_wdata   (ICACHE_wdata)  ,
		.ICACHE_stall   (ICACHE_stall)  ,
		.ICACHE_rdata   (ICACHE_rdata)  ,
//----------D cache interface-------
		.DCACHE_ren     (DCACHE_ren)    ,
		.DCACHE_wen     (DCACHE_wen)    ,
		.DCACHE_addr    (DCACHE_addr)   ,
		.DCACHE_wdata   (DCACHE_wdata)  ,
		.DCACHE_stall   (DCACHE_stall)  ,
		.DCACHE_rdata   (DCACHE_rdata)
	);
	
	cache D_cache(
        .clk        (clk)         ,
        .proc_reset (~rst_n)      ,
        .proc_read  (DCACHE_ren)  ,
        .proc_write (DCACHE_wen)  ,
        .proc_addr  (DCACHE_addr) ,
        .proc_rdata (DCACHE_rdata),
        .proc_wdata (DCACHE_wdata),
        .proc_stall (DCACHE_stall),
        .mem_read   (mem_read_D)  ,
        .mem_write  (mem_write_D) ,
        .mem_addr   (mem_addr_D)  ,
        .mem_wdata  (mem_wdata_D) ,
        .mem_rdata  (mem_rdata_D) ,
        .mem_ready  (mem_ready_D)
	);

	cache I_cache(
        .clk        (clk)         ,
        .proc_reset (~rst_n)      ,
        .proc_read  (ICACHE_ren)  ,
        .proc_write (ICACHE_wen)  ,
        .proc_addr  (ICACHE_addr) ,
        .proc_rdata (ICACHE_rdata),
        .proc_wdata (ICACHE_wdata),
        .proc_stall (ICACHE_stall),
        .mem_read   (mem_read_I)  ,
        .mem_write  (mem_write_I) ,
        .mem_addr   (mem_addr_I)  ,
        .mem_wdata  (mem_wdata_I) ,
        .mem_rdata  (mem_rdata_I) ,
        .mem_ready  (mem_ready_I)
	);
endmodule

module MIPS_Pipeline (
	clk,
	rst_n,
	ICACHE_ren,
	ICACHE_wen,
	ICACHE_addr,
	ICACHE_wdata,
	ICACHE_stall,
	ICACHE_rdata,
	DCACHE_ren,
	DCACHE_wen,
	DCACHE_addr,
	DCACHE_wdata,
	DCACHE_stall,
	DCACHE_rdata
);
input 	clk, rst_n;
//----------I Cache Interface-------
output  ICACHE_ren, ICACHE_wen;
output  [29:0] 	ICACHE_addr;
output  [31:0] 	ICACHE_wdata;
input         	ICACHE_stall;
input  	[31:0] 	ICACHE_rdata;
//----------D Cache Interface-------
output  DCACHE_ren, DCACHE_wen;
output  [29:0] 	DCACHE_addr;
output  [31:0] 	DCACHE_wdata;
input         	DCACHE_stall;
input  	[31:0] 	DCACHE_rdata;

//========= Pipeline Reg Declaration =========
//--------- First Half -----------------------
reg 	[31:0]	S1_PC, S1_PC_nxt;
reg 	[31:0]	S1_inst, S1_inst_nxt;
// WB = RegWrite + MemToReg
reg 	[1:0] 	S2_WB, S2_WB_nxt;
// M = Branch + MemRead + MemWrite
reg		[2:0]	S2_M, S2_M_nxt;
// EX = RegDst + ALUOp + ALUSrc
reg 	[3:0]	S2_EX, S2_EX_nxt;
reg 	[31:0]	S2_PC, S2_PC_nxt;
reg 	[31:0]	S2_rdata1, S2_rdata1_nxt;
reg 	[31:0]	S2_rdata2, S2_rdata2_nxt;
reg 	[31:0]	S2_I1, S2_I1_nxt;
reg 	[4:0]	S2_I2, S2_I2_nxt;
reg 	[4:0]	S2_I3, S2_I3_nxt;
//---------- Second Half ---------------------
reg 	[1:0]	S3_WB, S3_WB_nxt;
reg 	[2:0]	S3_M, S3_M_nxt;
reg 	[31:0]	S3_Add, S3_Add_nxt;
reg 	S3_Zero, S3_Zero_nxt;
reg 	[31:0]	S3_ALUResult, S3_ALUResult_nxt;
reg 	[31:0]	S3_rdata, S3_rdata_nxt;
reg 	[4:0]	S3_I, S3_I_nxt;
reg 	S4_WB, S4_WB_nxt;
reg 	[31:0]	S4_rdata, S4_rdata_nxt;
reg 	[31:0]	S4_ALUResult, S4_ALUResult_nxt;
reg 	[4:0]	S4_I, S4_I_nxt;

//========= Wire ============================
wire 	PCSrc;
wire 	RegWrite;
wire 	[31:0]	WriteData;
wire 	[4:0]	WriteReg;

//========= First Part ======================
// ID
assign	RegWrite = S4_WB[1];
assign	WriteData = S4_WB[0] ? S4_rdata : S4_ALUResult;
assign	WriteReg = S4_I;

//========= Second Part =====================
// EX
reg 	[2:0]	ALUControl;
wire 	[31:0]	ALU1;
wire 	[31:0]	ALU2;
assign	ALU1 = S2_rdata1;
assign	ALU2 = S2_EX[0] ? S2_I1 : S2_rdata2;
always @(*) begin
	S3_Add_nxt = S3_Add;
	S3_WB_nxt = S3_WB;
	S3_M_nxt = S3_M;
	S3_Zero_nxt = S3_Zero;
	S3_ALUResult_nxt = S3_ALUResult;
	S3_rdata_nxt = S3_rdata;
	S3_I_nxt = S3_I;
	if(!ICACHE_stall && !DCACHE_stall) begin
		S3_WB_nxt = S2_WB;
		S3_M_nxt = S2_M;
		S3_Add_nxt = (S2_I1 << 2) + S2_PC;
		case (S2_EX[2:1])
            0: ALUControl = 2; // add
            1: ALUControl = 6; // subtract
            2: case (S2_I1[5:0])
                6'b100000: ALUControl = 2; // add
                6'b100010: ALUControl = 6; // subtract
                6'b100100: ALUControl = 0; // and
                6'b100101: ALUControl = 1; // or
                6'b101010: ALUControl = 7; // set on less than
                default: ALUControl = 0;
            endcase
            default: ALUControl = 0;
        endcase
		case (ALUControl)
            2: begin
                S3_ALUResult_nxt = ALU1 + ALU2;
                S3_Zero_nxt = 0;
            end 
            6: begin
                S3_ALUResult_nxt = ALU1 - ALU2;
                S3_Zero_nxt = (S3_ALUResult_nxt == 0);
            end
            0: begin
                S3_ALUResult_nxt = ALU1 & ALU2;
                S3_Zero_nxt = 0;
            end
            1: begin
                S3_ALUResult_nxt = ALU1 | ALU2;
                S3_Zero_nxt = 0;
            end
            7: begin
                S3_ALUResult_nxt = ($signed(ALU1) < $signed(ALU2));
                S3_Zero_nxt = 0;
            end
            default: begin
                S3_ALUResult_nxt = S3_ALUResult;
                S3_Zero_nxt = S3_Zero;
            end
        endcase
		S3_rdata_nxt = S2_rdata2;
		if (S2_EX[3]) begin
			S3_I_nxt = S2_I3;
		end
		else begin
			S3_I_nxt = S2_I2;
		end
	end
end

// MEM
assign 	DCACHE_addr = S3_ALUResult;
assign	DCACHE_wdata = S3_rdata;
assign	DCACHE_wen = S3_M[0];
assign	DCACHE_ren = S3_M[1];
assign	PCSrc = S3_M[2] && S3_Zero;
always @(*) begin
	S4_rdata_nxt = S4_rdata;
	S4_WB_nxt = S4_WB;
	S4_ALUResult_nxt = S4_ALUResult;
	S4_I_nxt = S4_I;
	if (!ICACHE_stall && !DCACHE_stall) begin
		S4_rdata_nxt = DCACHE_rdata;
		S4_WB_nxt = S3_WB;
		S4_ALUResult_nxt = S3_ALUResult;
		S4_I_nxt = S3_I;
	end
end
//======== Sequetial Part =======================
always @(posedge clk or negedge rst_n) begin
	if(!rst_n)begin
		S1_PC 			<= 0;
		S1_inst 		<= 0;
		S2_WB 			<= 0;
		S2_M 			<= 0;
		S2_EX 			<= 0;
		S2_I1 			<= 0;
		S2_I2 			<= 0;
		S2_I3 			<= 0;
		S2_rdata1 		<= 0;
		S2_rdata2 		<= 0;
		S2_PC 			<= 0;
		S3_WB 			<= 0;
		S3_M 			<= 0;
		S3_Add 			<= 0;
		S3_Zero 		<= 0;
		S3_ALUResult 	<= 0;
		S3_rdata 		<= 0;
		S3_I 			<= 0;
		S4_WB 			<= 0;
		S4_rdata 		<= 0;
		S4_ALUResult 	<= 0;
		S4_I 			<= 0;
	end
	else begin
		S1_PC 			<= S1_PC_nxt;
		S1_inst 		<= S1_inst_nxt;
		S2_WB 			<= S2_WB_nxt;
		S2_M 			<= S2_M_nxt;
		S2_EX 			<= S2_EX_nxt;
		S2_I1 			<= S2_I1_nxt;
		S2_I2 			<= S2_I2_nxt;
		S2_I3 			<= S2_I3_nxt;
		S2_rdata1 		<= S2_rdata1_nxt;
		S2_rdata2 		<= S2_rdata2_nxt;
		S2_PC 			<= S2_PC_nxt;
		S3_WB 			<= S3_WB_nxt;
		S3_M 			<= S3_M_nxt;
		S3_Add 			<= S3_Add_nxt;
		S3_Zero 		<= S3_Zero_nxt;
		S3_ALUResult 	<= S3_ALUResult_nxt;
		S3_rdata 		<= S3_rdata_nxt;
		S3_I 			<= S3_I_nxt;
		S4_WB 			<= S4_WB_nxt;
		S4_rdata 		<= S4_rdata_nxt;
		S4_ALUResult 	<= S4_ALUResult_nxt;
		S4_I 			<= S4_I_nxt;
	end
end

endmodule



// Cache
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
    output         proc_stall;
    output  [31:0] proc_rdata;
    // memory interface
    input  [127:0] mem_rdata;
    input          mem_ready;
    output         mem_read, mem_write;
    output  [27:0] mem_addr;
    output [127:0] mem_wdata;

//==== parameters =========================================

    parameter WORDLEN = 32;
    parameter BLOCKNUM = 4;
    parameter TAGLEN = 26;

    parameter NONE = 2'd0;
    parameter ONE = 2'd1;
    parameter TWO = 2'd2;

    parameter IDLE = 3'd0;
    parameter COMPARE = 3'd1;
    parameter ALLOCATE = 3'd2;
    parameter WRITEBACK = 3'd3;
    parameter READ = 3'd4;
    parameter WRITE = 3'd5;
    
//==== wire/reg definition ================================
    
    /// internal FF
    // state
    reg     [2:0]   state, state_nxt;
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
    reg     mem_read, mem_read_nxt;
    reg     mem_write, mem_write_nxt;
    reg     [27:0]  mem_addr, mem_addr_nxt;
    reg     [127:0] mem_wdata, mem_wdata_nxt;

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

//==== combinational circuit ==============================

assign block_now = proc_addr[3:2];
assign tag_now = proc_addr[29:4];
assign word_idx = proc_addr[1:0];

assign hit1 = (valid1[block_now]) && (tag1[block_now] == tag_now);
assign hit2 = (valid2[block_now]) && (tag2[block_now] == tag_now);
assign miss1_clean = ~hit1 && ~dirty1[block_now];
assign miss2_clean = ~hit2 && ~dirty2[block_now];
assign miss1_dirty = ~hit1 && dirty1[block_now];
assign miss2_dirty = ~hit2 && dirty2[block_now];
assign hit = hit1 || hit2;
assign miss = ~hit;

always @(*) begin // FSM
    state_nxt = state;
    set_nxt = NONE;
    proc_stall_nxt = 0;
    case (state)
        IDLE: begin
            //$display("idle");
            if (proc_read || proc_write) begin
                state_nxt = COMPARE;
                proc_stall_nxt = 1;
                set_nxt = NONE;
            end
            else begin
                state_nxt = IDLE;
                proc_stall_nxt = 0;
                set_nxt = NONE;
            end
        end 
        COMPARE: begin
            //$display("compare");
            proc_stall_nxt = 1;
            if (hit) begin
                if (proc_write && ~proc_read) begin
                    state_nxt = WRITE;
                end
                else if (proc_read && ~proc_write) begin
                    state_nxt = READ;
                end
                else state_nxt = IDLE;

                if (hit1) begin
                    set_nxt = ONE;
                end
                else if (hit2) begin
                    set_nxt = TWO;
                end
                else set_nxt = NONE;
            end
            else begin
                if (miss1_clean) begin
                    state_nxt = ALLOCATE;
                    set_nxt = ONE;
                end
                else if (miss1_dirty) begin
                    state_nxt = WRITEBACK;
                    set_nxt = ONE;
                end
                else if (miss2_clean) begin
                    state_nxt = ALLOCATE;
                    set_nxt = TWO;
                end
                else if (miss2_dirty) begin
                    state_nxt = WRITEBACK;
                    set_nxt = TWO;
                end
                else begin
                    state_nxt = ALLOCATE;
                    set_nxt = ONE;
                end
            end
        end
        READ: begin
            //$display("read");
            state_nxt = IDLE;
            proc_stall_nxt = 0;
            set_nxt = NONE;
        end
        WRITE: begin
            //$display("write");
            state_nxt = IDLE;
            proc_stall_nxt = 0;
            set_nxt = NONE;
        end
        ALLOCATE: begin
            //$display("allocate");
            proc_stall_nxt = 1;
            set_nxt = set;
            if (mem_ready) begin
                if(proc_read && ~proc_write) begin
                    state_nxt = READ;
                end
                else if (proc_write && ~proc_read) begin
                    state_nxt = WRITE;
                end
            end
            else begin
                state_nxt = ALLOCATE;
            end
        end
        WRITEBACK: begin
            //$display("writeback");
            proc_stall_nxt = 1;
            set_nxt = set;
            if (mem_ready) begin
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
    mem_read_nxt = 0;
    mem_write_nxt = 0;
    mem_addr_nxt = 0;
    mem_wdata_nxt = 0;

    case (state)
        READ: begin
            if (set == ONE) begin
                case (word_idx)
                    0: proc_rdata_nxt = cch1[block_now][31:0];
                    1: proc_rdata_nxt = cch1[block_now][63:32];
                    2: proc_rdata_nxt = cch1[block_now][95:64];
                    3: proc_rdata_nxt = cch1[block_now][127:96];
                    default: proc_rdata_nxt = 0; 
                endcase
            end
            else if (set == TWO) begin
                case (word_idx)
                    0: proc_rdata_nxt = cch2[block_now][31:0];
                    1: proc_rdata_nxt = cch2[block_now][63:32];
                    2: proc_rdata_nxt = cch2[block_now][95:64];
                    3: proc_rdata_nxt = cch2[block_now][127:96];
                    default: proc_rdata_nxt = 0; 
                endcase
            end
        end 
        WRITE: begin
            if (set == ONE) begin
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
            else if (set == TWO) begin
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
        ALLOCATE: begin
            if (~mem_ready) begin
                mem_read_nxt = 1;
                mem_write_nxt = 0;
                mem_wdata_nxt = 0;
                mem_addr_nxt = proc_addr[29:2];
            end
            else begin
                if (set == ONE) begin
                    tag1_nxt[block_now] = tag_now;
                    valid1_nxt[block_now] = 1;
                    dirty1_nxt[block_now] = 0;
                    cch1_nxt[block_now] = mem_rdata;
                end
                else if (set == TWO) begin
                    tag2_nxt[block_now] = tag_now;
                    valid2_nxt[block_now] = 1;
                    dirty2_nxt[block_now] = 0;
                    cch2_nxt[block_now] = mem_rdata;
                end
            end
        end
        WRITEBACK: begin
            if (~mem_ready) begin
                mem_write_nxt = 1;
                if (set == ONE) begin
                    mem_wdata_nxt = cch1[block_now];
                    mem_addr_nxt = {tag1[block_now],block_now};
                end
                else if (set == TWO) begin
                    mem_wdata_nxt = cch2[block_now];
                    mem_addr_nxt = {tag2[block_now],block_now};
                end
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
            mem_read_nxt = 0;
            mem_write_nxt = 0;
            mem_addr_nxt = 0;
            mem_wdata_nxt = 0;
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
        mem_read        <= 0;
        mem_write       <= 0;
        mem_addr        <= 0;
        mem_wdata       <= 0;
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
        mem_read        <= mem_read_nxt;
        mem_write       <= mem_write_nxt;
        mem_addr        <= mem_addr_nxt;
        mem_wdata       <= mem_wdata_nxt;
    end
end

endmodule