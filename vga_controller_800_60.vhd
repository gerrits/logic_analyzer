------------------------------------------------------------------------
-- vga_controller_800_60.vhd
------------------------------------------------------------------------
-- Author : Ulrich Zoltn
--          Copyright 2006 Digilent, Inc.
------------------------------------------------------------------------
-- Software version : Xilinx ISE 7.1.04i
--                    WebPack
-- Device	        : 3s200ft256-4
------------------------------------------------------------------------
-- This file contains the logic to generate the synchronization signals,
-- horizontal and vertical pixel counter and video disable signal
-- for the 800x600@60Hz resolution.
------------------------------------------------------------------------
--  Behavioral description
------------------------------------------------------------------------
-- Please read the following article on the web regarding the
-- vga video timings:
-- http://www.epanorama.net/documents/pc/vga_timing.html

-- This module generates the video synch pulses for the monitor to
-- enter 800x600@60Hz resolution state. It also provides horizontal
-- and vertical counters for the currently displayed pixel and a blank
-- signal that is active when the pixel is not inside the visible screen
-- and the color outputs should be reset to 0.

-- timing diagram for the horizontal synch signal (HS)
-- 0                         840    968          1056 (pixels)
-- _________________________|------|_________________
-- timing diagram for the vertical synch signal (VS)
-- 0                                  601    605  628 (lines)
-- __________________________________|------|________

-- The blank signal is delayed one pixel clock period (25ns) from where
-- the pixel leaves the visible screen, according to the counters, to
-- account for the pixel pipeline delay. This delay happens because
-- it takes time from when the counters indicate current pixel should
-- be displayed to when the color data actually arrives at the monitor
-- pins (memory read delays, synchronization delays).
------------------------------------------------------------------------
--  Port definitions
------------------------------------------------------------------------
-- rst               - global reset signal
-- pixel_clk         - input pin, from dcm_40MHz
--                   - the clock signal generated by a DCM that has
--                   - a frequency of 40MHz.
-- HS                - output pin, to monitor
--                   - horizontal synch pulse
-- VS                - output pin, to monitor
--                   - vertical synch pulse
-- hcount            - output pin, 11 bits, to clients
--                   - horizontal count of the currently displayed
--                   - pixel (even if not in visible area)
-- vcount            - output pin, 11 bits, to clients
--                   - vertical count of the currently active video
--                   - line (even if not in visible area)
-- blank             - output pin, to clients
--                   - active when pixel is not in visible area.
------------------------------------------------------------------------
-- Revision History:
-- 09/18/2006(UlrichZ): created
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- simulation library
library UNISIM;
use UNISIM.VComponents.all;

-- the vga_controller_800_60 entity declaration
-- read above for behavioral description and port definitions.
entity vga_controller_800_60 is
port(
   rst         : in std_logic;
   pixel_clk   : in std_logic;
   HS          : out std_logic;
   VS          : out std_logic;
   hcount      : out std_logic_vector(10 downto 0);
   vcount      : out std_logic_vector(10 downto 0);
   blank       : out std_logic
);
end vga_controller_800_60;

architecture Behavioral of vga_controller_800_60 is

------------------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------------------

-- maximum value for the horizontal pixel counter
constant HMAX  : std_logic_vector(10 downto 0) := "10000100000"; -- 1056
-- maximum value for the vertical pixel counter
constant VMAX  : std_logic_vector(10 downto 0) := "01001110100"; --  628
-- total number of visible columns
constant HLINES: std_logic_vector(10 downto 0) := "01100100000"; --  800
-- value for the horizontal counter where front porch ends
constant HFP   : std_logic_vector(10 downto 0) := "01101001000"; --  840
-- value for the horizontal counter where the synch pulse ends
constant HSP   : std_logic_vector(10 downto 0) := "01111001000"; --  968
-- total number of visible lines
constant VLINES: std_logic_vector(10 downto 0) := "01001011000"; --  600
-- value for the vertical counter where the front porch ends
constant VFP   : std_logic_vector(10 downto 0) := "01001011001"; --  601
-- value for the vertical counter where the synch pulse ends
constant VSP   : std_logic_vector(10 downto 0) := "01001011101"; --  605
-- polarity of the horizontal and vertical synch pulse
-- only one polarity used, because for this resolution they coincide.
constant SPP   : std_logic := '1';

------------------------------------------------------------------------
-- SIGNALS
------------------------------------------------------------------------

-- horizontal and vertical counters
signal hcounter : std_logic_vector(10 downto 0) := (others => '0');
signal vcounter : std_logic_vector(10 downto 0) := (others => '0');

-- active when inside visible screen area.
signal video_enable: std_logic;

begin

   -- output horizontal and vertical counters
   hcount <= hcounter;
   vcount <= vcounter;

   -- blank is active when outside screen visible area
   -- color output should be blacked (put on 0) when blank in active
   -- blank is delayed one pixel clock period from the video_enable
   -- signal to account for the pixel pipeline delay.
   blank <= not video_enable when rising_edge(pixel_clk);

   -- increment horizontal counter at pixel_clk rate
   -- until HMAX is reached, then reset and keep counting
   h_count: process(pixel_clk)
   begin
      if(rising_edge(pixel_clk)) then
         if(rst = '1') then
            hcounter <= (others => '0');
         elsif(hcounter = HMAX) then
            hcounter <= (others => '0');
         else
            hcounter <= hcounter + 1;
         end if;
      end if;
   end process h_count;

   -- increment vertical counter when one line is finished
   -- (horizontal counter reached HMAX)
   -- until VMAX is reached, then reset and keep counting
   v_count: process(pixel_clk)
   begin
      if(rising_edge(pixel_clk)) then
         if(rst = '1') then
            vcounter <= (others => '0');
         elsif(hcounter = HMAX) then
            if(vcounter = VMAX) then
               vcounter <= (others => '0');
            else
               vcounter <= vcounter + 1;
            end if;
         end if;
      end if;
   end process v_count;

   -- generate horizontal synch pulse
   -- when horizontal counter is between where the
   -- front porch ends and the synch pulse ends.
   -- The HS is active (with polarity SPP) for a total of 128 pixels.
   do_hs: process(pixel_clk)
   begin
      if(rising_edge(pixel_clk)) then
         if(hcounter >= HFP and hcounter < HSP) then
            HS <= SPP;
         else
            HS <= not SPP;
         end if;
      end if;
   end process do_hs;

   -- generate vertical synch pulse
   -- when vertical counter is between where the
   -- front porch ends and the synch pulse ends.
   -- The VS is active (with polarity SPP) for a total of 4 video lines
   -- = 4*HMAX = 4224 pixels.
   do_vs: process(pixel_clk)
   begin
      if(rising_edge(pixel_clk)) then
         if(vcounter >= VFP and vcounter < VSP) then
            VS <= SPP;
         else
            VS <= not SPP;
         end if;
      end if;
   end process do_vs;
   
   -- enable video output when pixel is in visible area
   video_enable <= '1' when (hcounter < HLINES and vcounter < VLINES) else '0';

end Behavioral;