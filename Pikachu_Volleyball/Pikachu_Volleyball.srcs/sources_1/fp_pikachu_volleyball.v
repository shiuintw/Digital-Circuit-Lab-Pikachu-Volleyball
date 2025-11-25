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

reg  [9:0]  pikachu_usr_vpos = 380;
reg  [9:0]  pikachu_opp_vpos = 380;
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
localparam [9:0] VBUF_W = 320; // video buffer width
localparam [9:0] VBUF_H = 240; // video buffer height

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
// -- debounce
wire btn_level_0, btn_level_1, btn_level_2, btn_level_3;
debounce db0(.clk(clk), .btn_input(usr_btn[0]), .btn_output(btn_level_0)); // right
debounce db1(.clk(clk), .btn_input(usr_btn[1]), .btn_output(btn_level_1)); // jump
debounce db2(.clk(clk), .btn_input(usr_btn[2]), .btn_output(btn_level_2)); // smash
debounce db3(.clk(clk), .btn_input(usr_btn[3]), .btn_output(btn_level_3)); // left
// -- end of debounce

// -- 19-bits counter
reg [19:0] counter_19bits;
always @(posedge clk) begin
    if (~reset_n || counter_19bits[19]) counter_19bits <= 0;
    else counter_19bits <= counter_19bits + 1;
end

wire tick_19bits, btn0_tick, btn2_tick, btn3_tick;
assign tick_19bits = counter_19bits[19];
assign btn0_tick = btn_level_0 && counter_19bits[19]; // location++
assign btn3_tick = btn_level_3 && counter_19bits[19]; // location--

assign btn2_tick = btn_level_2 && counter_19bits[19]; // jump
// -- end of 19-bits counter

// btn 1
reg pre_btn_level_1;
wire btn1_pressed;
assign btn1_pressed = btn_level_1 && ~pre_btn_level_1;
always @(posedge clk) begin
    pre_btn_level_1 <= btn_level_1;
end

// end of button process
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// hpos animation
// 2^20 ~ 10.49ms
always @(posedge clk) begin
    // middle: 320
    if (btn0_tick && pikachu_usr_hpos < 260) pikachu_usr_hpos <= pikachu_usr_hpos + 1;
    else if (btn3_tick && pikachu_usr_hpos > 0) pikachu_usr_hpos <= pikachu_usr_hpos - 1;
end
// end of hpos animation
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// vpos animation
reg [7:0] jump_pixel = 0;
reg move_down = 0;
always @(posedge clk) begin
    if (~reset_n || jump_pixel <= 1) move_down <= 0;
    else if (~btn_level_2 || jump_pixel >= 119) move_down <= 1;
end
always @(posedge clk) begin
    if (btn2_tick && ~move_down) begin
        pikachu_usr_vpos <= pikachu_usr_vpos - 2;
        jump_pixel <= jump_pixel + 1;
    end
    else if (tick_19bits && move_down) begin
        pikachu_usr_vpos <= pikachu_usr_vpos + 2;
        jump_pixel <= jump_pixel - 1;
    end
end
// end 
// end of vpos animation
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// -- util
reg [28:0] animation_counter = 0;
always @(posedge clk) begin
    if (animation_counter[28]) animation_counter <= 0;
    else animation_counter <= animation_counter + 1;
end
// -- end of util

// -- offset: which image
reg [17:0] pikachu_usr_image_offset = 0; // todo change the photo
reg [17:0] pikachu_opp_image_offset = 0; // todo change the photo

// -- smash image prepare
reg       smash_enable = 0;
reg [2:0] smash_image  = 0;
reg pre_animation_counter23;
wire smash_image_change;
assign smash_image_change = animation_counter[23] && ~pre_animation_counter23;
always @(posedge clk) pre_animation_counter23 <= animation_counter[23];
always @(posedge clk) begin
    if (~reset_n) begin
        smash_enable <= 0;
        smash_image <= 0;
    end
    else if (btn1_pressed) smash_enable <= 1;
    else if (smash_enable && smash_image_change && smash_image == 5) begin
        smash_enable <= 0;
        smash_image <= 0;
    end
    else if (smash_enable && smash_image_change) smash_image <= smash_image + 1;
end
// -- end of smash image prepare
always @(posedge clk) begin
    // usr
    if (smash_enable) begin
        case (smash_image)
            0: pikachu_usr_image_offset <= pikachu_addr[0];
            1: pikachu_usr_image_offset <= pikachu_addr[4];
            2: pikachu_usr_image_offset <= pikachu_addr[5];
            3: pikachu_usr_image_offset <= pikachu_addr[5];
            4: pikachu_usr_image_offset <= pikachu_addr[4];
            5: pikachu_usr_image_offset <= pikachu_addr[0];
        endcase
    end
    else pikachu_usr_image_offset <= pikachu_addr[animation_counter[24:23]];
    
    // opp
    pikachu_opp_image_offset <= pikachu_addr[animation_counter[24:23]];
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

// pipeline
reg [17:0] usr_y_pixel_count;
always @(posedge clk) usr_y_pixel_count <= (pixel_y - pikachu_usr_vpos) * PIKACHU_W;

reg [17:0] opp_y_pixel_count;
always @(posedge clk) opp_y_pixel_count <= (pixel_y - pikachu_opp_vpos) * PIKACHU_W;
//
always @ (posedge clk) begin
    if (~reset_n) begin
        pixel_addr_background <= 0;
        pixel_addr_pikachu <= 0;
    end
    else begin
        if (pikachu_usr_region) begin
            pixel_addr_pikachu <= pikachu_usr_image_offset +
                                usr_y_pixel_count +
                                (pixel_x - pikachu_usr_hpos);
        end
        else if (pikachu_opp_region) begin
            pixel_addr_pikachu <= pikachu_opp_image_offset +
                                opp_y_pixel_count +
                                (PIKACHU_W - (pixel_x - pikachu_opp_hpos) - 1);
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
  else if ((pikachu_usr_region || pikachu_opp_region) && data_out_pikachu != 12'h0f0)
    rgb_next = data_out_pikachu;
  else
    rgb_next = data_out_background;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
