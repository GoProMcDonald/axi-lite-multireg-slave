module tb_axi_lite_slave_regs;
    logic clk, rst_n;

    // AXI信号定义
    logic [31:0] awaddr, wdata, araddr;
    logic        awvalid, wvalid, arvalid;
    logic        awready, wready, arready;

    logic [3:0]  wstrb;
    logic [1:0]  bresp, rresp;
    logic        bvalid, rvalid;
    logic        bready, rready;
    logic [31:0] rdata;

    // 实例化DUT
    axi_lite_slave_regs #(.REG_NUM(4)) dut (//axi_lite_slave_regs是模块名，即你要例化的那个模块。dut是例化出来的模块实例名，相当于给这个模块取个名字
        .clk(clk), .rst_n(rst_n),//前面的名字（比如.awaddr）是模块里定义的端口名。括号里的名字（比如awaddr）是testbench里实际的信号名
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wstrb(wstrb), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .araddr(araddr), .arvalid(arvalid), .arready(arready),
        .rdata(rdata), .rresp(rresp), .rvalid(rvalid), .rready(rready)
    );

    // 时钟与复位
    initial clk = 0;
    always #5 clk = ~clk;
    initial begin//复位信号初始化
        rst_n = 0;
        awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
        #20 rst_n = 1;
    end

    // 写任务
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);
    begin
        @(posedge clk);
        awaddr  <= addr;
        awvalid <= 1;
        wdata   <= data;
        wvalid  <= 1;
        wstrb   <= 4'b1111;

        // 并行等待两个通道握手后再拉低 valid
        fork
            begin
                wait (awready && awvalid);
                @(posedge clk);
                awvalid <= 0;
            end
            begin
                wait (wready && wvalid);
                @(posedge clk);
                wvalid <= 0;
            end
        join

        // 写响应握手
        bready <= 1;
        wait (bvalid);
        @(posedge clk);
        bready <= 0;
    end
    endtask

    // 读任务
task automatic axi_read(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] addr,
    output logic [31:0] data
);
    // Step 1: 发出读请求
    araddr  <= addr;
    arvalid <= 1;

    // Step 2: 等待从机响应 ARREADY
    wait (arready && arvalid);
    @(posedge clk);
    arvalid <= 0;

    // Step 3: 等待从机返回数据
    wait (rvalid);
    @(posedge clk); // 等一个时钟确保 RDATA 被采样
    data <= rdata;

    // Step 4: 主动响应 RREADY
    rready <= 1;
    @(posedge clk);
    rready <= 0;

    // 可选：打印结果
    $display("AXI READ: addr = 0x%08x, data = 0x%08x", addr, data);
endtask

    logic [31:0] rdata0, rdata1;

initial begin
    // 初始化
    clk    = 0;
    rst_n  = 0;
    #20;
    rst_n  = 1;

    // 写入数据
    axi_write(clk, rst_n, 32'h00000000, 32'hA5A50000);
    axi_write(clk, rst_n, 32'h00000004, 32'hDEAD1234);

    // 读取回来
    axi_read(clk, rst_n, 32'h00000000, rdata0);
    axi_read(clk, rst_n, 32'h00000004, rdata1);

    $display("Read Back: rdata0 = 0x%08x, rdata1 = 0x%08x", rdata0, rdata1);


    // 主仿真流程
    logic [31:0] rd_data;
    integer i;

    initial begin
        $dumpfile("dump.vcd");  // 指定VCD波形文件名
        $dumpvars(0, tb_axi_lite_slave_regs); // tb模块名改成你的testbench模块名
        wait(rst_n == 1);// 等待复位信号稳定
        // 写入4个寄存器
        for (i=0; i<4; i=i+1) begin
            axi_write(i*4, 32'hA5A5_0000 + i);//32'hA5A50000为起始值，依次写入4个寄存器，每个比上一个多1
        end
        // 依次读回
        for (i=0; i<4; i=i+1) begin
            axi_read(i*4, rd_data);//调用axi_read任务，把DUT读出的数据写到rd_data变量里
            $display("reg[%0d]=%h", i, rd_data);
        end
        // 读非法地址
        axi_read(32'h20, rd_data);
        $display("read invalid addr: %h (should be DEAD_BEEF)", rd_data);
        #100 $finish;
    end

endmodule
