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
    task automatic axi_write(input logic [31:0] addr, input logic [31:0] data);//定义一个自动任务axi_write，用于执行写操作
    begin
        @(posedge clk);
        awaddr  <= addr;
        awvalid <= 1;
        wdata   <= data;
        wvalid  <= 1;
        wstrb   <= 4'b1111;// 假设全写使能
        // 等待AWREADY和WREADY
        wait (awready && awvalid); @(posedge clk);//等待slave拉高awready，完成写地址通道握手
        awvalid <= 0;// 写地址握手完成后，将awvalid复位
        wait (wready && wvalid); @(posedge clk);//等待slave拉高wready，完成写数据通道握手
        wvalid <= 0;// 写数据握手完成后，将wvalid复位
        // 等待BVALID
        bready <= 1;// 准备接受写响应
        wait (bvalid);//等待slave拉高bvalid，表示写响应有效
        @(posedge clk);
        bready <= 0;// 写响应握手完成后，将bready复位
    end
    endtask

    // 读任务
    task automatic axi_read(input logic [31:0] addr, output logic [31:0] data);//定义一个自动任务axi_read，用于执行读操作
    begin
        @(posedge clk);
        araddr  <= addr;
        arvalid <= 1;
        wait (arready && arvalid); @(posedge clk);
        arvalid <= 0;
        rready  <= 1;
        wait (rvalid);
        data = rdata;
        @(posedge clk);
        rready <= 0;
    end
    endtask

    // 主仿真流程
    logic [31:0] rd_data;
    integer i;

    initial begin
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
