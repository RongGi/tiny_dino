/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_RongGi_tiny_dino(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [10:0] day_counter;
  reg [9:0]  obstracle_counter;
  reg [4:0] jump_counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );


  wire ground = pix_y[7] & pix_y[8];
  reg is_day;
  reg [1:0] day_color;
  reg block;
  reg obstracle;

  localparam [16*16-1:0] dino = {
      16'b0000000001111110,
      16'b0000000011011111,
      16'b0000000011111111,
      16'b0000000011111111,
      16'b0000000011110000,
      16'b1000000111111100,
      16'b1000001111100000,
      16'b1100011111100000,
      16'b1111111111111000,
      16'b1111111111101000,
      16'b1111111111100000,
      16'b0111111111100000,
      16'b0001111111000000,
      16'b0000110110000000,
      16'b0000100010000000,
      16'b0000110011000000
  };
  localparam [16*16-1:0] cactus = {
      16'b0000000110000000,
      16'b0000001110000000,
      16'b0000001111000000,
      16'b0000001111000110,
      16'b0000001111000110,
      16'b0000001111001110,
      16'b0110001111001110,
      16'b0111001111011110,
      16'b0111001111111110,
      16'b0111001111111100,
      16'b0011111111110000,
      16'b0001111110000000,
      16'b0000000110000000,
      16'b0000000110000000,
      16'b0000000110000000,
      16'b0000000110000000
  };

  assign R = video_active ? 
              ground ? 
                {2'b10}: 
                block ? 
                  2'b10 :
                  obstracle ?
                    2'b00 :
                    is_day ? 
                      day_color:
                      day_color ^ 2'b11 : 
              2'b00;
  assign G = video_active ? ground ? {2'b01}: block ? 2'b10 : obstracle ? 2'b10: is_day ? day_color :day_color ^ 2'b11 : 2'b00;
  assign B = video_active ? ground ? {2'b01}: block ? 2'b00 : obstracle ? 2'b10: is_day ? day_color :day_color ^ 2'b11 : 2'b00;
  
  // jump fsm
  // states: no jump, jumping, stay afloat, lowering
  reg [1:0] state_d, state_q;
  reg [4:0] on_air_counter_d, on_air_counter_q;
  reg [5:0] dino_sub_height_d, dino_sub_height_q;
  localparam [5:0] dino_standard_height = 6'b111111;
  localparam [4:0] jump_speed = 5'b00010;
  localparam [4:0] howering = 5'b11111;
  always @(*) begin
    state_d = state_q;
    dino_sub_height_d = dino_sub_height_q;
    on_air_counter_d = on_air_counter_q;
    case(state_q)
      2'b00: if (ui_in[0]) begin
          state_d = 2'b01;
        end

      2'b01: if(dino_sub_height_q[5:0] <= {jump_speed,1'b0}) begin
          state_d = 2'b10;
          on_air_counter_d = 5'b00000;
        end else begin
          dino_sub_height_d[5:0] = dino_sub_height_q[5:0] - {jump_speed,1'b0};
        end

      2'b10: if(on_air_counter_q == howering) begin
          state_d = 2'b11;
        end else begin
          on_air_counter_d = on_air_counter_q + 5'b00001;
        end

      2'b11: if(dino_sub_height_q[5:0] >= dino_standard_height) begin
          state_d = 2'b00;
        end else begin
          dino_sub_height_d[5:0] = dino_sub_height_q[5:0] + {jump_speed,1'b0};
        end

      default: begin 
          state_d = 2'b00;
          dino_sub_height_d = dino_standard_height;
          on_air_counter_d = 5'b00000;
        end

    endcase
  end

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      state_q <= 2'b00;
      dino_sub_height_q <= dino_standard_height;
      on_air_counter_q <= 5'b00000;
    end else begin
      state_q <= state_d;
      dino_sub_height_q <= dino_sub_height_d;
      on_air_counter_q <= on_air_counter_d;
    end
  end

  // pixel state
  always @(posedge clk) begin
    if (pix_x > day_counter[10:1]) begin
      is_day <= 1;
    end else begin
      is_day <= 0;
    end
    if (pix_x[9:5]==5'b00010 & (9'b100100000+{3'b000,dino_sub_height_q}) < pix_y[8:0] & pix_y[8:0]<(9'b101000001+{3'b000,dino_sub_height_q}) & dino[dino_sub_height_q[4:1]-(pix_y[4:1]+2)*16 + (16-pix_x[4:1])]) begin
      block <= 1;
    end else begin
      block <= 0;
    end
    if ((pix_y[8:5]==4'b1011) & (pix_x<obstracle_counter) & (pix_x>(obstracle_counter-10'b00_0100_0000)) & (cactus[(16-pix_y[4:1])*16 + (obstracle_counter[4:1]-pix_x[4:1])])) begin
      obstracle <= 1;
    end else begin
      obstracle <= 0;
    end
  end

  // moving objects
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      day_counter <= 0;
      obstracle_counter <= 0;
      day_color<= 2'b11;
    end else if (day_counter == 0)begin
      day_color <= day_color ^ 2'b11;
      day_counter <= day_counter - 2;
    end else begin
      day_counter <= day_counter - 2;
      obstracle_counter <= obstracle_counter - 4;
    end
  end

  // Suppress unused signals warning
  wire _unused_ok_ = &{pix_y};

endmodule
