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
reg  [9:0]  pikachu_usr_vpos = 380;
reg  [9:0]  pikachu_opp_vpos = 380;
reg  [9:0]  ball_vpos        = 100;
reg  [9:0]  pikachu_usr_hpos = 140;
reg  [9:0]  pikachu_opp_hpos = 480;
reg  [9:0]  ball_hpos        = 295;

localparam  [9:0]  usr_score_vpos  = 10;
localparam  [9:0]  usr_score_hpos  = 10;
localparam  [9:0]  opp_score_vpos  = 10;
localparam  [9:0]  opp_score_hpos  = 590;

localparam  [9:0]  init_display_vpos  = 200;
localparam  [9:0]  init_display_hpos  = 220;

wire        pikachu_usr_region;
wire        pikachu_opp_region;
wire        usr_score_region;
wire        opp_score_region;
wire        ball_region;
wire        init_display_region;

// declare SRAM control signals
wire [16:0] sram_addr_background;
wire [16:0] sram_addr_pikachu;
wire [16:0] sram_addr_ball;
wire [16:0] sram_addr_nums;
wire [16:0] sram_addr_init_display;
wire [11:0] data_in;
wire [11:0] data_out_background;
wire [11:0] data_out_pikachu;
wire [11:0] data_out_ball;
wire [11:0] data_out_nums;
wire [11:0] data_out_init_display;
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
reg  [17:0] pixel_addr_ball;
reg  [17:0] pixel_addr_nums;
reg  [17:0] pixel_addr_init_display;

// Declare the video buffer size
localparam [9:0] VBUF_W = 320; // video buffer width
localparam [9:0] VBUF_H = 240; // video buffer height

// Set parameters for the pikachu images
parameter [5:0] PIKACHU_W = 50;
parameter [5:0] PIKACHU_H = 50;
parameter [5:0] BALL_W    = 50;
parameter [5:0] BALL_H    = 50;
parameter [5:0] NUMS_W    = 40;
parameter [5:0] NUMS_H    = 40;
parameter [7:0] INIT_DISPLAY_W    = 200;
parameter [5:0] INIT_DISPLAY_H    = 39;
reg [17:0] pikachu_addr[0:6];
reg [17:0] ball_addr;
reg [17:0] nums_addr[0:9];
reg [17:0] init_display_addr;

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
  
  // ball
  ball_addr = 0;
  
  // nums
  nums_addr[0] = 0;
  nums_addr[1] = 1600;
  nums_addr[2] = 3200;
  nums_addr[3] = 4800;
  nums_addr[4] = 6400;
  nums_addr[5] = 8000;
  nums_addr[6] = 9600;
  nums_addr[7] = 11200;
  nums_addr[8] = 12800;
  nums_addr[9] = 14400;
  
  // init display
  init_display_addr = 0;
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
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(14), .RAM_SIZE(15000), .FILE_NAME("modified_pikachu.mem"))
  ram_pikachu (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_pikachu), .data_i(data_in), .data_o(data_out_pikachu));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(12), .RAM_SIZE(2500), .FILE_NAME("ball.mem"))
  ram_ball (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_ball), .data_i(data_in), .data_o(data_out_ball));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(14), .RAM_SIZE(16000), .FILE_NAME("nums.mem"))
  ram_nums (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_nums), .data_i(data_in), .data_o(data_out_nums));
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(13), .RAM_SIZE(7800), .FILE_NAME("init_display.mem"))
  ram_init_display (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr_init_display), .data_i(data_in), .data_o(data_out_init_display));

assign sram_we = ~reset_n; // In this demo, we do not write the SRAM. However, if
                          // you set 'sram_we' to 0, Vivado fails to synthesize
                          // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;       // Here, we always enable the SRAM block.
assign sram_addr_background   = pixel_addr_background;
assign sram_addr_pikachu      = pixel_addr_pikachu;
assign sram_addr_ball         = pixel_addr_ball;
assign sram_addr_nums         = pixel_addr_nums;
assign sram_addr_init_display = pixel_addr_init_display;
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// game control
localparam [1:0] S_START = 2'b00, S_GAME = 2'b01, S_OVER = 2'b11;
wire start2game, game2over, over2start;
wire restart;
assign start2game = ~usr_sw[3];
assign over2start = usr_sw[3];

reg [1:0] P = 2'b00, P_next = 2'b00;
always @(posedge clk) begin
    if (~reset_n) P <= S_START;
    else P <= P_next;
end

always @* begin
    case (P)
        S_START: begin
            if (start2game) P_next = S_GAME;
            else P_next = S_START;
        end
        S_GAME: begin
            if (game2over) P_next = S_OVER;
            else P_next = S_GAME;
        end
        S_OVER: begin
            if (over2start) P_next = S_START;
            else P_next = S_OVER;
        end
        default: P_next = S_START;
    endcase
end
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
wire tick_19bits, tick_21bits, btn0_tick, btn2_tick, btn3_tick;

reg [19:0] counter_19bits;
always @(posedge clk) begin
    if (~reset_n || counter_19bits[19]) counter_19bits <= 0;
    else counter_19bits <= counter_19bits + 1;
end
reg [2:0] counter_21bits;
always @(posedge clk) begin
    if (~reset_n || counter_21bits[2]) counter_21bits <= 0;
    else if (tick_19bits) counter_21bits <= counter_21bits + 1;
end

assign tick_19bits = counter_19bits[19];
assign tick_21bits = counter_21bits[2];
assign btn0_tick = btn_level_0 && counter_19bits[19]; // location++
assign btn3_tick = btn_level_3 && counter_19bits[19]; // location--

assign btn2_tick = btn_level_2 && counter_19bits[19]; // jump
// -- end of 19-bits counter

// btn pressed
reg pre_btn_level_1;
wire btn1_pressed;
assign btn1_pressed = btn_level_1 && ~pre_btn_level_1;
always @(posedge clk) begin
    pre_btn_level_1 <= btn_level_1;
end

reg pre_btn_level_2;
wire btn2_pressed;
assign btn2_pressed = btn_level_2 && ~pre_btn_level_2;
always @(posedge clk) begin
    pre_btn_level_2 <= btn_level_2;
end

// end of button process
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// hpos animation
// -- usr
// prone
wire usr_moving_down;
wire usr_prone;
reg [6:0] usr_prone_count = 0;
reg usr_prone_enable = 0;
assign usr_prone = usr_prone_enable;
always @(posedge clk) begin // count
    if (~reset_n || P != S_GAME || restart || usr_prone_count[6]) usr_prone_count <= 0;
    else if (tick_19bits && usr_prone_enable) usr_prone_count <= usr_prone_count + 1;
end
always @(posedge clk) begin // enable
    if (~reset_n || P != S_GAME || restart || usr_prone_count[6]) usr_prone_enable <= 0;
    else if (btn2_pressed && usr_moving_down) usr_prone_enable <= 1;
end

// move
always @(posedge clk) begin
    // middle: 320
    if (~reset_n || P != S_GAME || restart) pikachu_usr_hpos <= 140;
    else if (tick_19bits && usr_prone && pikachu_usr_hpos < 248) pikachu_usr_hpos <= pikachu_usr_hpos + 3;
    else if (btn0_tick && pikachu_usr_hpos < 250) pikachu_usr_hpos <= pikachu_usr_hpos + 1;
    else if (btn3_tick && pikachu_usr_hpos > 0) pikachu_usr_hpos <= pikachu_usr_hpos - 1;
end
// -- end of usr

// -- opp
always @(posedge clk) begin
    // middle: 320
    if (~reset_n || P != S_GAME || restart) pikachu_opp_hpos <= 480;
    else if (tick_19bits && pikachu_opp_hpos < ball_hpos && pikachu_opp_hpos < 580) pikachu_opp_hpos <= pikachu_opp_hpos + 1;
    else if (tick_19bits && pikachu_opp_hpos > ball_hpos && pikachu_opp_hpos > 340) pikachu_opp_hpos <= pikachu_opp_hpos - 1;
end

// end of hpos animation
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// vpos animation
// -- usr
reg [7:0] jump_pixel = 0;
reg move_down = 0;
assign usr_moving_down = move_down;
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || restart || jump_pixel <= 2) move_down <= 0;
    else if (~btn_level_2 || jump_pixel >= 108) move_down <= 1;
end
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || restart) begin
        pikachu_usr_vpos <= 380;
        jump_pixel <= 0;
    end
    else if (btn2_tick && ~move_down) begin
        pikachu_usr_vpos <= pikachu_usr_vpos - 2;
        jump_pixel <= jump_pixel + 1;
    end
    else if (tick_19bits && move_down) begin
        pikachu_usr_vpos <= pikachu_usr_vpos + 2;
        jump_pixel <= jump_pixel - 1;
    end
end
// -- end of usr

// -- opp
reg [7:0] opp_jump_pixel = 0;
reg opp_move_down = 0;
wire opp_jump_signal;
wire ball_moving_down;
assign opp_jump_signal = (pikachu_opp_vpos >= ball_vpos + BALL_H) &&
                         ball_moving_down &&
                         ~usr_sw[2] &&
                         (pikachu_opp_hpos <= ball_hpos + 55) &&
                         (pikachu_opp_hpos >= (ball_hpos < 25 ? 0 : ball_hpos - 25));
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || restart || opp_jump_pixel <= 2) opp_move_down <= 0;
    else if (~opp_jump_signal || jump_pixel >= 108) opp_move_down <= 1;
end
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || restart) begin
        pikachu_opp_vpos <= 380;
        opp_jump_pixel <= 0;
    end
    else if (opp_jump_signal && tick_19bits && ~opp_move_down) begin
        pikachu_opp_vpos <= pikachu_opp_vpos - 2;
        opp_jump_pixel <= opp_jump_pixel + 1;
    end
    else if (tick_19bits && opp_move_down) begin
        pikachu_opp_vpos <= pikachu_opp_vpos + 2;
        opp_jump_pixel <= opp_jump_pixel - 1;
    end
end
// -- end of opp

// end of vpos animation
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// -- ball interaction

// touch event
wire [9:0] ball_vcenter = ball_vpos + 25;
wire [9:0] ball_hcenter = ball_hpos + 25;
wire [9:0] usr_vcenter  = pikachu_usr_vpos + 25;
wire [9:0] usr_hcenter  = pikachu_usr_hpos + 25;
wire [9:0] opp_vcenter  = pikachu_opp_vpos + 25;
wire [9:0] opp_hcenter  = pikachu_opp_hpos + 25;
wire v_touch_usr, h_touch_usr, usr_is_left;
wire v_touch_opp, h_touch_opp, opp_is_left;
wire touch_left_frame, touch_right_frame, touch_top_screen, touch_net, net_is_left, net_is_below;
assign v_touch_usr = usr_vcenter > ball_vcenter ? (usr_vcenter - ball_vcenter < 47) : (ball_vcenter - usr_vcenter < 47);
assign h_touch_usr = usr_hcenter > ball_hcenter ? (usr_hcenter - ball_hcenter < 47) : (ball_hcenter - usr_hcenter < 47);
assign usr_is_left = ball_hcenter > usr_hcenter;
assign v_touch_opp = opp_vcenter > ball_vcenter ? (opp_vcenter - ball_vcenter < 47) : (ball_vcenter - opp_vcenter < 47);
assign h_touch_opp = opp_hcenter > ball_hcenter ? (opp_hcenter - ball_hcenter < 47) : (ball_hcenter - opp_hcenter < 47);
assign opp_is_left = ball_hcenter > opp_hcenter;
assign touch_left_frame = ball_hpos <= 15;
assign touch_right_frame = ball_hpos >= 575; // 640 - 50 - 15
assign touch_top_screen = ball_vpos <= 15;
assign touch_ground = ball_vpos >= 385;
assign touch_net = ball_hpos >= 250 && ball_hpos <= 340 && ball_vcenter >= 250;
assign net_is_left = ball_hcenter < 295;
assign net_is_below = ball_vcenter >= 250 && ball_vcenter <= 285;

// opp smash
wire opp_smash;
assign opp_smash = ball_vcenter < 240 && // ball high enough
                   pikachu_opp_vpos < 250 && // jump high enough
                   opp_hcenter > ball_hcenter && // right dir
                   ~usr_sw[1] &&
                   v_touch_opp &&
                   h_touch_opp;
//

// -- speed control
reg [5:0] ball_hspeed = 0;
reg [5:0] ball_vspeed = 5;
reg ball_hdir = 0; // 0right, 1left
reg ball_vdir = 0; // 0down, 1up
assign ball_moving_down = ball_vdir == 0; // for opp

always @(posedge clk) begin // speed dir
    if (~reset_n || P != S_GAME || restart) begin
        ball_vdir <= 0;
        ball_hdir <= 0;
    end
    else if (ball_vspeed == 0) ball_vdir <= 0;
    else if (v_touch_usr && h_touch_usr) begin // usr
        ball_vdir <= 1;
        ball_hdir <= ~usr_is_left;
    end
    else if (v_touch_opp && h_touch_opp) begin // opp
        ball_vdir <= 1;
        ball_hdir <= ~opp_is_left;
    end
    else begin // mergin
        // vdir
        if (touch_ground) ball_vdir <= 1;
        else if (touch_top_screen) ball_vdir <= 0;
        else if (touch_net && net_is_below) ball_vdir <= 1;
        
        // hdir
        if (touch_left_frame) ball_hdir <= 0;
        else if (touch_right_frame) ball_hdir <= 1;
        else if (touch_net && net_is_left) ball_hdir <= 1;
        else if (touch_net && ~net_is_left) ball_hdir <= 0;
    end
end

reg [2:0] acc_counter = 0; // speed counter
wire acc_signal;
assign acc_singal = acc_counter == 2'b11;
always @(posedge clk) begin
    if (~reset_n || acc_counter == 2'b11) acc_counter <= 0;
    else if (tick_21bits) acc_counter <= acc_counter + 1;
end

always @(posedge clk) begin // speed val
    // vspeed
    if (~reset_n || P != S_GAME || restart) ball_vspeed <= 5;
    else if (v_touch_usr && h_touch_usr && btn_level_1) ball_vspeed <= 0;
    else if (opp_smash) ball_vspeed <= 0;
    else if ((v_touch_usr && h_touch_usr) || (v_touch_opp && h_touch_opp)) ball_vspeed <= 12;
    else if (acc_singal && ball_vdir && ball_vspeed > 0) ball_vspeed <= ball_vspeed - 1;
    else if (acc_singal && ~ball_vdir && ball_vspeed < 13) ball_vspeed <= ball_vspeed + 1;
    
    // hspeed
    if (~reset_n || P != S_GAME || restart) ball_hspeed <= 0;
    else if (v_touch_usr && h_touch_usr && btn_level_1 && ~usr_prone) ball_hspeed <= 13;
    else if (opp_smash) ball_hspeed <= 13;
    else if (v_touch_usr && h_touch_usr) ball_hspeed <= 5;
    else if (v_touch_opp && h_touch_opp) ball_hspeed <= 5;
end

// score control
reg pre_touch_ground;
wire score_increase_signal;
always @(posedge clk) pre_touch_ground <= touch_ground;
assign score_inctrease_signal = ~pre_touch_ground && touch_ground;

reg [3:0] usr_score = 0, opp_score = 0;
assign game2over = usr_score == 9 || opp_score == 9;
always @(posedge clk) begin
    if (~reset_n || P == S_START) begin
        usr_score <= 0;
        opp_score <= 0;
    end
    else if (score_inctrease_signal) begin
        if (ball_hpos <= 295) opp_score <= opp_score + 1;
        else usr_score <= usr_score + 1;
    end
end
// -- end of score control

// restart counter
reg [3:0] restart_counter = 0;
assign restart = restart_counter[3];
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || ~touch_ground) restart_counter <= 0;
    else if (~restart_counter[3] && tick_21bits) restart_counter <= restart_counter + 1;
end
// -- end of restart counter

// pos control (pos += speed)
always @(posedge clk) begin
    if (~reset_n || P != S_GAME || restart) begin
        ball_vpos <= 100;
        ball_hpos <= 295;
    end
    else if (touch_ground); // ball does not move 
    else if (tick_21bits) begin
        if (~ball_vdir) begin
            if (ball_vpos + ball_vspeed <= 385) ball_vpos <= ball_vpos + ball_vspeed;
            else ball_vpos <= 385;
        end
        else begin
            if (ball_vpos >= ball_vspeed) ball_vpos <= ball_vpos - ball_vspeed;
            else ball_vpos <= 0;
        end
        if (~ball_hdir) begin
            if (ball_hpos + ball_hspeed <= 590)
                ball_hpos <= ball_hpos + ball_hspeed;
            else ball_hpos <= 590;
        end
        else if (ball_hpos >= ball_hspeed) ball_hpos <= ball_hpos - ball_hspeed;
    end
end
// -- end of pos and score control
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
// for usr
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
    else if (btn1_pressed && ~usr_prone) smash_enable <= 1;
    else if (smash_enable && smash_image_change && smash_image == 4) begin
        smash_enable <= 0;
        smash_image <= 0;
    end
    else if (smash_enable && smash_image_change) smash_image <= smash_image + 1;
end

// for opp
reg       smash_enable_opp = 0;
reg [2:0] smash_image_opp  = 0;
wire smash_image_change_opp;
assign smash_image_change_opp = animation_counter[23] && ~pre_animation_counter23;
always @(posedge clk) begin
    if (~reset_n) begin
        smash_enable_opp <= 0;
        smash_image_opp <= 0;
    end
    else if (opp_smash) smash_enable_opp <= 1;
    else if (smash_enable_opp && smash_image_change_opp && smash_image_opp == 4) begin
        smash_enable_opp <= 0;
        smash_image_opp <= 0;
    end
    else if (smash_enable_opp && smash_image_change_opp) smash_image_opp <= smash_image_opp + 1;
end
// -- end of smash image prepare
always @(posedge clk) begin
    // usr
    if (smash_enable) begin
        case (smash_image)
            0: pikachu_usr_image_offset <= pikachu_addr[3];
            1: pikachu_usr_image_offset <= pikachu_addr[4];
            2: pikachu_usr_image_offset <= pikachu_addr[4];
            3: pikachu_usr_image_offset <= pikachu_addr[3];
            4: pikachu_usr_image_offset <= pikachu_addr[0];
        endcase
    end
    else if (usr_prone) pikachu_usr_image_offset <= pikachu_addr[5];
    else pikachu_usr_image_offset <= pikachu_addr[animation_counter[24:23] % 3];
    
    // opp
    if (smash_enable_opp) begin
        case (smash_image_opp)
            0: pikachu_opp_image_offset <= pikachu_addr[3];
            1: pikachu_opp_image_offset <= pikachu_addr[4];
            2: pikachu_opp_image_offset <= pikachu_addr[4];
            3: pikachu_opp_image_offset <= pikachu_addr[3];
            4: pikachu_opp_image_offset <= pikachu_addr[0];
        endcase
    end
    else pikachu_opp_image_offset <= pikachu_addr[animation_counter[24:23] % 3];
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
assign ball_region        = (pixel_y >= ball_vpos) &&
                            (pixel_y < (ball_vpos + BALL_H)) &&
                            (pixel_x >= ball_hpos) &&
                            (pixel_x < (ball_hpos + BALL_W));
assign usr_score_region   = (pixel_y >= usr_score_vpos) &&
                            (pixel_y < (usr_score_vpos + NUMS_H)) &&
                            (pixel_x >= usr_score_hpos) &&
                            (pixel_x < (usr_score_hpos + NUMS_W));
assign opp_score_region   = (pixel_y >= opp_score_vpos) &&
                            (pixel_y < (opp_score_vpos + NUMS_H)) &&
                            (pixel_x >= opp_score_hpos) &&
                            (pixel_x < (opp_score_hpos + NUMS_W));
assign init_display_region= (pixel_y >= init_display_vpos) &&
                            (pixel_y < (init_display_vpos + INIT_DISPLAY_H)) &&
                            (pixel_x >= init_display_hpos) &&
                            (pixel_x < (init_display_hpos + INIT_DISPLAY_W));
                            
// pipeline
reg [17:0] usr_y_pixel_count;
always @(posedge clk) usr_y_pixel_count <= (pixel_y - pikachu_usr_vpos) * PIKACHU_W;

reg [17:0] opp_y_pixel_count;
always @(posedge clk) opp_y_pixel_count <= (pixel_y - pikachu_opp_vpos) * PIKACHU_W;

reg [17:0] ball_y_pixel_count;
always @(posedge clk) ball_y_pixel_count <= (pixel_y - ball_vpos) * BALL_W;

reg [17:0] usr_score_y_pixel_count;
always @(posedge clk) usr_score_y_pixel_count <= (pixel_y - usr_score_vpos) * NUMS_W;

reg [17:0] opp_score_y_pixel_count;
always @(posedge clk) opp_score_y_pixel_count <= (pixel_y - opp_score_vpos) * NUMS_W;

reg [17:0] init_display_y_pixel_count;
always @(posedge clk) init_display_y_pixel_count <= (pixel_y - init_display_vpos) * INIT_DISPLAY_W;
//
always @ (posedge clk) begin
    if (~reset_n) begin
        pixel_addr_background <= 0;
        pixel_addr_pikachu <= 0;
    end
    else begin
        // score
        if (usr_score_region) begin
            pixel_addr_nums <= nums_addr[usr_score] +
                               usr_score_y_pixel_count +
                               (pixel_x - usr_score_hpos);
        end
        else if (opp_score_region) begin
            pixel_addr_nums <= nums_addr[opp_score] +
                               opp_score_y_pixel_count +
                               (pixel_x - opp_score_hpos);
        end
        
        // pikachu
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
        
        // ball
        if (ball_region) begin
            pixel_addr_ball    <= ball_addr +
                                ball_y_pixel_count +
                                (BALL_W - (pixel_x - ball_hpos) - 1);
        end
        
        // init display
        if (init_display_region) begin
            pixel_addr_init_display <= init_display_addr +
                                       init_display_y_pixel_count +
                                       (pixel_x - init_display_hpos);
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
  else if (P != S_GAME && init_display_region && data_out_init_display != 12'h0f0)
    rgb_next = data_out_init_display;
  else if ((usr_score_region || opp_score_region) && data_out_nums != 12'h0f0)
    rgb_next = data_out_nums;
  else if (ball_region && data_out_ball != 12'h0f0)
    rgb_next = data_out_ball;
  else if ((pikachu_usr_region || pikachu_opp_region) && data_out_pikachu != 12'h0f0)
    rgb_next = data_out_pikachu;
  else
    rgb_next = data_out_background;
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
