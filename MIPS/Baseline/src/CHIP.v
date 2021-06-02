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
reg 	S4_WB, S4_WB_nxt;                       // need [1:0] ?
reg 	[31:0]	S4_rdata, S4_rdata_nxt;
reg 	[31:0]	S4_ALUResult, S4_ALUResult_nxt;
reg 	[4:0]	S4_I, S4_I_nxt;

//========= Wire ============================
wire 	PCSrc;
wire 	RegWrite;
wire 	[31:0]	WriteData;
wire 	[4:0]	WriteReg;

//========= First Part ======================
// IF

always @(*) begin
    S1_PC_nxt = S1_PC;
    S1_inst_nxt = S1_inst;
    if(!ICACHE_stall && !DCACHE_stall) begin
        if (PCSrc) begin
            S1_PC_nxt = S3_Add;         // for branch
        end
        else begin
            S1_PC_nxt = S1_PC + 4;      // normal
        end
        S1_inst_nxt = ICACHE_rdata;
    end
end

// ID
assign	RegWrite = S4_WB[1];
assign	WriteData = S4_WB[0] ? S4_rdata : S4_ALUResult;
assign	WriteReg = S4_I;
assign  ReadReg1 = S1_inst[25:21];
assign  ReadReg2 = S1_inst[20:26];

always @(*) begin
    S2_WB_nxt = S2_WB;
    S2_M_nxt = S2_M;
    S2_EX_nxt = S2_EX;
    S2_PC_nxt = S2_PC;
    S2_rdata1_nxt = S2_rdata1;
    S2_rdata2_nxt = S2_rdata2;
    S2_I1_nxt = S2_I1;
    S2_I2_nxt = S2_I2;
    S2_I3_nxt = S2_I3;

    if(!ICACHE_stall && !DCACHE_stall) begin
        S2_WB_nxt = {RegWrite, MemToReg};           // from Control WB     
        S2_M_nxt = {Branch, MemRead, MemWrite};     // from Control M      
        S2_EX_nxt = {RegDst, ALUOp, ALUSrc};        // from Control EX    
        S2_PC_nxt = S1_PC;
        S2_rdata1_nxt = ReadReg1,    // to Registers ReadReg1
        S2_rdata2_nxt = ReadReg2;    // to Registers ReadReg2
        S2_I1_nxt = {{16{S1_inst[15]}},S1_inst[15:0]};
        S2_I2_nxt = S1_inst[20:16];
        S2_I3_nxt = S1_inst[15:11];
    end
end

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