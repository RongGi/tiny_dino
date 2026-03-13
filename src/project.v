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
  reg jump;

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
  assign G = video_active ? ground ? {2'b10}: block ? 2'b10 : obstracle ? 2'b10: is_day ? day_color :day_color ^ 2'b11 : 2'b00;
  assign B = video_active ? ground ? {2'b10}: block ? 2'b00 : obstracle ? 2'b10: is_day ? day_color :day_color ^ 2'b11 : 2'b00;
  
  always @(posedge ui_in[0], negedge rst_n) begin
    if (~rst_n) begin
      jump <= 1'b0;
    end else begin
      jump <= 1'b1;
      jump_counter <= 5'b11111;
    end
  end
  always @(posedge clk) begin
    if (pix_x > day_counter[10:1]) begin
      is_day <= 1;
    end else begin
      is_day <= 0;
    end
    if (pix_x[9:5]==5'b00010 & pix_y[8:5]=={2'b10,~jump,1'b1}) begin
      block <= 1;
    end else begin
      block <= 0;
    end
    if ((pix_y[8:5]==4'b1011) & (pix_x<obstracle_counter) & (pix_x>obstracle_counter-10'b00_0100_0000)) begin
      obstracle <= 1;
    end else begin
      obstracle <= 0;
    end
  end

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
    if (jump_counter > 5'b00000) begin 
      jump_counter <= jump_counter - 1;
    end else begin
      jump <= 1'b0;
    end
  end

  // Suppress unused signals warning
  wire _unused_ok_ = &{pix_y};

endmodule
