module axi_lite_slave_regs #(
    parameter REG_NUM = 4
) (
    input  logic         clk,
    input  logic         rst_n,

    // 写地址通道
    input  logic [31:0]  awaddr,
    input  logic         awvalid,
    output logic         awready,

    // 写数据通道
    input  logic [31:0]  wdata,
    input  logic [3:0]   wstrb,
    input  logic         wvalid,
    output logic         wready,

    // 写响应通道
    output logic [1:0]   bresp,
    output logic         bvalid,
    input  logic         bready,

    // 读地址通道
    input  logic [31:0]  araddr,
    input  logic         arvalid,
    output logic         arready,

    // 读数据通道
    output logic [31:0]  rdata,
    output logic [1:0]   rresp,
    output logic         rvalid,
    input  logic         rready
);

    // 多寄存器
    logic [31:0] regfile [REG_NUM];//定义了一个“有REG_NUM个元素、每个元素32位”的寄存器组，变量名叫regfile。

    // 地址译码
    logic [1:0] awaddr_sel, araddr_sel;//定义了两个2位变量，分别用来存放写/读操作当前访问的是哪个寄存器。
    assign awaddr_sel = awaddr[3:2];//从awaddr中提取地址的高2位作为写操作的寄存器选择。
    assign araddr_sel = araddr[3:2];//从araddr中提取地址的高2位作为读操作的寄存器选择。

    // 写地址通道
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) awready <= 0;//
        else if (!awready && awvalid) awready <= 1;//如果awready未被置位且awvalid为1，则将awready置为1，表示可以接受写地址。
        else awready <= 0;//否则将awready复位为0。
    end

    // 写数据通道
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wready <= 0;
        else if (!wready && wvalid) wready <= 1;//如果wready未被置位且wvalid为1，则将wready置为1，表示可以接受写数据。
        else wready <= 0;//否则将wready复位为0。
    end

    // 写操作和响应
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0; i<REG_NUM; i++) regfile[i] <= 0;//把每一个寄存器的内容全部清零
            bvalid <= 0;//写响应有效信号复位
            bresp  <= 2'b00;// 写响应状态复位
        end else if (awvalid && awready && wvalid && wready) begin//当awvalid、awready、wvalid和wready都为1时，表示写操作有效。满足写地址通道/写数据通道都握手成功，本周期要处理一次写操作。只有在主机和从机双方都准备好并握手成功时才写入数据。
            if (awaddr_sel < REG_NUM) begin//如果awaddr_sel小于寄存器数量，则表示写入有效寄存器
                if (wstrb[0]) regfile[awaddr_sel][7:0]   <= wdata[7:0];//regfile[awaddr_sel][7:0] 就是**“编号为awaddr_sel的寄存器的低8位”**。
                if (wstrb[1]) regfile[awaddr_sel][15:8]  <= wdata[15:8];//如果wstrb的第1位为1，则写入wdata的第8到15位到寄存器的第8到15位。
                if (wstrb[2]) regfile[awaddr_sel][23:16] <= wdata[23:16];//如果wstrb的第2位为1，则写入wdata的第16到23位到寄存器的第16到23位。
                if (wstrb[3]) regfile[awaddr_sel][31:24] <= wdata[31:24];//如果wstrb的第3位为1，则写入wdata的第24到31位到寄存器的第24到31位。
                bresp <= 2'b00; //AXI协议标准中，2'b00表示OKAY，即“写成功，无错误”
            end else begin
                bresp <= 2'b10; //AXI协议中，2'b10表示SLVERR（slave error），即“从机错误/未实现/非法操作”。
            end
            bvalid <= 1;
        end else if (bvalid && bready) bvalid <= 0;
    end

    // 读地址通道
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) arready <= 0;
        else if (!arready && arvalid) arready <= 1;//如果arready未被置位且arvalid为1，则将arready置为1，表示可以接受读地址。
        else arready <= 0;
    end

    // 读数据通道
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata  <= 0;
            rresp  <= 0;
            rvalid <= 0;
        end else if (arready && arvalid) begin//当arready和arvalid都为1时，表示读操作有效。
            if (araddr_sel < REG_NUM) begin
                rdata <= regfile[araddr_sel];//从寄存器组中读取数据到rdata。
                rresp <= 2'b00; // 2'b00表示读操作成功，无错误
            end else begin
                rdata <= 32'hDEAD_BEEF;// 读取非法地址时返回一个特定的值
                rresp <= 2'b10; // 2'b10表示SLVERR（slave error），即“从机错误/未实现/非法操作”。
            end
            rvalid <= 1;// 设置rvalid为1，表示读数据有效
        end else if (rvalid && rready) rvalid <= 0;
    end

endmodule
