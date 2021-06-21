`include "L1_dm_new.v"
`include "L2_dm_new.v"
module L2_Cache(
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

//==== Input/Output definition ============================
    
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

// ==== Wires & Regs ======================================

    wire     [29:0]  addr;
    wire     read, write;
    wire     [127:0]  wdata, rdata;
    wire     ready;
    wire     stall;

// ==== Link Submodule ====================================

    L1  l1(
        .clk        (clk)   ,
        .proc_reset (proc_reset)    ,
        .proc_read  (proc_read)     ,
        .proc_write (proc_write)    ,
        .proc_addr  (proc_addr)     ,
        .proc_wdata (proc_wdata)    ,
        .proc_stall (proc_stall)    ,
        .proc_rdata (proc_rdata)    ,
        .addr       (addr)  ,
        .read       (read)  ,
        .write      (write) ,
        .wdata      (wdata) ,
        .rdata      (rdata) ,
        .ready      (ready),
        .stall      (stall)
    );

    L2  l2(
        .clk        (clk)   ,
        .reset      (proc_reset) ,
        .addr       (addr)  ,
        .read       (read)  ,
        .write      (write) ,
        .wdata      (wdata) ,
        .rdata      (rdata) ,
        .ready      (ready) ,
        .stall      (stall) ,
        .mem_read   (mem_read)  ,
        .mem_write  (mem_write) ,
        .mem_addr   (mem_addr)  ,
        .mem_wdata  (mem_wdata) ,
        .mem_rdata  (mem_rdata) ,
        .mem_ready  (mem_ready)
    );

endmodule

    