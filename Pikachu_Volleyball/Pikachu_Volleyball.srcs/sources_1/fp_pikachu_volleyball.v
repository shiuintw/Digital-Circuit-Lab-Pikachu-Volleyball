`timescale 1ns / 1ps

module fp_pikachu_volleyball(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] pikachu_usr_clock; // not used todo rm
reg  [31:0] pikachu_opp_clock; // not used todo rm

reg  [9:0]  pikachu_usr_vpos = 60;
reg  [9:0]  pikachu_opp_vpos = 60;
reg  [9:0]  pikachu_usr_hpos = 180;
reg  [9:0]  pikachu_opp_hpos = 480;

wire        pikachu_usr_region;
wire        pikachu_opp_region;

// declare SRAM control signals
wire [16:0] sram_addr_background;
wire [16:0] sram_addr_pikachu;
wire [11:0] data_in;
wire [11:0] data_out_background;
wire [11:0] data_out_pikachu;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr_background;
reg  [17:0] pixel_addr_pikachu;

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the pikachu images
parameter [5:0] PIKACHU_W = 50;
parameter [5:0] PIKACHU_H = 50;
reg [17:0] pikachu_addr[0:6]; // todo more images

// Initializes the pikachu images starting addresses.
initial begin
  // walk
  pikachu_addr[0] = 0;
  pikachu_addr[1] = 2500;
  pikachu_addr[2] = 5000;
  pikachu_addr[3] = 7500;
  
  // smash
  pikachu_addr[4] = 10000;
  pikachu_addr[5] = 12500;
  
  // prone
  pikachu_addr[6] = 15000;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(76800), .FILE_NAME("background.mem"))
  ram_background (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_background), .data_i(data_in), .data_o(data_out_background));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(15), .RAM_SIZE(17500), .FILE_NAME("pikachu.mem"))
  ram_pikachu (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_pikachu), .data_i(data_in), .data_o(data_out_pikachu));

assign sram_we = ~reset_n; // In this demo, we do not write the SRAM. However, if
                          // you set 'sram_we' to 0, Vivado fails to synthesize
                          // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;       // Here, we always enable the SRAM block.
assign sram_addr_background = pixel_addr_background;
assign sram_addr_pikachu    = pixel_addr_pikachu;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// button process
wire btn_level_0, btn_level_1, btn_level_2, btn_level_3;
debounce db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level_0)); // right
debounce db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level_1)); // jump
debounce db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level_2)); // smash
debounce db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level_3)); // left

// btn 0, 3
reg [19:0] hold_0 = 0;
reg [19:0] hold_3 = 0;
wire btn0_tick, btn3_tick;
assign btn0_tick = hold_0[1]; // location++
assign btn3_tick = hold_3[1]; // location--
always @(posedge clk) begin
    if (~reset_n) begin
        hold_0 <= 0;
        hold_3 <= 0;
    end
    else begin
        if (~btn_level_0 || hold_0[19]) hold_0 <= 0;
        else hold_0 <= hold_0 + 1;
        
        if (~btn_level_3 || hold_3[19]) hold_3 <= 0;
        else hold_3 <= hold_3 + 1;
    end
end

// btn 1, 2
reg pre_btn_level_1;
reg pre_btn_level_2;
wire btn1_pressed, btn2_pressed;
assign btn1_pressed = btn_level_1 && ~pre_btn_level_1;
assign btn2_pressed = btn_level_2 && ~pre_btn_level_2;
always @(posedge clk) begin
    pre_btn_level_1 <= btn_level_1;
    pre_btn_level_2 <= btn_level_2;
end

// end of button process
// ------------------------------------------------------------------------


// ------------------------------------------------------------------------
// todo pikachu_usr_hpos pikachu_usr_vpos pikachu_opp_hpos pikachu_opp_hpos
// 2^20 ~ 10.49ms

// -- usr
// todo jump: vpos

// hpos
always @(posedge clk) begin
    // middle: 320
    if (btn0_tick && pikachu_usr_hpos < 260) pikachu_usr_hpos <= pikachu_usr_hpos + 1;
    else if (btn3_tick && pikachu_usr_hpos > 0) pikachu_usr_hpos <= pikachu_usr_hpos - 1;
end
//
// -- end of usr

// -- opp(bot)
// -- end of opp(bot)

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// -- util
reg [28:0] counter = 0;
always @(posedge clk) begin
    if (counter[28]) counter <= 0;
    else counter <= counter + 1;
end
// -- end of util

// -- offset: which image
reg [17:0] pikachu_usr_image_offset = 0; // todo change the photo
reg [17:0] pikachu_opp_image_offset = 0; // todo change the photo
always @(posedge clk) begin
    pikachu_usr_image_offset <= pikachu_addr[counter[24:23]];
end
// -- end of offset

assign pikachu_usr_region = (pixel_y >= pikachu_usr_vpos) &&
                            (pixel_y < (pikachu_usr_vpos + PIKACHU_H)) &&
                            (pixel_x >= pikachu_usr_hpos) &&
                            (pixel_x < (pikachu_usr_hpos + PIKACHU_W));
assign pikachu_opp_region = (pixel_y >= pikachu_opp_vpos) &&
                            (pixel_y < (pikachu_opp_vpos + PIKACHU_H)) &&
                            (pixel_x >= pikachu_opp_hpos) &&
                            (pixel_x < (pikachu_opp_hpos + PIKACHU_W));

always @ (posedge clk) begin
    if (~reset_n) begin
        pixel_addr_background <= 0;
        pixel_addr_pikachu <= 0;
    end
    else begin
        if (pikachu_usr_region) begin // todo add reverse direction
            pixel_addr_pikachu <= pikachu_usr_image_offset +
                                (pixel_y - pikachu_usr_vpos) * PIKACHU_W +
                                (pixel_x - pikachu_usr_hpos);
        end
        else if (pikachu_opp_region) begin // todo add reverse direction
            pixel_addr_pikachu <= pikachu_opp_image_offset +
                                (pixel_y - pikachu_opp_vpos) * PIKACHU_W +
                                (pixel_x - pikachu_opp_hpos);
        end
        // Scale up a 320x240 image for the 640x480 display.
        // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
        pixel_addr_background <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
    end
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if (pikachu_usr_region || pikachu_opp_region)
    rgb_next = data_out_pikachu;
  else
    rgb_next = data_out_background;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
