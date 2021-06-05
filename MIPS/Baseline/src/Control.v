module Control(
    //input 
    opcode, //Instruction[31:26]
    funct,  //Instruction[5:0]
    //output 
    WB,
    M,
    EX,
    Beq,
    Bne,
    Jump
);
output  [1:0] WB;
output  [1:0] M;
output  [5:0] EX;
output        Jump;
output        Beq;
output        Bne;
input   [5:0] opcode;
input   [5:0] funct;

parameter AND   = 4'b0000;
parameter OR    = 4'b0001;
parameter ADD   = 4'b0010;
parameter SRL   = 4'b0011;
parameter SUB   = 4'b0110;
parameter SLT   = 4'b0111;
parameter XOR   = 4'b1001;
parameter SLL   = 4'b1010;
parameter SRA   = 4'b1011;
parameter NOR   = 4'b1100;
parameter SLTI  = 4'b1110;

reg       RegWrite;
reg       MemtoReg; 
reg       Beq;     
reg       Bne;     
reg       MemRead;    
reg       MemWrite;   
reg       RegDst;     
reg       ALUSrc;
reg [3:0] ALUControl;
reg       Jump;       

assign WB = {RegWrite, MemtoReg};
assign M  = {MemRead, MemWrite};
assign EX = {RegDst, ALUSrc, ALUControl};

always @(*) begin

    RegWrite    = 1'b1;
    MemtoReg    = 1'b0;
    Beq         = 1'b0;
    Bne         = 1'b0;
    MemRead     = 1'b0;
    MemWrite    = 1'b0;
    RegDst      = 1'b0;
    ALUControl  = ADD;
    ALUSrc      = 1'b1;
    Jump        = 1'b0;

    // brute force solution
    case (opcode)
        
        6'b000000: begin // R type
            RegDst      = 1'b1;
            ALUSrc      = 1'b0;
            case (funct)
                6'b100000: begin // ADD
                    ALUControl  = ADD;
                end
                6'b100010: begin // SUB
                    ALUControl  = SUB;
                end
                6'b100100: begin // AND
                    ALUControl  = AND;
                end
                6'b100101: begin // OR
                    ALUControl  = OR;
                end
                6'b100110: begin // XOR
                    ALUControl  = XOR;
                end
                6'b100111: begin // NOR
                    ALUControl  = NOR;
                end
                6'b000000: begin // SLL
                    ALUControl  = SLL;
                end
                6'b000011: begin // SRA
                    ALUControl  = SRA;
                end
                6'b000010: begin // SRL
                    ALUControl  = SRL;
                end
                6'b101010: begin // SLT
                    ALUControl  = SLT;
                end
                6'b001000: begin // JA
                    Jump        = 1'b1;
                end
                6'b001001: begin // JALR
                    Jump        = 1'b1;
                end
                default begin

                end
            endcase
        end
        6'b001000: begin // ADDI
            ALUControl = ADD;
        end
        6'b001100: begin // ANDI
            ALUControl = AND;
        end
        6'b001101: begin // ORI
            ALUControl = OR;
        end
        6'b001110: begin // XORI
            ALUControl = XOR;
        end
        6'b001010: begin // SLTI
            ALUControl = SLT;
        end
        6'b000100: begin // BEQ
            RegWrite    = 1'b0;
            Beq      = 1'b1;
            ALUControl = SUB;
        end
        6'b000101: begin // BNE
            RegWrite    = 1'b0;
            Bne      = 1'b1;
            ALUControl = SUB;
        end
        6'b100011: begin // LW
            MemtoReg    = 1'b1;
            MemRead     = 1'b1;
            ALUControl = ADD;
        end
        6'b101011: begin // SW
            RegWrite    = 1'b0;
            MemWrite    = 1'b1;
            ALUControl = ADD;
        end
        6'b000010: begin // J
            ALUControl = ADD;
            Jump        = 1'b1
        end
        6'b000011: begin // JAL
            ALUControl = ADD;
            Jump        = 1'b1;
        end  
        default begin
            RegWrite    = 1'b1;
            MemtoReg    = 1'b0;
            Beq         = 1'b0;
            Bne         = 1'b0;
            MemRead     = 1'b0;
            MemWrite    = 1'b0;
            RegDst      = 1'b0;
            ALUControl  = ADD;
            ALUSrc      = 1'b1;
            Jump        = 1'b0;
        end
    endcase
end
       
endmodule