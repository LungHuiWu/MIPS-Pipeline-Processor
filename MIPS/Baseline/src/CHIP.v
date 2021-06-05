`include "cache.v"
`include "ALU.v"
`include "Control.v"
`include "Register.v"
`include "ForwardUnit.v"
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
// EX = RegDst + ALUSrc + ALUControl
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
reg 	[1:0]   S4_WB, S4_WB_nxt;                       // need [1:0] ?
reg 	[31:0]	S4_rdata, S4_rdata_nxt;
reg 	[31:0]	S4_ALUResult, S4_ALUResult_nxt;
reg 	[4:0]	S4_I, S4_I_nxt;

//========= Wire ============================
wire 	        PCSrc;
wire 	[31:0]	PC4_A_SE_SL2;	// PC+4 + Address with Sign Extend Shift Left 2
wire 			Equal;			// ReadData1 and ReadData2 are equal					

//========= Registers =========================
wire            RegWrite;
wire    [4:0]   ReadReg1;
wire    [4:0]   ReadReg2;    
wire 	[4:0]	WriteReg;
wire 	[31:0]	WriteData;
wire 	[31:0]	ReadData1;
wire 	[31:0]	ReadData2;

Registers register(
    .clk(clk), 
    .rst_n(rst_n),
    .RegWrite(RegWrite),
    .Read_register_1(ReadReg1),
    .Read_register_2(ReadReg2),
    .Write_register(WriteReg),
    .Write_data(WriteData),
    .Read_data_1(ReadData1),
    .Read_data_2(ReadData2),
);
//========= Control =========================

wire 	[1:0]   WB; 
wire 	[2:0]   M;
wire 	[5:0]   EX;
wire 	        Jump;

Control control(
    .opcode(S1_inst[31:26]),
    .funct(S1_inst[5:0]),
    .WB(WB),
    .M(M),
    .EX(EX),
    .Jump(Jump)
);
//========= ALU =============================
wire 	[31:0]	Alu_data1;
wire 	[31:0]	Alu_data2;

ALU alu(
    .in1(Alu_data1),
    .in2(Alu_data2),
    .out(),
    .ALUControl(S2_EX[3:0])
);
//========= Forwarding Unit==================
ForwardUnit FWU(
    .ExMemRd(S3_I), 
    .MemWbRd(S4_I),
    .IdExRs(S2_I2),
    .IdExRt(S2_I3),
    .ExMem_RegWrite(S3_WB[1]),
    .MemWb_RegWrite(S4_WB[1]),
    .ExMem_data(S3_ALUResult),
    .MemWb_data(WriteData),
    .IdEx_data1(S2_rdata1),
    .IdEx_data2(S2_rdata2),
    .Alu_data1(Alu_data1),
    .Alu_data2(Alu_data2)
);
//========= First Part ======================
// IF

always @(*) begin
    S1_PC_nxt = S1_PC;
    S1_inst_nxt = S1_inst;
    if(!ICACHE_stall && !DCACHE_stall) begin
        if (PCSrc) begin
            S1_PC_nxt = PC4_A_SE_SL2 + 4;         // for branch
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
assign  ReadReg2 = S1_inst[20:16];
assign 	PC4_A_SE_SL2 = S1_PC + {{16{S1_inst[15]}},S1_inst[15:0]}<<2;
assign  Equal = (ReadData1 == ReadData2);	

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
        S2_WB_nxt = WB;        // from Control WB     
        S2_M_nxt = M;          // from Control M      
        S2_EX_nxt = EX;        // from Control EX    
        S2_PC_nxt = S1_PC;
        S2_rdata1_nxt = ReadData1,    // from Registers ReadData1
        S2_rdata2_nxt = ReadData2;    // from Registers ReadData2
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

