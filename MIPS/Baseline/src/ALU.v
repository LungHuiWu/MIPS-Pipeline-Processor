module ALU(
    in1,
    in2,
    out,
    ALUControl
);

input      [31:0]      in1, in2;
output reg [31:0]      out;
input      [3:0]       ALUControl;

always @(*) begin
    case (ALUControl)
        4'b0010: begin
            out = in1 + in2; // addu
        end 
        4'b0110: begin
            out = in1 - in2; // subu
        end
        4'b0000: begin
            out = in1 & in2; // and
        end
        4'b0001: begin
            out = in1 | in2; // or
        end
        4'b0111: begin
            out = ($signed(in1) < $signed(in2)); // slt
        end
        4'b1001: begin
            out = in1 ^ in2; // xor
        end
        4'b1010: begin
            out = in1 << in2; // sll
        end
        4'b1011: begin
            out = $signed(in1) >>> in2; // sra
        end
        4'b1100: begin
            out = ~(in1 | in2); // nor
        end
        4'b1110: begin
            out = (in1 < in2); // sltu
        end
        4'b0011: begin
            out = in1 >> in2; // srl
        end
        default: begin
            out = 0;
        end
    endcase
end

endmodule