`include "mycpu_top.h"
// pre-if 计算next_pc
// if 通过next_pc对inst_ram发起取指请求
module IF(
    input  wire        clk,
    input  wire        reset,

    // bram interface
    output wire        inst_sram_en,
    output wire [3:0]  inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    // bus
    output [`IF_TO_ID_BUS_WIDTH:0] if_to_id_bus,
    input [`ID_TO_IF_BUS_WIDTH:0] id_to_if_bus,

    // pipeline 
    input id_allow_in,
    output if_to_id_valid
);

// input id_to_if_bus
wire [31:0] br_target;
wire        br_taken;

assign {
    br_taken,
    br_target
} = id_to_if_bus;

// output if_to_id_bus
wire [31:0] inst;
reg  [31:0] if_pc;

assign if_to_id_bus = {
    inst,
    if_pc
};

// pipeline control
reg if_valid;
wire if_allow_in;
wire if_ready_go;
wire pre_if_valid;

// 下面这段是什么意思？
always @(posedge clk) begin
    if(reset) begin
        if_valid <= 1'b0;
    end else if(if_allow_in) begin
        if_valid <= pre_if_valid; // if级只要allow_in，可以源源不断
    end
end

// pre if stage
// 流入if阶段的是nextpc
wire [31:0] seq_pc;
wire [31:0] next_pc;

assign seq_pc       = if_pc + 3'h4;
assign next_pc       = br_taken ? br_target : seq_pc;
assign pre_if_valid = ~reset;


// IF stage
assign if_ready_go = 1'b1; 
assign if_to_id_valid = if_valid && if_ready_go;
assign if_allow_in = !if_valid || (if_ready_go && id_allow_in);

always @(posedge clk) begin
    if (reset) begin
        if_pc <= 32'h1bfffffc;  // error!! trick! to make nextpc be 0x1c000000 during reset 
    end
    else if(if_allow_in && pre_if_valid) begin // why?
        if_pc <= next_pc;
    end
end

assign inst_sram_en    = pre_if_valid && if_allow_in; //  why?
assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = next_pc; // 从 pc to nextpc
assign inst_sram_wdata = 32'b0;
assign inst            = inst_sram_rdata;

endmodule //IF
