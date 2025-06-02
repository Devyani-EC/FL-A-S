module add_sub(A,B,op_add,result);
    input  [31:0] A, B;
    input         op_add;  // 1 = add, 0 = subtract
    output reg [31:0] result;

    reg [31:0] A_swap, B_swap;
    reg [23:0] A_Mantissa, B_Mantissa, Temp_Mantissa, B_shifted_mantissa;
    reg [22:0] Mantissa;
    reg [7:0]  A_Exponent, B_Exponent, Exponent=0;
    reg        A_sign, B_sign, Sign;
    reg [7:0] diff_Exponent; 
    reg        carry;
    wire        comp;
    integer    i;

FloatingCompare comp_abs(.A({1'b0, A[30:0]}), .B({1'b0, B[30:0]}), .result(comp));

always @(*) begin
// (switch numbers if needed)
A_swap = comp ? A : B;
B_swap = comp ? B : A;
A_sign = A_swap[31];
B_sign = B_swap[31];
A_Exponent = A_swap[30:23];
B_Exponent = B_swap[30:23];

if (A_swap[30:23] == 8'h00) begin // Denormal
    A_Mantissa = {1'b0, A_swap[22:0]};
end else if (A_swap[30:23] == 8'hFF) begin // Inf or NaN  Bypass or raise flag
end else begin// Normalized
    A_Mantissa = {1'b1, A_swap[22:0]};
end

if (B_swap[30:23] == 8'h00) begin// Denormal
    B_Mantissa = {1'b0, B_swap[22:0]};
end else if (B_swap[30:23] == 8'hFF) begin // Inf or NaN Bypass or raise flag
end else begin // Normalized
    B_Mantissa = {1'b1, B_swap[22:0]};
end

// shift B to same exponent 
diff_Exponent = A_Exponent-B_Exponent;
B_shifted_mantissa = (B_Mantissa >> diff_Exponent);

if (op_add) begin
    {carry, Temp_Mantissa} = (A_sign ~^ B_sign) ? A_Mantissa + B_shifted_mantissa : A_Mantissa - B_shifted_mantissa;
    Exponent = A_Exponent;
end else begin
    {carry, Temp_Mantissa} = (A_sign ~^ B_sign) ? A_Mantissa - B_shifted_mantissa : A_Mantissa + B_shifted_mantissa;
    Exponent = A_Exponent;
end

// adjust mantissa to format 1.xxxx (bit 23 is 1)
if(carry) begin
    Temp_Mantissa = Temp_Mantissa>>1;
    Exponent = (Exponent < 8'hff) ? Exponent + 1 : 8'hff;  // protect exponent overflow
end
else if(|Temp_Mantissa != 1'b1) begin// mantissa contains no 1 or unknown value (result should be 0)
    Temp_Mantissa = 0;
end
else begin
        // 1st bit is not 1, but there is some 1 in the mantissa (protecting exponent underflow)
        // fixed limit of iterations because Vivado saw this as an infinite loop
    for(i = 0; Temp_Mantissa[23] !== 1'b1 && Exponent > 0 && i < 24; i = i + 1) begin
        Temp_Mantissa = Temp_Mantissa << 1;
        Exponent = Exponent - 1;
    end
end
if (!op_add) begin
    if ((!A[31]) && (B[31]))
        Sign = A[31];
    else if ((A[31]) && (!B[31]))
        Sign = A[31];
    else if ((!A[31]) &&(!B[31])) begin
        if(!comp) Sign = 1'b1;
        else Sign = 1'b0;
    end else if ((A[31]) && (B[31])) begin
        if(!comp) Sign = 1'b0;
        else Sign = 1'b1;
    end else if ((!A[31]) && (!B[31]))begin
        if(!comp) Sign = 1'b1;
        else Sign = 1'b0;
    end 
end else begin
    Sign = A_sign;
end

if(Temp_Mantissa == 0) begin 
    Sign = 0;
    Exponent =0;
end  

Mantissa = Temp_Mantissa[22:0];
result = {Sign,Exponent,Mantissa};
end
endmodule	

module FloatingCompare (input [31:0]A,
                        input [31:0]B,
                        output reg result);

always @(*) begin
        // compare signs
        if (A[31] != B[31])
            result = ~A[31];  // A is positive (0) -> A >= B -> result = 1

        // compare exponents
        else begin
            if (A[30:23] != B[30:23]) begin
                result = (A[30:23] > B[30:23]) ? 1'b1 : 1'b0;  
            end
            // compare mantissas
            else begin
                if(A[22:0] != B[22:0])begin
                    result = (A[22:0] > B[22:0]) ? 1'b1 : 1'b0;  
                end else begin 
                    result = 1'b1;
                end
            end 
        end
  
end

endmodule
